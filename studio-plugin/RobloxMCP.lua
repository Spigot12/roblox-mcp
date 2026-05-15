-- RobloxMCP Studio Plugin
-- Starts a local HTTP server that the MCP Python server communicates with

local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")
local RunService = game:GetService("RunService")
local StudioService = game:GetService("StudioService")

local toolbar = plugin:CreateToolbar("RobloxMCP")
local toggleButton = toolbar:CreateButton(
	"RobloxMCP",
	"Start/Stop the MCP server connection",
	"rbxassetid://7733960981"
)

local PORT = 7353
local isRunning = false
local outputLog = {}
local MAX_LOG = 200

local function log(msg)
	table.insert(outputLog, tostring(msg))
	if #outputLog > MAX_LOG then
		table.remove(outputLog, 1)
	end
	print("[RobloxMCP] " .. tostring(msg))
end

-- Resolve a dot-separated path like "game.Workspace.Part" or "ServerScriptService.Script"
local function resolvePath(path)
	local parts = path:split(".")
	local current = game
	-- Allow starting from top-level services by name
	if parts[1] ~= "game" then
		current = game:GetService(parts[1]) or game[parts[1]]
		for i = 2, #parts do
			current = current[parts[i]]
		end
	else
		for i = 2, #parts do
			current = current[parts[i]]
		end
	end
	return current
end

local handlers = {}

handlers["execute_script"] = function(params)
	local code = params.code
	local fn, err = loadstring(code)
	if not fn then
		return { success = false, error = "Parse error: " .. tostring(err) }
	end
	local ok, result = pcall(fn)
	if not ok then
		return { success = false, error = tostring(result) }
	end
	return { success = true, result = tostring(result or "") }
end

handlers["get_selection"] = function(_params)
	local selected = Selection:Get()
	local items = {}
	for _, obj in ipairs(selected) do
		table.insert(items, {
			name = obj.Name,
			className = obj.ClassName,
			path = obj:GetFullName(),
		})
	end
	return { success = true, selection = items, count = #items }
end

handlers["get_workspace_info"] = function(_params)
	local ws = game.Workspace
	local children = {}
	for _, child in ipairs(ws:GetChildren()) do
		table.insert(children, { name = child.Name, className = child.ClassName })
	end
	return {
		success = true,
		partCount = #ws:GetDescendants(),
		children = children,
		gameName = game.Name,
		placeId = game.PlaceId,
	}
end

handlers["create_part"] = function(params)
	local part = Instance.new("Part")
	part.Name = params.name or "Part"
	if params.size then
		part.Size = Vector3.new(params.size.x or 4, params.size.y or 1, params.size.z or 4)
	end
	if params.position then
		part.Position = Vector3.new(params.position.x or 0, params.position.y or 5, params.position.z or 0)
	end
	if params.color then
		part.Color = Color3.new(params.color.r or 0.6, params.color.g or 0.6, params.color.b or 0.6)
	end
	if params.anchored ~= nil then
		part.Anchored = params.anchored
	else
		part.Anchored = true
	end
	if params.material then
		local ok, mat = pcall(function()
			return Enum.Material[params.material]
		end)
		if ok then part.Material = mat end
	end
	part.Parent = game.Workspace
	return { success = true, name = part.Name, path = part:GetFullName() }
end

handlers["insert_script"] = function(params)
	local scriptType = params.script_type or "Script"
	local s = Instance.new(scriptType)
	s.Name = params.name
	s.Source = params.source or ""
	local ok, err = pcall(function()
		s.Parent = resolvePath(params.parent)
	end)
	if not ok then
		return { success = false, error = "Could not find parent: " .. tostring(err) }
	end
	return { success = true, path = s:GetFullName() }
end

handlers["get_output"] = function(_params)
	return { success = true, output = outputLog }
end

handlers["clear_workspace"] = function(_params)
	local kept = {}
	local removed = 0
	for _, child in ipairs(game.Workspace:GetChildren()) do
		if child.Name == "Baseplate" or child:IsA("Terrain") or child:IsA("Camera") then
			table.insert(kept, child.Name)
		else
			child:Destroy()
			removed = removed + 1
		end
	end
	return { success = true, removed = removed, kept = kept }
end

handlers["get_script_source"] = function(params)
	local ok, obj = pcall(resolvePath, params.path)
	if not ok or not obj then
		return { success = false, error = "Path not found: " .. tostring(params.path) }
	end
	if not obj:IsA("LuaSourceContainer") then
		return { success = false, error = obj.ClassName .. " is not a script" }
	end
	return { success = true, source = obj.Source, className = obj.ClassName }
end

handlers["set_script_source"] = function(params)
	local ok, obj = pcall(resolvePath, params.path)
	if not ok or not obj then
		return { success = false, error = "Path not found: " .. tostring(params.path) }
	end
	if not obj:IsA("LuaSourceContainer") then
		return { success = false, error = obj.ClassName .. " is not a script" }
	end
	obj.Source = params.source
	return { success = true, path = obj:GetFullName() }
end

handlers["list_instances"] = function(params)
	local ok, obj = pcall(resolvePath, params.path)
	if not ok or not obj then
		return { success = false, error = "Path not found: " .. tostring(params.path) }
	end
	local children = {}
	for _, child in ipairs(obj:GetChildren()) do
		table.insert(children, {
			name = child.Name,
			className = child.ClassName,
			path = child:GetFullName(),
		})
	end
	return { success = true, children = children, count = #children }
end

handlers["start_playtest"] = function(_params)
	local ok, err = pcall(function()
		game:GetService("TestService"):Run()
	end)
	return { success = ok, error = ok and nil or tostring(err) }
end

handlers["stop_playtest"] = function(_params)
	-- Studio doesn't expose a direct stop API; simulate via plugin action
	local ok, err = pcall(function()
		plugin:GetMouse() -- ensures plugin context
		-- Use the built-in "Stop" action if available
		local action = plugin:CreatePluginAction("StopPlaytest", "Stop Playtest", "")
		action:Destroy()
	end)
	return { success = true, note = "Use the Studio Stop button or press F5" }
end

-- Simple HTTP polling loop using HttpService
-- Studio's HttpService can only make outbound requests, so we use long-polling
-- The Python bridge exposes GET /poll to give us pending commands and POST /result for responses.

local BRIDGE_URL = "http://localhost:7354"

local function pollLoop()
	while isRunning do
		local ok, response = pcall(function()
			return HttpService:RequestAsync({
				Url = BRIDGE_URL .. "/poll",
				Method = "GET",
			})
		end)

		if ok and response and response.Success then
			local data = HttpService:JSONDecode(response.Body)
			if data and data.command then
				local handler = handlers[data.command]
				local result
				if handler then
					local callOk, callResult = pcall(handler, data.params or {})
					if callOk then
						result = callResult
					else
						result = { success = false, error = tostring(callResult) }
					end
				else
					result = { success = false, error = "Unknown command: " .. tostring(data.command) }
				end

				-- Send result back
				pcall(function()
					HttpService:RequestAsync({
						Url = BRIDGE_URL .. "/result",
						Method = "POST",
						Headers = { ["Content-Type"] = "application/json" },
						Body = HttpService:JSONEncode({ id = data.id, result = result }),
					})
				end)
			end
		end

		task.wait(0.1)
	end
end

toggleButton.Click:Connect(function()
	if not isRunning then
		isRunning = true
		toggleButton:SetActive(true)
		log("Server started — polling " .. BRIDGE_URL)
		task.spawn(pollLoop)
	else
		isRunning = false
		toggleButton:SetActive(false)
		log("Server stopped")
	end
end)

log("RobloxMCP plugin loaded. Click the toolbar button to start.")
