"""Project-specific stdio MCP. No tool accepts shell commands or executable paths."""
import atexit
import hashlib
import json
import os
import platform
import re
import shutil
import socket
import subprocess
import sys
import threading
import time
import uuid
from functools import wraps
from pathlib import Path
from typing import Any, Literal

from mcp.server import MCPServer
from PIL import Image, ImageChops, ImageGrab, ImageStat
from archive import inventory

ROOT = Path(__file__).resolve().parents[2]
LOCAL = Path(__file__).with_name('local.json')
Game = Literal['original', 'remake']
mcp = MCPServer('sleuth-game-dev')
LOCK = threading.RLock()
PROCESSES = {}


def config():
    return json.loads(LOCAL.read_text(encoding='utf-8'))


def inside(path: str, bases: tuple[str, ...], exists=True) -> Path:
    p = Path(path)
    if not p.is_absolute():
        p = ROOT / p
    if '..' in p.parts or ':' in str(p)[3:]:
        raise ValueError('Traversal or alternate data streams are forbidden')
    p = p.resolve()
    if not p.is_relative_to(ROOT) or not any(p.is_relative_to((ROOT / base).resolve()) for base in bases):
        raise ValueError('Path outside approved project directories')
    if exists and not p.is_file():
        raise ValueError('File does not exist')
    return p


def output(base, name):
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,64}', name):
        raise ValueError('Use a simple filename label, 1–64 letters, digits, underscores or hyphens')
    p = inside(f'{base}/{name}-{uuid.uuid4().hex[:10]}.png', (base,), False)
    p.parent.mkdir(parents=True, exist_ok=True)
    return p


def tool(fn):
    @wraps(fn)
    def safe(*args, **kwargs):
        with LOCK:
            try:
                return fn(*args, **kwargs)
            except (ValueError, OSError, RuntimeError, subprocess.SubprocessError) as exc:
                return {'ok': False, 'error': str(exc), 'action': fn.__name__}
    mcp.tool(structured_output=True)(safe)
    return safe


def run_bounded(command, cwd, timeout):
    """Internal fixed-command runner. No shell and no input from MCP callers."""
    try:
        p = subprocess.run(command, cwd=cwd, capture_output=True, timeout=timeout,
                           text=True, encoding='utf-8', errors='replace', shell=False)
        return {'ok': p.returncode == 0, 'exit_code': p.returncode,
                'stdout': p.stdout[-24000:], 'stderr': p.stderr[-12000:], 'timed_out': False}
    except subprocess.TimeoutExpired:
        return {'ok': False, 'exit_code': None, 'timed_out': True, 'error': 'Execution time limit exceeded; child killed and waited'}
    except OSError as exc:
        return {'ok': False, 'exit_code': None, 'timed_out': False, 'error': str(exc)}


def windows(pid):
    import win32gui
    import win32process
    found = []
    def visit(hwnd, _):
        if win32gui.IsWindowVisible(hwnd) and win32process.GetWindowThreadProcessId(hwnd)[1] == pid:
            if win32gui.GetClientRect(hwnd)[2] > 100:
                found.append(hwnd)
    win32gui.EnumWindows(visit, None)
    return found


def window(game):
    state = PROCESSES.get(game)
    if not state or state['process'].poll() is not None:
        raise RuntimeError('No running game owned by this MCP session; launch it first')
    found = windows(state['process'].pid)
    if len(found) != 1:
        raise RuntimeError(f'Expected one visible owned window, found {len(found)}')
    return found[0]


@tool
def inspect_game_archive() -> dict[str, Any]:
    """Inspect the fixed reference archive as data, with path and size validation."""
    result = inventory(Path(config()['archive']))
    return {'ok': result['sha256'] == config()['archive_sha256'], **result}


@tool
def get_game_environment() -> dict[str, Any]:
    """Report configured paths and supported capabilities, without launching anything."""
    c = config()
    return {'ok': True, 'os': platform.platform(), 'python': sys.version, 'python_executable': sys.executable,
            'project': str(ROOT), 'emulator': c['emulator'], 'emulator_exists': Path(c['emulator']).is_file(),
            'archive': c['archive'], 'reference': str(ROOT / 'reference/original'),
            'keyboard': 'PID-targeted Win32 key messages; verify gameplay with screenshots',
            'screenshot': 'Windows PrintWindow through Pillow; surface output configured',
            'mouse': 'unavailable: both prototypes use keyboard controls',
            'reset': 'fresh process, fresh working copy; random mystery is not deterministic',
            'remake': 'playable 2D foyer; Godot project main scene', 'godot': c.get('godot')}


@tool
def get_project_status() -> dict[str, Any]:
    """Report project structure and the current initialization scope."""
    return {'ok': True, 'entries': sorted(p.name for p in ROOT.iterdir()),
            'tests': sorted(str(p.relative_to(ROOT)) for p in (ROOT / 'tests').glob('test_*.py')),
            'engine': 'Godot 4 / GDScript, 2D pixel-art haunted mansion', 'remake_playable': (ROOT / 'src/foyer/foyer.tscn').is_file(),
            'plan': str(ROOT / 'docs/DEVELOPMENT_PLAN.md')}


@tool
def launch_original_game() -> dict[str, Any]:
    """Launch the verified SLEUTH0.EXE in DOSBox-X, mounting only a disposable game copy."""
    if PROCESSES.get('original') and PROCESSES['original']['process'].poll() is None:
        return {'ok': False, 'error': 'Original already running in this session'}
    previous = PROCESSES.get('original', {}).get('text_channel')
    if previous:
        previous.close()
    c = config()
    report = json.loads(inside('reference/inventory.json', ('reference',)).read_text())
    source = inside('reference/original/SLEUTH0.EXE', ('reference/original',))
    for entry in report['files']:
        if entry['directory']:
            continue
        p = inside('reference/original/' + entry['name'], ('reference/original',))
        if hashlib.sha256(p.read_bytes()).hexdigest() != entry['sha256']:
            raise ValueError('Reference file differs from inventory: ' + entry['name'])
    if source.read_bytes()[:2] != b'MZ':
        raise ValueError('Expected a DOS MZ executable')
    emulator = Path(c['emulator'])
    if hashlib.sha256(emulator.read_bytes()).hexdigest() != c['emulator_sha256']:
        raise ValueError('Emulator changed; reverify local configuration')
    run_dir = inside('test-results/run-' + uuid.uuid4().hex, ('test-results',), False)
    run_dir.mkdir(parents=True)
    shutil.copytree(ROOT / 'reference/original', run_dir / 'game')
    # Both paths originate in our fixed project root; never insert model input into DOS commands.
    mount = str(run_dir / 'game')
    if any(ch in mount for ch in '\r\n"'):
        raise ValueError('Project path is not representable safely in DOSBox config')
    channel = DosTextChannel()
    conf = run_dir / 'dosbox.conf'
    conf.write_text('[sdl]\nfullscreen=false\noutput=surface\nshowmenu=false\nautolock=false\n'
                    '[cpu]\ncore=normal\ncycles=fixed 1000\n[render]\naspect=true\nscaler=none\n'
                    f'[dosbox]\nmachine=vgaonly\nmemsize=16\nmcp_server={channel.port}\n[autoexec]\n@echo off\n'
                    f'mount c "{mount}"\nc:\nSLEUTH0.EXE\nexit\n', encoding='utf-8')
    log = run_dir / 'emulator.log'
    try:
        with log.open('wb') as stream:
            p = subprocess.Popen([str(emulator), '-conf', str(conf), '-defaultdir', str(run_dir), '-noconsole'],
                                 cwd=run_dir, stdout=stream, stderr=subprocess.STDOUT, shell=False)
    except OSError:
        channel.close()
        raise
    PROCESSES['original'] = {'process': p, 'run_dir': str(run_dir), 'log': str(log), 'text_channel': channel}
    deadline = time.monotonic() + 12
    while p.poll() is None and time.monotonic() < deadline:
        if len(windows(p.pid)) == 1:
            return {'ok': True, 'pid': p.pid, 'window_verified': True, 'gameplay_verified': False,
                    'run_dir': str(run_dir), 'note': 'Capture screenshot to verify actual game startup'}
        time.sleep(.15)
    if p.poll() is None:
        p.terminate()
        p.wait(timeout=5)
    channel.close()
    return {'ok': False, 'exit_code': p.poll(), 'error': 'No unique game window within startup timeout', 'log': str(log)}


@tool
def launch_remake(mode: Literal['mansion', 'case_lab'] = 'mansion', case_seed: int = 1) -> dict[str, Any]:
    """Launch the mansion or placeholder case lab through fixed scene allowlists."""
    if mode not in ('mansion', 'case_lab') or not 0 <= case_seed <= 2147483647:
        raise ValueError('Use a supported scene and a seed from 0 to 2147483647')
    if PROCESSES.get('remake') and PROCESSES['remake']['process'].poll() is None:
        return {'ok': False, 'error': 'Remake already running in this session'}
    value = config().get('godot_gui')
    if not value or not Path(value).is_file():
        return {'ok': False, 'error': 'Configure the installed Godot console executable using setup_local.py --godot'}
    godot = Path(value)
    if config().get('godot_gui_sha256') != hashlib.sha256(godot.read_bytes()).hexdigest():
        return {'ok': False, 'error': 'Godot binary changed or has no recorded hash; rerun setup_local.py with --godot'}
    run_dir = inside('test-results/remake-' + uuid.uuid4().hex, ('test-results',), False)
    run_dir.mkdir(parents=True)
    imported = run_bounded([str(godot), '--headless', '--path', str(ROOT), '--editor', '--import', '--quit'], ROOT, 30)
    if not imported['ok']:
        return {'ok': False, 'error': 'Godot resource import failed', 'diagnostics': imported}
    log = run_dir / 'remake.log'
    session_path = 'res://' + run_dir.relative_to(ROOT).as_posix()
    scene_args = ['res://src/mystery/case_lab.tscn'] if mode == 'case_lab' else []
    with log.open('wb') as stream:
        p = subprocess.Popen([str(godot), '--path', str(ROOT), '--rendering-method', 'gl_compatibility',
                              *scene_args, '--', '--dev-session=' + session_path,
                              '--case-seed=' + str(case_seed)], cwd=ROOT,
                             stdout=stream, stderr=subprocess.STDOUT, shell=False,
                             creationflags=subprocess.CREATE_NO_WINDOW)
    PROCESSES['remake'] = {'process': p, 'run_dir': str(run_dir), 'log': str(log)}
    deadline = time.monotonic() + 15
    while p.poll() is None and time.monotonic() < deadline:
        if len(windows(p.pid)) == 1 and (run_dir / 'state.json').is_file():
            return {'ok': True, 'pid': p.pid, 'window_verified': True, 'run_dir': str(run_dir), 'scene': 'case_lab' if mode == 'case_lab' else 'foyer'}
        time.sleep(.15)
    stop_game('remake')
    return {'ok': False, 'error': 'Godot did not report a ready foyer and unique window in time', 'log': str(log)}


@tool
def get_game_status(game: Game = 'original') -> dict[str, Any]:
    """Report only processes owned by this server instance."""
    state = PROCESSES.get(game)
    if not state:
        return {'ok': True, 'running': False, 'owned': False, 'exit_code': None}
    p = state['process']
    result = {'ok': True, 'running': p.poll() is None, 'owned': True, 'pid': p.pid,
            'exit_code': p.poll(), 'run_dir': state['run_dir'],
            'windows': windows(p.pid) if p.poll() is None else []}
    if game == 'remake':
        # Godot atomically replaces this rolling snapshot. Retry transient Windows
        # resolution/read races without relaxing the approved-path validation.
        for attempt in range(5):
            try:
                path = inside(state['run_dir'] + '/state.json', ('test-results',), False)
                if path.is_file():
                    result['game_state'] = json.loads(path.read_text(encoding='utf-8'))
                break
            except (OSError, ValueError):
                if attempt == 4:
                    raise
                time.sleep(.02)
    return result


@tool
def stop_game(game: Game = 'original') -> dict[str, Any]:
    """Terminate and wait for only the child process owned by this server."""
    state = PROCESSES.get(game)
    if state and state.get('text_channel'):
        state['text_channel'].close()
    if not state or state['process'].poll() is not None:
        return {'ok': True, 'stopped': False, 'reason': 'No owned running process'}
    p = state['process']
    p.terminate()
    try:
        p.wait(timeout=5)
    except subprocess.TimeoutExpired:
        p.kill()
        p.wait(timeout=5)
    return {'ok': p.poll() is not None, 'stopped': True, 'exit_code': p.returncode}


@tool
def send_game_input(keys: list[str], game: Game = 'original', hold_ms: int = 40) -> dict[str, Any]:
    """Send up to 120 keys directly to the owned HWND. No global keyboard injection.

    Use single lowercase letters, digits, space, or ENTER/ESC/BACKSPACE/UP/DOWN/LEFT/RIGHT/F6.
    OS delivery does not prove the game consumed the keys; inspect a follow-up screenshot.
    """
    import win32api
    import win32con
    import win32gui
    import win32process
    special = {'ENTER': 13, 'ESC': 27, 'BACKSPACE': 8, 'UP': 38, 'DOWN': 40, 'LEFT': 37, 'RIGHT': 39, 'F4': 115, 'F6': 117, 'F7': 118, 'F8': 119, 'F10': 121, 'F11': 122}
    if not 20 <= hold_ms <= 1000 or len(keys) * (hold_ms + 240) > 45000:
        raise ValueError('Hold 20–1000ms per key, maximum batch duration 45 seconds')
    if not 1 <= len(keys) <= 120:
        raise ValueError('Send 1–120 keys')
    codes = []
    for key in keys:
        if key in special:
            codes.append(special[key])
        elif re.fullmatch('[a-z0-9 ]', key):
            codes.append(ord(key.upper()))
        else:
            raise ValueError('Unsupported key: ' + key)
    # Char's first pose preview can load large approved PNGs and room navigation.
    # Keep input HWND-owned and bounded while allowing that work to finish.
    if sum(hold_ms + 40 + 2 * (3000 if code in [118, 119, 122] else 100) for code in codes) > 45000:
        raise ValueError('Input batch exceeds the 45-second bound including action timeouts')
    hwnd = window(game)
    pid = PROCESSES[game]['process'].pid
    for vk in codes:
        if not win32gui.IsWindow(hwnd) or win32process.GetWindowThreadProcessId(hwnd)[1] != pid:
            raise RuntimeError('Owned window disappeared; input aborted')
        scan = win32api.MapVirtualKey(vk, 0)
        timeout_ms = 3000 if vk in [118, 119, 122] else 100
        flags = 1 | (scan << 16) | ((1 << 24) if vk in (37, 38, 39, 40) else 0)
        win32gui.SendMessageTimeout(hwnd, win32con.WM_KEYDOWN, vk, flags, win32con.SMTO_ABORTIFHUNG, timeout_ms)
        time.sleep(hold_ms / 1000)
        win32gui.SendMessageTimeout(hwnd, win32con.WM_KEYUP, vk, flags | (3 << 30), win32con.SMTO_ABORTIFHUNG, timeout_ms)
        time.sleep(.04)
    return {'ok': True, 'keys_delivered_to_window': len(codes), 'hwnd': hwnd, 'game_consumption_verified': False}


@tool
def send_mouse_input(game: Game = 'original') -> dict[str, Any]:
    """Report the unavailable mouse adapter; no cursor or mouse messages are emitted."""
    return {'ok': False, 'status': 'unsupported', 'error': 'Original and foyer prototype use keyboard controls; no mouse adapter is needed yet.'}


class DosTextChannel:
    """Private loopback channel for the owned emulator's visible text buffer only."""
    def __init__(self):
        self.listener = socket.socket()
        self.listener.bind(('127.0.0.1', 0))
        self.listener.listen(1)
        self.listener.settimeout(3)
        self.port = self.listener.getsockname()[1]
        self.connection = None
        self.reader = None
        self.serial = 0

    def request(self, command):
        # Never expose raw debugger commands, addresses or filenames to MCP callers.
        if command not in ('PING', 'EXEC MEMDUMPBIN 0040:004E 2 display-offset.bin',
                            *(f'EXEC MEMDUMPBIN B800:{offset:04X} FA0 screen.bin'
                              for offset in range(0, 0x8000, 0x1000))):
            raise ValueError('Unsupported display-channel operation')
        try:
            if self.connection is None:
                self.connection, _ = self.listener.accept()
                self.connection.settimeout(3)
                self.reader = self.connection.makefile('rb')
                self.listener.close()
            self.serial += 1
            ident = str(self.serial)
            self.connection.sendall(f'REQ {ident} {command}\n'.encode('ascii'))
            lines = []
            started = False
            for _ in range(256):
                raw = self.reader.readline(4097)
                if not raw or len(raw) > 4096:
                    raise RuntimeError('Emulator display channel closed or oversized response')
                line = raw.decode('utf-8', errors='replace').strip()
                if line == f'BEGIN {ident} OK':
                    started = True
                elif line == f'END {ident}' and started:
                    return lines
                elif started:
                    lines.append(line)
                elif line.startswith(f'BEGIN {ident} ERR'):
                    raise RuntimeError('Emulator rejected display capture')
            raise RuntimeError('Emulator display response exceeded limit')
        except (OSError, RuntimeError):
            self.close()
            raise

    def close(self):
        if self.reader is not None:
            self.reader.close()
        if self.connection is not None:
            self.connection.close()
        self.listener.close()


def original_screen_text():
    """Read only the 80x25 visible color text page, without clipboard or CPU changes."""
    window('original')
    state = PROCESSES['original']
    channel = state.get('text_channel')
    if channel is None:
        raise RuntimeError('Relaunch the owned original to enable the text channel')
    metadata = Path(state['run_dir']) / 'display-offset.bin'
    metadata.unlink(missing_ok=True)
    channel.request('EXEC MEMDUMPBIN 0040:004E 2 display-offset.bin')
    value = metadata.read_bytes()
    if len(value) != 2:
        raise RuntimeError('Invalid BIOS display page offset')
    offset = int.from_bytes(value, 'little')
    if offset not in range(0, 0x8000, 0x1000):
        raise RuntimeError('Unsupported BIOS text page offset')
    path = Path(state['run_dir']) / 'screen.bin'
    path.unlink(missing_ok=True)
    response = channel.request(f'EXEC MEMDUMPBIN B800:{offset:04X} FA0 screen.bin')
    if not any('binary success' in line for line in response):
        raise RuntimeError('Emulator did not confirm visible text capture')
    data = path.read_bytes()
    if len(data) != 4000:
        raise RuntimeError('Expected an 80x25 DOS color text page')
    # Attribute bytes are excluded. No code, game variables or other memory is read.
    chars = data[::2].replace(b'\x00', b' ')
    text = '\n'.join(chars[y*80:(y+1)*80].decode('cp437').rstrip() for y in range(25))
    if not text.strip():
        raise RuntimeError('Display is blank or transitioning; retry after startup')
    return text


@tool
def read_original_screen() -> dict[str, Any]:
    """Read the owned visible DOS text screen without OCR or clipboard access."""
    try:
        text = original_screen_text()
    except Exception as exc:
        return {'ok': False, 'error': str(exc), 'action': 'read_original_screen'}
    return {'ok': True, 'text': text,
            'screen_sha256': hashlib.sha256(text.encode('utf-8')).hexdigest(),
            'method': 'DOSBox-X fixed visible video text buffer',
            'hidden_game_state': False}


def original_player_position(text):
    """Locate the displayed yellow smiley; no hidden world coordinates are read."""
    positions = [[x, y] for y, row in enumerate(text.split('\n')[:18])
                 for x, char in enumerate(row) if char == '\x02']
    if len(positions) != 1:
        raise RuntimeError('Expected one visible player marker in the floor plan')
    return positions[0]


@tool
def original_move(direction: Literal['UP', 'DOWN', 'LEFT', 'RIGHT'], steps: int = 1) -> dict[str, Any]:
    """Walk up to 20 cells, observe each step and stop on a wall or changed prompt."""
    if direction not in ('UP', 'DOWN', 'LEFT', 'RIGHT') or not 1 <= steps <= 20:
        raise ValueError('Use an arrow direction and 1–20 steps')
    text = original_screen_text()
    if not any(row.strip() in ('>', '>_') for row in text.split('\n')[-4:]):
        raise RuntimeError('Expected an idle gameplay prompt before movement')
    start = position = original_player_position(text)
    trace = []
    reason = 'completed'
    for _ in range(steps):
        sent = send_game_input([direction], 'original', 20)
        if not sent.get('ok'):
            return sent
        time.sleep(.05)
        text = original_screen_text()
        after = original_player_position(text)
        trace.append({'from': position, 'to': after})
        if after == position:
            reason = 'blocked'
            break
        position = after
        if not any(row.strip() in ('>', '>_') for row in text.split('\n')[-4:]):
            reason = 'prompt_changed'
            break
    return {'ok': True, 'direction': direction, 'requested_steps': steps,
            'steps_sent': len(trace), 'start': start, 'position': position,
            'trace': trace, 'stop_reason': reason, 'text': text,
            'hidden_game_state': False}


@tool
def original_command(command: str) -> dict[str, Any]:
    """Send one bounded gameplay command and return the resulting DOS text screen.

    Not a shell: only the original game's question/examine/evidence verbs are allowed.
    """
    command = command.strip().lower()
    if not re.fullmatch(r'[a-z][a-z ]{0,58}', command):
        raise ValueError('Use a short alphabetic game command')
    verbs = {'q', 'question', 'alibi', 'ex', 'examine', 'search', 'look',
             'get', 'take', 'drop', 'gather', 'assemble', 'accuse', 'guest',
             'people', 'help', 'knock'}
    if command.split()[0] not in verbs:
        raise ValueError('Unsupported gameplay verb')
    window('original')
    started = time.monotonic()
    before = original_screen_text()
    if not any(row.strip() in ('>', '>_') for row in before.splitlines()[-4:]):
        raise RuntimeError('Expected an idle gameplay prompt; finish the menu or dialogue first')
    sent = send_game_input(['ESC'] + list(command) + ['ENTER'], 'original', 20)
    if not sent.get('ok'): return sent
    deadline = time.monotonic() + 3
    previous = None
    while time.monotonic() < deadline:
        time.sleep(.08)
        result = read_original_screen()
        text = result.get('text', '')
        if result.get('ok') and text == previous and any(
                row.strip() in ('>', '>_') for row in text.splitlines()[-4:]):
            break
        previous = text
    else:
        return {'ok': False, 'command': command, 'error': 'No stable gameplay prompt after command',
                'last_screen': result}
    result.update(command=command, elapsed_seconds=round(time.monotonic()-started, 3),
                  note='Visible text only; inspect prompt before issuing another command')
    return result


@tool
def capture_game_screenshot(label: str = 'capture', game: Game = 'original', reference: bool = False) -> dict[str, Any]:
    """Capture owned DOSBox with PrintWindow or the ready Godot viewport. Return a unique PNG path."""
    hwnd = window(game)
    if game == 'remake':
        run_dir = Path(PROCESSES[game]['run_dir'])
        capture = inside(str(run_dir / 'capture.png'), ('test-results',), False)
        if capture.exists():
            capture.unlink()
        inside(str(run_dir / 'capture.request'), ('test-results',), False).touch()
        deadline = time.monotonic() + 5
        while not capture.is_file() and time.monotonic() < deadline:
            time.sleep(.05)
        if not capture.is_file():
            raise RuntimeError('Godot viewport capture timed out')
        with Image.open(capture) as source:
            image = source.copy()
    else:
        image = ImageGrab.grab(window=hwnd)
    if min(image.size) < 100 or sum(ImageStat.Stat(image.convert('RGB')).var) < 1:
        raise RuntimeError('Capture is empty or uniform; no usable screenshot confirmed')
    path = output('reference/screenshots' if reference else 'test-results/screenshots', label)
    image.save(path)
    return {'ok': True, 'path': str(path), 'width': image.width, 'height': image.height,
            'method': 'Godot viewport' if game == 'remake' else 'PrintWindow', 'hwnd': hwnd,
            'capture_region': 'game viewport' if game == 'remake' else 'owned window as returned by PrintWindow'}


@tool
def reset_game(game: Game = 'original') -> dict[str, Any]:
    """Restart the owned game. Original mystery RNG is not deterministic."""
    stopped = stop_game(game)
    if not stopped['ok']:
        return stopped
    return launch_original_game() if game == 'original' else launch_remake()


@tool
def read_game_logs(game: Game = 'original') -> dict[str, Any]:
    """Read bounded emulator or Godot stdout/stderr from an owned launch directory."""
    state = PROCESSES.get(game)
    if not state:
        return {'ok': False, 'error': 'No launch log for this session'}
    path = inside(state['log'], ('test-results',))
    with path.open('rb') as stream:
        stream.seek(max(0, path.stat().st_size - 24000))
        content = stream.read(24000).decode('utf-8', errors='replace')
    return {'ok': True, 'path': str(path), 'text': content,
            'note': 'Godot diagnostics; live state is in get_game_status' if game == 'remake' else 'Emulator diagnostics, not game state or parsed DOS output'}


@tool
def run_project_tests() -> dict[str, Any]:
    """Run the fixed pytest suite, bounded to 90 seconds, and persist JSON/JUnit results."""
    report = inside('test-results/pytest.xml', ('test-results',), False)
    report.parent.mkdir(parents=True, exist_ok=True)
    result = run_bounded([sys.executable, '-m', 'pytest', 'tests', '-q', '--junitxml=' + str(report)], ROOT, 90)
    result.update({'junit': str(report), 'timestamp': time.time()})
    inside('test-results/latest-tests.json', ('test-results',), False).write_text(json.dumps(result, indent=2), encoding='utf-8')
    return result


@tool
def get_test_results() -> dict[str, Any]:
    """Return the latest persisted pytest exit code and diagnostics."""
    p = inside('test-results/latest-tests.json', ('test-results',), False)
    return json.loads(p.read_text()) if p.exists() else {'ok': False, 'error': 'No recorded test run; call run_project_tests'}


@tool
def compare_game_screenshots(first: str, second: str) -> dict[str, Any]:
    """Compare PNGs inside screenshot directories. Differences are diagnostic, not state equivalence."""
    bases = ('reference/screenshots', 'test-results/screenshots')
    paths = [inside(first, bases), inside(second, bases)]
    if any(p.suffix.lower() != '.png' for p in paths):
        raise ValueError('Only PNG captures supported')
    with Image.open(paths[0]) as a, Image.open(paths[1]) as b:
        if a.size != b.size:
            return {'ok': True, 'same_dimensions': False, 'sizes': [a.size, b.size], 'identical': False}
        diff = ImageChops.difference(a.convert('RGB'), b.convert('RGB'))
        changed = sum(1 for pixel in diff.get_flattened_data() if pixel != (0, 0, 0))
        return {'ok': True, 'same_dimensions': True, 'identical': changed == 0,
                'changed_pixels': changed, 'changed_fraction': changed / (a.width * a.height),
                'mean_absolute_channel_difference': sum(ImageStat.Stat(diff).mean) / 3,
                'note': 'Window frames, time, animation and RNG affect this diagnostic'}


def cleanup():
    for game in list(PROCESSES):
        stop_game(game)


atexit.register(cleanup)
if __name__ == '__main__':
    try:
        mcp.run(transport='stdio')
    finally:
        cleanup()
