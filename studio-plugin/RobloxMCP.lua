-- RobloxMCP Studio Plugin
-- Provides a dock widget GUI and a long-poll bridge to the Python MCP server

local HttpService   = game:GetService("HttpService")
local Selection     = game:GetService("Selection")
local StudioService = game:GetService("StudioService")

-- ── Constants ────────────────────────────────────────────────────────────────
local BRIDGE_URL  = "http://localhost:7354"
local POLL_RATE   = 0.1   -- seconds between polls
local MAX_LOG     = 100   -- max log entries shown

-- ── Dock Widget ──────────────────────────────────────────────────────────────
local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	false,   -- initially hidden
	false,
	260, 420,
	220, 300
)

local widget = plugin:CreateDockWidgetPluginGui("RobloxMCP", widgetInfo)
widget.Title = "RobloxMCP"

-- ── Toolbar button ───────────────────────────────────────────────────────────
local toolbar      = plugin:CreateToolbar("RobloxMCP")
local toggleButton = toolbar:CreateButton("RobloxMCP", "Open RobloxMCP panel", "rbxassetid://7733960981")
toggleButton.ClickableWhenViewportHidden = true

toggleButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
	toggleButton:SetActive(widget.Enabled)
end)

-- ── Theme helper ─────────────────────────────────────────────────────────────
local function isDark()
	local ok, theme = pcall(function() return settings().Studio.Theme end)
	if not ok then return true end
	return theme.Name == "Dark"
end

local C = {}
local function applyTheme()
	if isDark() then
		C.bg        = Color3.fromRGB(30,  30,  30)
		C.panel     = Color3.fromRGB(40,  40,  40)
		C.border    = Color3.fromRGB(60,  60,  60)
		C.text      = Color3.fromRGB(220, 220, 220)
		C.subtext   = Color3.fromRGB(150, 150, 150)
		C.btnBg     = Color3.fromRGB(55,  55,  55)
		C.btnHover  = Color3.fromRGB(75,  75,  75)
		C.green     = Color3.fromRGB(0,   200, 100)
		C.red       = Color3.fromRGB(220, 70,  70)
		C.logBg     = Color3.fromRGB(22,  22,  22)
		C.logText   = Color3.fromRGB(180, 180, 180)
	else
		C.bg        = Color3.fromRGB(240, 240, 240)
		C.panel     = Color3.fromRGB(255, 255, 255)
		C.border    = Color3.fromRGB(200, 200, 200)
		C.text      = Color3.fromRGB(30,  30,  30)
		C.subtext   = Color3.fromRGB(100, 100, 100)
		C.btnBg     = Color3.fromRGB(220, 220, 220)
		C.btnHover  = Color3.fromRGB(200, 200, 200)
		C.green     = Color3.fromRGB(0,   160, 80)
		C.red       = Color3.fromRGB(200, 50,  50)
		C.logBg     = Color3.fromRGB(250, 250, 250)
		C.logText   = Color3.fromRGB(60,  60,  60)
	end
end
applyTheme()

-- ── GUI layout ───────────────────────────────────────────────────────────────
local root = Instance.new("Frame")
root.Size            = UDim2.new(1, 0, 1, 0)
root.BackgroundColor3 = C.bg
root.BorderSizePixel = 0
root.Parent          = widget

-- padding
local pad = Instance.new("UIPadding", root)
pad.PaddingLeft   = UDim.new(0, 10)
pad.PaddingRight  = UDim.new(0, 10)
pad.PaddingTop    = UDim.new(0, 10)
pad.PaddingBottom = UDim.new(0, 10)

local layout = Instance.new("UIListLayout", root)
layout.FillDirection = Enum.FillDirection.Vertical
layout.SortOrder     = Enum.SortOrder.LayoutOrder
layout.Padding       = UDim.new(0, 8)

-- ── Header ───────────────────────────────────────────────────────────────────
local header = Instance.new("Frame", root)
header.Size             = UDim2.new(1, 0, 0, 28)
header.BackgroundTransparency = 1
header.LayoutOrder      = 1

local titleLabel = Instance.new("TextLabel", header)
titleLabel.Size            = UDim2.new(1, 0, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text            = "Roblox MCP"
titleLabel.Font            = Enum.Font.GothamBold
titleLabel.TextSize        = 16
titleLabel.TextColor3      = C.text
titleLabel.TextXAlignment  = Enum.TextXAlignment.Left

-- ── Status card ──────────────────────────────────────────────────────────────
local statusCard = Instance.new("Frame", root)
statusCard.Size             = UDim2.new(1, 0, 0, 54)
statusCard.BackgroundColor3 = C.panel
statusCard.BorderSizePixel  = 0
statusCard.LayoutOrder      = 2
Instance.new("UICorner", statusCard).CornerRadius = UDim.new(0, 8)

local statusDot = Instance.new("Frame", statusCard)
statusDot.Size              = UDim2.new(0, 10, 0, 10)
statusDot.Position          = UDim2.new(0, 14, 0.5, -5)
statusDot.BackgroundColor3  = C.red
statusDot.BorderSizePixel   = 0
Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)

local statusLabel = Instance.new("TextLabel", statusCard)
statusLabel.Size           = UDim2.new(1, -40, 0, 18)
statusLabel.Position       = UDim2.new(0, 32, 0, 10)
statusLabel.BackgroundTransparency = 1
statusLabel.Text           = "Disconnected"
statusLabel.Font           = Enum.Font.GothamBold
statusLabel.TextSize       = 13
statusLabel.TextColor3     = C.text
statusLabel.TextXAlignment = Enum.TextXAlignment.Left

local statusSub = Instance.new("TextLabel", statusCard)
statusSub.Size           = UDim2.new(1, -40, 0, 14)
statusSub.Position       = UDim2.new(0, 32, 0, 30)
statusSub.BackgroundTransparency = 1
statusSub.Text           = "Click Start to connect"
statusSub.Font           = Enum.Font.Gotham
statusSub.TextSize       = 11
statusSub.TextColor3     = C.subtext
statusSub.TextXAlignment = Enum.TextXAlignment.Left

-- ── Start / Stop button ───────────────────────────────────────────────────────
local startBtn = Instance.new("TextButton", root)
startBtn.Size             = UDim2.new(1, 0, 0, 36)
startBtn.BackgroundColor3 = C.green
startBtn.BorderSizePixel  = 0
startBtn.Text             = "Start Server"
startBtn.Font             = Enum.Font.GothamBold
startBtn.TextSize         = 14
startBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
startBtn.LayoutOrder      = 3
Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 8)

-- ── Info row (port) ───────────────────────────────────────────────────────────
local infoLabel = Instance.new("TextLabel", root)
infoLabel.Size           = UDim2.new(1, 0, 0, 14)
infoLabel.BackgroundTransparency = 1
infoLabel.Text           = "Bridge: localhost:7354"
infoLabel.Font           = Enum.Font.Gotham
infoLabel.TextSize       = 11
infoLabel.TextColor3     = C.subtext
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.LayoutOrder    = 4

-- ── Log section label ─────────────────────────────────────────────────────────
local logTitle = Instance.new("TextLabel", root)
logTitle.Size           = UDim2.new(1, 0, 0, 14)
logTitle.BackgroundTransparency = 1
logTitle.Text           = "Activity Log"
logTitle.Font           = Enum.Font.GothamBold
logTitle.TextSize       = 11
logTitle.TextColor3     = C.subtext
logTitle.TextXAlignment = Enum.TextXAlignment.Left
logTitle.LayoutOrder    = 5

-- ── Scrolling log ─────────────────────────────────────────────────────────────
local logFrame = Instance.new("Frame", root)
logFrame.Size             = UDim2.new(1, 0, 1, -210)
logFrame.BackgroundColor3 = C.logBg
logFrame.BorderSizePixel  = 0
logFrame.LayoutOrder      = 6
logFrame.ClipsDescendants = true
Instance.new("UICorner", logFrame).CornerRadius = UDim.new(0, 8)

local scroll = Instance.new("ScrollingFrame", logFrame)
scroll.Size                = UDim2.new(1, 0, 1, 0)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel     = 0
scroll.ScrollBarThickness  = 4
scroll.ScrollBarImageColor3 = C.border
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize          = UDim2.new(0, 0, 0, 0)

local scrollPad = Instance.new("UIPadding", scroll)
scrollPad.PaddingLeft   = UDim.new(0, 6)
scrollPad.PaddingRight  = UDim.new(0, 6)
scrollPad.PaddingTop    = UDim.new(0, 4)
scrollPad.PaddingBottom = UDim.new(0, 4)

local scrollLayout = Instance.new("UIListLayout", scroll)
scrollLayout.FillDirection = Enum.FillDirection.Vertical
scrollLayout.SortOrder     = Enum.SortOrder.LayoutOrder
scrollLayout.Padding       = UDim.new(0, 2)

-- ── Clear log button ──────────────────────────────────────────────────────────
local clearBtn = Instance.new("TextButton", root)
clearBtn.Size             = UDim2.new(1, 0, 0, 26)
clearBtn.BackgroundColor3 = C.btnBg
clearBtn.BorderSizePixel  = 0
clearBtn.Text             = "Clear Log"
clearBtn.Font             = Enum.Font.Gotham
clearBtn.TextSize         = 12
clearBtn.TextColor3       = C.subtext
clearBtn.LayoutOrder      = 7
Instance.new("UICorner", clearBtn).CornerRadius = UDim.new(0, 6)

-- ── Log logic ─────────────────────────────────────────────────────────────────
local logEntries  = {}
local logCounter  = 0

local function addLog(msg, isError)
	logCounter += 1
	local row = Instance.new("TextLabel")
	row.Size                 = UDim2.new(1, 0, 0, 0)
	row.AutomaticSize        = Enum.AutomaticSize.Y
	row.BackgroundTransparency = 1
	row.Text                 = msg
	row.Font                 = Enum.Font.Code
	row.TextSize             = 11
	row.TextColor3           = isError and C.red or C.logText
	row.TextXAlignment       = Enum.TextXAlignment.Left
	row.TextWrapped          = true
	row.LayoutOrder          = logCounter
	row.Parent               = scroll

	table.insert(logEntries, row)
	if #logEntries > MAX_LOG then
		logEntries[1]:Destroy()
		table.remove(logEntries, 1)
	end

	-- auto-scroll to bottom
	task.defer(function()
		scroll.CanvasPosition = Vector2.new(0, scroll.AbsoluteCanvasSize.Y)
	end)
end

clearBtn.MouseButton1Click:Connect(function()
	for _, entry in ipairs(logEntries) do entry:Destroy() end
	logEntries = {}
end)

-- ── State ─────────────────────────────────────────────────────────────────────
local isRunning    = false
local cmdCount     = 0

local function setStatus(connected, sub)
	statusDot.BackgroundColor3 = connected and C.green or C.red
	statusLabel.Text = connected and "Connected" or "Disconnected"
	statusSub.Text   = sub or (connected and "Ready" or "Click Start to connect")
end

local function setRunning(v)
	isRunning = v
	if v then
		startBtn.Text             = "Stop Server"
		startBtn.BackgroundColor3 = C.red
		toggleButton:SetActive(true)
		addLog("Server started — polling " .. BRIDGE_URL)
		setStatus(false, "Waiting for bridge…")
	else
		startBtn.Text             = "Start Server"
		startBtn.BackgroundColor3 = C.green
		toggleButton:SetActive(false)
		setStatus(false, "Click Start to connect")
		addLog("Server stopped")
	end
end

-- ── Command handlers ──────────────────────────────────────────────────────────
local function resolvePath(path)
	local parts = path:split(".")
	local current
	if parts[1] == "game" then
		current = game
		for i = 2, #parts do current = current[parts[i]] end
	else
		local ok, svc = pcall(function() return game:GetService(parts[1]) end)
		current = ok and svc or game[parts[1]]
		for i = 2, #parts do current = current[parts[i]] end
	end
	return current
end

local handlers = {}

handlers["execute_script"] = function(p)
	local fn, err = loadstring(p.code)
	if not fn then return {success=false, error="Parse error: "..tostring(err)} end
	local ok, res = pcall(fn)
	return ok and {success=true, result=tostring(res or "")} or {success=false, error=tostring(res)}
end

handlers["get_selection"] = function(_)
	local items = {}
	for _, obj in ipairs(Selection:Get()) do
		table.insert(items, {name=obj.Name, className=obj.ClassName, path=obj:GetFullName()})
	end
	return {success=true, selection=items, count=#items}
end

handlers["get_workspace_info"] = function(_)
	local children = {}
	for _, c in ipairs(game.Workspace:GetChildren()) do
		table.insert(children, {name=c.Name, className=c.ClassName})
	end
	return {success=true, partCount=#game.Workspace:GetDescendants(), children=children,
	        gameName=game.Name, placeId=game.PlaceId}
end

handlers["create_part"] = function(p)
	local part = Instance.new("Part")
	part.Name = p.name or "Part"
	if p.size then part.Size = Vector3.new(p.size.x or 4, p.size.y or 1, p.size.z or 4) end
	if p.position then part.Position = Vector3.new(p.position.x or 0, p.position.y or 5, p.position.z or 0) end
	if p.color then part.Color = Color3.new(p.color.r or .6, p.color.g or .6, p.color.b or .6) end
	part.Anchored = p.anchored ~= false
	if p.material then
		local ok, mat = pcall(function() return Enum.Material[p.material] end)
		if ok then part.Material = mat end
	end
	part.Parent = game.Workspace
	return {success=true, name=part.Name, path=part:GetFullName()}
end

handlers["insert_script"] = function(p)
	local s = Instance.new(p.script_type or "Script")
	s.Name   = p.name
	s.Source = p.source or ""
	local ok, err = pcall(function() s.Parent = resolvePath(p.parent) end)
	return ok and {success=true, path=s:GetFullName()} or {success=false, error=tostring(err)}
end

handlers["get_output"] = function(_)
	local msgs = {}
	for _, e in ipairs(logEntries) do table.insert(msgs, e.Text) end
	return {success=true, output=msgs}
end

handlers["clear_workspace"] = function(_)
	local removed = 0
	for _, c in ipairs(game.Workspace:GetChildren()) do
		if not (c.Name == "Baseplate" or c:IsA("Terrain") or c:IsA("Camera")) then
			c:Destroy(); removed += 1
		end
	end
	return {success=true, removed=removed}
end

handlers["get_script_source"] = function(p)
	local ok, obj = pcall(resolvePath, p.path)
	if not ok or not obj then return {success=false, error="Path not found: "..tostring(p.path)} end
	if not obj:IsA("LuaSourceContainer") then return {success=false, error=obj.ClassName.." is not a script"} end
	return {success=true, source=obj.Source, className=obj.ClassName}
end

handlers["set_script_source"] = function(p)
	local ok, obj = pcall(resolvePath, p.path)
	if not ok or not obj then return {success=false, error="Path not found: "..tostring(p.path)} end
	if not obj:IsA("LuaSourceContainer") then return {success=false, error=obj.ClassName.." is not a script"} end
	obj.Source = p.source
	return {success=true, path=obj:GetFullName()}
end

handlers["list_instances"] = function(p)
	local ok, obj = pcall(resolvePath, p.path)
	if not ok or not obj then return {success=false, error="Path not found: "..tostring(p.path)} end
	local children = {}
	for _, c in ipairs(obj:GetChildren()) do
		table.insert(children, {name=c.Name, className=c.ClassName, path=c:GetFullName()})
	end
	return {success=true, children=children, count=#children}
end

handlers["start_playtest"] = function(_)
	local ok, err = pcall(function() game:GetService("TestService"):Run() end)
	return {success=ok, error=ok and nil or tostring(err)}
end

handlers["stop_playtest"] = function(_)
	return {success=true, note="Use the Studio Stop button or press F5"}
end

-- ── Poll loop ─────────────────────────────────────────────────────────────────
local bridgeOk = false

local function pollLoop()
	while isRunning do
		local ok, response = pcall(function()
			return HttpService:RequestAsync({Url=BRIDGE_URL.."/poll", Method="GET"})
		end)

		if ok and response and response.Success then
			if not bridgeOk then
				bridgeOk = true
				setStatus(true, "Bridge connected")
				addLog("Bridge connected at "..BRIDGE_URL)
			end

			local data = HttpService:JSONDecode(response.Body)
			if data and data.command then
				cmdCount += 1
				addLog("["..cmdCount.."] "..data.command)

				local handler = handlers[data.command]
				local result
				if handler then
					local callOk, callResult = pcall(handler, data.params or {})
					result = callOk and callResult or {success=false, error=tostring(callResult)}
				else
					result = {success=false, error="Unknown command: "..tostring(data.command)}
				end

				pcall(function()
					HttpService:RequestAsync({
						Url     = BRIDGE_URL.."/result",
						Method  = "POST",
						Headers = {["Content-Type"]="application/json"},
						Body    = HttpService:JSONEncode({id=data.id, result=result}),
					})
				end)

				if result.success == false then
					addLog("  error: "..(result.error or "?"), true)
				end
			end
		else
			if bridgeOk then
				bridgeOk = false
				setStatus(false, "Bridge disconnected")
				addLog("Bridge unreachable — retrying…", true)
			end
		end

		task.wait(POLL_RATE)
	end
	bridgeOk = false
end

-- ── Button actions ────────────────────────────────────────────────────────────
startBtn.MouseButton1Click:Connect(function()
	if not isRunning then
		setRunning(true)
		task.spawn(pollLoop)
	else
		setRunning(false)
	end
end)

startBtn.MouseEnter:Connect(function()
	startBtn.BackgroundColor3 = isRunning and Color3.fromRGB(240, 90, 90) or Color3.fromRGB(0, 180, 85)
end)
startBtn.MouseLeave:Connect(function()
	startBtn.BackgroundColor3 = isRunning and C.red or C.green
end)

clearBtn.MouseEnter:Connect(function() clearBtn.BackgroundColor3 = C.btnHover end)
clearBtn.MouseLeave:Connect(function() clearBtn.BackgroundColor3 = C.btnBg end)

-- open panel on first load
widget.Enabled = true
toggleButton:SetActive(true)
addLog("RobloxMCP loaded. Press Start Server to begin.")
