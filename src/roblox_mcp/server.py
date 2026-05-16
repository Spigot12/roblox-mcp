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
        r = await client.post(f"{BRIDGE_URL}/command", json={"command": command, "params": params})
        r.raise_for_status()
        return r.json()


def _tool(name, desc, props, required=None):
    return types.Tool(
        name=name,
        description=desc,
        inputSchema={"type": "object", "properties": props, "required": required or []},
    )


@app.list_tools()
async def list_tools() -> list[types.Tool]:
    return [
        # ── Execution ──────────────────────────────────────────────────────────
        _tool("execute_script", "Execute a Lua script in the Roblox Studio plugin context.",
              {"code": {"type": "string"}}, ["code"]),

        _tool("get_output_log", "Get Studio output log messages (print/warn/error). Pass optional filter: 'all' | 'print' | 'warning' | 'error'.",
              {"filter": {"type": "string", "enum": ["all", "print", "warning", "error"]}}),

        _tool("undo", "Undo the last action in Roblox Studio (ChangeHistoryService).", {}),
        _tool("redo", "Redo the last undone action in Roblox Studio.", {}),

        # ── Instance inspection ────────────────────────────────────────────────
        _tool("get_workspace_info", "Get Workspace stats — part count, children, game name/placeId.", {}),
        _tool("get_place_info", "Get detailed place information: PlaceId, GameId, Creator, genre, etc.", {}),
        _tool("get_selection", "Get all currently selected objects in Studio.", {}),

        _tool("list_instances", "List direct children of an instance by dot-separated path.",
              {"path": {"type": "string"}}, ["path"]),

        _tool("get_properties", "Get all readable properties of any instance.",
              {"path": {"type": "string"}}, ["path"]),

        _tool("get_descendants", "Get all descendants of an instance, optionally filtered by ClassName.",
              {"path": {"type": "string"}, "class_name": {"type": "string"},
               "max_results": {"type": "number"}}, ["path"]),

        _tool("compare_instances", "Compare properties of two instances and return the differences.",
              {"path_a": {"type": "string"}, "path_b": {"type": "string"}}, ["path_a", "path_b"]),

        _tool("search_by_property", "Find instances where a property matches a given value.",
              {"property": {"type": "string"}, "value": {},
               "scope": {"type": "string"}, "class_name": {"type": "string"},
               "max_results": {"type": "number"}}, ["property", "value"]),

        _tool("find_instances", "Search for instances by name and/or ClassName.",
              {"name": {"type": "string"}, "class_name": {"type": "string"},
               "scope": {"type": "string"}, "max_results": {"type": "number"}}),

        # ── Instance modification ──────────────────────────────────────────────
        _tool("create_part", "Create a Part in the Workspace.",
              {"name": {"type": "string"},
               "size": {"type": "object", "properties": {"x": {"type": "number"}, "y": {"type": "number"}, "z": {"type": "number"}}},
               "position": {"type": "object", "properties": {"x": {"type": "number"}, "y": {"type": "number"}, "z": {"type": "number"}}},
               "color": {"type": "object", "properties": {"r": {"type": "number"}, "g": {"type": "number"}, "b": {"type": "number"}}},
               "anchored": {"type": "boolean"},
               "material": {"type": "string"}}, ["name"]),

        _tool("set_property", "Set one property on an instance. Vector3 → {x,y,z}, Color3 → {r,g,b}.",
              {"path": {"type": "string"}, "property": {"type": "string"}, "value": {}},
              ["path", "property", "value"]),

        _tool("set_properties", "Set multiple properties on one instance at once.",
              {"path": {"type": "string"}, "properties": {"type": "object"}},
              ["path", "properties"]),

        _tool("mass_set_property", "Set the same property on multiple instances.",
              {"paths": {"type": "array", "items": {"type": "string"}},
               "property": {"type": "string"}, "value": {}},
              ["paths", "property", "value"]),

        _tool("mass_get_property", "Get the same property from multiple instances.",
              {"paths": {"type": "array", "items": {"type": "string"}},
               "property": {"type": "string"}},
              ["paths", "property"]),

        _tool("delete_instance", "Destroy an instance by path.",
              {"path": {"type": "string"}}, ["path"]),

        _tool("clone_instance", "Clone an instance to a new parent.",
              {"path": {"type": "string"}, "parent": {"type": "string"}, "new_name": {"type": "string"}},
              ["path"]),

        _tool("clear_workspace", "Remove all non-essential parts from Workspace (keeps Baseplate/Terrain).", {}),

        # ── Scripts ────────────────────────────────────────────────────────────
        _tool("insert_script", "Insert a Script, LocalScript, or ModuleScript into a service.",
              {"name": {"type": "string"}, "source": {"type": "string"},
               "script_type": {"type": "string", "enum": ["Script", "LocalScript", "ModuleScript"]},
               "parent": {"type": "string"}},
              ["name", "source", "script_type", "parent"]),

        _tool("get_script_source", "Get the full source code of a script.",
              {"path": {"type": "string"}}, ["path"]),

        _tool("set_script_source", "Replace the full source of a script.",
              {"path": {"type": "string"}, "source": {"type": "string"}}, ["path", "source"]),

        _tool("edit_script_lines", "Replace specific text within a script (find and replace).",
              {"path": {"type": "string"}, "old_text": {"type": "string"}, "new_text": {"type": "string"},
               "replace_all": {"type": "boolean"}},
              ["path", "old_text", "new_text"]),

        _tool("insert_script_lines", "Insert lines at a specific line number in a script (1-based, inserts BEFORE that line).",
              {"path": {"type": "string"}, "line": {"type": "number"}, "text": {"type": "string"}},
              ["path", "line", "text"]),

        _tool("delete_script_lines", "Delete a range of lines from a script (1-based, inclusive).",
              {"path": {"type": "string"}, "from_line": {"type": "number"}, "to_line": {"type": "number"}},
              ["path", "from_line", "to_line"]),

        _tool("grep_scripts", "Search all scripts for a text pattern. Returns matching script paths and line numbers.",
              {"pattern": {"type": "string"}, "scope": {"type": "string"},
               "max_results": {"type": "number"}}, ["pattern"]),

        _tool("find_and_replace_in_scripts", "Find and replace text across all scripts.",
              {"find": {"type": "string"}, "replace": {"type": "string"},
               "scope": {"type": "string"}, "preview": {"type": "boolean"}},
              ["find", "replace"]),

        # ── Attributes ─────────────────────────────────────────────────────────
        _tool("get_attributes", "Get all attributes of an instance.",
              {"path": {"type": "string"}}, ["path"]),

        _tool("set_attribute", "Set an attribute on an instance.",
              {"path": {"type": "string"}, "name": {"type": "string"}, "value": {}},
              ["path", "name", "value"]),

        _tool("delete_attribute", "Delete an attribute from an instance.",
              {"path": {"type": "string"}, "name": {"type": "string"}}, ["path", "name"]),

        _tool("bulk_set_attributes", "Set multiple attributes on an instance at once.",
              {"path": {"type": "string"}, "attributes": {"type": "object"}}, ["path", "attributes"]),

        # ── Tags (CollectionService) ───────────────────────────────────────────
        _tool("get_tags", "Get all CollectionService tags on an instance.",
              {"path": {"type": "string"}}, ["path"]),

        _tool("add_tag", "Add a CollectionService tag to an instance.",
              {"path": {"type": "string"}, "tag": {"type": "string"}}, ["path", "tag"]),

        _tool("remove_tag", "Remove a CollectionService tag from an instance.",
              {"path": {"type": "string"}, "tag": {"type": "string"}}, ["path", "tag"]),

        _tool("get_tagged", "Get all instances with a specific CollectionService tag.",
              {"tag": {"type": "string"}, "max_results": {"type": "number"}}, ["tag"]),

        # ── Playtest ───────────────────────────────────────────────────────────
        _tool("start_playtest", "Start a playtest in Roblox Studio.", {}),
        _tool("stop_playtest", "Stop the current playtest.", {}),
    ]


@app.call_tool()
async def call_tool(name: str, arguments: dict) -> list[types.TextContent]:
    try:
        result = await send_command(name, arguments)
        return [types.TextContent(type="text", text=json.dumps(result, indent=2))]
    except httpx.ConnectError:
        return [types.TextContent(type="text", text=(
            "ERROR: Cannot connect to bridge. Make sure:\n"
            "1. Roblox Studio is open with the RobloxMCP plugin installed\n"
            "2. You clicked 'Start Server' in the plugin panel"
        ))]
    except httpx.HTTPStatusError as e:
        return [types.TextContent(type="text", text=f"ERROR: {e.response.status_code}: {e.response.text}")]
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
