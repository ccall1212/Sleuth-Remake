import asyncio
import subprocess
import sys
from pathlib import Path
import pytest
from PIL import Image
from mcp import Client
from mcp.client.stdio import StdioServerParameters
import server


@pytest.mark.parametrize('path', ['../README.md', 'C:/Windows/win.ini', 'src/data.png', 'reference/screenshots/a.png:secret'])
def test_path_rejection(path):
    with pytest.raises(ValueError):
        server.inside(path, ('test-results',), False)


def test_output_rejection():
    for name in ['../escape', 'C:/escape', 'bad name', 'a' * 65]:
        with pytest.raises(ValueError):
            server.output('test-results/screenshots', name)


def test_run_failure_timeout():
    failure = server.run_bounded([sys.executable, '-c', 'raise SystemExit(7)'], server.ROOT, 3)
    assert failure['exit_code'] == 7 and not failure['ok']
    timed = server.run_bounded([sys.executable, '-c', 'import time;time.sleep(10)'], server.ROOT, .1)
    assert timed['timed_out'] and not timed['ok']
    missing = server.run_bounded(['C:/not-a-real-executable.exe'], server.ROOT, 3)
    assert not missing['ok'] and missing['exit_code'] is None


def test_no_arbitrary_window_input(monkeypatch):
    configured = server.config()
    monkeypatch.setattr(server, 'config', lambda: {**configured, 'godot': None, 'godot_gui': None})
    assert not server.send_game_input(['ENTER'], 'remake')['ok']
    assert not server.send_game_input(['ALT+F4'])['ok']
    assert not server.send_mouse_input()['ok']
    assert not server.capture_game_screenshot(game='remake')['ok']
    assert not server.launch_remake()['ok']
    assert not server.reset_game('remake')['ok']
    assert server.stop_game('remake')['stopped'] is False
    assert not server.read_original_screen()['ok']
    for command in ['quit', 'restart', 'dir', 'question a\nquit', 'x' * 100]:
        assert not server.original_command(command)['ok']


def test_comparison():
    a = server.output('test-results/screenshots', 'synthetic-a')
    b = server.output('test-results/screenshots', 'synthetic-b')
    Image.new('RGB', (10, 10), 'red').save(a)
    Image.new('RGB', (10, 10), 'blue').save(b)
    assert server.compare_game_screenshots(str(a), str(a))['identical']
    assert server.compare_game_screenshots(str(a), str(b))['changed_pixels'] == 100
    assert not server.compare_game_screenshots('../README.md', str(a))['ok']
    Image.new('RGB', (12, 10), 'blue').save(b)
    assert not server.compare_game_screenshots(str(a), str(b))['same_dimensions']


def test_only_owned_process_stopped():
    unrelated = subprocess.Popen([sys.executable, '-c', 'import time;time.sleep(30)'])
    owned = subprocess.Popen([sys.executable, '-c', 'import time;time.sleep(30)'])
    try:
        server.PROCESSES['remake'] = {'process': owned, 'run_dir': 'test', 'log': 'test'}
        assert server.stop_game('remake')['stopped']
        assert owned.poll() is not None and unrelated.poll() is None
    finally:
        unrelated.terminate()
        unrelated.wait(timeout=5)
        server.PROCESSES.pop('remake', None)


def test_game_status_survives_snapshot_replacement(tmp_path, monkeypatch):
    from types import SimpleNamespace
    import json
    monkeypatch.setattr(server, 'ROOT', tmp_path)
    folder = tmp_path / 'test-results/remake-snapshot'
    folder.mkdir(parents=True)
    (folder / 'state.json').write_text(json.dumps({'guest_questioned': True}))
    validate = server.inside
    attempts = []
    def changing_snapshot(*args, **kwargs):
        attempts.append(1)
        if len(attempts) == 1:
            raise ValueError('Transient resolution during snapshot replacement')
        return validate(*args, **kwargs)
    monkeypatch.setattr(server, 'inside', changing_snapshot)
    monkeypatch.setattr(server, 'windows', lambda pid: [])
    server.PROCESSES['remake'] = {'process': SimpleNamespace(pid=123, poll=lambda: None), 'run_dir': str(folder)}
    try:
        result = server.get_game_status('remake')
        assert result['ok'] and result['game_state']['guest_questioned']
        assert len(attempts) == 2
    finally:
        server.PROCESSES.pop('remake', None)


def test_stdio_discovery_and_calls():
    async def check(mode):
        params = StdioServerParameters(command=sys.executable, args=[str(server.ROOT / 'tools/dos-game-mcp/server.py')], cwd=str(server.ROOT))
        async with Client(params, mode=mode, read_timeout_seconds=20) as client:
            listed = await client.list_tools()
            names = {t.name for t in listed.tools}
            assert len(names) == 18
            assert {'read_original_screen', 'original_command', 'original_move'} <= names
            for name in ['inspect_game_archive', 'get_game_environment', 'get_project_status', 'get_game_status']:
                result = await client.call_tool(name, {})
                assert not result.is_error and result.structured_content['ok']
            result = await client.call_tool('send_game_input', {'keys': ['ALT+F4']})
            assert not result.structured_content['ok']
            invalid = await client.call_tool('get_game_status', {'game': 'not-a-game'})
            assert invalid.is_error
    for mode in ['auto', 'legacy']:
        asyncio.run(check(mode))


@pytest.mark.parametrize('initial_exit', [None, 7])
def test_emulator_startup_timeout_and_failure(monkeypatch, initial_exit):
    class Child:
        pid = 123456
        returncode = initial_exit
        def poll(self):
            return self.returncode
        def terminate(self):
            self.returncode = 1
        def wait(self, timeout):
            return self.returncode
    child = Child()
    monkeypatch.setattr(server.subprocess, 'Popen', lambda *args, **kwargs: child)
    monkeypatch.setattr(server, 'windows', lambda pid: [])
    clock = iter([0, 100])
    monkeypatch.setattr(server.time, 'monotonic', lambda: next(clock))
    try:
        result = server.launch_original_game()
        assert not result['ok'] and result['exit_code'] is not None
        assert child.poll() is not None
    finally:
        server.PROCESSES.pop('original', None)


@pytest.mark.parametrize('reply', [b'BEGIN 1 OK\nPONG\nEND 1\n',
                                 b'BEGIN 1 ERR\nbad\nEND 1\n', b''])
def test_display_channel_framing(reply):
    import socket
    import threading
    channel = server.DosTextChannel()
    received = []
    def emulator():
        with socket.create_connection(('127.0.0.1', channel.port), timeout=2) as peer:
            received.append(peer.recv(1024))
            if reply:
                peer.sendall(reply)
    worker = threading.Thread(target=emulator)
    worker.start()
    try:
        if b' OK' in reply:
            assert channel.request('PING') == ['PONG']
        else:
            with pytest.raises(RuntimeError):
                channel.request('PING')
        assert received == [b'REQ 1 PING\n']
        with pytest.raises(ValueError):
            channel.request('EXEC MEMDUMPBIN 1000:0000 100 secret.bin')
    finally:
        channel.close()
        worker.join(timeout=3)


def test_display_page_selection(tmp_path, monkeypatch):
    monkeypatch.setattr(server, 'window', lambda game: 1)
    class Display:
        offset = b'\x00\x10'
        def request(self, command):
            if '0040:004E' in command:
                (tmp_path / 'display-offset.bin').write_bytes(self.offset)
                return ['success']
            assert command == 'EXEC MEMDUMPBIN B800:1000 FA0 screen.bin'
            data = bytearray(b' \x07' * 2000)
            for i, char in enumerate(b'Visible guest list >'):
                data[i*2] = char
            (tmp_path / 'screen.bin').write_bytes(data)
            return ['DEBUG: Memory dump binary success.']
    channel = Display()
    monkeypatch.setitem(server.PROCESSES, 'original', {'run_dir': str(tmp_path), 'text_channel': channel})
    assert server.original_screen_text().splitlines()[0] == 'Visible guest list >'
    channel.offset = b'\xff\xff'
    with pytest.raises(RuntimeError, match='Unsupported BIOS'):
        server.original_screen_text()


def test_original_command_requires_prompt(monkeypatch):
    monkeypatch.setattr(server, 'window', lambda game: 1)
    monkeypatch.setattr(server, 'original_screen_text', lambda: 'Select Basic Sleuth')
    monkeypatch.setattr(server, 'send_game_input', lambda *a: pytest.fail('Input sent at menu'))
    assert 'idle gameplay prompt' in server.original_command('guest')['error']


def test_original_move_checks_every_step(monkeypatch):
    def screen(x, y):
        rows = [' ' * 80 for _ in range(25)]
        rows[y] = rows[y][:x] + '\x02' + rows[y][x+1:]
        rows[23] = '>'
        return '\n'.join(rows)
    displays = iter([screen(21, 11), screen(23, 11), screen(23, 11)])
    monkeypatch.setattr(server, 'original_screen_text', lambda: next(displays))
    sent = []
    monkeypatch.setattr(server, 'send_game_input', lambda keys, *args: sent.append(keys) or {'ok': True})
    monkeypatch.setattr(server.time, 'sleep', lambda seconds: None)
    result = server.original_move('RIGHT', 10)
    assert result['ok'] and result['position'] == [23, 11]
    assert result['stop_reason'] == 'blocked' and len(sent) == 2
    assert result['trace'][-1] == {'from': [23, 11], 'to': [23, 11]}


def test_original_move_rejects_unverified_input(monkeypatch):
    monkeypatch.setattr(server, 'send_game_input', lambda *a: pytest.fail('Input unexpectedly sent'))
    for direction, steps in [('UP', 0), ('UP', 21), ('F10', 1)]:
        assert not server.original_move(direction, steps)['ok']
    monkeypatch.setattr(server, 'original_screen_text', lambda: 'Select an option')
    assert not server.original_move('UP')['ok']
    with pytest.raises(RuntimeError):
        server.original_player_position('no player')
    with pytest.raises(RuntimeError):
        server.original_player_position('\x02\x02')
