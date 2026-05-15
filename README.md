# Roblox MCP

A Model Context Protocol (MCP) server that connects Claude AI directly to Roblox Studio. Inspired by [blender-mcp](https://github.com/ahujasid/blender-mcp).

![Architecture](https://img.shields.io/badge/status-alpha-orange) ![Python](https://img.shields.io/badge/python-3.10%2B-blue) ![License](https://img.shields.io/badge/license-MIT-green)

## What it does

Claude can directly:
- **Execute Lua scripts** inside Roblox Studio
- **Create and place parts** in the Workspace
- **Insert Scripts / LocalScripts / ModuleScripts** into services
- **Read and write script source code**
- **List instances** in the game tree
- **Get Studio output** logs
- And more...

## Architecture

```
Claude (MCP client)
     │  stdio
     ▼
MCP Server (Python)   ← roblox-mcp
     │  HTTP POST /command  (port 7353)
     ▼
HTTP Bridge (aiohttp)
     │  long-poll GET /poll  (port 7354)
     ▼
Roblox Studio Plugin (Lua)
     └─ HttpService outbound requests
```

Because Roblox Studio plugins cannot receive inbound HTTP, the bridge acts as a queue. The plugin polls every 100ms for pending commands.

## Installation

### 1. Install the MCP server

**Recommended — via `uvx` (no install needed):**
```bash
uvx roblox-mcp
```

**Or install with pip:**
```bash
pip install roblox-mcp
```

### 2. Install the Studio Plugin

1. Open Roblox Studio
2. Go to **Plugins → Plugin Manager → Install from file**
3. Select `studio-plugin/RobloxMCP.lua`  
   *(or copy the contents into a new Plugin script via the Script Editor)*

### 3. Configure Claude Desktop

Add to your `claude_desktop_config.json`:

**macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`  
**Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "roblox": {
      "command": "uvx",
      "args": ["roblox-mcp"]
    }
  }
}
```

If you installed via pip:
```json
{
  "mcpServers": {
    "roblox": {
      "command": "roblox-mcp"
    }
  }
}
```

### 4. Start everything

1. Open Roblox Studio with your place
2. Click the **RobloxMCP** button in the Studio toolbar to start the plugin server
3. Start Claude Desktop — the MCP server launches automatically

## Available Tools

| Tool | Description |
|------|-------------|
| `execute_script` | Run arbitrary Lua code in Studio |
| `create_part` | Create a Part in the Workspace |
| `insert_script` | Add a Script/LocalScript/ModuleScript |
| `get_script_source` | Read a script's source code |
| `set_script_source` | Update a script's source code |
| `list_instances` | List children of any instance |
| `get_workspace_info` | Workspace stats and children |
| `get_selection` | Currently selected objects |
| `get_output` | Recent Output window messages |
| `clear_workspace` | Remove all parts (keeps Baseplate) |
| `start_playtest` | Start playtesting |
| `stop_playtest` | Stop playtesting |

## Example prompts

- *"Create a red neon part at position 0, 10, 0 and make it spin using a Script"*
- *"Write a working obby with 10 stages and insert all the scripts"*
- *"Read the source of ServerScriptService.GameManager and fix the bug"*
- *"List everything in the Workspace"*

## Development

```bash
git clone https://github.com/Spigot12/roblox-mcp
cd roblox-mcp
pip install -e ".[dev]"
python -m roblox_mcp.bridge  # start bridge separately for debugging
```

## Contributing

Pull requests welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT — see [LICENSE](LICENSE)
