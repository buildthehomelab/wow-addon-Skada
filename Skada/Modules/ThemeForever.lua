-- ThemeForever.lua
-- WoW Forever-style meter window on top of the Bar Display.
--
-- Windows with `foreverstyle` set get:
--   * a header laid out like WoW Forever's built-in meter: fight timer,
--     mode dropdown button, gold mode title ("Damage Done"), and three
--     buttons on the right (segment, menu, collapse);
--   * a thin gold frame: DragonUI's small filigree inset when DragonUI is
--     loaded, the stock tooltip border tinted gold otherwise;
--   * a breakdown panel docked beside the window: left-clicking a player
--     lists their spells there instead of drilling down in the window.
--     Clicking the same player again (or right-clicking the panel) closes it.
--
-- The look is also the default for fresh profiles and is listed as the
-- "WoW Forever" theme. Any window can switch it off under
-- Bars > General > WoW Forever style.

local _, Skada = ...
if not Skada or not Skada.windowdefaults then return end

local Private = Skada.Private
local pairs, ipairs, type, format = pairs, ipairs, type, string.format
local min, max, floor, abs = math.min, math.max, math.floor, math.abs
local tsort, wipe = table.sort, wipe
local CreateFrame, GameTooltip = CreateFrame, GameTooltip
local IsModifierKeyDown, IsShiftKeyDown = IsModifierKeyDown, IsShiftKeyDown

local TEX = format([[%s\Textures\forever\]], Skada.mediapath)
local GOLD = {r = 1, g = 0.82, b = 0}
local RIM = {r = 0.72, g = 0.58, b = 0.32}
local PANEL_GAP = 8
local PANEL_PAD = 6

-------------------------------------------------------------------------------
-- theme + defaults

local THEME = {
	foreverstyle = true,
	barspacing = 2,
	bartexture = "Smooth",
	barfont = "Friz Quadrata TT",
	barfontflags = "",
	barfontsize = 11,
	numfont = "Friz Quadrata TT",
	numfontflags = "",
	numfontsize = 11,
	barheight = 18,
	barwidth = 240,
	baroffset = 4,
	barorientation = 1,
	barcolor = {r = 0.3, g = 0.3, b = 0.8, a = 1},
	barbgcolor = {r = 0.12, g = 0.12, b = 0.12, a = 0.6},
	baraltcolor = {r = 0.45, g = 0.45, b = 0.8, a = 1},
	spellschoolcolors = true,
	classcolorbars = true,
	classicons = true,
	specicons = true,
	spark = false,
	title = {
		height = 24,
		font = "Friz Quadrata TT",
		fontsize = 13,
		fontflags = "",
		texture = "Flat",
		color = {r = 0.09, g = 0.08, b = 0.06, a = 0.95},
		textcolor = {r = GOLD.r, g = GOLD.g, b = GOLD.b, a = 1},
		bordercolor = {r = 0, g = 0, b = 0, a = 0},
		bordertexture = "None",
		borderthickness = 0,
		borderinsets = 0,
		spacing = 1,
		toolbar = 2,
		toolbaropacity = 1
	},
	background = {
		height = 160,
		texture = "Solid",
		color = {r = 0.03, g = 0.03, b = 0.03, a = 0.82},
		bordercolor = {r = 0, g = 0, b = 0, a = 0},
		bordertexture = "None",
		borderthickness = 0,
		borderinsets = 0,
		tilesize = 0
	},
	strata = "LOW",
	scale = 1,
	enabletitle = true,
	titleset = false,
	display = "bar",
	snapto = true
}
Skada.ForeverTheme = THEME

do
	local copy = Private.tCopy
	local windefs = Skada.windowdefaults
	for k, v in pairs(THEME) do
		if type(v) == "table" then
			windefs[k] = windefs[k] or {}
			copy(windefs[k], v)
		else
			windefs[k] = v
		end
	end
	windefs.mode = "Damage" -- open on Damage Done, not the mode list



	-- same refresh as ThemeTWW.lua: the seed window was copied before us.
	local seed = Skada.defaults and Skada.defaults.profile and Skada.defaults.profile.windows
	seed = seed and seed[1]
	if seed and copy then
		for k in pairs(seed) do
			seed[k] = nil
		end
		copy(seed, windefs)
	end

	-- "698 (174.5)" on players, damage per second per spell in the panel.
	local columns = Skada.defaults and Skada.defaults.profile and Skada.defaults.profile.columns
	if columns then
		-- keys are "<module name>_<column>"; AceAddon prefixes module names.
		columns.Skada_Damage_Percent = false
		columns.Skada_Damage_sDPS = true
		columns.Skada_Healing_Percent = false
		columns.Skada_Healing_sHPS = true
	end
end

-------------------------------------------------------------------------------
-- display hooks

local function install(mod)
	local L = Skada.Locale
	local SLB = LibStub("SpecializedLibBars-1.0")
	local protoAdjustTitle = SLB.barListPrototype.AdjustTitle
	local classcolors = Skada.classcolors
	local validclass = Skada.validclass
	local SpellLink = Private.SpellLink or GetSpellLink
	local total_noclick = Private.total_noclick

	local function IsForever(win)
		return win and win.db and win.db.foreverstyle and win.db.display == "bar" and win.bargroup
	end

	-- WoW Forever's names for the main modes; anything else keeps Skada's.
	local MODE_TITLES = (GetLocale() == "enUS" or GetLocale() == "enGB") and {
		["Damage"] = "Damage Done",
		["Healing"] = "Healing Done"
	} or {}

	---------------------------------------------------------------------------
	-- art

	-- frames `f`'s `target` region (the whole frame unless collapsed to its header).
	local function ApplyChrome(f, target)
		target = target or f
		local NS = _G.DragonUI and _G.DragonUI_NineSlice
		local layout = NS and NS.GetLayout and NS.GetLayout("SmallInsetFrameTemplate")
		if layout then
			if not f.foreverNine then
				f.foreverNine = CreateFrame("Frame", nil, f)
				f.foreverNine:SetFrameLevel(f:GetFrameLevel() + 4)
				NS.ApplyLayout(f.foreverNine, layout)
			end
			f.foreverNine:ClearAllPoints()
			f.foreverNine:SetAllPoints(target)
			f.foreverNine:Show()
			if f.foreverEdge then
				f.foreverEdge:Hide()
			end
		else
			if not f.foreverEdge then
				f.foreverEdge = CreateFrame("Frame", nil, f)
				f.foreverEdge:SetFrameLevel(f:GetFrameLevel() + 4)
				f.foreverEdge:SetBackdrop({edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]], edgeSize = 12})
				f.foreverEdge:SetBackdropBorderColor(RIM.r, RIM.g, RIM.b, 1)
			end
			f.foreverEdge:ClearAllPoints()
			f.foreverEdge:SetPoint("TOPLEFT", target, "TOPLEFT", -3, 3)
			f.foreverEdge:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 3, -3)
			f.foreverEdge:Show()
			if f.foreverNine then
				f.foreverNine:Hide()
			end
		end
	end

	local function HideChrome(f)
		if f.foreverNine then f.foreverNine:Hide() end
		if f.foreverEdge then f.foreverEdge:Hide() end
	end

	local function buttonOnEnter(self)
		GameTooltip_SetDefaultAnchor(GameTooltip, self)
		GameTooltip:SetText(self.title)
		if self.description then
			GameTooltip:AddLine(self.description, 1, 1, 1, true)
		end
		GameTooltip:Show()
	end

	local function buttonOnMouseDown(self)
		self.icon:ClearAllPoints()
		self.icon:SetPoint("TOPLEFT", 1, -1)
		self.icon:SetPoint("BOTTOMRIGHT", 1, -1)
	end

	local function buttonOnMouseUp(self)
		self.icon:ClearAllPoints()
		self.icon:SetAllPoints(self)
	end

	local function NewButton(parent, glyph, red, title, description, onclick)
		local b = CreateFrame("Button", nil, parent)
		b:SetWidth(18)
		b:SetHeight(18)
		b:SetFrameLevel(parent:GetFrameLevel() + 2)
		b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

		local base = red and "button-red" or "button"
		b.base = b:CreateTexture(nil, "BACKGROUND")
		b.base:SetAllPoints(b)
		b.base:SetTexture(TEX .. base)

		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetAllPoints(b)
		b.icon:SetTexture(TEX .. glyph)
		if not red then
			b.icon:SetVertexColor(GOLD.r, GOLD.g, GOLD.b)
		end

		local hl = b:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints(b)
		hl:SetTexture(TEX .. base)
		hl:SetBlendMode("ADD")
		hl:SetAlpha(0.35)

		b.title, b.description = title, description
		b:SetScript("OnEnter", buttonOnEnter)
		b:SetScript("OnLeave", GameTooltip_Hide)
		b:SetScript("OnMouseDown", buttonOnMouseDown)
		b:SetScript("OnMouseUp", buttonOnMouseUp)
		b:SetScript("OnClick", onclick)
		return b
	end

	---------------------------------------------------------------------------
	-- breakdown panel

	local ClosePanel, RefreshPanel

	local function rowOnEnter(row)
		local panel = row:GetParent()
		local data, mode = row.data, panel.mode
		if not data then return end

		GameTooltip:SetOwner(row, "ANCHOR_NONE")
		GameTooltip:SetPoint("TOPLEFT", panel, "TOPRIGHT", 4, 0)
		GameTooltip:ClearLines()
		local md = mode and mode.metadata
		if md and md.tooltip then
			md.tooltip(panel.proxy, data.id, data.label, GameTooltip)
		end
		if GameTooltip:NumLines() == 0 and data.spellid then
			local link = SpellLink(abs(data.spellid))
			if link then
				GameTooltip:SetHyperlink(link)
			end
		end
		if GameTooltip:NumLines() > 0 then
			GameTooltip:Show()
		end
	end

	local function rowOnClick(row, button)
		local panel = row:GetParent()
		if button == "RightButton" then
			ClosePanel(panel.win)
		elseif IsShiftKeyDown() and row.data and row.data.spellid then
			local link = SpellLink(abs(row.data.spellid))
			if link then
				local editbox = ChatEdit_GetActiveWindow()
				if editbox then
					ChatEdit_InsertLink(link)
				else
					ChatFrame_OpenChat(link, DEFAULT_CHAT_FRAME)
				end
			end
		end
	end

	local function GetRow(panel, i)
		local row = panel.rows[i]
		if row then return row end

		row = CreateFrame("Button", nil, panel)
		row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		row:SetScript("OnEnter", rowOnEnter)
		row:SetScript("OnLeave", GameTooltip_Hide)
		row:SetScript("OnClick", rowOnClick)

		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetPoint("TOPLEFT")
		row.icon:SetPoint("BOTTOMLEFT")
		row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

		row.bar = CreateFrame("StatusBar", nil, row)
		row.bar:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 1, 0)
		row.bar:SetPoint("BOTTOMRIGHT")
		row.bar:SetMinMaxValues(0, 1)

		row.bg = row.bar:CreateTexture(nil, "BACKGROUND")
		row.bg:SetAllPoints(row.bar)

		row.label = row.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.label:SetPoint("LEFT", row.bar, "LEFT", 3, 0)
		row.label:SetJustifyH("LEFT")
		row.label:SetShadowOffset(1, -1)

		row.value = row.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.value:SetPoint("RIGHT", row.bar, "RIGHT", -3, 0)
		row.value:SetJustifyH("RIGHT")
		row.value:SetShadowOffset(1, -1)
		row.label:SetPoint("RIGHT", row.value, "LEFT", -4, 0)

		panel.rows[i] = row
		return row
	end

	local function value_sort(a, b)
		if a.value == b.value then
			return (a.label or "") < (b.label or "")
		end
		return a.value > b.value
	end

	local function panelOnMouseWheel(panel, delta)
		local offset = max(0, min(panel.offset - delta, panel.maxoffset or 0))
		if offset ~= panel.offset then
			panel.offset = offset
			RefreshPanel(panel.win, true)
		end
	end

	local function panelOnMouseUp(panel, button)
		if button == "RightButton" then
			ClosePanel(panel.win)
		end
	end

	local function GetPanel(win)
		local g = win.bargroup
		local panel = g.foreverPanel
		if panel then return panel end

		panel = CreateFrame("Frame", nil, g)
		panel:SetFrameLevel(g:GetFrameLevel() + 6)
		panel:EnableMouse(true)
		panel:EnableMouseWheel(true)
		panel:SetBackdrop({bgFile = [[Interface\Buttons\WHITE8X8]]})
		panel:SetScript("OnMouseWheel", panelOnMouseWheel)
		panel:SetScript("OnMouseUp", panelOnMouseUp)
		panel:Hide()

		panel.win = win
		panel.rows = {}
		panel.list = {}
		panel.offset = 0
		panel.proxy = Skada.Window.new(win)
		panel.proxy.metadata = {}

		g.foreverPanel = panel
		return panel
	end

	-- docks the panel on the side of the window that has room.
	local function PlacePanel(g, panel)
		local width = panel:GetWidth()
		local right = (g:GetRight() or 0) * g:GetEffectiveScale()
		local room = UIParent:GetRight() * UIParent:GetEffectiveScale()
		panel:ClearAllPoints()
		if right + (PANEL_GAP + width) * g:GetEffectiveScale() > room then
			panel:SetPoint("TOPRIGHT", g, "TOPLEFT", -PANEL_GAP, 0)
		else
			panel:SetPoint("TOPLEFT", g, "TOPRIGHT", PANEL_GAP, 0)
		end
	end

	function RefreshPanel(win, keepoffset)
		local g = win and win.bargroup
		local panel = g and g.foreverPanel
		if not panel or not panel.mode then return end

		local set = win:GetSelectedSet()
		local proxy = panel.proxy
		if not set then
			ClosePanel(win)
			return
		end

		proxy:reset()
		proxy.selectedset = win.selectedset
		wipe(proxy.metadata)
		if panel.mode.Enter then
			panel.mode:Enter(proxy, panel.actorid, panel.actorname, panel.actorclass)
		end
		panel.mode:Update(proxy, set)

		local list = wipe(panel.list)
		local dataset = proxy.dataset
		for i = 1, #dataset do
			local d = dataset[i]
			if d and d.id and d.value and not d.ignore then
				list[#list + 1] = d
			end
		end

		if #list == 0 then
			ClosePanel(win)
			return
		end
		if not (panel.mode.metadata and panel.mode.metadata.ordersort) then
			tsort(list, value_sort)
		end

		local p = win.db
		local rowheight = p.barheight
		local spacing = p.barspacing
		local step = rowheight + spacing
		local maxrows = max(6, floor((g:GetHeight() - PANEL_PAD * 2 + spacing) / step))
		local shown = min(#list, maxrows)

		panel.maxoffset = #list - shown
		if not keepoffset then
			panel.offset = 0
		end
		panel.offset = min(panel.offset, panel.maxoffset)

		panel:SetWidth(p.barwidth)
		panel:SetHeight(shown * step - spacing + PANEL_PAD * 2)
		panel:SetBackdropColor(p.background.color.r, p.background.color.g, p.background.color.b, p.background.color.a or 1)
		ApplyChrome(panel)
		PlacePanel(g, panel)

		local texture = Skada:MediaFetch("statusbar", p.bartexture)
		local font = Skada:MediaFetch("font", p.barfont)
		local numfont = Skada:MediaFetch("font", p.numfont)
		local color = validclass[panel.actorclass] and classcolors(panel.actorclass) or p.barcolor
		local bgc = p.barbgcolor
		local topvalue = max(list[1].value or 0, 1)
		if panel.mode.metadata and panel.mode.metadata.ordersort then
			for i = 2, #list do
				topvalue = max(topvalue, list[i].value or 0)
			end
		end

		for i = 1, shown do
			local d = list[i + panel.offset]
			local row = GetRow(panel, i)
			row.data = d

			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PAD, -PANEL_PAD - (i - 1) * step)
			row:SetPoint("RIGHT", panel, "RIGHT", -PANEL_PAD, 0)
			row:SetHeight(rowheight)
			row.icon:SetWidth(rowheight)
			row.icon:SetTexture(d.icon or [[Interface\Icons\INV_Misc_QuestionMark]])

			row.bar:SetStatusBarTexture(texture)
			row.bar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
			row.bar:SetValue((d.value or 0) / topvalue)
			row.bg:SetTexture(texture)
			row.bg:SetVertexColor(bgc.r, bgc.g, bgc.b, bgc.a or 0.6)

			row.label:SetFont(font, p.barfontsize, p.barfontflags)
			row.value:SetFont(numfont, p.numfontsize, p.numfontflags)
			row.label:SetText(d.text or d.label)
			row.value:SetText(d.valuetext)
			row:Show()
		end

		for i = shown + 1, #panel.rows do
			panel.rows[i].data = nil
			panel.rows[i]:Hide()
		end

		panel:Show()
	end

	function ClosePanel(win)
		local panel = win and win.bargroup and win.bargroup.foreverPanel
		if not panel then return end
		panel.mode, panel.actorid, panel.actorname, panel.actorclass = nil, nil, nil, nil
		panel:Hide()
	end

	local function TogglePanel(win, id, label, class, mode)
		local panel = GetPanel(win)
		if panel:IsShown() and panel.actorid == id and panel.mode == mode then
			ClosePanel(win)
			return
		end
		panel.win = win
		panel.mode = mode
		panel.actorid, panel.actorname, panel.actorclass = id, label, class
		panel.proxy:clean()
		RefreshPanel(win)
	end

	---------------------------------------------------------------------------
	-- header

	local function ModeTitle(win)
		local mode = win.selectedmode
		if not mode then
			return win.metadata and win.metadata.title
		elseif mode == win.parentmode then
			return MODE_TITLES[mode.moduleName] or mode.localeName
		end
		return win.title or mode.localeName
	end

	local function UpdateTimer(g)
		local fv = g.forever
		local win = g.win
		local set = win and win.selectedset and win:GetSelectedSet()
		local secs = set and Skada:GetSetTime(set)
		fv.timer:SetText(secs and format("[%s]", Skada:FormatTime(secs)) or "")
	end

	local function tickerOnUpdate(self, elapsed)
		self.elapsed = (self.elapsed or 0) + elapsed
		if self.elapsed >= 0.5 then
			self.elapsed = 0
			UpdateTimer(self:GetParent():GetParent())
		end
	end

	local function AdjustForeverTitle(g)
		local fv = g.forever
		local text = g.button.text
		g.button.icon:Hide()
		text:ClearAllPoints()
		text:SetJustifyH("LEFT")
		text:SetJustifyV("MIDDLE")
		text:SetPoint("LEFT", fv.dropdown, "RIGHT", 5, 0)
		text:SetPoint("RIGHT", fv.segment, "LEFT", -4, 0)
	end

	local function adjustTitle(g, nomouseover)
		if g.forever and g.forever.on then
			return AdjustForeverTitle(g)
		end
		return protoAdjustTitle(g, nomouseover)
	end

	local function dropdownOnClick(self)
		Skada:ModeMenu(self.list.win, self)
	end

	local function segmentOnClick(self, button)
		local win = self.list.win
		if button == "RightButton" then
			win:SetSelectedSet(win.selectedset == "total" and "current" or "total")
		else
			Skada:SegmentMenu(win)
		end
	end

	local function menuOnClick(self, button)
		if button == "RightButton" then
			Private.OpenOptions(self.list.win)
		else
			Skada:OpenMenu(self.list.win)
		end
	end

	local function collapseOnClick(self)
		local win = self.list.win
		win.db.forevercollapsed = not win.db.forevercollapsed
		Skada:ApplySettings(win)
	end

	local function SetupHeader(g)
		local fv = {}
		g.forever = fv
		local anchor = g.button

		-- a font object up front: Update can set the time before ApplySettings
		-- picks the title font, and a fontless SetText errors in the client.
		fv.timer = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		fv.timer:SetPoint("LEFT", anchor, "LEFT", 7, 0)
		fv.timer:SetShadowOffset(1, -1)

		fv.dropdown = NewButton(anchor, "arrow", false, L["Mode"], L["Jump to a specific mode."], dropdownOnClick)
		fv.dropdown:SetPoint("LEFT", fv.timer, "RIGHT", 4, 0)

		fv.collapse = NewButton(anchor, "minus", true, "Collapse", "Hide or show the bars.", collapseOnClick)
		fv.collapse:SetPoint("RIGHT", anchor, "RIGHT", -4, 0)

		fv.menu = NewButton(anchor, "gear", false, L["Configure"], L["btn_config_desc"], menuOnClick)
		fv.menu:SetPoint("RIGHT", fv.collapse, "LEFT", -3, 0)

		fv.segment = NewButton(anchor, "ring", false, L["Segment"], "Click: choose a fight.\nRight-click: switch between Current and Overall.", segmentOnClick)
		fv.segment:SetPoint("RIGHT", fv.menu, "LEFT", -3, 0)

		for _, b in ipairs({fv.dropdown, fv.collapse, fv.menu, fv.segment}) do
			b.list = g
		end

		fv.rule = anchor:CreateTexture(nil, "OVERLAY")
		fv.rule:SetTexture([[Interface\Buttons\WHITE8X8]])
		fv.rule:SetVertexColor(RIM.r, RIM.g, RIM.b, 0.8)
		fv.rule:SetHeight(1)
		fv.rule:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, 0)
		fv.rule:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)

		fv.ticker = CreateFrame("Frame", nil, anchor)
		fv.ticker:SetScript("OnUpdate", tickerOnUpdate)

		g.AdjustTitle = adjustTitle
	end

	local function ShowHeader(g, show)
		local fv = g.forever
		for _, region in ipairs({fv.timer, fv.dropdown, fv.collapse, fv.menu, fv.segment, fv.rule, fv.ticker}) do
			if show then
				region:Show()
			else
				region:Hide()
			end
		end
	end

	---------------------------------------------------------------------------
	-- wrap the display

	local origCreate = mod.Create
	function mod:Create(window, isnew)
		origCreate(self, window, isnew)
		local g = window.bargroup
		if g and not g.forever then
			SetupHeader(g)
		end
	end

	local origApplySettings = mod.ApplySettings
	function mod:ApplySettings(win)
		origApplySettings(self, win)
		local g = win and win.bargroup
		if not g or not g.forever then return end

		local p = win.db
		local fv = g.forever
		fv.on = IsForever(win) and true or nil

		if not fv.on then
			ShowHeader(g, false)
			HideChrome(g)
			ClosePanel(win)
			g:SetDisableResize(p.noresize)
			g:EnableMouse(true) -- in case it was collapsed
			g:AdjustButtons()
			return
		end

		-- the header buttons replace Skada's toolbar.
		for i = 1, #g.buttons do
			g.buttons[i].visible = nil
		end
		g:AdjustButtons()

		ShowHeader(g, true)
		local font = p.title.fontpath or Skada:MediaFetch("font", p.title.font)
		fv.timer:SetFont(font, max(9, p.title.fontsize - 2), p.title.fontflags)
		fv.timer:SetTextColor(GOLD.r, GOLD.g, GOLD.b)
		UpdateTimer(g)

		local size = max(14, min(20, p.title.height - 6))
		for _, b in ipairs({fv.dropdown, fv.collapse, fv.menu, fv.segment}) do
			b:SetWidth(size)
			b:SetHeight(size)
		end

		-- collapsed: the frame keeps its size (and saved position) but only
		-- the header shows; the empty body lets clicks through.
		if p.forevercollapsed then
			ClosePanel(win)
			g:SetDisableResize(true)
			g:EnableMouse(false)
			g:SetBackdropColor(0, 0, 0, 0)
			g.maxBars = 0
			g:SortBars()
			ApplyChrome(g, g.button)
		else
			g:SetDisableResize(p.noresize)
			g:EnableMouse(true)
			ApplyChrome(g)
		end
		fv.collapse.title = p.forevercollapsed and "Expand" or "Collapse"
		AdjustForeverTitle(g)

		if g.foreverPanel and g.foreverPanel:IsShown() then
			RefreshPanel(win, true)
		end
	end

	local origSetTitle = mod.SetTitle
	function mod:SetTitle(win, title)
		if IsForever(win) and win.bargroup.forever then
			win.bargroup.button:SetText(ModeTitle(win) or title)
			return
		end
		return origSetTitle(self, win, title)
	end

	local origUpdate = mod.Update
	function mod:Update(win)
		origUpdate(self, win)
		if not IsForever(win) or not win.bargroup.forever then return end
		win.bargroup.button:SetText(ModeTitle(win))
		UpdateTimer(win.bargroup)
		if win.bargroup.foreverPanel and win.bargroup.foreverPanel:IsShown() then
			RefreshPanel(win, true)
		end
	end

	local origWipe = mod.Wipe
	function mod:Wipe(win)
		ClosePanel(win)
		return origWipe(self, win)
	end

	local origBarClick = mod.BarClick
	function mod:BarClick(event, bar, button)
		local win = not Skada.testMode and bar and bar.win
		local md = win and win.metadata
		local click1 = md and md.click1
		if
			IsForever(win) and button == "LeftButton" and not IsModifierKeyDown()
			and win.selectedmode and win.selectedmode == win.parentmode
			and not md.click and type(click1) == "table" and click1.Update
			and bar.id and not bar.ignore and not total_noclick(win.selectedset, click1)
		then
			TogglePanel(win, bar.id, bar.text, bar.class, click1)
			GameTooltip:Hide()
			return
		end
		return origBarClick(self, event, bar, button)
	end

	local origAddDisplayOptions = mod.AddDisplayOptions
	function mod:AddDisplayOptions(win, options)
		origAddDisplayOptions(self, win, options)
		local general = options.baroptions and options.baroptions.args and options.baroptions.args.general
		if not general then return end
		general.args.foreverstyle = {
			type = "toggle",
			name = "WoW Forever style",
			desc = "Header, frame and docked spell breakdown like WoW Forever's damage meter.",
			order = 1,
			width = "double",
			get = function() return win.db.foreverstyle end,
			set = function(_, val)
				win.db.foreverstyle = val and true or false
				Skada:ApplySettings(win)
			end
		}
	end
end

-- Bar Display is built by Skada:LoadModules at OnInitialize; windows come later.
hooksecurefunc(Skada, "LoadModules", function()
	if Skada.foreverInstalled then return end
	local mod = Skada:GetModule("Bar Display", true)
	if mod then
		Skada.foreverInstalled = true
		install(mod)
	end
end)
