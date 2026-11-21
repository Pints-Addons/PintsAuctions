-- Pint's Auctions - the Selling tab: your bags on the left, price and post on the right, who else is selling below.
local ADDON, NS = ...
-- Compatibility: WoW Forever runs on the modern game client, where these older functions moved or were renamed.
local GetItemInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)

local PA = NS.PA
local Print, Money = PA.Print, PA.Money
local ME = UnitName("player")
local function S() return PA.S end
-- WoW Forever's auction house is the modern one: selling there is in Modern.lua
if not GetAuctionSellItemInfo then return end

local sell = { bags = {}, idx = nil }
PA.sell = sell
local DUR = { { 1, "2 hours" }, { 2, "8 hours" }, { 3, "24 hours" } }

---------------------------------------------------------------- your bags
local function IsBound(bag, slot, info)
	if info.isBound ~= nil then return info.isBound end
	if C_Item and C_Item.IsBound and ItemLocation and ItemLocation.CreateFromBagAndSlot then
		local ok, b = pcall(C_Item.IsBound, ItemLocation:CreateFromBagAndSlot(bag, slot))
		if ok then return b end
	end
	return false
end
local function ScanBags()
	local by, out = {}, {}
	local NumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
	for bag = 0, 4 do
		for slot = 1, (NumSlots(bag) or 0) do
			local info = C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
			if info and info.hyperlink and not IsBound(bag, slot, info) then
				local key = PA.Key(info.hyperlink)
				local g = by[key]
				if not g then
					local name, _, quality, _, _, _, _, maxStack, equipLoc, _, vendor = GetItemInfo(info.hyperlink)
					g = { key = key, link = info.hyperlink, name = name or info.hyperlink:match("%[(.-)%]") or "?", texture = info.iconFileID, quality = quality or info.quality,
						count = 0, bag = bag, slot = slot, itemID = info.itemID, maxStack = maxStack or 1, gear = equipLoc and equipLoc ~= "", vendor = vendor or 0 }
					by[key] = g; out[#out + 1] = g
				end
				g.count = g.count + (info.stackCount or 1)
				if info.isLocked then g.locked = true end
				-- prefer a slot that isn't locked
				if g.locked and not info.isLocked then g.bag, g.slot = bag, slot end
			end
		end
	end
	table.sort(out, function(a, b) return a.name < b.name end)
	sell.bags = out
	return out
end
local function RefreshBags()
	if not sell.bagList then return end
	local data = {}
	for i, g in ipairs(sell.bags) do
		local p = PA.Price(g.link)
		data[i] = { "|cff" .. ({ [0] = "9d9d9d", "ffffff", "1eff00", "0070dd", "a335ee", "ff8000" })[g.quality or 1] .. g.name .. "|r", g.count, p and Money(p, true) or "|cff666666-|r",
			texture = g.texture, link = g.link, key = g.key, g = g, i = i }
	end
	sell.bagList.selectedKey = sell.key
	sell.bagList:Set(data, true)
end

---------------------------------------------------------------- the item in the auction slot
local function SellInfo()
	local name, texture, count, quality, _, vendor, _, stackCount, totalCount, itemID = GetAuctionSellItemInfo()
	if not name then return end
	return { name = name, texture = texture, count = count or 1, quality = quality, max = stackCount or count or 1, total = totalCount or count or 1, itemID = itemID, vendor = vendor }
end
PA.SellInfo = SellInfo
local function Undercut(p)
	if not p then return nil end
	local v
	if S().undercutMode == "pct" then v = math.floor(p * (1 - (S().undercutPct or 0) / 100))
	else v = p - (S().undercut or 0) end
	return math.max(1, math.floor(v))
end
local function Deposit(dur, bid, buyout, stack, num)
	if GetAuctionDeposit then local ok, d = pcall(GetAuctionDeposit, dur, bid, buyout, stack, num); if ok and d then return d end end
	if CalculateAuctionDeposit then local ok, d = pcall(CalculateAuctionDeposit, dur, stack, num); if ok and d then return d end end
	return 0
end
local function Numbers()
	local info = SellInfo()
	if not info then return end
	local unit = sell.unit:Get()
	local stack = math.max(1, tonumber(sell.stack:GetText()) or info.count)
	local num = math.max(1, tonumber(sell.num:GetText()) or 1)
	local buyout = unit and unit * stack
	local bid = buyout
	if buyout and S().useBid then
		bid = sell.bid:Get() or math.floor(buyout * (S().bidPct or 0.95))
		bid = math.max(1, math.min(bid, buyout))
	end
	return info, unit, stack, num, bid, buyout
end
local function Totals()
	local info, unit, stack, num, bid, buyout = Numbers()
	sell.bidRow:SetShown(S().useBid)
	if not info then sell.post:Disable(); sell.deposit:SetText(""); sell.total:SetText(""); sell.warn:SetText(""); return end
	local okStacks = stack * num <= info.total and stack <= (info.max or stack)
	if not unit or unit <= 0 then sell.post:Disable(); sell.deposit:SetText(""); sell.total:SetText(""); sell.warn:SetText("|cffffd100Set a price.|r"); return end
	local dep = Deposit(sell.dur, bid, buyout, stack, num)
	sell.deposit:SetText("Deposit:  " .. Money(dep))
	sell.total:SetText(("Total:  %s  |cffaaaaaa(%d x %s)|r"):format(Money(buyout * num), num, Money(buyout)))
	local typical = PA.Typical(info.itemID) or PA.Price(info.itemID)
	sell.low = S().confirmLow and typical and unit < typical * (S().lowWarn or 0.5)
	local warn = ""
	if not okStacks then warn = "|cffff4040You don't have " .. stack * num .. " to post.|r"
	elseif sell.low then warn = "|cffff4040Well under the usual " .. Money(typical) .. " each - " .. (sell.confirm and "post again to confirm." or "Post twice to confirm.") .. "|r" end
	sell.warn:SetText(warn)
	local canPay = GetMoney() >= dep
	sell.post:SetEnabled(okStacks and (canPay or not S().greyPost))
	sell.post:SetText(sell.confirm and "Confirm post" or "Post")
end
PA.SellTotals = Totals

local function SetUnit(v)
	sell.unit:Set(v)
	local stack = tonumber(sell.stack:GetText()) or 1
	sell.stackPrice:Set(v and v * stack)
	if S().useBid then sell.bid:Set(v and math.floor(v * stack * (S().bidPct or 0.95))) end
	Totals()
end

-- look up who's selling it now and suggest a price
local function PriceCheck(info)
	sell.current:Set({}); sell.status:SetText("Checking current prices...")
	local seen = {}
	local key = sell.key
	PA.CancelSearches()
	PA.Search({ text = info.name, exact = true, maxPages = 5,
		onRow = function(r)
			if r.name == info.name and (not key or not key:find(":") or PA.Key(r.link) == key) then seen[#seen + 1] = r end
		end,
		onDone = function()
			if SellInfo() == nil or SellInfo().name ~= info.name then return end
			local function U(r) return r.buyout > 0 and r.buyout / r.count or math.huge end
			table.sort(seen, function(a, b) return U(a) < U(b) end)
			local rows, lowest, mine = {}, nil, nil
			for _, r in ipairs(seen) do
				local own = r.owner == ME
				if r.buyout > 0 then if own then mine = mine or U(r) elseif not lowest then lowest = U(r) end end
				rows[#rows + 1] = { r.buyout > 0 and Money(U(r)) or "|cff888888bid|r", r.count, r.buyout > 0 and Money(r.buyout) or Money(r.minBid), own and "|cff40ff40you|r" or (r.owner or "?"), auction = r }
			end
			sell.current:Set(rows)
			if lowest then PA.Record(PA.Key(seen[1].link) or tostring(info.itemID), math.floor(lowest + 0.5)) end
			local suggest
			if lowest then suggest = (mine and mine <= lowest) and math.floor(mine) or Undercut(math.floor(lowest))
			elseif mine then suggest = math.floor(mine)
			else
				suggest = PA.Price(info.itemID)
				if not suggest and (info.vendor or 0) > 0 then suggest = math.floor(info.vendor / math.max(1, info.count) * (S().gearMult or 3)) end
			end
			local n = 0; for _, r in ipairs(seen) do n = n + r.count end
			sell.status:SetText(#seen > 0 and (n .. " on sale in " .. #seen .. " auctions" .. (lowest and (", cheapest " .. Money(lowest) .. " each") or "")) or "Nobody else is selling it right now.")
			if sell.autoPrice then SetUnit(suggest) end
		end })
end

function PA.SellLoaded()
	if not sell.unit then return end
	local info = SellInfo()
	sell.confirm = false
	if not info then
		sell.icon:SetTexture(nil); sell.name:SetText("|cff888888Pick an item from your bags on the left|r"); sell.status:SetText("")
		sell.current:Set({}); sell.unit:Set(nil); sell.stackPrice:Set(nil); Totals()
		return
	end
	-- which bag row is it?
	local g = sell.idx and sell.bags[sell.idx]
	if not (g and g.itemID == info.itemID) then
		g = nil
		for i, b in ipairs(sell.bags) do if b.itemID == info.itemID then g = b; sell.idx = i; break end end
	end
	sell.key = g and g.key or tostring(info.itemID)
	RefreshBags()
	sell.icon:SetTexture(info.texture)
	sell.name:SetText("|cff" .. ({ [0] = "9d9d9d", "ffffff", "1eff00", "0070dd", "a335ee", "ff8000" })[info.quality or 1] .. info.name .. "|r  |cffaaaaaa(" .. info.total .. " in bags)|r")
	local maxStack = select(8, GetItemInfo(info.itemID)) or info.max or info.count
	local stack, num
	if S().stackMode == "ones" then stack, num = 1, info.total
	elseif S().stackMode == "single" then stack, num = info.count, 1
	else stack = math.min(maxStack, info.total); num = math.max(1, math.floor(info.total / stack)) end
	sell.stack:SetText(tostring(stack)); sell.num:SetText(tostring(num))
	sell.autoPrice = true
	SetUnit(nil)
	PriceCheck(info)
end

local function Select(i)
	local g = sell.bags[i]
	if not g then return end
	sell.idx, sell.key = i, g.key
	RefreshBags()
	if InCombatLockdown and InCombatLockdown() then return end
	ClearCursor()
	C_Container.PickupContainerItem(g.bag, g.slot)
	ClickAuctionSellItemButton()
	ClearCursor()
end
PA.SellSelect = Select
function PA.SellSkip(d)
	if #sell.bags == 0 then return end
	local i = (sell.idx or 0) + d
	if i < 1 then i = #sell.bags elseif i > #sell.bags then i = 1 end
	Select(i)
end

-- after a post: carry on with the same item if any are left, otherwise the next one down
local function AfterPost()
	sell.posting = nil
	C_Timer.After(0.4, function()
		local key, idx = sell.key, sell.idx or 1
		ScanBags(); RefreshBags()
		if PA.page ~= "sell" then return end
		if SellInfo() or not S().autoNext then PA.SellLoaded(); return end
		for i, g in ipairs(sell.bags) do if g.key == key then Select(i); return end end
		if sell.bags[idx] then Select(idx) else PA.SellLoaded() end
	end)
end
function PA.SellPost()
	local info, unit, stack, num, bid, buyout = Numbers()
	if not info or not unit or sell.posting or not sell.post:IsEnabled() then return end
	if sell.low and not sell.confirm then sell.confirm = true; Totals(); return end
	PostAuction(bid, buyout, sell.dur, stack, num)
	sell.confirm = false
	sell.posting = { num = num, at = GetTime() }
	if S().rememberDur then S().duration = sell.dur end
	PA.Record(sell.key or tostring(info.itemID), unit)
	if S().chatPosts then Print(("posted %d x %d %s at %s each (%s)."):format(num, stack, info.name, Money(unit), DUR[sell.dur][2])) end
	local guard = sell.posting
	C_Timer.After(2 + num * 1.5, function() if sell.posting == guard then AfterPost() end end)
end

local function CancelOwn(r)
	for i = 1, (GetNumAuctionItems("owner")) do
		local name, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, saleStatus = GetAuctionItemInfo("owner", i)
		if name == r.name and count == r.count and buyout == r.buyout and saleStatus ~= 1 then
			CancelAuction(i)
			Print(("cancelled %d %s."):format(count, name))
			return true
		end
	end
	Print("couldn't find that one in your auctions - try Refresh.")
end

---------------------------------------------------------------- building the tab
function PA.BuildSell(p)
	local Label, Btn, Edit, Tip, List, MoneyBox = PA.Label, PA.Btn, PA.Edit, PA.Tip, PA.List, PA.MoneyBox
	local LW = 240
	sell.bagList = List(p, LW, 21, 16, { { 122, "LEFT", "Your bags" }, { 30, "RIGHT", "Qty" }, { 70, "RIGHT", "Price" } }, function(item) Select(item.i) end)
	sell.bagList:SetPoint("TOPLEFT", 0, -16)

	local X = LW + 14
	local slot = CreateFrame("Button", nil, p, "BackdropTemplate"); slot:SetSize(38, 38); slot:SetPoint("TOPLEFT", X, 0)
	slot:SetBackdrop({ bgFile = "Interface\\Buttons\\UI-Slot-Background", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	slot:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
	sell.icon = slot:CreateTexture(nil, "ARTWORK"); sell.icon:SetPoint("TOPLEFT", 2, -2); sell.icon:SetPoint("BOTTOMRIGHT", -2, 2)
	local function take() ClickAuctionSellItemButton(); ClearCursor() end
	slot:SetScript("OnReceiveDrag", take); slot:SetScript("OnClick", take)
	Tip(slot, "Item to sell", "Pick one from the list, drop one here, or Alt-click one in your bags. Click to take it back.")
	sell.name = Label(p, "", "GameFontHighlight"); sell.name:SetPoint("TOPLEFT", slot, "TOPRIGHT", 8, -3); sell.name:SetWidth(440); sell.name:SetJustifyH("LEFT")
	sell.status = Label(p, "", "GameFontDisableSmall"); sell.status:SetPoint("TOPLEFT", slot, "TOPRIGHT", 8, -22); sell.status:SetWidth(440); sell.status:SetJustifyH("LEFT")

	local y = -48
	local l1 = Label(p, "Unit price"); l1:SetPoint("TOPLEFT", X, y - 4)
	sell.unit = MoneyBox(p, function(user)
		if not user then return end
		sell.autoPrice, sell.confirm = false, false
		local u = sell.unit:Get(); local st = tonumber(sell.stack:GetText()) or 1
		sell.stackPrice:Set(u and u * st); Totals()
	end)
	sell.unit:SetPoint("TOPLEFT", X + 64, y)
	local l2 = Label(p, "Stack price"); l2:SetPoint("TOPLEFT", X + 262, y - 4)
	sell.stackPrice = MoneyBox(p, function(user)
		if not user then return end
		sell.autoPrice, sell.confirm = false, false
		local v = sell.stackPrice:Get(); local st = tonumber(sell.stack:GetText()) or 1
		sell.unit:Set(v and math.floor(v / math.max(1, st))); Totals()
	end)
	sell.stackPrice:SetPoint("TOPLEFT", X + 330, y)

	y = y - 28
	local l3 = Label(p, "Stacks"); l3:SetPoint("TOPLEFT", X, y - 4)
	sell.num = Edit(p, 34, true); sell.num:SetPoint("TOPLEFT", X + 70, y)
	local l4 = Label(p, "of"); l4:SetPoint("LEFT", sell.num, "RIGHT", 6, 0)
	sell.stack = Edit(p, 34, true); sell.stack:SetPoint("LEFT", l4, "RIGHT", 10, 0)
	local mx = Btn(p, "Max", 44, 20); mx:SetPoint("LEFT", sell.stack, "RIGHT", 6, 0)
	mx:SetScript("OnClick", function()
		local info = SellInfo(); if not info then return end
		local st = tonumber(sell.stack:GetText()) or info.count
		sell.num:SetText(tostring(math.max(1, math.floor(info.total / math.max(1, st)))))
	end)
	Tip(mx, "Max stacks", "As many stacks of this size as you have.")
	sell.num:SetScript("OnTextChanged", function() sell.confirm = false; Totals() end)
	sell.stack:SetScript("OnTextChanged", function()
		sell.confirm = false
		local u = sell.unit:Get(); local st = tonumber(sell.stack:GetText()) or 1
		sell.stackPrice:Set(u and u * st); Totals()
	end)
	local l5 = Label(p, "Duration"); l5:SetPoint("TOPLEFT", X + 262, y - 4)
	sell.durBtns = {}
	local dx = X + 320
	for k, d in ipairs(DUR) do
		local c = CreateFrame("CheckButton", nil, p, "UIRadioButtonTemplate"); c:SetSize(16, 16); c:SetPoint("TOPLEFT", dx, y - 2)
		local t = Label(c, d[2]); t:SetPoint("LEFT", c, "RIGHT", 2, 0)
		c:SetScript("OnClick", function() sell.dur = d[1]; for kk, cc in ipairs(sell.durBtns) do cc:SetChecked(kk == k) end; Totals() end)
		sell.durBtns[k] = c; dx = dx + 66
	end

	y = y - 28
	sell.bidRow = CreateFrame("Frame", nil, p); sell.bidRow:SetSize(250, 20); sell.bidRow:SetPoint("TOPLEFT", X, y)
	local l6 = Label(sell.bidRow, "Stack bid"); l6:SetPoint("LEFT", 0, 0)
	sell.bid = MoneyBox(sell.bidRow, function(user) if user then Totals() end end); sell.bid:SetPoint("LEFT", 64, 0)
	sell.deposit = Label(p, ""); sell.deposit:SetPoint("TOPLEFT", X + 262, y - 4)
	sell.total = Label(p, ""); sell.total:SetPoint("TOPLEFT", X + 262, y - 20)
	sell.warn = Label(p, ""); sell.warn:SetPoint("TOPLEFT", X, y - 40); sell.warn:SetWidth(500); sell.warn:SetJustifyH("LEFT")

	y = y - 60
	sell.post = Btn(p, "Post", 120, 26); sell.post:SetPoint("TOPLEFT", X, y)
	sell.post:SetScript("OnClick", PA.SellPost)
	Tip(sell.post, "Post", "Space posts too (when not typing). Shift-Space skips to the next item, Backspace goes back.")
	local skip = Btn(p, "Skip", 60, 26); skip:SetPoint("LEFT", sell.post, "RIGHT", 6, 0)
	skip:SetScript("OnClick", function() PA.SellSkip(1) end)
	local again = Btn(p, "Check prices", 100, 26); again:SetPoint("LEFT", skip, "RIGHT", 6, 0)
	again:SetScript("OnClick", function() local i = SellInfo(); if i then PriceCheck(i) end end)

	sell.current = List(p, 762 - X, 7, 16, { { 120, "RIGHT", "Unit price" }, { 60, "RIGHT", "Available" }, { 120, "RIGHT", "Stack price" }, { 150, "LEFT", "   Seller" } }, function(item)
		sell.current.selected = item; sell.current:Refresh()
		local r = item.auction
		sell.cancelBtn:SetEnabled(r.owner == ME)
		if r.owner == ME then sell.buyBtn:Disable() else PA.PrepareBuy(r, sell.buyBtn, function(t) sell.status:SetText(t) end) end
	end, true)
	sell.current:SetPoint("TOPLEFT", X, y - 52)
	sell.buyBtn = Btn(p, "Buy", 150, 22); sell.buyBtn:SetPoint("TOPLEFT", sell.current, "BOTTOMLEFT", 0, -16); sell.buyBtn:Disable()
	sell.buyBtn:SetScript("OnClick", function() PA.DoBuy(function() local i = SellInfo(); if i then PriceCheck(i) end end) end)
	sell.cancelBtn = Btn(p, "Cancel auction", 110, 22); sell.cancelBtn:SetPoint("LEFT", sell.buyBtn, "RIGHT", 6, 0); sell.cancelBtn:Disable()
	sell.cancelBtn:SetScript("OnClick", function()
		local it = sell.current.selected
		if it and CancelOwn(it.auction) then sell.cancelBtn:Disable(); C_Timer.After(0.8, function() local i = SellInfo(); if i then PriceCheck(i) end end) end
	end)
	local hist = Btn(p, "History", 80, 22); hist:SetPoint("LEFT", sell.cancelBtn, "RIGHT", 6, 0)
	-- price history: shown in a tooltip that goes away when you move off the button or click it again
	hist:SetScript("OnClick", function(self)
		if GameTooltip:IsOwned(self) and GameTooltip:IsShown() then GameTooltip:Hide(); return end
		local info = SellInfo(); if not info then return end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Lowest price by day: " .. info.name, 1, 0.82, 0)
		local n = 0
		for i, h in ipairs(PA.History(sell.key or info.itemID)) do
			if i > 14 then break end
			GameTooltip:AddDoubleLine(h[3] == 0 and "today" or (h[3] .. (h[3] == 1 and " day ago" or " days ago")), Money(h[2]), 1, 1, 1, 1, 1, 1)
			n = n + 1
		end
		if n == 0 then GameTooltip:AddLine("nothing seen yet", 0.55, 0.55, 0.55) end
		GameTooltip:Show()
	end)
	hist:HookScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)

	p.OnOpen = function()
		sell.dur = sell.dur or S().duration or 3
		for k, c in ipairs(sell.durBtns) do c:SetChecked(DUR[k][1] == sell.dur) end
		if GetOwnerAuctionItems then GetOwnerAuctionItems() end
		ScanBags(); RefreshBags()
		PA.SellLoaded()
	end
end

---------------------------------------------------------------- events
local ev = CreateFrame("Frame")
ev:RegisterEvent("NEW_AUCTION_UPDATE"); ev:RegisterEvent("BAG_UPDATE_DELAYED"); ev:RegisterEvent("AUCTION_HOUSE_SHOW")
ev:RegisterEvent("AUCTION_MULTISELL_UPDATE"); ev:RegisterEvent("AUCTION_MULTISELL_FAILURE")
ev:SetScript("OnEvent", function(_, e, a1, a2)
	if e == "AUCTION_HOUSE_SHOW" then
		sell.dur = S().duration or 3     -- a fresh visit starts on the default duration
		return
	end
	if not (PA.HostShown() and PA.page == "sell") then return end
	if e == "NEW_AUCTION_UPDATE" then
		local info = SellInfo()
		if sell.posting and not info and sell.posting.num == 1 then AfterPost() end
		if not sell.posting then PA.SellLoaded() end
	elseif e == "AUCTION_MULTISELL_UPDATE" then
		if sell.posting and a1 and a2 and a1 >= a2 then AfterPost() end
	elseif e == "AUCTION_MULTISELL_FAILURE" then
		if sell.posting then AfterPost() end
	elseif e == "BAG_UPDATE_DELAYED" then
		if not sell.posting then ScanBags(); RefreshBags() end
	end
end)
