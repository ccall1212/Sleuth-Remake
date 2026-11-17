import asyncio
import pytest
from research_original import Survey, inspection_command, player, visible_path


def grid():
    rows = [['#'] * 80 for _ in range(17)]
    for y in range(1, 16):
        for x in range(1, 79):
            rows[y][x] = ' '
    rows[3][3] = '\x02'
    return rows


def text(rows):
    return '\n'.join(''.join(row) for row in rows) + '\n' * 8


def test_route_uses_door_and_checks_intermediate_columns():
    rows = grid()
    for y in range(1, 16):
        rows[y][4] = '#'
    rows[6][4] = ' '
    route = visible_path(text(rows), (3, 3), (7, 3))
    x, y = 3, 3
    directions = {'UP': (0, -1), 'DOWN': (0, 1), 'LEFT': (-2, 0), 'RIGHT': (2, 0)}
    crossings = []
    for step in route:
        dx, dy = directions[step]
        if dx and x+dx//2 == 4:
            crossings.append(y)
        x, y = x+dx, y+dy
    assert (x, y) == (7, 3) and crossings == [6]
    rows[6][4] = '#'
    with pytest.raises(RuntimeError, match='No visible route'):
        visible_path(text(rows), (3, 3), (7, 3))


def test_guest_column_parity_and_player_detection():
    rows = grid()
    rows[4][8] = '\x01'
    assert player(text(rows)) == (3, 3)
    route = visible_path(text(rows), (3, 3), (8, 4), near=True)
    assert route
    with pytest.raises(RuntimeError):
        visible_path(text(rows), (3, 3), (8, 4))
    rows[5][9] = '\x02'
    with pytest.raises(RuntimeError):
        player(text(rows))


def test_wide_layout_allows_central_doorway():
    rows = grid()
    assert visible_path(text(rows), (37, 4), (41, 4)) == ['RIGHT', 'RIGHT']
    rows[4][40] = '#'
    assert visible_path(text(rows), (37, 4), (41, 4)) != ['RIGHT', 'RIGHT']


def test_malformed_grid_is_rejected():
    with pytest.raises(RuntimeError):
        visible_path('not a map', (1, 1), (3, 1))


def test_short_inspection_uses_visible_head_noun():
    assert inspection_command('large bottle of tonic') == 'ex bottle'
    assert inspection_command('bronze figurine') == 'ex figurine'
    assert inspection_command('ornate clock in a wooden frame') == 'ex clock'


def test_survey_requires_glass_and_never_collects_weapon(tmp_path):
    class Client:
        async def call_tool(self, *args):
            pytest.fail('Gated command reached the emulator')
    survey = Survey(Client(), 1, tmp_path)
    for command in ['q', 'alibi example', 'examine floor']:
        with pytest.raises(RuntimeError, match='magnifying glass'):
            asyncio.run(survey.call('original_command', {'command': command}))
    survey.summary['has_magnifier'] = True
    for command in ['get', 'take', 'get weapon', 'take knife', 'get statue']:
        with pytest.raises(RuntimeError, match='leaves weapons'):
            asyncio.run(survey.call('original_command', {'command': command}))
    for command in ['assemble', 'gather', 'accuse example']:
        with pytest.raises(RuntimeError, match='accusation'):
            asyncio.run(survey.call('original_command', {'command': command}))


@pytest.mark.parametrize('confirmed', [False, True])
def test_survey_requires_pickup_confirmation(tmp_path, confirmed):
    survey = Survey(None, 1, tmp_path)
    survey.text = '\n' * 18 + 'A magnifying glass is lying on the floor.\n>'
    async def walk(*args):
        pass
    async def call(tool, arguments):
        assert tool == 'original_command' and arguments['command'] == 'get magnifying glass'
        return {'ok': True, 'text': 'carrying the magnifying glass' if confirmed else 'not found'}
    survey.walk = walk
    survey.call = call
    if confirmed:
        asyncio.run(survey.visit([(7, 12)]))
        assert survey.summary['has_magnifier']
    else:
        with pytest.raises(RuntimeError, match='not confirmed'):
            asyncio.run(survey.visit([(7, 12)]))
        assert not survey.summary.get('has_magnifier')
