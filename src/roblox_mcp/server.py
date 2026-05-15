import asyncio
import json
import logging
import httpx
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp import types

logger = logging.getLogger(__name__)

PLUGIN_HOST = "localhost"
PLUGIN_PORT = 7353
PLUGIN_URL = f"http://{PLUGIN_HOST}:{PLUGIN_PORT}"

app = Server("roblox-mcp")


async def send_command(command: str, params: dict) -> dict:
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            f"{PLUGIN_URL}/command",
            json={"command": command, "params": params},
        )
        response.raise_for_status()
        return response.json()


@app.list_tools()
async def list_tools() -> list[types.Tool]:
    return [
        types.Tool(
            name="execute_script",
            description="Execute a Lua script in Roblox Studio. The script runs in the command bar context and can manipulate the game, create parts, etc.",
            inputSchema={
                "type": "object",
                "properties": {
                    "code": {
                        "type": "string",
                        "description": "Lua code to execute in Roblox Studio",
                    }
                },
                "required": ["code"],
            },
        ),
        types.Tool(
            name="get_selection",
            description="Get information about the currently selected objects in Roblox Studio",
            inputSchema={"type": "object", "properties": {}},
        ),
        types.Tool(
            name="get_workspace_info",
            description="Get information about the current Workspace — parts count, children names, game details",
            inputSchema={"type": "object", "properties": {}},
        ),
        types.Tool(
            name="create_part",
            description="Create a new Part in the Workspace with specified properties",
            inputSchema={
                "type": "object",
                "properties": {
                    "name": {"type": "string", "description": "Name for the part"},
                    "size": {
                        "type": "object",
                        "description": "Size as {x, y, z}",
                        "properties": {
                            "x": {"type": "number"},
                            "y": {"type": "number"},
                            "z": {"type": "number"},
                        },
                    },
                    "position": {
                        "type": "object",
                        "description": "Position as {x, y, z}",
                        "properties": {
                            "x": {"type": "number"},
                            "y": {"type": "number"},
                            "z": {"type": "number"},
                        },
                    },
                    "color": {
                        "type": "object",
                        "description": "BrickColor RGB 0-1 as {r, g, b}",
                        "properties": {
                            "r": {"type": "number"},
                            "g": {"type": "number"},
                            "b": {"type": "number"},
                        },
                    },
                    "anchored": {
                        "type": "boolean",
                        "description": "Whether the part is anchored",
                    },
                    "material": {
                        "type": "string",
                        "description": "Roblox material name e.g. SmoothPlastic, Neon, Wood",
                    },
                },
                "required": ["name"],
            },
        ),
        types.Tool(
            name="insert_script",
            description="Insert a Script or LocalScript into a service (ServerScriptService, StarterPlayerScripts, etc.)",
            inputSchema={
                "type": "object",
                "properties": {
                    "name": {"type": "string", "description": "Script name"},
                    "source": {"type": "string", "description": "Lua source code"},
                    "script_type": {
                        "type": "string",
                        "enum": ["Script", "LocalScript", "ModuleScript"],
                        "description": "Type of script",
                    },
                    "parent": {
                        "type": "string",
                        "description": "Parent service/object e.g. ServerScriptService, StarterPlayer.StarterPlayerScripts",
                    },
                },
                "required": ["name", "source", "script_type", "parent"],
            },
        ),
        types.Tool(
            name="get_output",
            description="Get recent output/print messages from the Roblox Studio Output window",
            inputSchema={"type": "object", "properties": {}},
        ),
        types.Tool(
            name="clear_workspace",
            description="Remove all non-essential parts from the Workspace (keeps baseplate and terrain)",
            inputSchema={"type": "object", "properties": {}},
        ),
        types.Tool(
            name="get_script_source",
            description="Get the source code of a script by its path in the game tree",
            inputSchema={
                "type": "object",
                "properties": {
                    "path": {
                        "type": "string",
                        "description": "Dot-separated path e.g. ServerScriptService.MyScript",
                    }
                },
                "required": ["path"],
            },
        ),
        types.Tool(
            name="set_script_source",
            description="Set/update the source code of an existing script",
            inputSchema={
                "type": "object",
                "properties": {
                    "path": {
                        "type": "string",
                        "description": "Dot-separated path e.g. ServerScriptService.MyScript",
                    },
                    "source": {"type": "string", "description": "New Lua source code"},
                },
                "required": ["path", "source"],
            },
        ),
        types.Tool(
            name="list_instances",
            description="List all children of an instance by path",
            inputSchema={
                "type": "object",
                "properties": {
                    "path": {
                        "type": "string",
                        "description": "Dot-separated path e.g. game.Workspace or ServerScriptService",
                    }
                },
                "required": ["path"],
            },
        ),
        types.Tool(
            name="start_playtest",
            description="Start a playtest in Roblox Studio",
            inputSchema={"type": "object", "properties": {}},
        ),
        types.Tool(
            name="stop_playtest",
            description="Stop the current playtest in Roblox Studio",
            inputSchema={"type": "object", "properties": {}},
        ),
    ]


@app.call_tool()
async def call_tool(name: str, arguments: dict) -> list[types.TextContent]:
    try:
        result = await send_command(name, arguments)
        return [types.TextContent(type="text", text=json.dumps(result, indent=2))]
    except httpx.ConnectError:
        return [
            types.TextContent(
                type="text",
                text=(
                    "ERROR: Cannot connect to Roblox Studio plugin.\n"
                    "Make sure:\n"
                    "1. Roblox Studio is open\n"
                    "2. The RobloxMCP plugin is installed and enabled\n"
                    "3. The plugin server is running (click 'Start Server' in the plugin toolbar)"
                ),
            )
        ]
    except httpx.HTTPStatusError as e:
        return [
            types.TextContent(
                type="text",
                text=f"ERROR: Plugin returned status {e.response.status_code}: {e.response.text}",
            )
        ]
    except Exception as e:
        return [types.TextContent(type="text", text=f"ERROR: {type(e).__name__}: {e}")]


def main():
    logging.basicConfig(level=logging.INFO)
    asyncio.run(_main())


async def _main():
    from .bridge import run_bridge
    bridge_task = asyncio.create_task(run_bridge())
    try:
        async with stdio_server() as (read_stream, write_stream):
            await app.run(read_stream, write_stream, app.create_initialization_options())
    finally:
        bridge_task.cancel()
