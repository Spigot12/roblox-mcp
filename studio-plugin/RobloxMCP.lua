-- RobloxMCP Studio Plugin

local HttpService   = game:GetService("HttpService")
local Selection     = game:GetService("Selection")

local BRIDGE_URL  = "http://localhost:7353"
local POLL_RATE   = 0.1
local MAX_LOG     = 100

-- ── Dock Widget ───────────────────────────────────────────────────────────────
local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right, false, false, 260, 460, 220, 320
)
local widget = plugin:CreateDockWidgetPluginGui("RobloxMCP", widgetInfo)
widget.Title = "RobloxMCP"

local toolbar      = plugin:CreateToolbar("RobloxMCP")
local toggleButton = toolbar:CreateButton("RobloxMCP", "Open RobloxMCP panel", "rbxassetid://7733960981")
toggleButton.ClickableWhenViewportHidden = true
toggleButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
	toggleButton:SetActive(widget.Enabled)
end)

-- ── Theme ─────────────────────────────────────────────────────────────────────
local C = {}
local function applyTheme()
	local dark = pcall(function() return settings().Studio.Theme.Name == "Dark" end)
	if not dark then dark = true end
	if dark then
		C.bg      = Color3.fromRGB(30,30,30);   C.panel  = Color3.fromRGB(40,40,40)
		C.border  = Color3.fromRGB(60,60,60);   C.text   = Color3.fromRGB(220,220,220)
		C.subtext = Color3.fromRGB(150,150,150); C.btnBg  = Color3.fromRGB(55,55,55)
		C.btnHov  = Color3.fromRGB(75,75,75);   C.green  = Color3.fromRGB(0,200,100)
		C.red     = Color3.fromRGB(220,70,70);  C.logBg  = Color3.fromRGB(22,22,22)
		C.logText = Color3.fromRGB(180,180,180); C.yellow = Color3.fromRGB(255,200,60)
	else
		C.bg      = Color3.fromRGB(240,240,240); C.panel  = Color3.fromRGB(255,255,255)
		C.border  = Color3.fromRGB(200,200,200); C.text   = Color3.fromRGB(30,30,30)
		C.subtext = Color3.fromRGB(100,100,100); C.btnBg  = Color3.fromRGB(220,220,220)
		C.btnHov  = Color3.fromRGB(200,200,200); C.green  = Color3.fromRGB(0,160,80)
		C.red     = Color3.fromRGB(200,50,50);  C.logBg  = Color3.fromRGB(250,250,250)
		C.logText = Color3.fromRGB(60,60,60);   C.yellow = Color3.fromRGB(180,130,0)
	end
end
applyTheme()

-- ── Root ──────────────────────────────────────────────────────────────────────
local root = Instance.new("Frame")
root.Size = UDim2.new(1,0,1,0); root.BackgroundColor3 = C.bg; root.BorderSizePixel = 0
root.Parent = widget
local pad = Instance.new("UIPadding", root)
pad.PaddingLeft=UDim.new(0,10); pad.PaddingRight=UDim.new(0,10)
pad.PaddingTop=UDim.new(0,10);  pad.PaddingBottom=UDim.new(0,10)
local rootLayout = Instance.new("UIListLayout", root)
rootLayout.FillDirection=Enum.FillDirection.Vertical; rootLayout.SortOrder=Enum.SortOrder.LayoutOrder
rootLayout.Padding=UDim.new(0,6)

local function makeFrame(parent, h, lo)
	local f = Instance.new("Frame", parent)
	f.Size=UDim2.new(1,0,0,h); f.BackgroundTransparency=1; f.LayoutOrder=lo
	return f
end

-- ── Header ────────────────────────────────────────────────────────────────────
local hdr = makeFrame(root, 26, 1)
local titleLbl = Instance.new("TextLabel", hdr)
titleLbl.Size=UDim2.new(1,0,1,0); titleLbl.BackgroundTransparency=1
titleLbl.Text="Roblox MCP"; titleLbl.Font=Enum.Font.GothamBold
titleLbl.TextSize=16; titleLbl.TextColor3=C.text; titleLbl.TextXAlignment=Enum.TextXAlignment.Left

-- ── Status card ───────────────────────────────────────────────────────────────
local statusCard = Instance.new("Frame", root)
statusCard.Size=UDim2.new(1,0,0,52); statusCard.BackgroundColor3=C.panel
statusCard.BorderSizePixel=0; statusCard.LayoutOrder=2
Instance.new("UICorner", statusCard).CornerRadius=UDim.new(0,8)

local dot = Instance.new("Frame", statusCard)
dot.Size=UDim2.new(0,10,0,10); dot.Position=UDim2.new(0,14,0.5,-5)
dot.BackgroundColor3=C.red; dot.BorderSizePixel=0
Instance.new("UICorner", dot).CornerRadius=UDim.new(1,0)

local statusLbl = Instance.new("TextLabel", statusCard)
statusLbl.Size=UDim2.new(1,-40,0,18); statusLbl.Position=UDim2.new(0,32,0,8)
statusLbl.BackgroundTransparency=1; statusLbl.Text="Disconnected"
statusLbl.Font=Enum.Font.GothamBold; statusLbl.TextSize=13
statusLbl.TextColor3=C.text; statusLbl.TextXAlignment=Enum.TextXAlignment.Left

local statusSub = Instance.new("TextLabel", statusCard)
statusSub.Size=UDim2.new(1,-40,0,14); statusSub.Position=UDim2.new(0,32,0,28)
statusSub.BackgroundTransparency=1; statusSub.Text="Click Start to connect"
statusSub.Font=Enum.Font.Gotham; statusSub.TextSize=11
statusSub.TextColor3=C.subtext; statusSub.TextXAlignment=Enum.TextXAlignment.Left

-- ── Start / Stop button ───────────────────────────────────────────────────────
local startBtn = Instance.new("TextButton", root)
startBtn.Size=UDim2.new(1,0,0,34); startBtn.BackgroundColor3=C.green
startBtn.BorderSizePixel=0; startBtn.Text="Start Server"
startBtn.Font=Enum.Font.GothamBold; startBtn.TextSize=14
startBtn.TextColor3=Color3.new(1,1,1); startBtn.LayoutOrder=3
Instance.new("UICorner", startBtn).CornerRadius=UDim.new(0,8)

-- ── Stats row ─────────────────────────────────────────────────────────────────
local statsRow = makeFrame(root, 16, 4)
local cmdCountLbl = Instance.new("TextLabel", statsRow)
cmdCountLbl.Size=UDim2.new(0.5,0,1,0); cmdCountLbl.BackgroundTransparency=1
cmdCountLbl.Text="Commands: 0"; cmdCountLbl.Font=Enum.Font.Gotham
cmdCountLbl.TextSize=11; cmdCountLbl.TextColor3=C.subtext
cmdCountLbl.TextXAlignment=Enum.TextXAlignment.Left

local errCountLbl = Instance.new("TextLabel", statsRow)
errCountLbl.Size=UDim2.new(0.5,0,1,0); errCountLbl.Position=UDim2.new(0.5,0,0,0)
errCountLbl.BackgroundTransparency=1; errCountLbl.Text="Errors: 0"
errCountLbl.Font=Enum.Font.Gotham; errCountLbl.TextSize=11
errCountLbl.TextColor3=C.subtext; errCountLbl.TextXAlignment=Enum.TextXAlignment.Right

-- ── Last command ──────────────────────────────────────────────────────────────
local lastCmdCard = Instance.new("Frame", root)
lastCmdCard.Size=UDim2.new(1,0,0,30); lastCmdCard.BackgroundColor3=C.panel
lastCmdCard.BorderSizePixel=0; lastCmdCard.LayoutOrder=5
Instance.new("UICorner", lastCmdCard).CornerRadius=UDim.new(0,6)

local lastCmdPre = Instance.new("TextLabel", lastCmdCard)
lastCmdPre.Size=UDim2.new(0,40,1,0); lastCmdPre.Position=UDim2.new(0,8,0,0)
lastCmdPre.BackgroundTransparency=1; lastCmdPre.Text="Last:"
lastCmdPre.Font=Enum.Font.Gotham; lastCmdPre.TextSize=11
lastCmdPre.TextColor3=C.subtext; lastCmdPre.TextXAlignment=Enum.TextXAlignment.Left

local lastCmdLbl = Instance.new("TextLabel", lastCmdCard)
lastCmdLbl.Size=UDim2.new(1,-56,1,0); lastCmdLbl.Position=UDim2.new(0,52,0,0)
lastCmdLbl.BackgroundTransparency=1; lastCmdLbl.Text="—"
lastCmdLbl.Font=Enum.Font.GothamBold; lastCmdLbl.TextSize=12
lastCmdLbl.TextColor3=C.text; lastCmdLbl.TextXAlignment=Enum.TextXAlignment.Left
lastCmdLbl.TextTruncate=Enum.TextTruncate.AtEnd

-- ── Log section ───────────────────────────────────────────────────────────────
local logTitleRow = makeFrame(root, 14, 6)
local logTitleLbl = Instance.new("TextLabel", logTitleRow)
logTitleLbl.Size=UDim2.new(0.5,0,1,0); logTitleLbl.BackgroundTransparency=1
logTitleLbl.Text="Activity Log"; logTitleLbl.Font=Enum.Font.GothamBold
logTitleLbl.TextSize=11; logTitleLbl.TextColor3=C.subtext
logTitleLbl.TextXAlignment=Enum.TextXAlignment.Left

local logFrame = Instance.new("Frame", root)
logFrame.Size=UDim2.new(1,0,1,-230); logFrame.BackgroundColor3=C.logBg
logFrame.BorderSizePixel=0; logFrame.LayoutOrder=7; logFrame.ClipsDescendants=true
Instance.new("UICorner", logFrame).CornerRadius=UDim.new(0,8)

local scroll = Instance.new("ScrollingFrame", logFrame)
scroll.Size=UDim2.new(1,0,1,0); scroll.BackgroundTransparency=1
scroll.BorderSizePixel=0; scroll.ScrollBarThickness=4
scroll.ScrollBarImageColor3=C.border; scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
scroll.CanvasSize=UDim2.new(0,0,0,0)
local sp = Instance.new("UIPadding", scroll)
sp.PaddingLeft=UDim.new(0,6); sp.PaddingRight=UDim.new(0,6)
sp.PaddingTop=UDim.new(0,4); sp.PaddingBottom=UDim.new(0,4)
local sl = Instance.new("UIListLayout", scroll)
sl.FillDirection=Enum.FillDirection.Vertical; sl.SortOrder=Enum.SortOrder.LayoutOrder
sl.Padding=UDim.new(0,2)

local clearBtn = Instance.new("TextButton", root)
clearBtn.Size=UDim2.new(1,0,0,24); clearBtn.BackgroundColor3=C.btnBg
clearBtn.BorderSizePixel=0; clearBtn.Text="Clear Log"; clearBtn.Font=Enum.Font.Gotham
clearBtn.TextSize=11; clearBtn.TextColor3=C.subtext; clearBtn.LayoutOrder=8
Instance.new("UICorner", clearBtn).CornerRadius=UDim.new(0,6)

local infoLbl = Instance.new("TextLabel", root)
infoLbl.Size=UDim2.new(1,0,0,12); infoLbl.BackgroundTransparency=1
infoLbl.Text="localhost:7353"; infoLbl.Font=Enum.Font.Gotham
infoLbl.TextSize=10; infoLbl.TextColor3=C.subtext
infoLbl.TextXAlignment=Enum.TextXAlignment.Center; infoLbl.LayoutOrder=9

-- ── Log helpers ───────────────────────────────────────────────────────────────
local logEntries = {}
local logCounter = 0

local function addLog(msg, color)
	logCounter += 1
	local row = Instance.new("TextLabel")
	row.Size=UDim2.new(1,0,0,0); row.AutomaticSize=Enum.AutomaticSize.Y
	row.BackgroundTransparency=1; row.Text=msg
	row.Font=Enum.Font.Code; row.TextSize=11
	row.TextColor3=color or C.logText
	row.TextXAlignment=Enum.TextXAlignment.Left; row.TextWrapped=true
	row.LayoutOrder=logCounter; row.Parent=scroll
	table.insert(logEntries, row)
	if #logEntries > MAX_LOG then logEntries[1]:Destroy(); table.remove(logEntries,1) end
	task.defer(function() scroll.CanvasPosition=Vector2.new(0, scroll.AbsoluteCanvasSize.Y) end)
end

clearBtn.MouseButton1Click:Connect(function()
	for _, e in ipairs(logEntries) do e:Destroy() end
	logEntries = {}
end)

-- ── State ─────────────────────────────────────────────────────────────────────
local isRunning  = false
local bridgeOk   = false
local cmdCount   = 0
local errCount   = 0

local function setStatus(connected, sub)
	dot.BackgroundColor3 = connected and C.green or C.red
	statusLbl.Text = connected and "Connected" or "Disconnected"
	statusSub.Text = sub or (connected and "Ready" or "Click Start to connect")
end

local function setRunning(v)
	isRunning = v
	if v then
		startBtn.Text="Stop Server"; startBtn.BackgroundColor3=C.red
		toggleButton:SetActive(true)
		addLog("Server started — " .. BRIDGE_URL)
		setStatus(false, "Waiting for bridge…")
	else
		startBtn.Text="Start Server"; startBtn.BackgroundColor3=C.green
		toggleButton:SetActive(false)
		setStatus(false, "Click Start to connect")
		addLog("Server stopped")
		bridgeOk = false
	end
end

-- ── Path resolver ─────────────────────────────────────────────────────────────
local function resolvePath(path)
	local parts = path:split(".")
	local current
	if parts[1] == "game" then
		current = game
		for i = 2, #parts do current = current[parts[i]] end
	else
		local ok, svc = pcall(function() return game:GetService(parts[1]) end)
		current = (ok and svc) or game[parts[1]]
		for i = 2, #parts do current = current[parts[i]] end
	end
	return current
end

local function serializeValue(val)
	local t = typeof(val)
	if t == "Vector3"   then return {x=val.X, y=val.Y, z=val.Z} end
	if t == "Color3"    then return {r=val.R, g=val.G, b=val.B} end
	if t == "Vector2"   then return {x=val.X, y=val.Y} end
	if t == "CFrame"    then return {x=val.X, y=val.Y, z=val.Z} end
	if t == "BrickColor" then return tostring(val) end
	if t == "EnumItem"  then return tostring(val) end
	if t == "boolean" or t == "number" or t == "string" then return val end
	return tostring(val)
end

-- ── Handlers ──────────────────────────────────────────────────────────────────
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
	return {success=true, partCount=#game.Workspace:GetDescendants(),
	        children=children, gameName=game.Name, placeId=game.PlaceId}
end

handlers["create_part"] = function(p)
	local part = Instance.new("Part")
	part.Name = p.name or "Part"
	if p.size then part.Size=Vector3.new(p.size.x or 4, p.size.y or 1, p.size.z or 4) end
	if p.position then part.Position=Vector3.new(p.position.x or 0, p.position.y or 5, p.position.z or 0) end
	if p.color then part.Color=Color3.new(p.color.r or .6, p.color.g or .6, p.color.b or .6) end
	part.Anchored = p.anchored ~= false
	if p.material then
		local ok, mat = pcall(function() return Enum.Material[p.material] end)
		if ok then part.Material=mat end
	end
	part.Parent = game.Workspace
	return {success=true, name=part.Name, path=part:GetFullName()}
end

handlers["insert_script"] = function(p)
	local s = Instance.new(p.script_type or "Script")
	s.Name=p.name; s.Source=p.source or ""
	local ok, err = pcall(function() s.Parent=resolvePath(p.parent) end)
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
		if not (c.Name=="Baseplate" or c:IsA("Terrain") or c:IsA("Camera")) then
			c:Destroy(); removed+=1
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

handlers["get_properties"] = function(p)
	local ok, obj = pcall(resolvePath, p.path)
	if not ok or not obj then return {success=false, error="Path not found: "..tostring(p.path)} end
	local props = {Name=obj.Name, ClassName=obj.ClassName,
	               Parent=obj.Parent and obj.Parent:GetFullName() or nil}
	local tryList = {"Position","Size","Color","Anchored","Material","Transparency",
	                 "CanCollide","Source","Value","BrickColor","CastShadow","Locked",
	                 "Visible","Text","Font","TextSize","BackgroundColor3","BorderSizePixel",
	                 "Rotation","Shape","TopSurface","BottomSurface","Massless","Velocity"}
	for _, prop in ipairs(tryList) do
		local ok2, val = pcall(function() return obj[prop] end)
		if ok2 and val ~= nil then
			local ok3, serialized = pcall(serializeValue, val)
			if ok3 then props[prop] = serialized end
		end
	end
	return {success=true, path=obj:GetFullName(), properties=props}
end

handlers["set_property"] = function(p)
	local ok, obj = pcall(resolvePath, p.path)
	if not ok or not obj then return {success=false, error="Path not found: "..tostring(p.path)} end
	local value = p.value
	if type(value) == "table" then
		if value.x ~= nil and value.z ~= nil then
			value = Vector3.new(value.x, value.y or 0, value.z)
		elseif value.r ~= nil and value.g ~= nil and value.b ~= nil then
			value = Color3.new(value.r, value.g, value.b)
		elseif value.x ~= nil and value.y ~= nil then
			value = Vector2.new(value.x, value.y)
		end
	end
	local setOk, err = pcall(function() obj[p.property] = value end)
	return setOk and {success=true, path=obj:GetFullName(), property=p.property}
	            or  {success=false, error=tostring(err)}
end

handlers["find_instances"] = function(p)
	local scope = game
	if p.scope then
		local ok, obj = pcall(resolvePath, p.scope)
		if ok then scope = obj end
	end
	local results = {}
	local max = p.max_results or 50
	local function search(obj)
		if #results >= max then return end
		if obj ~= scope then
			local nameMatch  = not p.name       or obj.Name      == p.name
			local classMatch = not p.class_name or obj.ClassName == p.class_name
			if nameMatch and classMatch then
				table.insert(results, {name=obj.Name, className=obj.ClassName, path=obj:GetFullName()})
			end
		end
		for _, child in ipairs(obj:GetChildren()) do
			if #results >= max then return end
			search(child)
		end
	end
	search(scope)
	return {success=true, results=results, count=#results}
end

handlers["delete_instance"] = function(p)
	local ok, obj = pcall(resolvePath, p.path)
	if not ok or not obj then return {success=false, error="Path not found: "..tostring(p.path)} end
	local name = obj.Name
	local parentPath = obj.Parent and obj.Parent:GetFullName() or "?"
	obj:Destroy()
	return {success=true, deleted=name, from=parentPath}
end

handlers["clone_instance"] = function(p)
	local ok, obj = pcall(resolvePath, p.path)
	if not ok or not obj then return {success=false, error="Path not found: "..tostring(p.path)} end
	local clone = obj:Clone()
	if p.new_name then clone.Name = p.new_name end
	local ok2, err = pcall(function()
		clone.Parent = p.parent and resolvePath(p.parent) or obj.Parent
	end)
	return ok2 and {success=true, path=clone:GetFullName()}
	           or  {success=false, error=tostring(err)}
end

handlers["start_playtest"] = function(_)
	local ok, err = pcall(function() game:GetService("TestService"):Run() end)
	return {success=ok, error=ok and nil or tostring(err)}
end

handlers["stop_playtest"] = function(_)
	return {success=true, note="Use the Studio Stop button or press F5"}
end

-- ── Poll loop ─────────────────────────────────────────────────────────────────
local function pollLoop()
	while isRunning do
		local ok, response = pcall(function()
			return HttpService:RequestAsync({Url=BRIDGE_URL.."/poll", Method="GET"})
		end)

		if ok and response and response.Success then
			if not bridgeOk then
				bridgeOk = true
				setStatus(true, "Bridge connected")
				addLog("Bridge connected")
			end

			local data = HttpService:JSONDecode(response.Body)
			if data and data.command then
				cmdCount += 1
				cmdCountLbl.Text = "Commands: " .. cmdCount
				lastCmdLbl.Text  = data.command
				lastCmdLbl.TextColor3 = C.yellow
				addLog("[" .. cmdCount .. "] " .. data.command)

				local handler = handlers[data.command]
				local result
				if handler then
					local callOk, callResult = pcall(handler, data.params or {})
					result = callOk and callResult or {success=false, error=tostring(callResult)}
				else
					result = {success=false, error="Unknown command: "..tostring(data.command)}
				end

				if result.success == false then
					errCount += 1
					errCountLbl.Text = "Errors: " .. errCount
					errCountLbl.TextColor3 = C.red
					lastCmdLbl.TextColor3  = C.red
					addLog("  error: "..(result.error or "?"), C.red)
				else
					lastCmdLbl.TextColor3 = C.green
				end

				pcall(function()
					HttpService:RequestAsync({
						Url=BRIDGE_URL.."/result", Method="POST",
						Headers={["Content-Type"]="application/json"},
						Body=HttpService:JSONEncode({id=data.id, result=result}),
					})
				end)
			end
		else
			if bridgeOk then
				bridgeOk = false
				setStatus(false, "Bridge disconnected — retrying…")
				addLog("Bridge unreachable", C.red)
			end
		end

		task.wait(POLL_RATE)
	end
	bridgeOk = false
end

-- ── Button wiring ─────────────────────────────────────────────────────────────
startBtn.MouseButton1Click:Connect(function()
	if not isRunning then setRunning(true); task.spawn(pollLoop)
	else setRunning(false) end
end)
startBtn.MouseEnter:Connect(function()
	startBtn.BackgroundColor3 = isRunning and Color3.fromRGB(240,90,90) or Color3.fromRGB(0,180,85)
end)
startBtn.MouseLeave:Connect(function()
	startBtn.BackgroundColor3 = isRunning and C.red or C.green
end)
clearBtn.MouseEnter:Connect(function() clearBtn.BackgroundColor3=C.btnHov end)
clearBtn.MouseLeave:Connect(function() clearBtn.BackgroundColor3=C.btnBg end)

widget.Enabled = true
toggleButton:SetActive(true)
addLog("RobloxMCP loaded — press Start Server")
