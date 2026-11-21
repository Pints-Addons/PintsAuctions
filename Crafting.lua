-- Pint's Auctions - crafting: beside the profession window, what the reagents cost, what the result sells for, and the profit.
local ADDON, NS = ...
local PA = NS.PA
local Money = PA.Money
local function S() return PA.S end

local API = {
	trade = { frame = "TradeSkillFrame", sel = "GetTradeSkillSelectionIndex", info = "GetTradeSkillInfo", num = "GetTradeSkillNumReagents",
		reagent = "GetTradeSkillReagentInfo", rlink = "GetTradeSkillReagentItemLink", link = "GetTradeSkillItemLink", made = "GetTradeSkillNumMade", hook = "TradeSkillFrame_SetSelection" },
	craft = { frame = "CraftFrame", sel = "GetCraftSelectionIndex", info = "GetCraftInfo", num = "GetCraftNumReagents",
		reagent = "GetCraftReagentInfo", rlink = "GetCraftReagentItemLink", link = "GetCraftItemLink", hook = "CraftFrame_SetSelection" },
}
local boxes = {}

local function Read(kind)
	local a = API[kind]
	local F = function(n, ...) local f = _G[a[n]]; if f then return f(...) end end
	local i = F("sel")
	if not i or i == 0 then return end
	local name, kindOf = F("info", i)
	if not name or kindOf == "header" then return end
	local out = { name = name, reagents = {}, cost = 0, missing = false }
	for r = 1, (F("num", i) or 0) do
		local rname, tex, need, have = F("reagent", i, r)
		local link = F("rlink", i, r)
		local each = link and PA.Price(link)
		out.reagents[#out.reagents + 1] = { name = rname, texture = tex, need = need or 1, have = have or 0, link = link, each = each }
		if each then out.cost = out.cost + each * (need or 1) else out.missing = true end
	end
	local link = F("link", i)
	if link and link:find("item:") then
		local lo, hi = 1, 1
		if a.made then lo, hi = F("made", i); lo, hi = lo or 1, hi or lo or 1 end
		out.makes = (lo + hi) / 2
		local p = PA.Price(link)
		if p then out.value = p * out.makes end
	end
	return out
end

local function Box(kind)
	if boxes[kind] then return boxes[kind] end
	local parent = _G[API[kind].frame]
	if not parent then return end
	local b = CreateFrame("Frame", "PintsAuctionsCraft_" .. kind, parent, "BackdropTemplate")
	b:SetWidth(230)
	b:SetPoint("TOPLEFT", parent, "TOPRIGHT", -34, -74)
	b:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
	b:SetBackdropColor(0, 0, 0, 0.85)
	b.title = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); b.title:SetPoint("TOPLEFT", 10, -10); b.title:SetWidth(210); b.title:SetJustifyH("LEFT")
	b.lines = {}
	b.find = PA.Btn(b, "Create Shopping List", 150, 20); b.find:SetPoint("BOTTOMLEFT", 8, 8)
	b.find:SetScript("OnClick", function()
		local d = b.data; if not d then return end
		local name = d.name
		local made = false
		if PA.db.lists[name] then
			PA.Print("there's already a shopping list called \"" .. name .. "\".")
		else
			local terms = {}
			for _, r in ipairs(d.reagents) do if r.name then terms[#terms + 1] = { text = r.name, exact = true } end end
			PA.db.lists[name] = terms; made = true
			PA.Print("made the shopping list \"" .. name .. "\" (" .. #terms .. " reagent" .. (#terms == 1 and "" or "s") .. ").")
		end
		-- at the auction house: open it on the Shopping tab
		if AuctionFrame and AuctionFrame:IsShown() and PA.SelectTab and PA.ShowList then PA.SelectTab("shop"); PA.ShowList(name) end
	end)
	PA.Tip(b.find, "Create Shopping List", "Makes a shopping list named after this recipe with its reagents (unless one by that name already exists). Find it on the auction house's Shopping tab.")
	boxes[kind] = b
	return b
end

local function Line(b, i)
	local l = b.lines[i]
	if not l then
		l = { left = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"), right = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall") }
		l.left:SetPoint("TOPLEFT", 10, -26 - (i - 1) * 14); l.left:SetWidth(120); l.left:SetJustifyH("LEFT"); l.left:SetWordWrap(false)
		l.right:SetPoint("TOPRIGHT", -10, -26 - (i - 1) * 14); l.right:SetJustifyH("RIGHT")
		b.lines[i] = l
	end
	l.left:Show(); l.right:Show()
	return l
end

-- a Pint's Auctions button in the profession window's header shows / hides the panel
local toggles = {}
local Update
local function Toggle(kind)
	if toggles[kind] then return toggles[kind] end
	local parent = _G[API[kind].frame]
	if not parent then return end
	local t = CreateFrame("Button", "PintsAuctionsCraftToggle_" .. kind, parent)
	t:SetSize(22, 22); t:SetFrameLevel(parent:GetFrameLevel() + 10)
	local close = _G[API[kind].frame .. "CloseButton"] or parent.CloseButton
	if close then t:SetPoint("RIGHT", close, "LEFT", -2, 0) else t:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -62, -14) end
	t.icon = t:CreateTexture(nil, "ARTWORK"); t.icon:SetAllPoints(); t.icon:SetTexture("Interface\\AddOns\\PintsAuctions\\Icon")
	t.ring = t:CreateTexture(nil, "OVERLAY"); t.ring:SetPoint("TOPLEFT", -2, 2); t.ring:SetPoint("BOTTOMRIGHT", 2, -2)
	t.ring:SetTexture("Interface\\Buttons\\UI-Quickslot2"); t.ring:SetTexCoord(0.2, 0.8, 0.2, 0.8)
	t:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	t:SetScript("OnClick", function()
		S().craftHide = not S().craftHide
		Update("trade"); Update("craft")
	end)
	t:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine("|cffd4a017Pint's|r Auctions")
		GameTooltip:AddLine(S().craftHide and "Click to show reagent costs and profit" or "Click to hide reagent costs and profit", 1, 1, 1)
		GameTooltip:Show()
	end)
	t:SetScript("OnLeave", function() GameTooltip:Hide() end)
	toggles[kind] = t
	return t
end

Update = function(kind)
	if not S() then return end
	local b = Box(kind)
	if not b then return end
	local t = Toggle(kind)
	if t then t.icon:SetDesaturated(S().craftHide and true or false); t.icon:SetAlpha(S().craftHide and 0.6 or 1) end
	if S().craftHide or not (S().craftCost or S().craftProfit) then b:Hide(); return end
	local d = Read(kind)
	b.data = d
	if not d then b:Hide(); return end
	b.title:SetText(d.name)
	local n = 0
	local function add(l, r) n = n + 1; local x = Line(b, n); x.left:SetText(l); x.right:SetText(r) end
	if S().craftCost then
		for _, r in ipairs(d.reagents) do
			add(("%dx %s"):format(r.need, r.name or "?"), r.each and Money(r.each * r.need) or "|cff888888no price|r")
		end
		add("|cffffd100Reagents|r", Money(d.cost) .. (d.missing and "|cff888888+?|r" or ""))
	end
	if S().craftProfit then
		if d.makes then
			add("|cffffd100Sells for|r" .. (d.makes ~= 1 and (" |cff888888(x" .. d.makes .. ")|r") or ""), d.value and Money(d.value) or "|cff888888no price|r")
			if d.value then
				local p = d.value - d.cost
				add("|cffffd100Profit|r", (p >= 0 and "" or "|cffff4040-|r") .. Money(math.abs(p)) .. (d.missing and "|cff888888?|r" or ""))
			end
		else
			add("|cff888888Makes no item to sell|r", "")
		end
	end
	for i = n + 1, #b.lines do b.lines[i].left:Hide(); b.lines[i].right:Hide() end
	b:SetHeight(26 + n * 14 + 36)
	b:Show()
end

local hooked = {}
local function Hook(kind)
	local a = API[kind]
	if hooked[kind] or not _G[a.hook] then return end
	hooked[kind] = true
	hooksecurefunc(a.hook, function() Update(kind) end)
	local f = _G[a.frame]
	if f then f:HookScript("OnShow", function() C_Timer.After(0, function() Update(kind) end) end) end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED"); ev:RegisterEvent("PLAYER_LOGIN"); pcall(ev.RegisterEvent, ev, "TRADE_SKILL_UPDATE"); pcall(ev.RegisterEvent, ev, "CRAFT_UPDATE")
ev:SetScript("OnEvent", function(_, e, a1)
	if e == "ADDON_LOADED" or e == "PLAYER_LOGIN" then
		Hook("trade"); Hook("craft")
	elseif e == "TRADE_SKILL_UPDATE" then if hooked.trade then Update("trade") end
	elseif e == "CRAFT_UPDATE" then if hooked.craft then Update("craft") end
	end
end)
