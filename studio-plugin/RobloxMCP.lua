-- RobloxMCP Studio Plugin v2

local HttpService         = game:GetService("HttpService")
local Selection           = game:GetService("Selection")
local CollectionService   = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local LogService          = game:GetService("LogService")

local BRIDGE_URL = "http://localhost:7353"
local POLL_RATE  = 0.1
local MAX_LOG    = 100
local MAX_OUTPUT = 500

-- ── Studio output capture ─────────────────────────────────────────────────────
local outputBuffer = {}
LogService.MessageOut:Connect(function(msg, msgType)
	local typeStr = "print"
	if msgType == Enum.MessageType.MessageWarning then typeStr = "warning"
	elseif msgType == Enum.MessageType.MessageError then typeStr = "error"
	elseif msgType == Enum.MessageType.MessageInfo then typeStr = "info" end
	table.insert(outputBuffer, {text=msg, type=typeStr, time=os.time()})
	if #outputBuffer > MAX_OUTPUT then table.remove(outputBuffer, 1) end
end)

-- ── Dock Widget ───────────────────────────────────────────────────────────────
local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right, false, false, 260, 460, 220, 320)
local widget = plugin:CreateDockWidgetPluginGui("RobloxMCP", widgetInfo)
widget.Title = "RobloxMCP"

local toolbar      = plugin:CreateToolbar("RobloxMCP")
local toggleButton = toolbar:CreateButton("RobloxMCP", "Open RobloxMCP panel", "rbxassetid://7733960981")
toggleButton.ClickableWhenViewportHidden = true
toggleButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled; toggleButton:SetActive(widget.Enabled)
end)

-- ── Theme ─────────────────────────────────────────────────────────────────────
local C = {}
local function applyTheme()
	local ok, theme = pcall(function() return settings().Studio.Theme.Name end)
	local dark = not ok or theme ~= "Light"
	if dark then
		C.bg=Color3.fromRGB(30,30,30);    C.panel=Color3.fromRGB(40,40,40)
		C.border=Color3.fromRGB(60,60,60); C.text=Color3.fromRGB(220,220,220)
		C.sub=Color3.fromRGB(150,150,150); C.btnBg=Color3.fromRGB(55,55,55)
		C.btnHov=Color3.fromRGB(75,75,75); C.green=Color3.fromRGB(0,200,100)
		C.red=Color3.fromRGB(220,70,70);   C.logBg=Color3.fromRGB(22,22,22)
		C.logTxt=Color3.fromRGB(180,180,180); C.yellow=Color3.fromRGB(255,200,60)
	else
		C.bg=Color3.fromRGB(240,240,240);  C.panel=Color3.fromRGB(255,255,255)
		C.border=Color3.fromRGB(200,200,200); C.text=Color3.fromRGB(30,30,30)
		C.sub=Color3.fromRGB(100,100,100); C.btnBg=Color3.fromRGB(220,220,220)
		C.btnHov=Color3.fromRGB(200,200,200); C.green=Color3.fromRGB(0,160,80)
		C.red=Color3.fromRGB(200,50,50);   C.logBg=Color3.fromRGB(250,250,250)
		C.logTxt=Color3.fromRGB(60,60,60); C.yellow=Color3.fromRGB(180,130,0)
	end
end
applyTheme()

-- ── UI helpers ────────────────────────────────────────────────────────────────
local root = Instance.new("Frame")
root.Size=UDim2.new(1,0,1,0); root.BackgroundColor3=C.bg; root.BorderSizePixel=0; root.Parent=widget
local _p = Instance.new("UIPadding",root)
_p.PaddingLeft=UDim.new(0,10); _p.PaddingRight=UDim.new(0,10)
_p.PaddingTop=UDim.new(0,10);  _p.PaddingBottom=UDim.new(0,10)
local rootL = Instance.new("UIListLayout",root)
rootL.FillDirection=Enum.FillDirection.Vertical; rootL.SortOrder=Enum.SortOrder.LayoutOrder
rootL.Padding=UDim.new(0,6)

local function frame(parent, h, lo)
	local f=Instance.new("Frame",parent); f.Size=UDim2.new(1,0,0,h)
	f.BackgroundTransparency=1; f.LayoutOrder=lo; return f
end
local function label(parent, text, size, font, color, xAlign)
	local l=Instance.new("TextLabel",parent); l.Size=UDim2.new(1,0,1,0)
	l.BackgroundTransparency=1; l.Text=text; l.Font=font or Enum.Font.Gotham
	l.TextSize=size or 12; l.TextColor3=color or C.text
	l.TextXAlignment=xAlign or Enum.TextXAlignment.Left; return l
end
local function corner(parent, r) Instance.new("UICorner",parent).CornerRadius=UDim.new(0,r or 8) end

-- Header
local hdrF = frame(root,26,1)
label(hdrF,"Roblox MCP",16,Enum.Font.GothamBold,C.text)

-- Status card
local statusCard=Instance.new("Frame",root); statusCard.Size=UDim2.new(1,0,0,52)
statusCard.BackgroundColor3=C.panel; statusCard.BorderSizePixel=0; statusCard.LayoutOrder=2; corner(statusCard)
local dot=Instance.new("Frame",statusCard); dot.Size=UDim2.new(0,10,0,10)
dot.Position=UDim2.new(0,14,0.5,-5); dot.BackgroundColor3=C.red; dot.BorderSizePixel=0; corner(dot,99)
local statusLbl=Instance.new("TextLabel",statusCard); statusLbl.Size=UDim2.new(1,-40,0,18)
statusLbl.Position=UDim2.new(0,32,0,8); statusLbl.BackgroundTransparency=1; statusLbl.Text="Disconnected"
statusLbl.Font=Enum.Font.GothamBold; statusLbl.TextSize=13; statusLbl.TextColor3=C.text
statusLbl.TextXAlignment=Enum.TextXAlignment.Left
local statusSub=Instance.new("TextLabel",statusCard); statusSub.Size=UDim2.new(1,-40,0,14)
statusSub.Position=UDim2.new(0,32,0,28); statusSub.BackgroundTransparency=1
statusSub.Text="Click Start to connect"; statusSub.Font=Enum.Font.Gotham
statusSub.TextSize=11; statusSub.TextColor3=C.sub; statusSub.TextXAlignment=Enum.TextXAlignment.Left

-- Start button
local startBtn=Instance.new("TextButton",root); startBtn.Size=UDim2.new(1,0,0,34)
startBtn.BackgroundColor3=C.green; startBtn.BorderSizePixel=0; startBtn.Text="Start Server"
startBtn.Font=Enum.Font.GothamBold; startBtn.TextSize=14; startBtn.TextColor3=Color3.new(1,1,1)
startBtn.LayoutOrder=3; corner(startBtn)

-- Stats row
local statsF=frame(root,16,4)
local cmdLbl=Instance.new("TextLabel",statsF); cmdLbl.Size=UDim2.new(0.5,0,1,0)
cmdLbl.BackgroundTransparency=1; cmdLbl.Text="Commands: 0"; cmdLbl.Font=Enum.Font.Gotham
cmdLbl.TextSize=11; cmdLbl.TextColor3=C.sub; cmdLbl.TextXAlignment=Enum.TextXAlignment.Left
local errLbl=Instance.new("TextLabel",statsF); errLbl.Size=UDim2.new(0.5,0,1,0)
errLbl.Position=UDim2.new(0.5,0,0,0); errLbl.BackgroundTransparency=1; errLbl.Text="Errors: 0"
errLbl.Font=Enum.Font.Gotham; errLbl.TextSize=11; errLbl.TextColor3=C.sub
errLbl.TextXAlignment=Enum.TextXAlignment.Right

-- Last command card
local lastCard=Instance.new("Frame",root); lastCard.Size=UDim2.new(1,0,0,30)
lastCard.BackgroundColor3=C.panel; lastCard.BorderSizePixel=0; lastCard.LayoutOrder=5; corner(lastCard,6)
local lastPre=Instance.new("TextLabel",lastCard); lastPre.Size=UDim2.new(0,40,1,0)
lastPre.Position=UDim2.new(0,8,0,0); lastPre.BackgroundTransparency=1; lastPre.Text="Last:"
lastPre.Font=Enum.Font.Gotham; lastPre.TextSize=11; lastPre.TextColor3=C.sub
lastPre.TextXAlignment=Enum.TextXAlignment.Left
local lastLbl=Instance.new("TextLabel",lastCard); lastLbl.Size=UDim2.new(1,-56,1,0)
lastLbl.Position=UDim2.new(0,52,0,0); lastLbl.BackgroundTransparency=1; lastLbl.Text="—"
lastLbl.Font=Enum.Font.GothamBold; lastLbl.TextSize=12; lastLbl.TextColor3=C.text
lastLbl.TextXAlignment=Enum.TextXAlignment.Left; lastLbl.TextTruncate=Enum.TextTruncate.AtEnd

-- Log title
local logTF=frame(root,14,6)
label(logTF,"Activity Log",11,Enum.Font.GothamBold,C.sub)

-- Scroll log
local logFrame=Instance.new("Frame",root); logFrame.Size=UDim2.new(1,0,1,-232)
logFrame.BackgroundColor3=C.logBg; logFrame.BorderSizePixel=0; logFrame.LayoutOrder=7
logFrame.ClipsDescendants=true; corner(logFrame)
local scroll=Instance.new("ScrollingFrame",logFrame); scroll.Size=UDim2.new(1,0,1,0)
scroll.BackgroundTransparency=1; scroll.BorderSizePixel=0; scroll.ScrollBarThickness=4
scroll.ScrollBarImageColor3=C.border; scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
scroll.CanvasSize=UDim2.new(0,0,0,0)
local sp=Instance.new("UIPadding",scroll); sp.PaddingLeft=UDim.new(0,6); sp.PaddingRight=UDim.new(0,6)
sp.PaddingTop=UDim.new(0,4); sp.PaddingBottom=UDim.new(0,4)
local sl=Instance.new("UIListLayout",scroll); sl.FillDirection=Enum.FillDirection.Vertical
sl.SortOrder=Enum.SortOrder.LayoutOrder; sl.Padding=UDim.new(0,2)

-- Clear button
local clearBtn=Instance.new("TextButton",root); clearBtn.Size=UDim2.new(1,0,0,24)
clearBtn.BackgroundColor3=C.btnBg; clearBtn.BorderSizePixel=0; clearBtn.Text="Clear Log"
clearBtn.Font=Enum.Font.Gotham; clearBtn.TextSize=11; clearBtn.TextColor3=C.sub; clearBtn.LayoutOrder=8; corner(clearBtn,6)

-- Port label
local portLbl=Instance.new("TextLabel",root); portLbl.Size=UDim2.new(1,0,0,12)
portLbl.BackgroundTransparency=1; portLbl.Text="localhost:7353 · "..#({}) .." tools"
portLbl.Font=Enum.Font.Gotham; portLbl.TextSize=10; portLbl.TextColor3=C.sub
portLbl.TextXAlignment=Enum.TextXAlignment.Center; portLbl.LayoutOrder=9

-- ── Log helpers ───────────────────────────────────────────────────────────────
local logEntries = {}
local logN = 0
local function addLog(msg, color)
	logN += 1
	local r=Instance.new("TextLabel"); r.Size=UDim2.new(1,0,0,0); r.AutomaticSize=Enum.AutomaticSize.Y
	r.BackgroundTransparency=1; r.Text=msg; r.Font=Enum.Font.Code; r.TextSize=11
	r.TextColor3=color or C.logTxt; r.TextXAlignment=Enum.TextXAlignment.Left
	r.TextWrapped=true; r.LayoutOrder=logN; r.Parent=scroll
	table.insert(logEntries, r)
	if #logEntries > MAX_LOG then logEntries[1]:Destroy(); table.remove(logEntries,1) end
	task.defer(function() scroll.CanvasPosition=Vector2.new(0, scroll.AbsoluteCanvasSize.Y) end)
end
clearBtn.MouseButton1Click:Connect(function()
	for _,e in ipairs(logEntries) do e:Destroy() end; logEntries={}
end)

-- ── State ─────────────────────────────────────────────────────────────────────
local isRunning=false; local bridgeOk=false; local cmdCount=0; local errCount=0

local function setStatus(conn, sub)
	dot.BackgroundColor3=conn and C.green or C.red
	statusLbl.Text=conn and "Connected" or "Disconnected"
	statusSub.Text=sub or (conn and "Ready" or "Click Start to connect")
end
local function setRunning(v)
	isRunning=v
	if v then startBtn.Text="Stop Server"; startBtn.BackgroundColor3=C.red; toggleButton:SetActive(true)
	        addLog("Server started — "..BRIDGE_URL); setStatus(false,"Waiting for bridge…")
	else   startBtn.Text="Start Server"; startBtn.BackgroundColor3=C.green; toggleButton:SetActive(false)
	       setStatus(false,"Click Start to connect"); addLog("Server stopped"); bridgeOk=false end
end

-- ── Path resolver ─────────────────────────────────────────────────────────────
local function resolvePath(path)
	local parts = path:split(".")
	local cur
	if parts[1]=="game" then cur=game; for i=2,#parts do cur=cur[parts[i]] end
	else
		local ok,svc=pcall(function() return game:GetService(parts[1]) end)
		cur=(ok and svc) or game[parts[1]]
		for i=2,#parts do cur=cur[parts[i]] end
	end
	return cur
end

local function serializeValue(val)
	local t=typeof(val)
	if t=="Vector3"   then return {x=val.X,y=val.Y,z=val.Z} end
	if t=="Color3"    then return {r=val.R,g=val.G,b=val.B} end
	if t=="Vector2"   then return {x=val.X,y=val.Y} end
	if t=="CFrame"    then return {x=val.X,y=val.Y,z=val.Z,rx=val.LookVector.X,ry=val.LookVector.Y,rz=val.LookVector.Z} end
	if t=="BrickColor" then return tostring(val) end
	if t=="EnumItem"  then return tostring(val) end
	if t=="boolean" or t=="number" or t=="string" then return val end
	return tostring(val)
end

local function coerceValue(value)
	if type(value)=="table" then
		if value.x~=nil and value.z~=nil then return Vector3.new(value.x,value.y or 0,value.z)
		elseif value.r~=nil and value.g~=nil and value.b~=nil then return Color3.new(value.r,value.g,value.b)
		elseif value.x~=nil and value.y~=nil then return Vector2.new(value.x,value.y) end
	end
	return value
end

local COMMON_PROPS = {"Position","Size","Color","Anchored","Material","Transparency","CanCollide",
	"Source","Value","BrickColor","CastShadow","Locked","Visible","Text","Font","TextSize",
	"BackgroundColor3","BorderSizePixel","Rotation","Shape","TopSurface","BottomSurface",
	"Massless","Velocity","Name","ClassName"}

-- ── Handlers ──────────────────────────────────────────────────────────────────
local H = {}

H.execute_script = function(p)
	local fn,err=loadstring(p.code)
	if not fn then return {success=false,error="Parse: "..tostring(err)} end
	local ok,res=pcall(fn)
	return ok and {success=true,result=tostring(res or "")} or {success=false,error=tostring(res)}
end

H.get_output_log = function(p)
	local filter = p.filter or "all"
	local results = {}
	for _,entry in ipairs(outputBuffer) do
		if filter=="all" or entry.type==filter then
			table.insert(results, entry)
		end
	end
	return {success=true, log=results, count=#results}
end

H.undo = function(_)
	local ok,err=pcall(function() ChangeHistoryService:Undo() end)
	return {success=ok, error=ok and nil or tostring(err)}
end

H.redo = function(_)
	local ok,err=pcall(function() ChangeHistoryService:Redo() end)
	return {success=ok, error=ok and nil or tostring(err)}
end

H.get_workspace_info = function(_)
	local children={}
	for _,c in ipairs(game.Workspace:GetChildren()) do
		table.insert(children,{name=c.Name,className=c.ClassName})
	end
	return {success=true, partCount=#game.Workspace:GetDescendants(),
	        children=children, gameName=game.Name, placeId=game.PlaceId}
end

H.get_place_info = function(_)
	local info = {
		placeId   = game.PlaceId,
		gameId    = game.GameId,
		name      = game.Name,
		creator   = tostring(game.CreatorId),
		creatorType = tostring(game.CreatorType),
		genre     = tostring(game.Genre),
		maxPlayers = game.Players.MaxPlayers,
	}
	return {success=true, info=info}
end

H.get_selection = function(_)
	local items={}
	for _,obj in ipairs(Selection:Get()) do
		table.insert(items,{name=obj.Name,className=obj.ClassName,path=obj:GetFullName()})
	end
	return {success=true, selection=items, count=#items}
end

H.list_instances = function(p)
	local ok,obj=pcall(resolvePath,p.path)
	if not ok or not obj then return {success=false,error="Path not found: "..tostring(p.path)} end
	local children={}
	for _,c in ipairs(obj:GetChildren()) do
		table.insert(children,{name=c.Name,className=c.ClassName,path=c:GetFullName()})
	end
	return {success=true, children=children, count=#children}
end

H.get_properties = function(p)
	local ok,obj=pcall(resolvePath,p.path)
	if not ok or not obj then return {success=false,error="Path not found: "..tostring(p.path)} end
	local props={Name=obj.Name,ClassName=obj.ClassName,
	             Parent=obj.Parent and obj.Parent:GetFullName() or nil}
	for _,prop in ipairs(COMMON_PROPS) do
		local ok2,val=pcall(function() return obj[prop] end)
		if ok2 and val~=nil then
			local ok3,s=pcall(serializeValue,val)
			if ok3 then props[prop]=s end
		end
	end
	return {success=true,path=obj:GetFullName(),properties=props}
end

H.get_descendants = function(p)
	local ok,obj=pcall(resolvePath,p.path)
	if not ok or not obj then return {success=false,error="Path not found: "..tostring(p.path)} end
	local max=p.max_results or 200
	local results={}
	for _,d in ipairs(obj:GetDescendants()) do
		if not p.class_name or d.ClassName==p.class_name then
			table.insert(results,{name=d.Name,className=d.ClassName,path=d:GetFullName()})
			if #results>=max then break end
		end
	end
	return {success=true, descendants=results, count=#results}
end

H.compare_instances = function(p)
	local okA,a=pcall(resolvePath,p.path_a)
	local okB,b=pcall(resolvePath,p.path_b)
	if not okA or not a then return {success=false,error="path_a not found"} end
	if not okB or not b then return {success=false,error="path_b not found"} end
	local diffs={}
	for _,prop in ipairs(COMMON_PROPS) do
		local okV1,v1=pcall(function() return a[prop] end)
		local okV2,v2=pcall(function() return b[prop] end)
		if okV1 and okV2 then
			local s1=pcall(serializeValue,v1) and serializeValue(v1) or tostring(v1)
			local s2=pcall(serializeValue,v2) and serializeValue(v2) or tostring(v2)
			if tostring(s1)~=tostring(s2) then
				table.insert(diffs,{property=prop, a=s1, b=s2})
			end
		end
	end
	return {success=true, path_a=a:GetFullName(), path_b=b:GetFullName(),
	        differences=diffs, identical=#diffs==0}
end

H.search_by_property = function(p)
	local scope=game
	if p.scope then local ok,obj=pcall(resolvePath,p.scope); if ok then scope=obj end end
	local max=p.max_results or 50; local results={}
	local function search(obj)
		if #results>=max then return end
		if not p.class_name or obj.ClassName==p.class_name then
			local ok,val=pcall(function() return obj[p.property] end)
			if ok then
				local _,s=pcall(serializeValue,val)
				if tostring(s)==tostring(p.value) or tostring(val)==tostring(p.value) then
					table.insert(results,{name=obj.Name,className=obj.ClassName,
					                      path=obj:GetFullName(),value=s})
				end
			end
		end
		for _,c in ipairs(obj:GetChildren()) do
			if #results>=max then return end
			search(c)
		end
	end
	search(scope)
	return {success=true, results=results, count=#results}
end

H.find_instances = function(p)
	local scope=game
	if p.scope then local ok,obj=pcall(resolvePath,p.scope); if ok then scope=obj end end
	local max=p.max_results or 50; local results={}
	local function search(obj)
		if #results>=max or obj==scope then
			if obj~=scope then
				local nm=not p.name or obj.Name==p.name
				local cm=not p.class_name or obj.ClassName==p.class_name
				if nm and cm then
					table.insert(results,{name=obj.Name,className=obj.ClassName,path=obj:GetFullName()})
				end
			end
		else
			local nm=not p.name or obj.Name==p.name
			local cm=not p.class_name or obj.ClassName==p.class_name
			if nm and cm then
				table.insert(results,{name=obj.Name,className=obj.ClassName,path=obj:GetFullName()})
			end
		end
		for _,c in ipairs(obj:GetChildren()) do
			if #results>=max then return end
			search(c)
		end
	end
	-- fixed traversal
	local function traverse(obj)
		if #results>=max then return end
		if obj~=scope then
			local nm=not p.name or obj.Name==p.name
			local cm=not p.class_name or obj.ClassName==p.class_name
			if nm and cm then
				table.insert(results,{name=obj.Name,className=obj.ClassName,path=obj:GetFullName()})
			end
		end
		for _,c in ipairs(obj:GetChildren()) do traverse(c) end
	end
	traverse(scope)
	return {success=true, results=results, count=#results}
end

H.create_part = function(p)
	local part=Instance.new("Part"); part.Name=p.name or "Part"
	if p.size then part.Size=Vector3.new(p.size.x or 4,p.size.y or 1,p.size.z or 4) end
	if p.position then part.Position=Vector3.new(p.position.x or 0,p.position.y or 5,p.position.z or 0) end
	if p.color then part.Color=Color3.new(p.color.r or .6,p.color.g or .6,p.color.b or .6) end
	part.Anchored=p.anchored~=false
	if p.material then local ok,mat=pcall(function() return Enum.Material[p.material] end); if ok then part.Material=mat end end
	part.Parent=game.Workspace
	ChangeHistoryService:SetWaypoint("CreatePart:"..part.Name)
	return {success=true,name=part.Name,path=part:GetFullName()}
end

H.set_property = function(p)
	local ok,obj=pcall(resolvePath,p.path)
	if not ok or not obj then return {success=false,error="Path not found: "..tostring(p.path)} end
	local setOk,err=pcall(function() obj[p.property]=coerceValue(p.value) end)
	if setOk then ChangeHistoryService:SetWaypoint("SetProperty:"..p.property) end
	return setOk and {success=true} or {success=false,error=tostring(err)}
end

H.set_properties = function(p)
	local ok,obj=pcall(resolvePath,p.path)
	if not ok or not obj then return {success=false,error="Path not found: "..tostring(p.path)} end
	local set,failed={},{}
	for prop,val in pairs(p.properties) do
		local setOk,err=pcall(function() obj[prop]=coerceValue(val) end)
		if setOk then table.insert(set,prop) else table.insert(failed,{prop=prop,error=tostring(err)}) end
	end
	ChangeHistoryService:SetWaypoint("SetProperties")
	return {success=true,set=set,failed=failed}
end

H.mass_set_property = function(p)
	local results={}
	for _,path in ipairs(p.paths) do
		local ok,obj=pcall(resolvePath,path)
		if ok and obj then
			local setOk,err=pcall(function() obj[p.property]=coerceValue(p.value) end)
			table.insert(results,{path=path,success=setOk,error=setOk and nil or tostring(err)})
		else
			table.insert(results,{path=path,success=false,error="Not found"})
		end
	end
	ChangeHistoryService:SetWaypoint("MassSetProperty:"..p.property)
	return {success=true, results=results}
end

H.mass_get_property = function(p)
	local results={}
	for _,path in ipairs(p.paths) do
		local ok,obj=pcall(resolvePath,path)
		if ok and obj then
			local getOk,val=pcall(function() return obj[p.property] end)
			local _,s=pcall(serializeValue,val)
			table.insert(results,{path=path,value=getOk and s or nil,error=getOk and nil or tostring(val)})
		else
			table.insert(results,{path=path,error="Not found"})
		end
	end
	return {success=true, results=results}
end

H.delete_instance = function(p)
	local ok,obj=pcall(resolvePath,p.path)
	if not ok or not obj then return {success=false,error="Path not found: "..tostring(p.path)} end
	local name=obj.Name; local par=obj.Parent and obj.Parent:GetFullName() or "?"
	obj:Destroy(); ChangeHistoryService:SetWaypoint("Delete:"..name)
	return {success=true,deleted=name,from=par}
end

H.clone_instance = function(p)
	local ok,obj=pcall(resolvePath,p.path)
	if not ok or not obj then return {success=false,error="Path not found: "..tostring(p.path)} end
	local clone=obj:Clone(); if p.new_name then clone.Name=p.new_name end
	local ok2,err=pcall(function() clone.Parent=p.parent and resolvePath(p.parent) or obj.Parent end)
	if ok2 then ChangeHistoryService:SetWaypoint("Clone:"..clone.Name) end
	return ok2 and {success=true,path=clone:GetFullName()} or {success=false,error=tostring(err)}
end

H.clear_workspace = function(_)
	local removed=0
	for _,c in ipairs(game.Workspace:GetChildren()) do
		if not(c.Name=="Baseplate" or c:IsA("Terrain") or c:IsA("Camera")) then
			c:Destroy(); removed+=1
		end
	end
	ChangeHistoryService:SetWaypoint("ClearWorkspace")
	return {success=true,removed=removed}
end

-- ── Script tools ──────────────────────────────────────────────────────────────
H.insert_script = function(p)
	local s=Instance.new(p.script_type or "Script"); s.Name=p.name; s.Source=p.source or ""
	local ok,err=pcall(function() s.Parent=resolvePath(p.parent) end)
	if ok then ChangeHistoryService:SetWaypoint("InsertScript:"..s.Name) end
	return ok and {success=true,path=s:GetFullName()} or {success=false,error=tostring(err)}
end

H.get_script_source = function(p)
	local ok,obj=pcall(resolvePath,p.path)
	if not ok or not obj then return {success=false,error="Path not found: "..tostring(p.path)} end
	if not obj:IsA("LuaSourceContainer") then return {success=false,error=obj.ClassName.." is not a script"} end
	local lines=obj.Source:split("\n")
	return {success=true,source=obj.Source,lineCount=#lines,className=obj.ClassName}
end

H.set_script_source = function(p)
	local ok,obj=pcall(resolvePath,p.path)
	if not ok or not obj then return {success=false,error="Path not found: "..tostring(p.path)} end
	if not obj:IsA("LuaSourceContainer") then return {success=false,error=obj.ClassName.." is not a script"} end
	obj.Source=p.source; ChangeHistoryService:SetWaypoint("SetSource:"..obj.Name)
	return {success=true,path=obj:GetFullName()}
end

H.edit_script_lines = function(p)
	local ok,obj=pcall(resolvePath,p.path)
	if not ok or not obj then return {success=false,error="Path not found: "..tostring(p.path)} end
	if not obj:IsA("LuaSourceContainer") then return {success=false,error="Not a script"} end
	local src=obj.Source
	local count=0
	if p.replace_all then
		src,count=src:gsub(p.old_text:gsub("[%(%)%.%%%+%-%*%?%[%^%$]","%%%1"), p.new_text)
	else
		local s,e=src:find(p.old_text,1,true)
		if s then src=src:sub(1,s-1)..p.new_text..src:sub(e+1); count=1 end
	end
	if count==0 then return {success=false,error="Text not found in script"} end
	obj.Source=src; ChangeHistoryService:SetWaypoint("EditLines:"..obj.Name)
	return {success=true,replacements=count,path=obj:GetFullName()}
end

H.insert_script_lines = function(p)
	local ok,obj=pcall(resolvePath,p.path)
	if not ok or not obj then return {success=false,error="Path not found: "..tostring(p.path)} end
	if not obj:IsA("LuaSourceContainer") then return {success=false,error="Not a script"} end
	local lines=obj.Source:split("\n")
	local insertAt=math.clamp(p.line,1,#lines+1)
	table.insert(lines,insertAt,p.text)
	obj.Source=table.concat(lines,"\n"); ChangeHistoryService:SetWaypoint("InsertLines:"..obj.Name)
	return {success=true,insertedAt=insertAt,newLineCount=#lines}
end

H.delete_script_lines = function(p)
	local ok,obj=pcall(resolvePath,p.path)
	if not ok or not obj then return {success=false,error="Path not found: "..tostring(p.path)} end
	if not obj:IsA("LuaSourceContainer") then return {success=false,error="Not a script"} end
	local lines=obj.Source:split("\n")
	local from=math.clamp(p.from_line,1,#lines)
	local to=math.clamp(p.to_line,from,#lines)
	for _=from,to do table.remove(lines,from) end
	obj.Source=table.concat(lines,"\n"); ChangeHistoryService:SetWaypoint("DeleteLines:"..obj.Name)
	return {success=true,deletedLines=to-from+1,newLineCount=#lines}
end

H.grep_scripts = function(p)
	local scope=game; if p.scope then local ok,obj=pcall(resolvePath,p.scope); if ok then scope=obj end end
	local max=p.max_results or 100; local results={}
	local function searchObj(obj)
		if obj:IsA("LuaSourceContainer") then
			local lines=obj.Source:split("\n")
			for i,line in ipairs(lines) do
				if line:find(p.pattern,1,true) then
					table.insert(results,{path=obj:GetFullName(),line=i,text=line:match("^%s*(.-)%s*$")})
					if #results>=max then return end
				end
			end
		end
		for _,c in ipairs(obj:GetChildren()) do
			if #results>=max then return end
			searchObj(c)
		end
	end
	searchObj(scope)
	return {success=true,matches=results,count=#results}
end

H.find_and_replace_in_scripts = function(p)
	local scope=game; if p.scope then local ok,obj=pcall(resolvePath,p.scope); if ok then scope=obj end end
	local results={}; local totalReplaced=0
	local function processObj(obj)
		if obj:IsA("LuaSourceContainer") then
			local src=obj.Source
			if src:find(p.find,1,true) then
				local newSrc,count=src:gsub(p.find:gsub("[%(%)%.%%%+%-%*%?%[%^%$]","%%%1"),p.replace)
				table.insert(results,{path=obj:GetFullName(),count=count})
				totalReplaced+=count
				if not p.preview then
					obj.Source=newSrc
				end
			end
		end
		for _,c in ipairs(obj:GetChildren()) do processObj(c) end
	end
	processObj(scope)
	if not p.preview and totalReplaced>0 then
		ChangeHistoryService:SetWaypoint("FindReplace")
	end
	return {success=true,files=results,totalReplacements=totalReplaced,preview=p.preview==true}
end

-- ── Attributes ────────────────────────────────────────────────────────────────
H.get_attributes = function(p)
	local ok,obj=pcall(resolvePath,p.path)
	if not ok or not obj then return {success=false,error="Path not found: "..tostring(p.path)} end
	local attrs={}
	for k,v in pairs(obj:GetAttributes()) do
		local _,s=pcall(serializeValue,v); attrs[k]=s
	end
	return {success=true,path=obj:GetFullName(),attributes=attrs}
end

H.set_attribute = function(p)
	local ok,obj=pcall(resolvePath,p.path)
	if not ok or not obj then return {success=false,error="Path not found: "..tostring(p.path)} end
	local setOk,err=pcall(function() obj:SetAttribute(p.name,coerceValue(p.value)) end)
	return setOk and {success=true} or {success=false,error=tostring(err)}
end

H.delete_attribute = function(p)
	local ok,obj=pcall(resolvePath,p.path)
	if not ok or not obj then return {success=false,error="Path not found: "..tostring(p.path)} end
	local delOk,err=pcall(function() obj:SetAttribute(p.name,nil) end)
	return delOk and {success=true} or {success=false,error=tostring(err)}
end

H.bulk_set_attributes = function(p)
	local ok,obj=pcall(resolvePath,p.path)
	if not ok or not obj then return {success=false,error="Path not found: "..tostring(p.path)} end
	local set,failed={},{}
	for k,v in pairs(p.attributes) do
		local setOk,err=pcall(function() obj:SetAttribute(k,coerceValue(v)) end)
		if setOk then table.insert(set,k) else table.insert(failed,{attr=k,error=tostring(err)}) end
	end
	return {success=true,set=set,failed=failed}
end

-- ── Tags ──────────────────────────────────────────────────────────────────────
H.get_tags = function(p)
	local ok,obj=pcall(resolvePath,p.path)
	if not ok or not obj then return {success=false,error="Path not found: "..tostring(p.path)} end
	return {success=true,tags=CollectionService:GetTags(obj)}
end

H.add_tag = function(p)
	local ok,obj=pcall(resolvePath,p.path)
	if not ok or not obj then return {success=false,error="Path not found: "..tostring(p.path)} end
	CollectionService:AddTag(obj,p.tag)
	return {success=true}
end

H.remove_tag = function(p)
	local ok,obj=pcall(resolvePath,p.path)
	if not ok or not obj then return {success=false,error="Path not found: "..tostring(p.path)} end
	CollectionService:RemoveTag(obj,p.tag)
	return {success=true}
end

H.get_tagged = function(p)
	local max=p.max_results or 100; local results={}
	for _,obj in ipairs(CollectionService:GetTagged(p.tag)) do
		table.insert(results,{name=obj.Name,className=obj.ClassName,path=obj:GetFullName()})
		if #results>=max then break end
	end
	return {success=true,tag=p.tag,instances=results,count=#results}
end

-- ── Playtest ──────────────────────────────────────────────────────────────────
H.start_playtest = function(_)
	local ok,err=pcall(function() game:GetService("TestService"):Run() end)
	return {success=ok,error=ok and nil or tostring(err)}
end

H.stop_playtest = function(_)
	return {success=true,note="Use Studio Stop button or F5"}
end

-- ── Poll loop ─────────────────────────────────────────────────────────────────
local function pollLoop()
	while isRunning do
		local ok,response=pcall(function()
			return HttpService:RequestAsync({Url=BRIDGE_URL.."/poll",Method="GET"})
		end)
		if ok and response and response.Success then
			if not bridgeOk then
				bridgeOk=true; setStatus(true,"Bridge connected"); addLog("Bridge connected")
			end
			local data=HttpService:JSONDecode(response.Body)
			if data and data.command then
				cmdCount+=1; cmdLbl.Text="Commands: "..cmdCount
				lastLbl.Text=data.command; lastLbl.TextColor3=C.yellow
				addLog("["..cmdCount.."] "..data.command)

				local handler=H[data.command]
				local result
				if handler then
					local callOk,callResult=pcall(handler,data.params or {})
					result=callOk and callResult or {success=false,error=tostring(callResult)}
				else
					result={success=false,error="Unknown command: "..tostring(data.command)}
				end

				if result.success==false then
					errCount+=1; errLbl.Text="Errors: "..errCount; errLbl.TextColor3=C.red
					lastLbl.TextColor3=C.red; addLog("  error: "..(result.error or "?"),C.red)
				else
					lastLbl.TextColor3=C.green
				end

				pcall(function()
					HttpService:RequestAsync({
						Url=BRIDGE_URL.."/result",Method="POST",
						Headers={["Content-Type"]="application/json"},
						Body=HttpService:JSONEncode({id=data.id,result=result}),
					})
				end)
			end
		else
			if bridgeOk then
				bridgeOk=false; setStatus(false,"Bridge disconnected"); addLog("Bridge unreachable",C.red)
			end
		end
		task.wait(POLL_RATE)
	end
	bridgeOk=false
end

-- ── Wiring ────────────────────────────────────────────────────────────────────
startBtn.MouseButton1Click:Connect(function()
	if not isRunning then setRunning(true); task.spawn(pollLoop)
	else setRunning(false) end
end)
startBtn.MouseEnter:Connect(function()
	startBtn.BackgroundColor3=isRunning and Color3.fromRGB(240,90,90) or Color3.fromRGB(0,180,85)
end)
startBtn.MouseLeave:Connect(function()
	startBtn.BackgroundColor3=isRunning and C.red or C.green
end)
clearBtn.MouseEnter:Connect(function() clearBtn.BackgroundColor3=C.btnHov end)
clearBtn.MouseLeave:Connect(function() clearBtn.BackgroundColor3=C.btnBg end)

widget.Enabled=true; toggleButton:SetActive(true)
portLbl.Text="localhost:7353 · 35 tools"
addLog("RobloxMCP v2 loaded — press Start Server")
