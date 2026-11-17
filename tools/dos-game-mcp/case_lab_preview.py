"""Open an owned case-lab window for human playtesting; close it when finished."""
import argparse
import asyncio
import json
import sys
from pathlib import Path
from mcp import Client
from mcp.client.stdio import StdioServerParameters

ROOT = Path(__file__).resolve().parents[2]


async def main(seed):
    params = StdioServerParameters(command=sys.executable,
        args=[str(Path(__file__).with_name('server.py'))], cwd=str(ROOT))
    async with Client(params, read_timeout_seconds=90) as client:
        async def call(name, **arguments):
            result = (await client.call_tool(name, arguments)).structured_content
            if not result or not result.get('ok'):
                raise RuntimeError(result)
            return result
        try:
            await call('launch_remake', mode='case_lab', case_seed=seed)
            capture = await call('capture_game_screenshot', game='remake', label='case-lab-start')
            print(json.dumps({'ready': True, 'seed': seed, 'capture': capture['path']}), flush=True)
            while (await call('get_game_status', game='remake')).get('running', False):
                await asyncio.sleep(2)
        finally:
            await call('stop_game', game='remake')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seed', type=int, default=1)
    seed = parser.parse_args().seed
    if not 0 <= seed <= 2147483647:
        parser.error('--seed must be from 0 to 2147483647')
    asyncio.run(main(seed))
