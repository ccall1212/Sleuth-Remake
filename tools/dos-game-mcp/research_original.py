"""Bounded original-game observation through the project's official MCP client.

This surveys visible rooms and samples dialogue; it does not solve a case.
Original screen text and screenshots are written only to ignored test-results.
"""
import argparse
import asyncio
from collections import deque
import hashlib
import json
from pathlib import Path
import re
import sys
import time
import uuid

from mcp import Client
from mcp.client.stdio import StdioServerParameters

ROOT = Path(__file__).resolve().parents[2]
DIRECTIONS = {'UP': (0, -1), 'DOWN': (0, 1), 'LEFT': (-2, 0), 'RIGHT': (2, 0)}


def inspection_command(noun):
    """Use the visible object's head noun, e.g. a bottle of tonic -> ex bottle."""
    head = re.split(r'\s+(?:of|in|on|with|at)\s+', noun.lower(), maxsplit=1)[0].split()
    if not head or not all(word.isalpha() or '-' in word for word in head):
        raise ValueError('Expected a displayed object noun')
    return 'ex '+head[-1]


def player(text):
    found = [(x, y) for y, row in enumerate(text.split('\n')[:17])
             for x, char in enumerate(row) if char == '\x02']
    if len(found) != 1:
        raise RuntimeError('Expected one displayed player')
    return found[0]


def visible_path(text, start, goal, near=False):
    """BFS over displayed open cells, respecting the player's two-column stride.

    Guest markers can have a different column parity. Stop near them rather than
    trying to occupy their cell. Stair transfers are observed separately.
    """
    rows = text.split('\n')[:17]
    if len(rows) != 17 or any(len(row) > 80 for row in rows):
        raise RuntimeError('Expected the displayed floor-plan grid')
    rows = [row.ljust(80) for row in rows]
    queue = deque([(start, [])])
    seen = {start}
    while queue:
        (x, y), route = queue.popleft()
        reached = (abs(x-goal[0])/2 + abs(y-goal[1]) <= 1.5) if near else (x, y) == goal
        if reached:
            return route
        for key, (dx, dy) in DIRECTIONS.items():
            nx, ny = x+dx, y+dy
            if not (1 <= nx <= 77 and 1 <= ny <= 15) or (nx, ny) in seen:
                continue
            cells = [rows[ny][nx]]
            if dx:
                cells.append(rows[y][x+dx//2])
            if all(char in ' \x01\x02' for char in cells):
                seen.add((nx, ny))
                queue.append(((nx, ny), route+[key]))
    raise RuntimeError(f'No visible route from {start} to {goal}')


class Survey:
    def __init__(self, client, index, folder):
        self.client = client
        self.index = index
        self.folder = folder
        self.text = ''
        self.events = []
        self.started = time.monotonic()
        self.summary = {'case': index, 'completed': False, 'zones': [],
                        'encounters': [], 'screenshots': [], 'movement_keys': 0}

    async def call(self, tool, arguments=None):
        command = (arguments or {}).get('command', '')
        if tool == 'original_command':
            verb = command.split()[0] if command else ''
            if verb in ('get', 'take', 'pick') and command != 'get magnifying glass':
                raise RuntimeError('Survey leaves weapons in place until a separate solving step')
            if verb in ('assemble', 'gather', 'accuse'):
                raise RuntimeError('Survey cannot commit to an accusation')
            if verb in ('q', 'question', 'alibi', 'ex', 'examine') and not self.summary.get('has_magnifier'):
                raise RuntimeError('Collect the magnifying glass before investigation')
        if tool != 'stop_game' and (len(self.events) >= 400 or time.monotonic()-self.started > 180):
            raise RuntimeError('Survey action/time budget reached')
        result = await self.client.call_tool(tool, arguments or {})
        data = result.structured_content or {'ok': False, 'error': str(result.content)}
        self.events.append({'tool': tool, 'arguments': arguments or {}, 'result': data})
        if data.get('ok') and 'text' in data:
            self.text = data['text']
        if tool == 'original_move':
            self.summary['movement_keys'] += data.get('steps_sent', 0)
        return data

    async def wait_for(self, token):
        for _ in range(80):
            data = await self.call('read_original_screen')
            if token in data.get('text', ''):
                return
            await asyncio.sleep(.15)
        raise RuntimeError('Expected startup screen did not arrive')

    async def walk(self, goal, near=False):
        for _ in range(24):
            route = visible_path(self.text, player(self.text), goal, near)
            if not route:
                return
            key = route[0]
            count = 1
            while count < len(route) and route[count] == key:
                count += 1
            data = await self.call('original_move', {'direction': key, 'steps': min(count, 20)})
            if not data.get('ok') or data['stop_reason'] != 'completed':
                raise RuntimeError('Movement stopped unexpectedly; evidence retained')
        raise RuntimeError('Route segment budget reached')

    async def question_nearby(self, inspect_floor=False):
        guests = [(x, y) for y, row in enumerate(self.text.split('\n')[:17])
                  for x, char in enumerate(row) if char == '\x01']
        if not guests:
            return
        current = player(self.text)
        guest = min(guests, key=lambda p: abs(p[0]-current[0])/2+abs(p[1]-current[1]))
        await self.walk(guest, near=True)
        if inspect_floor:
            result = await self.call('original_command', {'command': 'ex floor'})
            if not result.get('ok'):
                raise RuntimeError('Floor inspection did not return a prompt')
            message = result['text'].lower()
            if 'bloodstain' in message and 'murder' in message:
                self.summary['murder_room_observation'] = {'position': list(player(self.text)),
                                                         'response': result['text']}
        encounter = {'position': list(player(self.text)), 'responses': []}
        name = None
        for prefix in ['q'] * 4:
            command = prefix + (' '+name.lower() if name else '')
            result = await self.call('original_command', {'command': command})
            if not result.get('ok'):
                raise RuntimeError('Question did not return a stable gameplay prompt')
            message = '\n'.join(self.text.split('\n')[18:]).strip()
            # Match a roster name, not an arbitrary word in a refusal or error.
            first = re.match(r'([A-Z][a-z]+)\b', message)
            if first and first[1] in self.names:
                name = first[1]
            encounter['responses'].append({'command': command, 'text': message})
        encounter['name'] = name
        self.summary['encounters'].append(encounter)
        screenshot = await self.call('capture_game_screenshot',
                                     {'label': f'survey-{self.index}-guest'})
        if screenshot.get('ok'):
            self.summary['screenshots'].append(screenshot['path'])
        print(json.dumps({'case': self.index, 'guest': name,
                          'responses': len(encounter['responses'])}), flush=True)

    async def visit(self, goals, investigate=False):
        for goal in goals:
            await self.walk(goal)
            description = '\n'.join(self.text.split('\n')[18:])
            self.summary['zones'].append({'target': list(goal), 'description': description,
                                         'phase': 'investigate' if investigate else 'find_glass'})
            if not investigate and not self.summary.get('has_magnifier') and 'magnifying glass' in description.lower():
                result = await self.call('original_command', {'command': 'get magnifying glass'})
                response = result.get('text', '').lower()
                if not result.get('ok') or 'carrying the magnifying glass' not in response:
                    raise RuntimeError('Magnifying glass pickup was not confirmed on screen')
                self.summary['has_magnifier'] = True
                self.summary['magnifier_at'] = list(goal)
                print(json.dumps({'case': self.index, 'magnifying_glass_collected': True}), flush=True)
            if investigate:
                # Inspect only nouns actually displayed in this room's description.
                nouns = re.findall(r'\b[Aa]n? ([A-Za-z -]{2,48}?) (?:lies|sits|hangs|protrudes|rests|is lying|is sitting)\b', description)
                for noun in dict.fromkeys(nouns):
                    result = await self.call('original_command', {'command': inspection_command(noun)})
                    if not result.get('ok'):
                        raise RuntimeError('Object inspection did not return a prompt')
                    if 'murder weapon' in result['text'].lower() and 'blood' in result['text'].lower():
                        self.summary['weapon_observation'] = {'target': list(goal), 'noun': noun,
                                                              'response': result['text']}
                await self.question_nearby(inspect_floor='staring at the floor' in description.lower())

    async def tour(self, split, investigate=False):
        if split:
            # Bring the player back down before repeating the ground-floor survey.
            if player(self.text)[0] > 40:
                await self.walk((61, 12))
                await self.call('original_move', {'direction': 'DOWN', 'steps': 4})
                await self.call('original_move', {'direction': 'UP', 'steps': 3})
            await self.visit([(7, 12), (7, 3), (31, 3), (31, 8), (31, 13)], investigate)
            await self.walk((17, 12))
            transfer = await self.call('original_move', {'direction': 'DOWN', 'steps': 4})
            if not transfer.get('ok') or transfer['position'][0] < 40:
                raise RuntimeError('Expected stair transfer was not observed')
            self.summary['stair_transfer'] = transfer['trace']
            await self.call('original_move', {'direction': 'UP', 'steps': 3})
            await self.visit([(49, 14), (49, 8), (49, 2), (69, 4), (69, 12)], investigate)
        else:
            await self.visit([(7, 12), (7, 4), (31, 2), (31, 10), (31, 14),
                              (49, 12), (71, 13), (71, 8), (71, 3)], investigate)

    async def run(self):
        try:
            if not (await self.call('launch_original_game')).get('ok'):
                raise RuntimeError('Original launch failed')
            await self.wait_for('PRESS ANY KEY')
            await self.call('send_game_input', {'keys': ['ENTER'], 'hold_ms': 20})
            await self.wait_for('Basic Sleuth')
            # Vary ordinary input timing; do not patch or seed the original RNG.
            await asyncio.sleep(.37*self.index)
            await self.call('send_game_input', {'keys': ['a'], 'hold_ms': 20})
            await self.wait_for('>')
            self.summary['introduction'] = '\n'.join(self.text.split('\n')[18:])
            roster = await self.call('original_command', {'command': 'guest'})
            if not roster.get('ok'):
                raise RuntimeError('Could not read guest roster')
            self.summary['roster'] = '\n'.join(self.text.split('\n')[18:])
            self.names = set(re.findall(r'\b([A-Z][a-z]+) [A-Z][a-z]+\b', self.summary['roster']))
            split = self.text.split('\n')[0][39] == ' '
            self.summary['layout'] = 'split' if split else 'wide'
            await self.call('original_move', {'direction': 'UP', 'steps': 5})
            await self.tour(split)
            if not self.summary.get('has_magnifier'):
                raise RuntimeError('Glass not found on visible route; investigation paused')
            await self.tour(split, investigate=True)
            self.summary['completed'] = True
        except RuntimeError as exc:
            self.summary['error'] = str(exc)
        finally:
            self.summary['stop_result'] = await self.call('stop_game')
            self.summary['seconds'] = round(time.monotonic()-self.started, 2)
            signature = self.summary.get('introduction', '') + self.summary.get('roster', '')
            self.summary['roster_fingerprint'] = hashlib.sha256(signature.encode()).hexdigest()
            path = self.folder / f'case-{self.index}.json'
            path.write_text(json.dumps({'summary': self.summary, 'events': self.events}, indent=2),
                            encoding='utf-8')
            print(json.dumps({'case': self.index, 'completed': self.summary['completed'],
                              'seconds': self.summary['seconds'], 'transcript': str(path),
                              'error': self.summary.get('error')}), flush=True)
        return self.summary


async def research(cases):
    folder = ROOT / 'test-results/original-research' / uuid.uuid4().hex[:12]
    folder.mkdir(parents=True)
    parameters = StdioServerParameters(command=sys.executable,
                                      args=[str(Path(__file__).with_name('server.py'))], cwd=str(ROOT))
    summaries = []
    async with Client(parameters, read_timeout_seconds=30) as client:
        for index in range(1, cases+1):
            summaries.append(await Survey(client, index, folder).run())
    (folder / 'summary.json').write_text(json.dumps(summaries, indent=2), encoding='utf-8')
    return all(s['completed'] for s in summaries)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cases', type=int, choices=range(1, 6), default=1)
    options = parser.parse_args()
    sys.exit(0 if asyncio.run(research(options.cases)) else 1)
