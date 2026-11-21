-- Pint's Auctions: your shopping lists, anywhere. See every list, how many of each item it wants and how many you
-- already have, add items (type a name, or shift-click an item into the box) and take them off, make or delete lists.
-- At the auction house "Search" runs the list. /pah shop, or "View shopping lists" in Pint's Professions.
local PA = _G.PintsAuctions
if not PA then return end
local Count = (C_Item and C_Item.GetItemCount) or GetItemCount

local W, H, LW, ROW = 520, 380, 170, 20
local f, cur
local lrows, irows = {}, {}

local function Lists() return PA.db and PA.db.lists or {} end
local function Names() local t = {}; for n in pairs(Lists()) do t[#t + 1] = n end; table.sort(t); return t end
local function Btn(parent, text, w, h) local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate"); b:SetSize(w, h or 22); b:SetText(text); return b end
local function Tip(b, t, d)
	b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(t); if d then GameTooltip:AddLine(d, 1, 1, 1, true) end; GameTooltip:Show() end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
local function Plain(t) return (t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h%[?(.-)%]?|h", "%1") end

local Draw
local function Box(parent, w)
	local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	e:SetSize(w, 20); e:SetAutoFocus(false)
	e:SetScript("OnEscapePressed", e.ClearFocus)
	return e
end

local function Build()
	f = CreateFrame("Frame", "PintsAuctionsLists", UIParent, "BackdropTemplate")
	f:SetSize(W, H); f:SetPoint("CENTER", 0, 40); f:SetFrameStrata("HIGH"); f:SetToplevel(true); f:SetClampedToScreen(true)
	f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 } })
	f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
	tinsert(UISpecialFrames, "PintsAuctionsLists")
	local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal"); t:SetPoint("TOPLEFT", 16, -14); t:SetText("|cffd4a017Pint's|r Shopping Lists")
	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -4, -4)
	close:SetScript("OnClick", function() f:Hide() end)

	-- left: the lists
	local lh = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); lh:SetPoint("TOPLEFT", 16, -40); lh:SetText("Lists")
	for i = 1, 13 do
		local b = CreateFrame("Button", nil, f)
		b:SetSize(LW, ROW - 2); b:SetPoint("TOPLEFT", 14, -56 - (i - 1) * ROW)
		b.t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.t:SetPoint("LEFT", 4, 0); b.t:SetWidth(LW - 8); b.t:SetJustifyH("LEFT"); b.t:SetWordWrap(false)
		b.sel = b:CreateTexture(nil, "BACKGROUND"); b.sel:SetAllPoints(); b.sel:SetColorTexture(1, 0.82, 0, 0.18)
		b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		b:SetScript("OnClick", function(self) cur = self.name; Draw() end)
		lrows[i] = b
	end
	f.lup = Btn(f, "^", 22, 18); f.lup:SetPoint("TOPLEFT", 14 + LW - 46, -38); f.lup:SetScript("OnClick", function() f.loff = math.max(0, (f.loff or 0) - 6); Draw() end)
	f.ldn = Btn(f, "v", 22, 18); f.ldn:SetPoint("LEFT", f.lup, "RIGHT", 2, 0); f.ldn:SetScript("OnClick", function() f.loff = (f.loff or 0) + 6; Draw() end)
	local new = Btn(f, "New list", 84, 20); new:SetPoint("BOTTOMLEFT", 14, 16)
	new:SetScript("OnClick", function() StaticPopup_Show("PINTSAUCTIONS_LISTS_NEW") end)
	local del = Btn(f, "Delete", 80, 20); del:SetPoint("LEFT", new, "RIGHT", 4, 0)
	del:SetScript("OnClick", function() if cur then StaticPopup_Show("PINTSAUCTIONS_LISTS_DEL", cur) end end)
	f.del = del

	-- right: what's on it
	local X = 14 + LW + 14
	f.head = f:CreateFontString(nil, "OVERLAY", "GameFontNormal"); f.head:SetPoint("TOPLEFT", X, -38); f.head:SetWidth(W - X - 20); f.head:SetJustifyH("LEFT"); f.head:SetWordWrap(false)
	local c1 = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); c1:SetPoint("TOPLEFT", X + 4, -58); c1:SetText("Item")
	local c2 = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); c2:SetPoint("TOPRIGHT", f, "TOPLEFT", W - 98, -58); c2:SetText("Want")
	local c3 = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); c3:SetPoint("TOPRIGHT", f, "TOPLEFT", W - 52, -58); c3:SetText("Have")
	for i = 1, 11 do
		local r = CreateFrame("Frame", nil, f)
		r:SetSize(W - X - 18, ROW); r:SetPoint("TOPLEFT", X, -72 - (i - 1) * ROW)
		r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(); r.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.03 or 0.07)
		r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.name:SetPoint("LEFT", 4, 0); r.name:SetWidth(W - X - 140); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
		r.want = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.want:SetPoint("RIGHT", r, "LEFT", W - X - 98 - 0, 0)
		r.have = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.have:SetPoint("RIGHT", r, "LEFT", W - X - 52, 0)
		r.x = CreateFrame("Button", nil, r); r.x:SetSize(14, 14); r.x:SetPoint("RIGHT", -4, 0)
		r.x:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up"); r.x:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight", "ADD")
		Tip(r.x, "Take it off the list")
		r.x:SetScript("OnClick", function(self) local l = cur and Lists()[cur]; if l and self.i then table.remove(l, self.i); Draw() end end)
		irows[i] = r
	end
	f.iup = Btn(f, "^", 22, 18); f.iup:SetPoint("TOPRIGHT", -40, -36); f.iup:SetScript("OnClick", function() f.ioff = math.max(0, (f.ioff or 0) - 5); Draw() end)
	f.idn = Btn(f, "v", 22, 18); f.idn:SetPoint("LEFT", f.iup, "RIGHT", 2, 0); f.idn:SetScript("OnClick", function() f.ioff = (f.ioff or 0) + 5; Draw() end)

	-- add an item: a name (or shift-click one into the box) and how many
	f.addName = Box(f, 190); f.addName:SetPoint("BOTTOMLEFT", X + 6, 44)
	local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); hint:SetPoint("BOTTOMLEFT", f.addName, "TOPLEFT", -4, 2); hint:SetText("Add: item name (or shift-click an item), how many")
	f.addQty = Box(f, 40); f.addQty:SetPoint("LEFT", f.addName, "RIGHT", 8, 0); f.addQty:SetNumeric(true)
	local add = Btn(f, "Add", 60, 20); add:SetPoint("LEFT", f.addQty, "RIGHT", 6, 0)
	local function Add()
		local l = cur and Lists()[cur]
		local name = strtrim(Plain(f.addName:GetText()))
		if not l or name == "" then return end
		local q = tonumber(f.addQty:GetText() or "")
		for _, t in ipairs(l) do
			if (t.text or ""):lower() == name:lower() then t.qty = q and ((t.qty or 0) + q) or t.qty; f.addName:SetText(""); f.addQty:SetText(""); Draw(); return end
		end
		l[#l + 1] = { text = name, exact = true, qty = q }
		f.addName:SetText(""); f.addQty:SetText(""); f.addName:ClearFocus(); f.addQty:ClearFocus()
		Draw()
	end
	add:SetScript("OnClick", Add)
	f.addName:SetScript("OnEnterPressed", Add); f.addQty:SetScript("OnEnterPressed", Add)
	f.addName:SetScript("OnTabPressed", function() f.addQty:SetFocus() end); f.addQty:SetScript("OnTabPressed", function() f.addName:SetFocus() end)
	f.add = add
	-- at the auction house: search for it
	local go = Btn(f, "Search at the auction house", 190, 20); go:SetPoint("BOTTOMLEFT", X + 2, 16)
	go:SetScript("OnClick", function() if cur and PA.OpenList then PA.OpenList(cur) end end)
	Tip(go, "Search at the auction house", "Runs this list on the Shopping tab. Open the auction house first.")
	f.go = go
	f.note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); f.note:SetPoint("LEFT", go, "RIGHT", 8, 0); f.note:SetWidth(W - X - 210); f.note:SetJustifyH("LEFT")
	f:RegisterEvent("BAG_UPDATE_DELAYED")
	f:SetScript("OnEvent", function() if f:IsShown() then Draw() end end)
	f:Hide()
end

-- shift-clicking an item while the add box has the cursor puts its name there
hooksecurefunc("ChatEdit_InsertLink", function(link)
	if f and f:IsShown() and f.addName:HasFocus() and type(link) == "string" then
		local name = link:match("%[(.-)%]"); if name then f.addName:SetText(name) end
	end
end)

Draw = function()
	if not f then return end
	local names = Names()
	if cur and not Lists()[cur] then cur = nil end
	if not cur then cur = names[1] end
	local lo = math.min(f.loff or 0, math.max(0, #names - #lrows)); f.loff = lo
	for i, b in ipairs(lrows) do
		local n = names[lo + i]
		if n then b.name = n; b.t:SetText(n .. "  |cff888888(" .. #Lists()[n] .. ")|r"); b.sel:SetShown(n == cur); b:Show() else b:Hide() end
	end
	f.lup:SetShown(lo > 0); f.ldn:SetShown(lo + #lrows < #names)
	local l = cur and Lists()[cur]
	f.head:SetText(cur or "|cff888888No shopping lists yet - New list makes one|r")
	f.del:SetEnabled(cur ~= nil); f.add:SetEnabled(cur ~= nil); f.go:SetEnabled(cur ~= nil)
	local items = l or {}
	local io = math.min(f.ioff or 0, math.max(0, #items - #irows)); f.ioff = io
	local short = 0
	for i, r in ipairs(irows) do
		local t = items[io + i]
		if t then
			local have = Count(t.text or "", true) or 0
			r.name:SetText(t.text or "?")
			r.want:SetText(t.qty and tostring(t.qty) or "|cff888888any|r")
			r.have:SetText(have > 0 and ((t.qty and have >= t.qty) and ("|cff40ff40" .. have .. "|r") or tostring(have)) or "|cff6060600|r")
			r.x.i = io + i
			r:Show()
		else r:Hide() end
	end
	for _, t in ipairs(items) do if t.qty and (Count(t.text or "", true) or 0) < t.qty then short = short + 1 end end
	f.iup:SetShown(io > 0); f.idn:SetShown(io + #irows < #items)
	f.note:SetText(#items == 0 and "" or (short > 0 and ("%d still to buy"):format(short) or "|cff40ff40got everything|r"))
end

StaticPopupDialogs["PINTSAUCTIONS_LISTS_NEW"] = {
	text = "Name the new shopping list:", button1 = ACCEPT, button2 = CANCEL, hasEditBox = true, timeout = 0, whileDead = true, hideOnEscape = true,
	OnAccept = function(self)
		local eb = self.editBox or self.EditBox
		local n = eb and strtrim(eb:GetText() or "")
		if n and n ~= "" then PA.db.lists[n] = PA.db.lists[n] or {}; cur = n; Draw() end
	end,
	EditBoxOnEnterPressed = function(self) local p = self:GetParent(); StaticPopupDialogs["PINTSAUCTIONS_LISTS_NEW"].OnAccept(p); p:Hide() end,
}
StaticPopupDialogs["PINTSAUCTIONS_LISTS_DEL"] = {
	text = "Delete the shopping list \"%s\"?", button1 = YES, button2 = NO, timeout = 0, whileDead = true, hideOnEscape = true,
	OnAccept = function() if cur then PA.db.lists[cur] = nil; cur = nil; Draw() end end,
}

function PA.ShowLists(name)
	if not (PA.db and PA.db.lists) then return end
	if not f then Build() end
	if name and PA.db.lists[name] then cur = name; f.ioff = 0 end
	f:Show(); Draw()
end
function PA.ToggleLists(name) if f and f:IsShown() and not name then f:Hide() else PA.ShowLists(name) end end
