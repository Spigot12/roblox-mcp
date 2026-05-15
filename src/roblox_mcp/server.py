import asyncio
import json
import logging
import httpx
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp import types

logger = logging.getLogger(__name__)

BRIDGE_URL = "http://localhost:7353"

app = Server("roblox-mcp")


async def send_command(command: str, params: dict) -> dict:
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            f"{BRIDGE_URL}/command",
            json={"command": command, "params": params},
        )
        response.raise_for_status()
        return response.json()


@app.list_tools()
async def list_tools() -> list[types.Tool]:
    return [
        types.Tool(
            name="execute_script",
            description="Execute a Lua script in Roblox Studio.",
            inputSchema={
                "type": "object",
                "properties": {"code": {"type": "string", "description": "Lua code to execute"}},
                "required": ["code"],
            },
        ),
        types.Tool(
            name="get_selection",
            description="Get information about the currently selected objects in Roblox Studio.",
            inputSchema={"type": "object", "properties": {}},
        ),
        types.Tool(
            name="get_workspace_info",
            description="Get information about the current Workspace — part count, children, game name.",
            inputSchema={"type": "object", "properties": {}},
        ),
        types.Tool(
            name="create_part",
            description="Create a new Part in the Workspace with specified properties.",
            inputSchema={
                "type": "object",
                "properties": {
                    "name": {"type": "string"},
                    "size": {
                        "type": "object",
                        "properties": {"x": {"type": "number"}, "y": {"type": "number"}, "z": {"type": "number"}},
                    },
                    "position": {
                        "type": "object",
                        "properties": {"x": {"type": "number"}, "y": {"type": "number"}, "z": {"type": "number"}},
                    },
                    "color": {
                        "type": "object",
                        "properties": {"r": {"type": "number"}, "g": {"type": "number"}, "b": {"type": "number"}},
                    },
                    "anchored": {"type": "boolean"},
                    "material": {"type": "string", "description": "e.g. SmoothPlastic, Neon, Wood"},
                },
                "required": ["name"],
            },
        ),
        types.Tool(
            name="insert_script",
            description="Insert a Script, LocalScript, or ModuleScript into a service.",
            inputSchema={
                "type": "object",
                "properties": {
                    "name": {"type": "string"},
                    "source": {"type": "string"},
                    "script_type": {"type": "string", "enum": ["Script", "LocalScript", "ModuleScript"]},
                    "parent": {"type": "string", "description": "e.g. ServerScriptService"},
                },
                "required": ["name", "source", "script_type", "parent"],
            },
        ),
        types.Tool(
            name="get_output",
            description="Get recent log entries from the RobloxMCP plugin panel.",
            inputSchema={"type": "object", "properties": {}},
        ),
        types.Tool(
            name="clear_workspace",
            description="Remove all non-essential parts from the Workspace (keeps Baseplate and Terrain).",
            inputSchema={"type": "object", "properties": {}},
        ),
        types.Tool(
            name="get_script_source",
            description="Get the source code of a script by its dot-separated path.",
            inputSchema={
                "type": "object",
                "properties": {"path": {"type": "string", "description": "e.g. ServerScriptService.MyScript"}},
                "required": ["path"],
            },
        ),
        types.Tool(
            name="set_script_source",
            description="Set/update the source code of an existing script.",
            inputSchema={
                "type": "object",
                "properties": {
                    "path": {"type": "string"},
                    "source": {"type": "string"},
                },
                "required": ["path", "source"],
            },
        ),
        types.Tool(
            name="list_instances",
            description="List all children of an instance by dot-separated path.",
            inputSchema={
                "type": "object",
                "properties": {"path": {"type": "string", "description": "e.g. game.Workspace"}},
                "required": ["path"],
            },
        ),
        types.Tool(
            name="get_properties",
            description="Get the properties of any instance (Position, Size, Color, etc.).",
            inputSchema={
                "type": "object",
                "properties": {"path": {"type": "string", "description": "e.g. Workspace.Part"}},
                "required": ["path"],
            },
        ),
        types.Tool(
            name="set_property",
            description=(
                "Set a property on any instance. "
                "For Vector3 pass value as {x,y,z}, for Color3 as {r,g,b} (0-1), "
                "for plain values pass a string/number/boolean."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "path": {"type": "string", "description": "e.g. Workspace.Part"},
                    "property": {"type": "string", "description": "Property name e.g. Anchored, Position"},
                    "value": {"description": "New value — string, number, bool, or {x,y,z} / {r,g,b} object"},
                },
                "required": ["path", "property", "value"],
            },
        ),
        types.Tool(
            name="find_instances",
            description="Search for instances by name and/or ClassName anywhere in the game tree.",
            inputSchema={
                "type": "object",
                "properties": {
                    "name": {"type": "string", "description": "Exact name to match (optional)"},
                    "class_name": {"type": "string", "description": "ClassName to match e.g. Part, Script (optional)"},
                    "scope": {"type": "string", "description": "Root path to search from, defaults to game"},
                    "max_results": {"type": "number", "description": "Max results to return (default 50)"},
                },
            },
        ),
        types.Tool(
            name="delete_instance",
            description="Delete (Destroy) an instance by its dot-separated path.",
            inputSchema={
                "type": "object",
                "properties": {"path": {"type": "string", "description": "e.g. Workspace.OldPart"}},
                "required": ["path"],
            },
        ),
        types.Tool(
            name="clone_instance",
            description="Clone an instance and place it under a new parent.",
            inputSchema={
                "type": "object",
                "properties": {
                    "path": {"type": "string", "description": "Path of the instance to clone"},
                    "parent": {"type": "string", "description": "Destination path (defaults to same parent)"},
                    "new_name": {"type": "string", "description": "Optional new name for the clone"},
                },
                "required": ["path"],
            },
        ),
        types.Tool(
            name="start_playtest",
            description="Start a playtest in Roblox Studio.",
            inputSchema={"type": "object", "properties": {}},
        ),
        types.Tool(
            name="stop_playtest",
            description="Stop the current playtest in Roblox Studio.",
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
                    "ERROR: Cannot connect to the bridge.\n"
                    "Make sure Roblox Studio is open, the RobloxMCP plugin is installed, "
                    "and you clicked 'Start Server' in the plugin panel."
                ),
            )
        ]
    except httpx.HTTPStatusError as e:
        return [types.TextContent(type="text", text=f"ERROR: Bridge returned {e.response.status_code}: {e.response.text}")]
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
