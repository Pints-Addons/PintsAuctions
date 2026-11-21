-- Pint's Auctions - tabs inside the auction house window: Shopping, Selling, Cancelling, Pint's.
local ADDON, NS = ...
local PA = NS.PA
local Print, Money = PA.Print, PA.Money

local HW, HH = 790, 420            -- the area we draw in, over the auction window's own pages
local host, pages, hostTabs = nil, {}, {}
local ME = UnitName("player")
local function S() return PA.S end
local function Plain(v) return (Money(v):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

---------------------------------------------------------------- small widgets
local function Btn(parent, text, w, h)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(w or 80, h or 22); b:SetText(text)
	return b
end
PA.Btn = Btn
local function Edit(parent, w, numeric)
	local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	e:SetSize(w, 20); e:SetAutoFocus(false); if numeric then e:SetNumeric(true) end
	e:SetScript("OnEscapePressed", e.ClearFocus); e:SetScript("OnEnterPressed", e.ClearFocus)
	return e
end
PA.Edit = Edit
local function Label(parent, text, font)
	local f = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall"); f:SetText(text or "")
	return f
end
PA.Label = Label
local function Tip(frame, title, text)
	frame:HookScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(title); if text then GameTooltip:AddLine(text, 1, 1, 1, true) end; GameTooltip:Show() end)
	frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end
PA.Tip = Tip
local QCOL = { [0] = "9d9d9d", [1] = "ffffff", [2] = "1eff00", [3] = "0070dd", [4] = "a335ee", [5] = "ff8000" }
local function QName(name, q) return "|cff" .. (QCOL[q or 1] or "ffffff") .. (name or "?") .. "|r" end
PA.QName = QName
local function Box(parent)
	local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	f:SetBackdropColor(0, 0, 0, 0.35); f:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
	return f
end

-- a scrolling list; cols = { {width, justify, header}, ... }; data = { { text1, text2, ..., texture = , link = } }
-- text too long for its column is written smaller until it fits (down to 8); still too long, it wraps onto two lines
local function Fit(fs, w, rowH)
	local font, size, flags = GameFontHighlightSmall:GetFont()
	if not font then return end
	fs:SetFont(font, size, flags); fs:SetWordWrap(false); fs:SetHeight(rowH)
	local sw = (fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth()) or fs:GetStringWidth() or 0
	if sw <= w or sw == 0 then return end
	local s = math.max(8, math.floor(size * w / sw * 2) / 2)
	fs:SetFont(font, s, flags)
	sw = (fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth()) or fs:GetStringWidth() or 0
	if sw > w and rowH >= 18 then fs:SetWordWrap(true); if fs.SetMaxLines then fs:SetMaxLines(2) end end
end
PA.FitText = Fit
local function List(parent, w, rows, rowH, cols, onClick, noIcon)
	local f = Box(parent)
	f:SetSize(w, rows * rowH + 4)
	f.data, f.offset, f.rows = {}, 0, {}
	local x0 = noIcon and 4 or rowH + 2
	-- the columns fit inside the box with a little room before its right edge (the icon takes some of the width):
	-- whatever doesn't fit comes off the first (name) column
	do
		local copy, total = {}, 0
		for i, col in ipairs(cols) do local c = {}; for k, v in pairs(col) do c[k] = v end; copy[i] = c; total = total + col[1] end
		local over = total - (w - x0 - 12)
		if over > 0 and copy[1] then copy[1][1] = math.max(40, copy[1][1] - over) end
		cols = copy
	end
	local hx = x0 + 2
	f.heads = {}
	for c, col in ipairs(cols) do
		if col[3] then
			local h = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); h:SetText(col[3])
			h:SetPoint("BOTTOMLEFT", f, "TOPLEFT", hx, 2); h:SetWidth(col[1] - 4 - (col.pad or 0)); h:SetJustifyH(col[2] or "LEFT")
			f.heads[c] = h
			-- sortable column: click the header to sort, click again to flip the order
			if col.sort then
				local hb = CreateFrame("Button", nil, f)
				hb:SetPoint("BOTTOMLEFT", f, "TOPLEFT", hx, 0); hb:SetSize(col[1] - 2, 16)
				hb:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
				hb:SetScript("OnClick", function()
					if f.sortCol == c then f.sortDesc = not f.sortDesc else f.sortCol, f.sortDesc = c, (col.sort ~= "asc") end
					if f.onSort then f.onSort(f.sortCol, f.sortDesc) end
					f:Set(f.data)
				end)
				hb:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine("Click to sort by " .. col[3]); GameTooltip:Show() end)
				hb:SetScript("OnLeave", function() GameTooltip:Hide() end)
			end
		end
		hx = hx + col[1]
	end
	f.cols = cols
	for i = 1, rows do
		local r = CreateFrame("Button", nil, f)
		r:SetSize(w - 4, rowH); r:SetPoint("TOPLEFT", 2, -2 - (i - 1) * rowH)
		r.hl = r:CreateTexture(nil, "HIGHLIGHT"); r.hl:SetAllPoints(); r.hl:SetColorTexture(1, 0.82, 0, 0.12)
		r.sel = r:CreateTexture(nil, "BACKGROUND"); r.sel:SetAllPoints(); r.sel:SetColorTexture(1, 0.82, 0, 0.22); r.sel:Hide()
		r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(rowH - 2, rowH - 2); r.icon:SetPoint("LEFT", 1, 0)
		r.cells = {}
		local x = x0
		for c, col in ipairs(cols) do
			local fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			fs:SetPoint("LEFT", x, 0); fs:SetWidth(col[1] - 4 - (col.pad or 0)); fs:SetJustifyH(col[2] or "LEFT"); fs:SetWordWrap(false)
			r.cells[c] = fs; x = x + col[1]
		end
		r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		r:SetScript("OnClick", function(self, b) if self.item and onClick then onClick(self.item, b, self) end end)
		r:SetScript("OnEnter", function(self)
			local it = self.item
			if it and it.link then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(it.link); GameTooltip:Show()
			elseif it and it.tip then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(it.tip, 1, 1, 1, true); GameTooltip:Show() end
		end)
		r:SetScript("OnLeave", function() GameTooltip:Hide() end)
		f.rows[i] = r
	end
	f.more = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); f.more:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", -2, -2)
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", function(self, d) self.offset = math.max(0, math.min(#self.data - rows, self.offset - d * 3)); self:Refresh() end)
	function f:Refresh()
		for i, r in ipairs(self.rows) do
			local item = self.data[i + self.offset]
			r.item = item
			if item then
				r.icon:SetTexture(item.texture); r.icon:SetShown(item.texture ~= nil)
				for c, fs in ipairs(r.cells) do fs:SetText(item[c] or ""); Fit(fs, cols[c][1] - 4 - (cols[c].pad or 0), rowH) end
				r:SetAlpha(item.dim and 0.45 or 1)
				r.sel:SetShown(item == self.selected or (self.selectedKey ~= nil and item.key == self.selectedKey))
				r:Show()
			else r:Hide() end
		end
		self.more:SetText(#self.data > rows and (("%d-%d of %d  (scroll)"):format(self.offset + 1, math.min(#self.data, self.offset + rows), #self.data)) or "")
	end
	function f:Sort()
		local c = self.sortCol
		for i, h in pairs(self.heads) do
			local t = cols[i][3]
			if i == c then t = (cols[i][2] == "RIGHT") and ((self.sortDesc and "v " or "^ ") .. t) or (t .. (self.sortDesc and " v" or " ^")) end
			h:SetText(t)
		end
		if not c then return end
		local desc = self.sortDesc
		local function v(it) local k = it.sk and it.sk[c]; if k == nil then k = it[c] end; return k end
		table.sort(self.data, function(a, b)
			local x, y = v(a), v(b)
			if type(x) ~= type(y) then x, y = tostring(x), tostring(y) end
			if x == y then return (a.name or "") < (b.name or "") end
			if desc then return x > y else return x < y end
		end)
	end
	function f:Set(data, keep) self.data = data or {}; self:Sort(); if not keep then self.offset = 0 else self.offset = math.max(0, math.min(self.offset, #self.data - rows)) end; self:Refresh() end
	return f
end
PA.List = List

-- gold / silver / copper boxes; onChange(user)
local function MoneyBox(parent, onChange)
	local f = CreateFrame("Frame", nil, parent); f:SetSize(170, 20)
	local function part(w, icon, x, prev)
		local e = Edit(f, w, true)
		if prev then e:SetPoint("LEFT", prev, "RIGHT", 14, 0) else e:SetPoint("LEFT", 6, 0) end
		local t = f:CreateTexture(nil, "ARTWORK"); t:SetSize(13, 13); t:SetPoint("LEFT", e, "RIGHT", 0, 0); t:SetTexture(icon)
		e:SetScript("OnTextChanged", function(_, user) if not f.setting and onChange then onChange(user) end end)
		e:SetScript("OnTabPressed", function() if f.next then f.next:SetFocus() end end)
		return e
	end
	f.g = part(56, "Interface\\MoneyFrame\\UI-GoldIcon")
	f.s = part(24, "Interface\\MoneyFrame\\UI-SilverIcon", nil, f.g)
	f.c = part(24, "Interface\\MoneyFrame\\UI-CopperIcon", nil, f.s)
	f.g.next, f.s.next = f.s, f.c
	f.g:SetScript("OnTabPressed", function() f.s:SetFocus() end); f.s:SetScript("OnTabPressed", function() f.c:SetFocus() end)
	function f:Get()
		local g, s, c = tonumber(f.g:GetText()), tonumber(f.s:GetText()), tonumber(f.c:GetText())
		if not (g or s or c) then return nil end
		return (g or 0) * 10000 + (s or 0) * 100 + (c or 0)
	end
	function f:Set(v)
		f.setting = true
		if not v then f.g:SetText(""); f.s:SetText(""); f.c:SetText("")
		else
			v = math.floor(v + 0.5)
			local g, s, c = math.floor(v / 10000), math.floor(v / 100) % 100, v % 100
			f.g:SetText(g > 0 and g or ""); f.s:SetText((g > 0 or s > 0) and s or ""); f.c:SetText(c)
		end
		f.setting = false
	end
	function f:HasFocus() return f.g:HasFocus() or f.s:HasFocus() or f.c:HasFocus() end
	return f
end
PA.MoneyBox = MoneyBox

-- a small pop-up menu
local menu
local function Menu(anchor, items)
	if not menu then
		menu = CreateFrame("Frame", "PintsAuctionsMenu", UIParent, "BackdropTemplate")
		menu:SetFrameStrata("FULLSCREEN_DIALOG"); menu:SetClampedToScreen(true); menu:EnableMouse(true)
		menu:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
		menu:SetBackdropColor(0, 0, 0, 0.95); menu.b = {}
		tinsert(UISpecialFrames, "PintsAuctionsMenu")
	end
	for i, it in ipairs(items) do
		local b = menu.b[i]
		if not b then
			b = CreateFrame("Button", nil, menu); b:SetSize(240, 16); b:SetPoint("TOPLEFT", 8, -6 - (i - 1) * 16)
			b.t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.t:SetPoint("LEFT", 4, 0)
			local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 0.82, 0, 0.18)
			b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			menu.b[i] = b
		end
		b.t:SetText(it.text); b:EnableMouse(it.fn ~= nil)
		b:SetScript("OnClick", function(_, btn) menu:Hide(); if it.fn then it.fn(btn) end end)
		b:Show()
	end
	for i = #items + 1, #menu.b do menu.b[i]:Hide() end
	menu:SetSize(256, #items * 16 + 12)
	menu:ClearAllPoints(); menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2); menu:Show()
end
PA.Menu = Menu

---------------------------------------------------------------- buying one particular auction (shared by Shopping and Selling)
-- the game only buys auctions on the page it last loaded, and only on a real click, so: load the page, then the button buys
local buyer = {}
-- the page changes under us after a buy; until the game sends the updated page, skip the slot we just bought
local listVersion, justBought = 0, nil
do local ev = CreateFrame("Frame"); pcall(ev.RegisterEvent, ev, "AUCTION_ITEM_LIST_UPDATE"); ev:SetScript("OnEvent", function() listVersion = listVersion + 1 end) end
local function Stale(i) return justBought and justBought.v == listVersion and justBought.i == i end
function PA.PrepareBuy(row, button, status)
	buyer.target, buyer.button, buyer.status = nil, button, status
	button:Disable()
	if not row or row.buyout <= 0 then return end
	if row.owner == ME then if status then status("That one is yours.") end; return end
	-- already on the page the game has loaded (the usual case in a chain: the next stack sits right below)? no search needed
	local n = GetNumAuctionItems("list") or 0
	for i = 1, n do
		local name, _, count, _, _, _, _, _, _, buyout, _, _, _, owner = GetAuctionItemInfo("list", i)
		if not Stale(i) and name == row.name and count == row.count and buyout == row.buyout and (owner == row.owner or not row.owner) then
			buyer.target = row
			button:SetText(("Buy %d for %s"):format(row.count, Plain(row.buyout))); button:Enable()
			if status then status("Ready - click Buy.") end
			return
		end
	end
	if status then status("Getting that auction ready...") end
	PA.CancelSearches()
	PA.Search({ text = row.name, exact = true, page = row.page or 0, maxPages = (row.page or 0) + 1, onDone = function()
		buyer.target = row
		button:SetText(("Buy %d for %s"):format(row.count, Plain(row.buyout))); button:Enable()
		if status then status("Ready - click Buy.") end
	end })
end
function PA.DoBuy(after)
	local t = buyer.target
	if not t then return end
	local n = GetNumAuctionItems("list")
	for i = 1, n do
		local name, _, count, _, _, _, _, _, _, buyout, _, _, _, owner = GetAuctionItemInfo("list", i)
		if not Stale(i) and name == t.name and count == t.count and buyout == t.buyout and (owner == t.owner or not t.owner) then
			if GetMoney() < buyout then Print("not enough gold."); return end
			PlaceAuctionBid("list", i, buyout)
			justBought = { i = i, v = listVersion }
			Print(("bought %d %s for %s."):format(count, name, Money(buyout)))
			buyer.target = nil; if buyer.button then buyer.button:Disable() end
			if after then C_Timer.After(0.25, function() after(t) end) end
			return
		end
	end
	Print("that auction is gone - refreshing.")
	buyer.target = nil; if buyer.button then buyer.button:Disable() end
	if after then after() end
end

---------------------------------------------------------------- the frame over the auction window, and its tabs
local PAGES = { { "shop", "Shopping" }, { "sell", "Selling" }, { "cancel", "Cancelling" }, { "deals", "Deals" }, { "pints", "Pint's" } }
local function ShowPage(name)
	for n, p in pairs(pages) do p:SetShown(n == name) end
	PA.page = name
	if pages[name] and pages[name].OnOpen then pages[name]:OnOpen() end
end
local function SelectTab(name)
	if not host then return end
	local t = hostTabs[name]
	if PanelTemplates_SetTab then PanelTemplates_SetTab(AuctionFrame, t:GetID()) end
	for _, n in ipairs({ "AuctionFrameBrowse", "AuctionFrameBid", "AuctionFrameAuctions" }) do local f = _G[n]; if f then f:Hide() end end
	host:Show()
	ShowPage(name)
end
PA.SelectTab = SelectTab
function PA.HostShown() return host and host:IsShown() end

local function BuildHost()
	host = CreateFrame("Frame", "PintsAuctionsFrame", AuctionFrame, "BackdropTemplate")
	host:SetSize(HW, HH)
	host:SetPoint("TOPLEFT", AuctionFrame, "TOPLEFT", 12, -12)
	host:SetFrameLevel(AuctionFrame:GetFrameLevel() + 20)
	host:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 } })
	host:EnableMouse(true)
	host:Hide()
	local title = Label(host, "|cffd4a017Pint's|r Auctions", "GameFontNormal"); title:SetPoint("TOPLEFT", 16, -12)
	host.title = Label(host, "", "GameFontHighlight"); host.title:SetPoint("LEFT", title, "RIGHT", 12, 0)
	local close = CreateFrame("Button", nil, host, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function() HideUIPanel(AuctionFrame) end)
	local opt = Btn(host, "Options", 70, 20); opt:SetPoint("TOPRIGHT", -34, -8)
	opt:SetScript("OnClick", function() if PA.OpenOptions then PA.OpenOptions() end end)
	for _, pg in ipairs(PAGES) do
		local p = CreateFrame("Frame", nil, host); p:SetPoint("TOPLEFT", 14, -34); p:SetPoint("BOTTOMRIGHT", -14, 12); p:Hide()
		p.title = pg[2]
		p:HookScript("OnShow", function() host.title:SetText(pg[2]) end)
		pages[pg[1]] = p
	end
	PA.BuildShop(pages.shop); PA.BuildSell(pages.sell); PA.BuildCancel(pages.cancel); PA.BuildPints(pages.pints); PA.BuildDeals(pages.deals)

	-- our tabs, after the game's own (and any other add-on's)
	local n = AuctionFrame.numTabs or 3
	while _G["AuctionFrameTab" .. (n + 1)] do n = n + 1 end
	local prev = _G["AuctionFrameTab" .. n]
	for _, pg in ipairs(PAGES) do
		n = n + 1
		local ok, t = pcall(CreateFrame, "Button", "AuctionFrameTab" .. n, AuctionFrame, "AuctionTabTemplate")
		if not ok or not t then t = CreateFrame("Button", "AuctionFrameTab" .. n, AuctionFrame, "CharacterFrameTabButtonTemplate") end
		t:SetID(n); t:SetText(pg[2])
		if prev then t:SetPoint("LEFT", prev, "RIGHT", -15, 0) else t:SetPoint("TOPLEFT", AuctionFrame, "BOTTOMLEFT", 15, 12) end
		t:SetScript("OnClick", function() PlaySound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB or 841); SelectTab(pg[1]) end)
		if PanelTemplates_TabResize then PanelTemplates_TabResize(t, 0) end
		t.pintsTab = pg[1]
		hostTabs[pg[1]] = t; prev = t
	end
	if PanelTemplates_SetNumTabs then PanelTemplates_SetNumTabs(AuctionFrame, n) else AuctionFrame.numTabs = n end
	for i = 1, n do local t = _G["AuctionFrameTab" .. i]; if t then t:SetFrameLevel(host:GetFrameLevel() + 5) end end
	if PanelTemplates_UpdateTabs then pcall(PanelTemplates_UpdateTabs, AuctionFrame) end
	-- one of the game's own tabs: step aside
	if AuctionFrameTab_OnClick then
		hooksecurefunc("AuctionFrameTab_OnClick", function(self) if not (self and self.pintsTab) then host:Hide() end end)
	end

	-- keyboard: Space posts / cancels, Shift-Space skips, Backspace goes back
	host:EnableKeyboard(true)
	host:SetPropagateKeyboardInput(true)
	host:SetScript("OnKeyDown", function(self, key)
		local used = false
		if not GetCurrentKeyBoardFocus() then
			if key == "SPACE" and PA.page == "sell" then
				if IsShiftKeyDown() then if S().shiftSkip then PA.SellSkip(1); used = true end
				elseif S().spacePost then PA.SellPost(); used = true end
			elseif key == "BACKSPACE" and PA.page == "sell" and S().bsPrev then PA.SellSkip(-1); used = true
			elseif key == "SPACE" and PA.page == "cancel" and S().spaceCancel then PA.CancelNext(); used = true
			end
		end
		if not InCombatLockdown() then self:SetPropagateKeyboardInput(not used) end
	end)
	host:SetScript("OnHide", function() if menu then menu:Hide() end end)
end

---------------------------------------------------------------- Shopping
local shop = {}
PA.shop = shop
local QUALITY = { { nil, "Any quality" }, { 1, "Common+" }, { 2, "Uncommon+" }, { 3, "Rare+" }, { 4, "Epic+" } }
local function AddHistory(term)
	local h = PA.db.history
	for i = #h, 1, -1 do if h[i].text == term.text and h[i].exact == term.exact then table.remove(h, i) end end
	table.insert(h, 1, term)
	while #h > 30 do table.remove(h) end
end
local function TermText(t) return (t.text ~= "" and t.text or "(everything)") .. (t.exact and " |cff888888exact|r" or "") .. ((t.minLevel or t.maxLevel) and (" |cff888888lvl " .. (t.minLevel or "") .. "-" .. (t.maxLevel or "") .. "|r") or "") end
local function CurrentTerm()
	return { text = shop.text:GetText(), minLevel = tonumber(shop.min:GetText()), maxLevel = tonumber(shop.max:GetText()),
		quality = shop.quality, usable = shop.usable:GetChecked() or nil, exact = shop.exact:GetChecked() or nil }
end
local function Group(rows)
	local by, out = {}, {}
	for _, r in ipairs(rows) do
		local key = PA.Key(r.link) or r.name
		local g = by[key]
		if not g then g = { name = r.name, link = r.link, texture = r.texture, quality = r.quality, qty = 0, low = nil, key = key, n = 0 }; by[key] = g; out[#out + 1] = g end
		g.qty = g.qty + r.count; g.n = g.n + 1
		if r.buyout > 0 then local u = r.buyout / r.count; if not g.low or u < g.low then g.low = u end end
	end
	for key, g in pairs(by) do if g.low then PA.Record(key, math.floor(g.low + 0.5)) end end
	table.sort(out, function(a, b) return (a.low or math.huge) < (b.low or math.huge) end)
	return out
end
local function RunSearch(terms)
	PA.CancelSearches()
	local all, empty = {}, {}
	shop.status:SetText("Searching...")
	shop.detail:Set({}); shop.buyBtn:Disable(); shop.results.selected = nil
	local maxPages = S().allPages and 50 or 10
	for k, t in ipairs(terms) do
		if #terms == 1 then AddHistory(t) end
		local found = 0
		PA.Search({ text = t.text, minLevel = t.minLevel, maxLevel = t.maxLevel, quality = t.quality, usable = t.usable, exact = t.exact, maxPages = maxPages,
			onRow = function(r) all[#all + 1] = r; found = found + 1 end,
			onPage = function(page, n, total) shop.status:SetText(("Searching %s (%d of %d)... %d of %d"):format(t.text ~= "" and t.text or "everything", k, #terms, math.min((page + 1) * 50, total or 0), total or 0)) end,
			onDone = function()
				if found == 0 then empty[#empty + 1] = t end
				if k == #terms then
					local groups = Group(all)
					local data = {}
					for _, g in ipairs(groups) do data[#data + 1] = { QName(g.name, g.quality), Money(g.low), g.qty, texture = g.texture, link = g.link, group = g, key = g.key } end
					if S().showEmpty then for _, e in ipairs(empty) do data[#data + 1] = { "|cff888888" .. (e.text ~= "" and e.text or "?") .. "|r", "|cff888888none up|r", 0, tip = "Nothing found for this search." } end end
					shop.results:Set(data)
					shop.status:SetText(#groups .. " item" .. (#groups == 1 and "" or "s") .. " found. Click one to see its auctions.")
					shop.RefreshLeft()
				end
			end })
	end
end
PA.RunSearch = RunSearch

local function Unit(r) return r.buyout / math.max(1, r.count) end
local ShowChain
local function OpenItem(g, keepChain)
	if not keepChain or shop.current ~= g then shop.chainBase, shop.chainFirst = nil, nil end
	shop.current = g
	-- show what's being looked at in the search box (shift-clicks, Deals, lists), ready to search again by hand
	if shop.text and g.name and shop.text:GetText() ~= g.name then shop.text:SetText(g.name); shop.text:SetCursorPosition(0) end
	shop.detail:Set({}); shop.buyBtn:Disable(); shop.buyBtn:SetText("Buy")
	shop.status:SetText("Loading " .. g.name .. "...")
	local rows = {}
	PA.CancelSearches()
	PA.Search({ text = g.name, exact = true, maxPages = S().allPages and 50 or 10,
		onRow = function(r) if (PA.Key(r.link) or r.name) == g.key then rows[#rows + 1] = r end end,
		onDone = function()
			table.sort(rows, function(a, b)
				local ua, ub = a.buyout > 0 and a.buyout / a.count or math.huge, b.buyout > 0 and b.buyout / b.count or math.huge
				return ua < ub
			end)
			shop.rows = rows
			local best
			for _, r in ipairs(rows) do if r.buyout > 0 and r.owner ~= ME then best = r; break end end
			if best then PA.Record(g.key, math.floor(Unit(best) + 0.5)) end
			ShowChain(best)
		end })
end
-- show what's left and line up `best` to buy (the cheapest stack, or the next one in a chain)
ShowChain = function(best)
	local rows, g = shop.rows or {}, shop.current
	local data = {}
	for _, r in ipairs(rows) do
		data[#data + 1] = { r.buyout > 0 and Money(Unit(r)) or "|cff888888bid only|r", r.count, r.buyout > 0 and Money(r.buyout) or Money(r.bid and r.bid > 0 and r.bid or r.minBid),
			r.owner == ME and "|cff40ff40you|r" or (r.owner or "?"), auction = r }
	end
	shop.detail:Set(data, true)
	shop.jump = nil
	if not best then shop.buyBtn:Disable(); shop.buyBtn:SetText("Buy"); shop.status:SetText(#rows > 0 and "None to buy out." or "None left."); return end
	shop.detail.selected = nil
	for _, d in ipairs(data) do if d.auction == best then shop.detail.selected = d end end
	shop.detail:Refresh()
	-- warn if the next stack costs much more than the one you just bought, or than the first one in this chain
	local last, first, u = shop.chainBase, shop.chainFirst, Unit(best)
	if last and S().chainWarn ~= false then
		local lim1, lim2 = S().chainJump or 0.2, S().chainJumpFirst or 0.4
		if u > last * (1 + lim1) then
			shop.jump = { from = last, to = u, pct = math.floor((u / last - 1) * 100 + 0.5), what = "the %s you just paid" }
		elseif first and u > first * (1 + lim2) then
			shop.jump = { from = first, to = u, pct = math.floor((u / first - 1) * 100 + 0.5), what = "the %s your first stack cost" }
		end
	end
	local name = g and g.name or best.name
	PA.PrepareBuy(best, shop.buyBtn, function(t)
		if shop.jump and t:find("Ready") then
			shop.buyBtn:SetText(("Buy %d for %s  (+%d%%)"):format(best.count, Plain(best.buyout), shop.jump.pct))
			t = ("|cffff8040Price jump: %s each, up %d%% from " .. shop.jump.what:format(Plain(shop.jump.from)) .. ".|r"):format(Plain(shop.jump.to), shop.jump.pct)
			PA.JumpPopup()
		end
		shop.status:SetText(#rows .. " auctions of " .. name .. ". " .. t)
	end)
end
-- after a buy: drop that stack and line up the next cheapest without searching everything again
local function AfterBuy(bought)
	if not bought then if shop.current then OpenItem(shop.current, true) end; return end
	shop.chainBase = Unit(bought)                          -- the stack you just bought
	shop.chainFirst = shop.chainFirst or Unit(bought)      -- the first stack of this chain
	if S().chainBuy == false then OpenItem(shop.current, true); return end
	local rows = shop.rows or {}
	for i, r in ipairs(rows) do if r == bought then table.remove(rows, i); break end end
	local nextR
	for _, r in ipairs(rows) do if r.buyout > 0 and r.owner ~= ME then nextR = r; break end end
	ShowChain(nextR)
end
PA.OpenItem, PA.AfterBuy = OpenItem, AfterBuy
StaticPopupDialogs["PINTSAUCTIONS_JUMP"] = {
	text = "%s", button1 = "Continue", button2 = "Stop", timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
	OnAccept = function() if shop.jump then PA.DoBuy(AfterBuy) end end,
	OnCancel = function()
		if not shop.jump then return end
		shop.jump = nil; buyer.target = nil
		shop.buyBtn:Disable(); shop.buyBtn:SetText("Buy")
		shop.status:SetText("Chain stopped - the price jumped. Pick a stack or Refresh to start again.")
	end,
}
function PA.JumpPopup()
	local j = shop.jump
	if not j then return end
	StaticPopup_Show("PINTSAUCTIONS_JUMP", ("Price jump!\n\nThe next stack is %s each,\n%d%% more than " .. j.what:format(Plain(j.from)) .. ".\n\nContinue buys it, Stop ends chain buying."):format(Plain(j.to), j.pct))
end

StaticPopupDialogs["PINTSAUCTIONS_NEWLIST"] = {
	text = "Name for the shopping list:", button1 = ACCEPT, button2 = CANCEL, hasEditBox = true, timeout = 0, whileDead = true, hideOnEscape = true,
	OnAccept = function(self, data)
		local eb = self.editBox or self.EditBox
		local name = eb and eb:GetText() or ""
		if name ~= "" then
			PA.db.lists[name] = PA.db.lists[name] or {}
			if data then for _, t in ipairs(data) do table.insert(PA.db.lists[name], t) end end
			shop.list = name
			Print("shopping list \"" .. name .. "\" saved.")
			if shop.RefreshLeft then shop.RefreshLeft() end
		end
	end,
	EditBoxOnEnterPressed = function(self) local p = self:GetParent(); StaticPopupDialogs.PINTSAUCTIONS_NEWLIST.OnAccept(p, p.data); p:Hide() end,
}
StaticPopupDialogs["PINTSAUCTIONS_DELLIST"] = {
	text = "Delete the shopping list \"%s\"?", button1 = YES, button2 = NO, timeout = 0, whileDead = true, hideOnEscape = true,
	OnAccept = function(_, name) PA.db.lists[name] = nil; if shop.list == name then shop.list = nil end; shop.RefreshLeft() end,
}

function PA.BuildShop(p)
	-- left: shopping lists / recent searches
	local LW = 230
	shop.mode = "lists"
	local bl = Btn(p, "Shopping Lists", 112, 20); bl:SetPoint("TOPLEFT", 0, 0)
	local br = Btn(p, "Recent Searches", 116, 20); br:SetPoint("LEFT", bl, "RIGHT", 2, 0)
	shop.lists = List(p, LW, 6, 16, { { LW - 50 }, { 40, "RIGHT" } }, function(item, btn)
		shop.list = item.name; shop.termSel = nil; shop.RefreshLeft()
		if btn == "LeftButton" and S().listAutoSearch and #PA.db.lists[item.name] > 0 then RunSearch(PA.db.lists[item.name]) end
	end, true)
	shop.lists:SetPoint("TOPLEFT", 0, -26)
	shop.terms = List(p, LW, 9, 16, { { LW - 10 } }, function(item, btn)
		local l = shop.list and PA.db.lists[shop.list]
		if not l then return end
		if btn == "RightButton" then table.remove(l, item.i); shop.termSel = nil; shop.RefreshLeft()
		else
			shop.termSel = item.i; shop.RefreshLeft()
			local t = item.term
			shop.text:SetText(t.text or ""); shop.exact:SetChecked(t.exact and true or false)
			shop.min:SetText(t.minLevel or ""); shop.max:SetText(t.maxLevel or "")
			RunSearch({ t })
		end
	end, true)
	shop.terms:SetPoint("TOPLEFT", shop.lists, "BOTTOMLEFT", 0, -20)
	shop.termsHdr = Label(p, "", "GameFontNormalSmall"); shop.termsHdr:SetPoint("BOTTOMLEFT", shop.terms, "TOPLEFT", 2, 3)
	shop.recent = List(p, LW, 19, 16, { { LW - 10 } }, function(item)
		local t = item.term
		shop.text:SetText(t.text or ""); shop.exact:SetChecked(t.exact and true or false); RunSearch({ t })
	end, true)
	shop.recent:SetPoint("TOPLEFT", 0, -26)
	local bNew = Btn(p, "New list", 74, 20); bNew:SetPoint("TOPLEFT", shop.terms, "BOTTOMLEFT", 0, -18)
	bNew:SetScript("OnClick", function() StaticPopup_Show("PINTSAUCTIONS_NEWLIST") end)
	local bAdd = Btn(p, "Add search", 78, 20); bAdd:SetPoint("LEFT", bNew, "RIGHT", 2, 0)
	bAdd:SetScript("OnClick", function()
		local t = CurrentTerm()
		if t.text == "" then Print("type something in the search box first."); return end
		if shop.list and PA.db.lists[shop.list] then table.insert(PA.db.lists[shop.list], t); shop.RefreshLeft()
		else StaticPopup_Show("PINTSAUCTIONS_NEWLIST", nil, nil, { t }) end
	end)
	Tip(bAdd, "Add search", "Adds what's in the search box to the selected list (or a new one).")
	local bDel = Btn(p, "Delete", 72, 20); bDel:SetPoint("LEFT", bAdd, "RIGHT", 2, 0)
	-- a search picked in the list: Delete removes just that one; nothing picked: the whole list (after asking)
	bDel:SetScript("OnClick", function()
		local l = shop.list and PA.db.lists[shop.list]
		if not l then return end
		if shop.termSel and l[shop.termSel] then
			local t = table.remove(l, shop.termSel)
			Print("removed \"" .. (t.text or "?") .. "\" from \"" .. shop.list .. "\".")
			shop.termSel = nil; shop.RefreshLeft()
		else
			StaticPopup_Show("PINTSAUCTIONS_DELLIST", shop.list, nil, shop.list)
		end
	end)
	Tip(bDel, "Delete", "With a search picked in the list below the lists: removes just that search. Otherwise: deletes the whole list (it asks first).")
	local bAll = Btn(p, "Search whole list", LW, 22); bAll:SetPoint("TOPLEFT", bNew, "BOTTOMLEFT", 0, -4)
	bAll:SetScript("OnClick", function() local l = shop.list and PA.db.lists[shop.list]; if l and #l > 0 then RunSearch(l) end end)
	shop.listButtons = { bNew, bAdd, bDel, bAll }
	function shop.RefreshLeft()
		local isLists = shop.mode == "lists"
		shop.lists:SetShown(isLists); shop.terms:SetShown(isLists); shop.termsHdr:SetShown(isLists); shop.recent:SetShown(not isLists)
		for _, b in ipairs(shop.listButtons) do b:SetShown(isLists) end
		bl:SetEnabled(not isLists); br:SetEnabled(isLists)
		local names = {}
		for n in pairs(PA.db.lists) do names[#names + 1] = n end
		table.sort(names)
		local data = {}
		for _, n in ipairs(names) do data[#data + 1] = { n, #PA.db.lists[n], name = n, key = n } end
		shop.lists.selectedKey = shop.list
		shop.lists:Set(data, true)
		local terms = {}
		local l = shop.list and PA.db.lists[shop.list]
		if l then for i, t in ipairs(l) do terms[#terms + 1] = { TermText(t), term = t, i = i, key = i, tip = "Click to search (and pick it - Delete then removes just this one). Right-click to remove it." } end end
		if shop.termSel and not (l and l[shop.termSel]) then shop.termSel = nil end
		shop.terms.selectedKey = shop.termSel
		shop.terms:Set(terms, true)
		shop.termsHdr:SetText(shop.list and ("In \"" .. shop.list .. "\"") or "Pick or make a list")
		local rec = {}
		for _, t in ipairs(PA.db.history) do rec[#rec + 1] = { TermText(t), term = t } end
		shop.recent:Set(rec, true)
		bDel:SetEnabled(shop.list ~= nil); bAll:SetEnabled(l ~= nil and #l > 0)
		bDel:SetText(shop.termSel and "Remove" or "Delete")
	end
	bl:SetScript("OnClick", function() shop.mode = "lists"; shop.RefreshLeft() end)
	function PA.ShowList(name) shop.mode = "lists"; shop.list = name; shop.termSel = nil; shop.RefreshLeft() end
	br:SetScript("OnClick", function() shop.mode = "recent"; shop.RefreshLeft() end)

	-- right: search and results
	local X = LW + 12
	shop.text = Edit(p, 190); shop.text:SetPoint("TOPLEFT", X + 6, 0)
	shop.text:SetScript("OnEnterPressed", function(self) self:ClearFocus(); RunSearch({ CurrentTerm() }) end)
	local go = Btn(p, "Search", 70, 22); go:SetPoint("LEFT", shop.text, "RIGHT", 4, 0)
	go:SetScript("OnClick", function() RunSearch({ CurrentTerm() }) end)
	local lv = Label(p, "Level"); lv:SetPoint("LEFT", go, "RIGHT", 10, 0)
	shop.min = Edit(p, 26, true); shop.min:SetPoint("LEFT", lv, "RIGHT", 8, 0)
	local dash = Label(p, "-"); dash:SetPoint("LEFT", shop.min, "RIGHT", 2, 0)
	shop.max = Edit(p, 26, true); shop.max:SetPoint("LEFT", dash, "RIGHT", 8, 0)
	shop.qi = 1
	-- quality: a drop-down list (click to open, pick one)
	local QCOLOR = { [1] = "ffffff", [2] = "1eff00", [3] = "0070dd", [4] = "a335ee" }
	local ARROW = "  |TInterface\\Buttons\\Arrow-Down-Up:12:12:0:-2|t"
	local function QLabel(i) local q = QUALITY[i]; return (q[1] and ("|cff" .. QCOLOR[q[1]] .. q[2] .. "|r") or q[2]) end
	shop.qbtn = Btn(p, QUALITY[1][2] .. ARROW, 104, 20); shop.qbtn:SetPoint("LEFT", shop.max, "RIGHT", 6, 0)
	shop.qbtn:SetScript("OnClick", function(self)
		local m = _G.PintsAuctionsMenu
		if m and m:IsShown() and m.owner == self then m:Hide(); return end
		local items = {}
		for i = 1, #QUALITY do
			items[i] = { text = (i == shop.qi and "|cffffd100>|r " or "   ") .. QLabel(i), fn = function()
				shop.qi = i; shop.quality = QUALITY[i][1]; self:SetText(QUALITY[i][2] .. ARROW)
			end }
		end
		PA.Menu(self, items)
		_G.PintsAuctionsMenu.owner = self
	end)
	shop.exact = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate"); shop.exact:SetSize(20, 20); shop.exact:SetPoint("TOPLEFT", X, -24)
	local ex = Label(p, "Exact name"); ex:SetPoint("LEFT", shop.exact, "RIGHT", 0, 0)
	shop.usable = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate"); shop.usable:SetSize(20, 20); shop.usable:SetPoint("LEFT", ex, "RIGHT", 10, 0)
	local us = Label(p, "Usable only"); us:SetPoint("LEFT", shop.usable, "RIGHT", 0, 0)
	shop.status = Label(p, "Type a name and press Search, or pick a shopping list.", "GameFontDisableSmall")
	shop.status:SetPoint("LEFT", us, "RIGHT", 14, 0); shop.status:SetWidth(HW - X - 230); shop.status:SetJustifyH("LEFT")
	local RW = HW - 28 - X
	shop.results = List(p, RW, 8, 16, { { RW - 220, "LEFT", "Name" }, { 120, "RIGHT", "Price each" }, { 70, "RIGHT", "Available" } }, function(item)
		if not item.group then return end
		shop.results.selected = item; shop.results:Refresh(); OpenItem(item.group)
	end)
	shop.results:SetPoint("TOPLEFT", X, -64)
	shop.detail = List(p, RW, 6, 16, { { 120, "RIGHT", "Each" }, { 50, "RIGHT", "Qty" }, { 120, "RIGHT", "Stack" }, { 160, "LEFT", "   Seller" } }, function(item)
		shop.detail.selected = item; shop.detail:Refresh(); shop.jump = nil
		PA.PrepareBuy(item.auction, shop.buyBtn, function(t) shop.status:SetText(t) end)
	end, true)
	shop.detail:SetPoint("TOPLEFT", shop.results, "BOTTOMLEFT", 0, -30)
	shop.buyBtn = Btn(p, "Buy", 200, 24); shop.buyBtn:SetPoint("TOPLEFT", shop.detail, "BOTTOMLEFT", 0, -16); shop.buyBtn:Disable()
	shop.buyBtn:SetScript("OnClick", function()
		if shop.jump then PA.JumpPopup(); return end
		PA.DoBuy(AfterBuy)
	end)
	local again = Btn(p, "Refresh", 80, 24); again:SetPoint("LEFT", shop.buyBtn, "RIGHT", 6, 0)
	again:SetScript("OnClick", function() if shop.current then OpenItem(shop.current, true) end end)
	local toList = Btn(p, "Add item to list", 130, 24); toList:SetPoint("LEFT", again, "RIGHT", 6, 0)
	toList:SetScript("OnClick", function()
		if not shop.current then return end
		local t = { text = shop.current.name, exact = true }
		if shop.list and PA.db.lists[shop.list] then table.insert(PA.db.lists[shop.list], t); shop.RefreshLeft(); Print("added " .. shop.current.name .. " to \"" .. shop.list .. "\".")
		else StaticPopup_Show("PINTSAUCTIONS_NEWLIST", nil, nil, { t }) end
	end)
	p.OnOpen = function()
		if not shop.opened then
			shop.opened = true
			local d = S().defaultList
			if d and d ~= "" and PA.db.lists[d] then shop.list = d; shop.RefreshLeft(); if S().listAutoSearch then RunSearch(PA.db.lists[d]) end end
		end
		shop.RefreshLeft()
	end
end
PA.BuildHost = function() if not host then BuildHost() end end
PA.HostFrame = function() return host end

---------------------------------------------------------------- a list made elsewhere (Pint's Professions' shopping list)
function PA.OpenList(name)
	local terms = PA.db and PA.db.lists[name]
	if not terms then return end
	if AuctionFrame and AuctionFrame:IsShown() and PA.SelectTab then
		PA.SelectTab("shop"); shop.list = name; shop.termSel = nil
		if shop.RefreshLeft then shop.RefreshLeft() end
		if #terms > 0 then RunSearch(terms) end
	end
end
