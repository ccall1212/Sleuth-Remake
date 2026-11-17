"""Loopback room reviewer plus an explicit whitelist of character preview PNGs."""
import argparse
import hashlib
import json
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
ROOMS = ROOT / 'assets/rooms/house-02'


def run(port):
    manifest = json.loads((ROOMS / 'furnishing-review/guest-preview-data.json').read_text())
    whitelist = {}
    for records in manifest['actors'].values():
        for record in records:
            path = (ROOT / record['source']).resolve()
            assert path.is_relative_to(ROOT / 'assets/characters/poses')
            assert hashlib.sha256(path.read_bytes()).hexdigest() == record['sha256']
            whitelist[record['url']] = path

    class Handler(SimpleHTTPRequestHandler):
        def translate_path(self, path):
            url = unquote(urlsplit(path).path)
            if url in whitelist:
                return str(whitelist[url])
            resolved = (ROOMS / url.lstrip('/')).resolve()
            return str(resolved if resolved.is_relative_to(ROOMS) else ROOMS / '_not_found_')

        def list_directory(self, path):
            self.send_error(404)
            return None

        def end_headers(self):
            self.send_header('Cache-Control', 'no-cache')
            super().end_headers()

    print(f'House review: http://127.0.0.1:{port}/furnishing-review/', flush=True)
    ThreadingHTTPServer(('127.0.0.1', port), partial(Handler, directory=str(ROOMS))).serve_forever()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=8796)
    run(parser.parse_args().port)
