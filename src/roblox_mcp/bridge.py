"""
HTTP bridge between the MCP server and the Roblox Studio plugin.

Single port (7353) serves all three endpoints:
  POST /command  — MCP server sends a command
  GET  /poll     — Studio plugin picks up the next pending command
  POST /result   — Studio plugin returns the result
"""

import asyncio
import json
import logging
import uuid
from typing import Any

from aiohttp import web

logger = logging.getLogger(__name__)

PORT = 7353


class CommandBridge:
    def __init__(self):
        self._pending: dict[str, asyncio.Future] = {}
        self._queue: asyncio.Queue = asyncio.Queue()

    async def send(self, command: str, params: dict) -> dict:
        cmd_id = str(uuid.uuid4())
        future: asyncio.Future = asyncio.get_event_loop().create_future()
        self._pending[cmd_id] = future
        await self._queue.put({"id": cmd_id, "command": command, "params": params})
        try:
            return await asyncio.wait_for(future, timeout=25.0)
        except asyncio.TimeoutError:
            self._pending.pop(cmd_id, None)
            raise TimeoutError(f"Studio did not respond to '{command}' within 25s")

    async def poll(self) -> dict | None:
        try:
            return self._queue.get_nowait()
        except asyncio.QueueEmpty:
            try:
                return await asyncio.wait_for(self._queue.get(), timeout=5.0)
            except asyncio.TimeoutError:
                return None

    def resolve(self, cmd_id: str, result: Any):
        future = self._pending.pop(cmd_id, None)
        if future and not future.done():
            future.set_result(result)


bridge = CommandBridge()


async def handle_command(request: web.Request) -> web.Response:
    body = await request.json()
    try:
        result = await bridge.send(body["command"], body.get("params", {}))
        return web.json_response(result)
    except TimeoutError as e:
        return web.json_response({"success": False, "error": str(e)}, status=504)
    except Exception as e:
        return web.json_response({"success": False, "error": str(e)}, status=500)


async def handle_poll(request: web.Request) -> web.Response:
    item = await bridge.poll()
    return web.json_response(item or {})


async def handle_result(request: web.Request) -> web.Response:
    body = await request.json()
    bridge.resolve(body.get("id", ""), body.get("result", {}))
    return web.json_response({"ok": True})


def create_app() -> web.Application:
    app = web.Application()
    app.router.add_post("/command", handle_command)
    app.router.add_get("/poll", handle_poll)
    app.router.add_post("/result", handle_result)
    return app


async def run_bridge():
    app = create_app()
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, "localhost", PORT)
    await site.start()
    logger.info(f"Bridge listening on http://localhost:{PORT}")
    await asyncio.Event().wait()


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    asyncio.run(run_bridge())
