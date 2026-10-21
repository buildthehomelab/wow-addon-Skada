-- Headless smoke test for the WoW Forever window (Skada/Modules/ThemeForever.lua).
--
-- Loads the whole Skada addon (every file the toc lists, in order) against a
-- stub of the 3.3.5a API, starts a fight, feeds combat log damage for the
-- player and their pet, then checks the header, the docked breakdown panel and
-- the collapse button. Needs a Lua 5.1 interpreter (LuaJIT works):
--
--     luajit tools/forever_smoke_test.lua
--
-- The stub is deliberately loose: any API it does not know is a no-op
-- returning nil, so a pass means "nothing errored and the panel filled", not
-- that the window looks right in the client.

local ADDON = "Skada"
local ROOT = "Skada/"

-------------------------------------------------------------------------------
-- tiny frame/widget stub

local events = {} -- event -> {frame = true}
local frames = {}
local widget_mt

local function noop() end

local function new_widget(kind, parent, name)
	local w = setmetatable({
		__kind = kind, __parent = parent, __name = name, __shown = true,
		__scripts = {}, __points = {}, __w = 0, __h = 0, __level = 1, __alpha = 1,
		__regions = {}, __children = {}, __text = nil
	}, widget_mt)
	if parent then
		parent.__children[#parent.__children + 1] = w
	end
	if name then
		_G[name] = w
	end
	return w
end

local methods = {}
function methods:SetScript(k, f) self.__scripts[k] = f end
function methods:GetScript(k) return self.__scripts[k] end
function methods:HookScript(k, f)
	local old = self.__scripts[k]
	self.__scripts[k] = old and function(...) old(...); return f(...) end or f
end
function methods:HasScript() return true end
function methods:RegisterEvent(e) events[e] = events[e] or {}; events[e][self] = true end
function methods:UnregisterEvent(e) if events[e] then events[e][self] = nil end end
function methods:UnregisterAllEvents() for _, t in pairs(events) do t[self] = nil end end
function methods:IsEventRegistered(e) return events[e] and events[e][self] or false end
function methods:Show() self.__shown = true; local f = self.__scripts.OnShow; if f then f(self) end end
function methods:Hide() self.__shown = false; local f = self.__scripts.OnHide; if f then f(self) end end
function methods:IsShown() return self.__shown end
function methods:IsVisible()
	local w = self
	while w do
		if not w.__shown then return false end
		w = w.__parent
	end
	return true
end
function methods:SetShown(s) if s then self:Show() else self:Hide() end end
function methods:GetParent() return self.__parent end
function methods:SetParent(p) self.__parent = p end
function methods:GetName() return self.__name end
function methods:GetObjectType() return self.__kind end
function methods:IsObjectType(t) return self.__kind == t end
function methods:SetWidth(v) self.__w = v end
function methods:SetHeight(v) self.__h = v end
function methods:SetSize(w, h) self.__w, self.__h = w, h end
function methods:GetWidth() return self.__w end
function methods:GetHeight() return self.__h end
function methods:GetSize() return self.__w, self.__h end
function methods:GetEffectiveScale() return 1 end
function methods:GetScale() return 1 end
function methods:GetLeft() return 100 end
function methods:GetRight() return 100 + self.__w end
function methods:GetTop() return 600 end
function methods:GetBottom() return 600 - self.__h end
function methods:GetCenter() return 100 + self.__w / 2, 600 - self.__h / 2 end
function methods:SetPoint(...) self.__points[#self.__points + 1] = {...} end
function methods:ClearAllPoints() self.__points = {} end
function methods:GetPoint(i) local p = self.__points[i or 1]; if p then return unpack(p) end end
function methods:GetNumPoints() return #self.__points end
function methods:SetAllPoints(r) self.__points = {{"ALL", r}} end
function methods:GetFrameLevel() return self.__level end
function methods:SetFrameLevel(l) self.__level = l end
function methods:GetAlpha() return self.__alpha end
function methods:SetAlpha(a) self.__alpha = a end
function methods:CreateTexture(name, layer)
	local t = new_widget("Texture", self, name and name:gsub("%$parent", self.__name or "") or nil)
	self.__regions[#self.__regions + 1] = t
	return t
end
function methods:CreateFontString(name, layer)
	local t = new_widget("FontString", self, name and name:gsub("%$parent", self.__name or "") or nil)
	self.__regions[#self.__regions + 1] = t
	return t
end
function methods:GetRegions() return unpack(self.__regions) end
function methods:GetNumRegions() return #self.__regions end
function methods:GetChildren() return unpack(self.__children) end
function methods:SetText(t) self.__text = t; if self.__fs then self.__fs.__text = t end end
function methods:GetText() return self.__text end
function methods:SetFormattedText(f, ...) self.__text = string.format(f, ...) end
function methods:GetStringWidth() return #(self.__text or "") * 6 end
function methods:GetFontString()
	self.__fs = self.__fs or new_widget("FontString", self)
	return self.__fs
end
function methods:SetTexture(t) self.__texture = t end
function methods:GetTexture() return self.__texture end
function methods:GetNormalTexture()
	self.__normal = self.__normal or new_widget("Texture", self)
	return self.__normal
end
function methods:SetNormalTexture(t)
	if type(t) == "table" then self.__normal = t else self:GetNormalTexture():SetTexture(t) end
end
function methods:GetHighlightTexture()
	self.__highlight = self.__highlight or new_widget("Texture", self)
	return self.__highlight
end
function methods:SetHighlightTexture(t)
	if type(t) == "table" then self.__highlight = t else self:GetHighlightTexture():SetTexture(t) end
end
function methods:GetPushedTexture()
	self.__pushed = self.__pushed or new_widget("Texture", self)
	return self.__pushed
end
function methods:GetStatusBarTexture()
	self.__sbt = self.__sbt or new_widget("Texture", self)
	return self.__sbt
end
function methods:SetMinMaxValues(a, b) self.__min, self.__max = a, b end
function methods:GetMinMaxValues() return self.__min or 0, self.__max or 1 end
function methods:SetValue(v) self.__value = v end
function methods:GetValue() return self.__value or 0 end
function methods:GetBackdropColor() return 0, 0, 0, 1 end
function methods:GetBackdropBorderColor() return 0, 0, 0, 1 end
function methods:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
function methods:GetTextColor() return 1, 1, 1, 1 end
function methods:GetShadowColor() return 0, 0, 0, 1 end
function methods:GetShadowOffset() return 0, 0 end
function methods:GetJustifyH() return "LEFT" end
function methods:IsMouseEnabled() return true end
function methods:GetID() return 0 end
function methods:GetTexCoord() return 0, 0, 0, 1, 1, 0, 1, 1 end
function methods:GetVertexColor() return 1, 1, 1, 1 end
function methods:GetStatusBarColor() return 1, 1, 1, 1 end
function methods:GetFrameStrata() return "LOW" end
function methods:IsMovable() return true end
function methods:IsResizable() return true end
function methods:GetAttribute() return nil end
function methods:GetHitRectInsets() return 0, 0, 0, 0 end
function methods:CanChangeAttribute() return true end
function methods:Click(button) local f = self.__scripts.OnClick; if f then f(self, button or "LeftButton") end end

-- widget methods the test never inspects: plain no-ops.
local METHOD_NOOPS = {
	"SetOwner",
	"SetStatusBarColor",
	"SetStatusBarTexture",
	"RegisterForDrag",
	"SetClampedToScreen",
	"SetBackdropBorderColor",
	"SetFrameStrata",
	"SetTextColor",
	"SetFont",
	"SetBlendMode",
	"SetShadowOffset",
	"SetScale",
	"EnableMouse",
	"EnableMouseWheel",
	"SetDesaturated",
	"SetVertexColor",
	"SetMaxResize",
	"SetMinResize",
	"RegisterForClicks",
	"SetTexCoord",
	"SetWordWrap",
	"SetBackdropColor",
	"SetBackdrop",
	"SetNormalFontObject",
	"CopyFontObject",
	"SetMovable",
	"SetResizable",
	"SetJustifyV",
	"SetJustifyH",
}
for _, k in ipairs(METHOD_NOOPS) do
	methods[k] = methods[k] or noop
end

widget_mt = {__index = methods}

-------------------------------------------------------------------------------
-- global API stub

local now = 1000
local clock = 1700000000

local env = {
	CreateFrame = function(kind, name, parent, template)
		local f = new_widget(kind, parent, name)
		frames[#frames + 1] = f
		return f
	end,
	GetTime = function() return now end,
	time = function() return clock end,
	date = os.date,
	GetLocale = function() return "enUS" end,
	GetBuildInfo = function() return "3.3.5", "12340", "Jun 24 2010", 30300 end,
	GetRealmName = function() return "Test" end,
	UnitName = function(u) if u == "player" then return "Bue" end if u == "pet" then return "Cow" end end,
	UnitGUID = function(u) if u == "player" then return "0x0000000000000001" end if u == "pet" then return "0xF140000000000002" end end,
	UnitClass = function(u) if u == "player" then return "Hunter", "HUNTER" end end,
	UnitRace = function() return "Orc", "Orc" end,
	UnitFactionGroup = function() return "Horde", "Horde" end,
	UnitLevel = function() return 80 end,
	UnitExists = function(u) return u == "player" or u == "pet" end,
	UnitIsPlayer = function(u) return u == "player" end,
	UnitAffectingCombat = function() return true end,
	UnitHealth = function() return 1000 end,
	UnitHealthMax = function() return 1000 end,
	UnitIsDeadOrGhost = function() return false end,
	UnitInRaid = function() return nil end,
	UnitInParty = function() return nil end,
	UnitInVehicle = function() return nil end,
	UnitPowerType = function() return 2 end,
	GetNumRaidMembers = function() return 0 end,
	GetNumPartyMembers = function() return 0 end,
	IsInInstance = function() return false, "none" end,
	GetInstanceInfo = function() return "Durotar", "none", 1 end,
	GetRealZoneText = function() return "Durotar" end,
	GetZoneText = function() return "Durotar" end,
	GetCVar = function() return "0" end,
	GetScreenWidth = function() return 1920 end,
	GetScreenHeight = function() return 1080 end,
	GetCursorPosition = function() return 0, 0 end,
	IsShiftKeyDown = function() return false end,
	IsControlKeyDown = function() return false end,
	IsAltKeyDown = function() return false end,
	IsModifierKeyDown = function() return false end,
	IsMouseButtonDown = function() return false end,
	InCombatLockdown = function() return false end,
	IsLoggedIn = function() return true end,
	GetAddOnMemoryUsage = function() return 512 end,
	GetAddOnInfo = function(n) return n, n, "", true, true end,
	GetAddOnMetadata = function(_, key) if key == "Version" then return "1.8.88-forever.1" end end,
	IsAddOnLoaded = function(n) return n == ADDON end,
	GetNumAddOns = function() return 1 end,
	GetSpellInfo = function(id) id = tonumber(id); if id then return "Spell" .. id, nil, "Interface\\Icons\\Spell" .. id end end,
	GetSpellLink = function(id) return "|cff71d5ff|Hspell:" .. tostring(id) .. "|h[Spell]|h|r" end,
	GetItemInfo = function() return nil end,
	GetTalentTabInfo = function() return "Marksmanship", nil, 51 end,
	GetNumTalentTabs = function() return 3 end,
	GetActiveTalentGroup = function() return 1 end,
	GetNumTalents = function() return 0 end,
	GetCurrentResolution = function() return 1 end,
	GetScreenResolutions = function() return "1920x1080" end,
	GetBindingKey = function() return nil end,
	GetCurrentBindingSet = function() return 1 end,
	SecondsToTime = function(s) return tostring(s) .. " sec" end,
	debugstack = function() return "" end,
	geterrorhandler = function()
		return function(e)
			print("LUA ERROR: " .. tostring(e) .. "\n" .. debug.traceback())
			os.exit(1)
		end
	end,
	seterrorhandler = noop,
	hooksecurefunc = function(t, k, f)
		if type(t) == "string" then t, k, f = _G, t, k end
		local old = t[k]
		t[k] = function(...) local r = {old(...)}; f(...); return unpack(r) end
	end,
	issecurevariable = function() return true end,
	securecall = function(f, ...) if type(f) == "string" then f = _G[f] end return f(...) end,
	strsplit = function(d, s, n)
		local out, start = {}, 1
		while true do
			if n and #out == n - 1 then out[#out + 1] = s:sub(start); break end
			local i, j = s:find(d, start, true)
			if not i then out[#out + 1] = s:sub(start); break end
			out[#out + 1] = s:sub(start, i - 1)
			start = j + 1
		end
		return unpack(out)
	end,
	strjoin = function(d, ...) return table.concat({...}, d) end,
	strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
	strmatch = string.match, strfind = string.find, strsub = string.sub, strlen = string.len,
	strupper = string.upper, strlower = string.lower, strrep = string.rep, strbyte = string.byte,
	strchar = string.char, strrev = string.reverse, gsub = string.gsub, format = string.format,
	gmatch = string.gmatch,
	tinsert = table.insert, tremove = table.remove, sort = table.sort, tconcat = table.concat,
	wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
	floor = math.floor, ceil = math.ceil, abs = math.abs, max = math.max, min = math.min,
	mod = math.fmod, random = math.random, sqrt = math.sqrt,
	bit = require and pcall(require, "bit") and require("bit") or nil,
	RAID_CLASS_COLORS = {},
	CLASS_ICON_TCOORDS = {},
	LOCALIZED_CLASS_NAMES_MALE = {},
	CLASS_SORT_ORDER = {"WARRIOR", "DEATHKNIGHT", "PALADIN", "PRIEST", "SHAMAN", "DRUID", "ROGUE", "MAGE", "WARLOCK", "HUNTER"},
	HIGHLIGHT_FONT_COLOR = {r = 1, g = 1, b = 1},
	NORMAL_FONT_COLOR = {r = 1, g = 0.82, b = 0},
	GRAY_FONT_COLOR = {r = 0.5, g = 0.5, b = 0.5},
	RED_FONT_COLOR = {r = 1, g = 0.1, b = 0.1},
	GREEN_FONT_COLOR = {r = 0.1, g = 1, b = 0.1},
	COMBATLOG_OBJECT_AFFILIATION_MINE = 0x1, COMBATLOG_OBJECT_AFFILIATION_PARTY = 0x2,
	COMBATLOG_OBJECT_AFFILIATION_RAID = 0x4, COMBATLOG_OBJECT_AFFILIATION_OUTSIDER = 0x8,
	COMBATLOG_OBJECT_AFFILIATION_MASK = 0xF,
	COMBATLOG_OBJECT_REACTION_FRIENDLY = 0x10, COMBATLOG_OBJECT_REACTION_NEUTRAL = 0x20,
	COMBATLOG_OBJECT_REACTION_HOSTILE = 0x40, COMBATLOG_OBJECT_REACTION_MASK = 0xF0,
	COMBATLOG_OBJECT_CONTROL_PLAYER = 0x100, COMBATLOG_OBJECT_CONTROL_NPC = 0x200,
	COMBATLOG_OBJECT_CONTROL_MASK = 0x300,
	COMBATLOG_OBJECT_TYPE_PLAYER = 0x400, COMBATLOG_OBJECT_TYPE_NPC = 0x800,
	COMBATLOG_OBJECT_TYPE_PET = 0x1000, COMBATLOG_OBJECT_TYPE_GUARDIAN = 0x2000,
	COMBATLOG_OBJECT_TYPE_OBJECT = 0x4000, COMBATLOG_OBJECT_TYPE_MASK = 0xFC00,
	COMBATLOG_OBJECT_TARGET = 0x10000, COMBATLOG_OBJECT_FOCUS = 0x20000,
	COMBATLOG_OBJECT_MAINTANK = 0x40000, COMBATLOG_OBJECT_MAINASSIST = 0x80000,
	COMBATLOG_OBJECT_RAIDTARGET_MASK = 0x0FF00000, COMBATLOG_OBJECT_NONE = 0x80000000,
	COMBATLOG_OBJECT_SPECIAL_MASK = 0xFFFF0000,
	SCHOOL_MASK_PHYSICAL = 1, SCHOOL_MASK_HOLY = 2, SCHOOL_MASK_FIRE = 4, SCHOOL_MASK_NATURE = 8,
	SCHOOL_MASK_FROST = 16, SCHOOL_MASK_SHADOW = 32, SCHOOL_MASK_ARCANE = 64,
	NUM_CHAT_WINDOWS = 1,
	MAX_PARTY_MEMBERS = 4, MAX_RAID_MEMBERS = 40,
	ENABLE = "Enable", DISABLE = "Disable", PETS = "Pets", NONE = "None", OKAY = "Okay", CANCEL = "Cancel",
	ACCEPT = "Accept", YES = "Yes", NO = "No", CLOSE = "Close", DEFAULT = "Default", RESET = "Reset",
	UIDROPDOWNMENU_MENU_LEVEL = 1,
	StaticPopupDialogs = {},
	TALENT_ACTIVATION_SPELLS = {63645, 63644},
	UISpecialFrames = {},
	DEFAULT_CHAT_FRAME = nil,
	SlashCmdList = {},
	hash_SlashCmdList = {},
	ChatTypeInfo = setmetatable({}, {__index = function() return {r = 1, g = 1, b = 1} end}),
}
env.UIParent = new_widget("Frame", nil, "UIParent")
env.UIParent.__w, env.UIParent.__h = 1920, 1080
env.WorldFrame = new_widget("Frame", nil, "WorldFrame")
env.GameTooltip = new_widget("GameTooltip", env.UIParent, "GameTooltip")
do -- GameTooltip keeps its lines so the test can read them
	local tt = env.GameTooltip
	tt.__lines = {}
	function tt:ClearLines() self.__lines = {} end
	function tt:AddLine(t) self.__lines[#self.__lines + 1] = tostring(t) end
	function tt:AddDoubleLine(a, b) self.__lines[#self.__lines + 1] = tostring(a) .. " | " .. tostring(b) end
	function tt:NumLines() return #self.__lines end
	function tt:SetText(t) self.__lines = {tostring(t)} end
end
env.DEFAULT_CHAT_FRAME = new_widget("ScrollingMessageFrame", env.UIParent, "ChatFrame1")
function env.DEFAULT_CHAT_FRAME:AddMessage(m) print("[chat] " .. tostring(m)) end
env.ChatFrame1 = env.DEFAULT_CHAT_FRAME
for _, c in ipairs(env.CLASS_SORT_ORDER) do
	env.RAID_CLASS_COLORS[c] = {r = 0.67, g = 0.83, b = 0.45, colorStr = "ffabd473"}
	env.CLASS_ICON_TCOORDS[c] = {0, 0.25, 0, 0.25}
	env.LOCALIZED_CLASS_NAMES_MALE[c] = c
end
env.CreateFont = function(name)
	local f = new_widget("Font", nil, name)
	return f
end
env.GameFontNormal = env.CreateFont("GameFontNormal")
env.GameFontHighlight = env.CreateFont("GameFontHighlight")
env.GameFontHighlightSmall = env.CreateFont("GameFontHighlightSmall")
env.GameFontNormalSmall = env.CreateFont("GameFontNormalSmall")
env.ChatFontNormal = env.CreateFont("ChatFontNormal")
env.ChatFontSmall = env.CreateFont("ChatFontSmall")
env.NumberFontNormal = env.CreateFont("NumberFontNormal")
env.GameTooltipText = env.CreateFont("GameTooltipText")
env.UIDropDownMenu_CreateInfo = function() return {} end
env.ToggleDropDownMenu = noop
env.CloseDropDownMenus = noop
env.UIDropDownMenu_AddButton = noop
env.GameTooltip_SetDefaultAnchor = noop
env.GameTooltip_Hide = noop
env.PlaySound = noop
env.ChatEdit_GetActiveWindow = function() return nil end
env.ChatFrame_OpenChat = noop

env.unpack = unpack
env.select = select
env.type = type

for k, v in pairs(env) do _G[k] = v end
string.trim = env.strtrim
string.split = env.strsplit
string.join = env.strjoin
-- API the test never inspects: plain no-ops.
local NOOPS = {
	"UpdateAddOnMemoryUsage",
	"UnitBuff",
	"IsActiveBattlefieldArena",
	"GetCurrentMapAreaID",
	"UnitInBattleground",
	"InterfaceOptions_AddCategory",
	"UnitIsUnit",
	"LoadAddOn",
}
for _, k in ipairs(NOOPS) do
	if _G[k] == nil then _G[k] = noop end
end
-- GlobalStrings: any ALL_CAPS name reads as itself, except optional tables
-- other addons provide.
local NOT_STRINGS = {CUSTOM_CLASS_COLORS = true}
setmetatable(_G, {__index = function(_, k)
	if type(k) == "string" and k:match("^[A-Z][A-Z0-9_]+$") and not NOT_STRINGS[k] then return k end
end})

-------------------------------------------------------------------------------
-- load the addon the way the client does

local ns = {}
local function load_lua(path)
	if not io.open(path) then
		print("skip (missing, the client skips it too): " .. path)
		return
	end
	local chunk, err = loadfile(path)
	if not chunk then error(err) end
	chunk(ADDON, ns)
end

local function load_xml(path)
	local dir = path:match("^(.*/)") or ""
	local fh = io.open(path)
	if not fh then
		print("skip (missing, the client skips it too): " .. path)
		return
	end
	local xml = fh:read("*a"):gsub("<!%-%-.-%-%->", "")
	fh:close()
	for tag, file in xml:gmatch("<(%a+)%s+file=\"([^\"]+)\"") do
		file = dir .. file:gsub("\\", "/")
		if tag == "Script" then
			load_lua(file)
		elseif tag == "Include" then
			load_xml(file)
		end
	end
end

for line in io.lines(ROOT .. ADDON .. ".toc") do
	line = line:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
	if line ~= "" and not line:match("^#") then
		local file = ROOT .. line:gsub("\\", "/")
		if file:match("%.xml$") then load_xml(file) else load_lua(file) end
	end
end

local function fire(event, ...)
	for f in pairs(events[event] or {}) do
		local h = f.__scripts.OnEvent
		if h then h(f, event, ...) end
	end
end

local function tick(seconds)
	for _ = 1, seconds * 10 do
		now = now + 0.1
		clock = math.floor(now) + 1700000000 - 1000
		for _, f in ipairs(frames) do
			local h = f.__scripts.OnUpdate
			if h and f:IsVisible() then h(f, 0.1) end
		end
	end
end

fire("ADDON_LOADED", ADDON)
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD")
tick(1)

local Skada = ns
local function check(cond, msg)
	if not cond then error("FAIL: " .. msg, 2) end
	print("ok   " .. msg)
end

check(Skada.foreverInstalled, "Forever style installed on Bar Display")
local win = Skada.windows[1]
check(win and win.db.foreverstyle, "fresh profile window uses the Forever style")
local g = win.bargroup
check(g.forever and g.forever.on, "header widgets built and on")

-------------------------------------------------------------------------------
-- a short fight: hunter + pet hit a mob

local PLAYER, PET, MOB = "0x0000000000000001", "0xF140000000000002", "0xF130000000000099"
local PFLAGS, PETFLAGS, MOBFLAGS = 0x511, 0x1111, 0xa48

fire("PLAYER_REGEN_DISABLED")
local function hit(src, srcName, srcFlags, spellid, amount)
	clock = clock + 0
	if spellid then
		fire("COMBAT_LOG_EVENT_UNFILTERED", clock, "SPELL_DAMAGE", src, srcName, srcFlags, MOB, "Boar", MOBFLAGS,
			spellid, "Spell" .. spellid, 1, amount, 0, 1, 0, 0, 0, nil, nil, nil)
	else
		fire("COMBAT_LOG_EVENT_UNFILTERED", clock, "SWING_DAMAGE", src, srcName, srcFlags, MOB, "Boar", MOBFLAGS,
			amount, 0, 1, 0, 0, 0, nil, nil, nil)
	end
end
for i = 1, 5 do
	hit(PLAYER, "Bue", PFLAGS, 75, 100)      -- Auto Shot
	hit(PLAYER, "Bue", PFLAGS, 49045, 70)    -- Arcane Shot
	hit(PET, "Cow", PETFLAGS, nil, 30)        -- pet melee
	tick(1)
end

Skada:UpdateDisplay(true)
tick(1)

check(g.button:GetText() == "Damage Done", "title reads Damage Done (got " .. tostring(g.button:GetText()) .. ")")
local timer = g.forever.timer:GetText()
check(timer and timer:match("^%[%d%d:%d%d%]$"), "timer shows [mm:ss] (got " .. tostring(timer) .. ")")

local playerbar
for _, bar in pairs(g:GetBars()) do
	if bar.id == PLAYER then playerbar = bar end
end
check(playerbar, "player has a bar")
print("     bar: " .. tostring(playerbar.label:GetText()) .. "  " .. tostring(playerbar.timerLabel:GetText()))

-- left-click the player: the panel docks beside the window instead of drilling down
local mod = Skada:GetModule("Bar Display")
local modeBefore = win.selectedmode
mod:BarClick("BarClick", playerbar, "LeftButton")
local panel = g.foreverPanel
check(panel and panel:IsShown(), "left-click opens the docked panel")
check(win.selectedmode == modeBefore, "window stays on the player list")

local labels = {}
for i, row in ipairs(panel.rows) do
	if row:IsShown() then
		labels[#labels + 1] = row.label:GetText() .. " = " .. tostring(row.value:GetText())
	end
end
check(#labels >= 2, "panel lists the player's spells (" .. #labels .. " rows)")
for _, l in ipairs(labels) do print("     " .. l) end

-- tooltip on a panel row
GameTooltip:ClearLines()
panel.rows[1].__scripts.OnEnter(panel.rows[1])
check(GameTooltip:NumLines() > 0, "panel row has a tooltip (" .. GameTooltip:NumLines() .. " lines)")

-- more damage refreshes the open panel
hit(PLAYER, "Bue", PFLAGS, 75, 1000)
tick(1)
Skada:UpdateDisplay(true)
check(panel:IsShown(), "panel stays open while the fight updates")

-- same click again closes it
mod:BarClick("BarClick", playerbar, "LeftButton")
check(not panel:IsShown(), "clicking the same player closes the panel")

-- collapse hides the bars, expand brings them back
g.forever.collapse:Click("LeftButton")
check(win.db.forevercollapsed and g.maxBars == 0, "collapse button hides the bars")
g.forever.collapse:Click("LeftButton")
check(not win.db.forevercollapsed and g.maxBars > 0, "collapse button again shows them")

-- switching the style off restores Skada's own toolbar
win.db.foreverstyle = false
Skada:ApplySettings(win)
check(not g.forever.on and not g.forever.dropdown:IsShown(), "style off hides the Forever header")
local visible = 0
for _, b in ipairs(g.buttons) do if b.visible then visible = visible + 1 end end
check(visible > 0, "Skada's toolbar buttons come back (" .. visible .. ")")

print("\nall checks passed")
