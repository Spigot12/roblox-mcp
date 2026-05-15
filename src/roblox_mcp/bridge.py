"""
HTTP bridge between the MCP server and the Roblox Studio plugin.

Architecture:
  MCP Server (port 7353)  <-->  Bridge (port 7354)  <-->  Studio Plugin (polls bridge)

The Studio plugin cannot receive inbound HTTP — it can only make outbound requests.
So the bridge acts as a queue: MCP server POSTs commands to port 7353 (forwarded here),
the plugin GETs /poll to pick them up, then POSTs /result back.
"""

import asyncio
import json
import logging
import uuid
from typing import Any

from aiohttp import web

logger = logging.getLogger(__name__)

BRIDGE_PORT = 7354
MCP_FACING_PORT = 7353


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
            return None

    def resolve(self, cmd_id: str, result: Any):
        future = self._pending.pop(cmd_id, None)
        if future and not future.done():
            future.set_result(result)


bridge = CommandBridge()


async def handle_command(request: web.Request) -> web.Response:
    """MCP server → bridge: POST /command  {command, params}"""
    body = await request.json()
    command = body.get("command")
    params = body.get("params", {})
    try:
        result = await bridge.send(command, params)
        return web.json_response(result)
    except TimeoutError as e:
        return web.json_response({"success": False, "error": str(e)}, status=504)
    except Exception as e:
        return web.json_response({"success": False, "error": str(e)}, status=500)


async def handle_poll(request: web.Request) -> web.Response:
    """Studio plugin → bridge: GET /poll  — returns next pending command or {}"""
    item = await bridge.poll()
    if item:
        return web.json_response(item)
    # Long-poll: wait up to 5 s for a command before returning empty
    try:
        item = await asyncio.wait_for(bridge._queue.get(), timeout=5.0)
        return web.json_response(item)
    except asyncio.TimeoutError:
        return web.json_response({})


async def handle_result(request: web.Request) -> web.Response:
    """Studio plugin → bridge: POST /result  {id, result}"""
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
    site = web.TCPSite(runner, "localhost", BRIDGE_PORT)
    await site.start()
    logger.info(f"Bridge listening on http://localhost:{BRIDGE_PORT}")

    mcp_app = web.Application()
    mcp_app.router.add_post("/command", handle_command)
    mcp_runner = web.AppRunner(mcp_app)
    await mcp_runner.setup()
    mcp_site = web.TCPSite(mcp_runner, "localhost", MCP_FACING_PORT)
    await mcp_site.start()
    logger.info(f"MCP-facing endpoint on http://localhost:{MCP_FACING_PORT}")

    await asyncio.Event().wait()
