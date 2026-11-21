-- Pint's Auctions: Waylaid Crates (WoW Forever). Every Waylaid Supply Crate, the cheapest way to fill each one at your
-- auction house's prices (counting what you already have), the Merchant's Favor it brings, and a Buy button that opens
-- the cheapest thing still to buy in the auction house's Buy view. Filters: every crate, the crates in your bags, and
-- crates you already have the goods for (worth buying the empty crate for).
-- Crates and their bundles: from Wowhead's WoW Forever database (November 2026); a crate in your bags is also read from
-- its own tooltip, so a change the game makes shows up.
local ADDON, NS = ...
local PA = NS.PA
if not (PA and C_AuctionHouse) or QueryAuctionItems then return end

local GII = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local Count = (C_Item and C_Item.GetItemCount) or GetItemCount

-- the goods crates take: name -> item number
local ID = {
	["Peacebloom"] = 2447, ["Silverleaf"] = 765, ["Earthroot"] = 2449, ["Mageroyal"] = 785, ["Briarthorn"] = 2450,
	["Stranglekelp"] = 3820, ["Bruiseweed"] = 2453, ["Wild Steelbloom"] = 3355, ["Grave Moss"] = 3369, ["Kingsblood"] = 3356,
	["Liferoot"] = 3357, ["Fadeleaf"] = 3818, ["Goldthorn"] = 3821, ["Khadgar's Whisker"] = 3358, ["Wintersbite"] = 3819,
	["Firebloom"] = 4625, ["Purple Lotus"] = 8831, ["Arthas' Tears"] = 8836, ["Golden Sansam"] = 13464, ["Sungrass"] = 8838,
	["Blindweed"] = 8839, ["Ghost Mushroom"] = 8845, ["Gromsblood"] = 8846, ["Dreamfoil"] = 13463, ["Mountain Silversage"] = 13465,
	["Plaguebloom"] = 13466, ["Icecap"] = 13467,
	["Copper Ore"] = 2770, ["Tin Ore"] = 2771, ["Silver Ore"] = 2775, ["Iron Ore"] = 2772, ["Gold Ore"] = 2776, ["Mithril Ore"] = 3858,
	["Truesilver Ore"] = 7911, ["Thorium Ore"] = 10620, ["Dark Iron Ore"] = 11370,
	["Copper Bar"] = 2840, ["Tin Bar"] = 3576, ["Bronze Bar"] = 2841, ["Silver Bar"] = 2842, ["Iron Bar"] = 3575, ["Gold Bar"] = 3577,
	["Steel Bar"] = 3859, ["Mithril Bar"] = 3860, ["Truesilver Bar"] = 6037, ["Thorium Bar"] = 12359, ["Dark Iron Bar"] = 11371,
	["Linen Cloth"] = 2589, ["Wool Cloth"] = 2592, ["Silk Cloth"] = 4306, ["Mageweave Cloth"] = 4338, ["Runecloth"] = 14047,
	["Bolt of Linen Cloth"] = 2996, ["Bolt of Woolen Cloth"] = 2997, ["Bolt of Silk Cloth"] = 4305, ["Bolt of Mageweave"] = 4339,
	["Bolt of Runecloth"] = 14048,
	["Light Leather"] = 2318, ["Medium Leather"] = 2319, ["Heavy Leather"] = 4234, ["Thick Leather"] = 4304, ["Rugged Leather"] = 8170,
	["Cured Light Hide"] = 4231, ["Cured Medium Hide"] = 4233, ["Cured Heavy Hide"] = 4236, ["Cured Thick Hide"] = 8172,
	["Strange Dust"] = 10940, ["Soul Dust"] = 11083, ["Vision Dust"] = 11137, ["Dream Dust"] = 11176,
	["Greater Magic Essence"] = 10939, ["Greater Astral Essence"] = 11082, ["Greater Mystic Essence"] = 11135, ["Greater Nether Essence"] = 11175,
	["Small Glimmering Shard"] = 10978, ["Large Glimmering Shard"] = 11084, ["Small Glowing Shard"] = 11138, ["Large Glowing Shard"] = 11139,
	["Small Radiant Shard"] = 11177, ["Large Radiant Shard"] = 11178, ["Small Brilliant Shard"] = 14343, ["Large Brilliant Shard"] = 14344,
	["Handful of Copper Bolts"] = 4359, ["Copper Tube"] = 4361, ["Copper Modulator"] = 4363, ["Bronze Tube"] = 4371,
	["Whirring Bronze Gizmo"] = 4375, ["Bronze Framework"] = 4382, ["Gold Power Core"] = 10558, ["Iron Strut"] = 4387,
	["Mithril Tube"] = 10559, ["Unstable Trigger"] = 10560, ["Mithril Casing"] = 10561, ["Thorium Widget"] = 15994,
	["Truesilver Transformer"] = 18631, ["Thorium Tube"] = 16000,
}
-- { crate item, name, tier, quality (1 white, 2 green), { "count name", ... } }
local CRATES = {
	{ 248682, "Apprentice Herbs", 1, 1, { "20 Peacebloom", "20 Silverleaf", "10 Earthroot", "10 Mageroyal", "10 Briarthorn" } },
	{ 248683, "Apprentice Ore", 1, 1, { "20 Copper Ore", "20 Tin Ore" } },
	{ 248684, "Apprentice Textiles", 1, 1, { "40 Linen Cloth", "20 Light Leather" } },
	{ 248685, "Apprentice Curiosities", 1, 1, { "20 Strange Dust", "4 Greater Magic Essence", "6 Small Glimmering Shard", "2 Large Glimmering Shard" } },
	{ 248702, "Apprentice Fabrics", 1, 2, { "2 Cured Light Hide", "20 Bolt of Linen Cloth" } },
	{ 248703, "Apprentice Ingots", 1, 2, { "20 Copper Bar", "20 Tin Bar", "10 Bronze Bar" } },
	{ 248704, "Apprentice Parts", 1, 2, { "16 Handful of Copper Bolts", "16 Copper Tube", "4 Copper Modulator" } },
	{ 248686, "Journeyman Herbs", 2, 1, { "10 Stranglekelp", "10 Bruiseweed", "10 Wild Steelbloom", "10 Grave Moss", "10 Kingsblood" } },
	{ 248687, "Journeyman Ore", 2, 1, { "10 Silver Ore", "20 Iron Ore" } },
	{ 248688, "Journeyman Textiles", 2, 1, { "20 Wool Cloth", "40 Silk Cloth", "20 Medium Leather" } },
	{ 248689, "Journeyman Curiosities", 2, 1, { "20 Soul Dust", "4 Greater Astral Essence", "6 Small Glowing Shard", "2 Large Glowing Shard" } },
	{ 248705, "Journeyman Fabrics", 2, 2, { "6 Bolt of Woolen Cloth", "10 Bolt of Silk Cloth", "2 Cured Medium Hide" } },
	{ 248706, "Journeyman Ingots", 2, 2, { "10 Silver Bar", "20 Iron Bar" } },
	{ 248707, "Journeyman Parts", 2, 2, { "8 Bronze Tube", "7 Whirring Bronze Gizmo", "4 Bronze Framework", "45 Gold Power Core" } },
	{ 248690, "Earthly Expert Herbs", 3, 1, { "20 Liferoot", "10 Fadeleaf", "10 Goldthorn", "10 Khadgar's Whisker" } },
	{ 248691, "Flowering Expert Herbs", 3, 1, { "10 Wintersbite", "10 Firebloom", "20 Purple Lotus", "10 Arthas' Tears" } },
	{ 248692, "Expert Ore", 3, 1, { "10 Gold Ore", "20 Mithril Ore" } },
	{ 248693, "Expert Textiles", 3, 1, { "40 Mageweave Cloth", "20 Heavy Leather" } },
	{ 248694, "Expert Curiosities", 3, 1, { "20 Vision Dust", "4 Greater Mystic Essence", "6 Small Radiant Shard", "2 Large Radiant Shard" } },
	{ 248708, "Expert Fabrics", 3, 2, { "8 Bolt of Mageweave", "2 Cured Heavy Hide" } },
	{ 248709, "Expert Ingots", 3, 2, { "20 Mithril Bar", "15 Steel Bar", "10 Gold Bar" } },
	{ 248710, "Expert Parts", 3, 2, { "8 Iron Strut", "5 Mithril Tube", "12 Unstable Trigger", "5 Mithril Casing" } },
	{ 248695, "Earthly Artisan Herbs", 4, 1, { "10 Golden Sansam", "20 Sungrass", "10 Blindweed", "10 Ghost Mushroom", "10 Gromsblood" } },
	{ 248696, "Flowering Artisan Herbs", 4, 1, { "20 Dreamfoil", "20 Mountain Silversage", "20 Plaguebloom", "20 Icecap" } },
	{ 248697, "Artisan Ore", 4, 1, { "10 Truesilver Ore", "20 Thorium Ore", "20 Dark Iron Ore" } },
	{ 248698, "Artisan Textiles", 4, 1, { "40 Runecloth", "20 Thick Leather", "20 Rugged Leather" } },
	{ 248699, "Artisan Curiosities", 4, 1, { "20 Dream Dust", "4 Greater Nether Essence", "6 Small Brilliant Shard", "2 Large Brilliant Shard" } },
	{ 248711, "Artisan Fabrics", 4, 2, { "8 Bolt of Runecloth", "2 Cured Thick Hide" } },
	{ 248712, "Artisan Ingots", 4, 2, { "2 Dark Iron Bar", "10 Truesilver Bar", "20 Thorium Bar" } },
	{ 248713, "Artisan Parts", 4, 2, { "5 Thorium Widget", "5 Truesilver Transformer", "2 Thorium Tube" } },
}
-- Merchant's Favor for a filled (sealed) crate, by tier - Wowhead's "A Sealed Crate" quests: white 5/10/15, green 10/20/30;
-- Artisan isn't on Wowhead yet: white 20 as seen in game, green 40 is a guess on the same pattern (shown with ~)
local FAVOR = { 5, 10, 15, 20 }
local FAVOR_GREEN = { 10, 20, 30, 40 }
PA.WAYLAID = CRATES

-- a crate's bundles from its own tooltip, when the game has it (a crate in your bags): "- 20 Strange Dust"
local tipCache = {}
local function TipBundles(id)
	if tipCache[id] then return tipCache[id] end
	if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return end
	local ok, d = pcall(C_TooltipInfo.GetItemByID, id)
	if not ok or not d or not d.lines then return end
	local out = {}
	for _, l in ipairs(d.lines) do
		local t = l.leftText
		if type(t) == "string" and not (issecretvalue and issecretvalue(t)) then
			for n, name in t:gmatch("%- (%d+) ([^\n]+)") do out[#out + 1] = n .. " " .. strtrim(name) end
		end
	end
	if #out > 0 then tipCache[id] = out; return out end
end

-- the cheapest way to fill one crate: { bundle text, item, count, have, buyCost, all of it yours? }
local function Best(c)
	local bundles = TipBundles(c[1]) or c[5]
	local best
	for _, b in ipairs(bundles) do
		local n, name = b:match("^(%d+) (.+)$")
		n = tonumber(n)
		local id = name and (ID[name] or select(2, GII(name)) and tonumber((select(2, GII(name))):match("item:(%d+)")))
		if n and id then
			local have = Count(id, true) or 0
			local need = math.max(0, n - have)
			local p = PA.Price(id)
			local cost = need == 0 and 0 or (p and p * need)
			local e = { text = b, id = id, n = n, have = have, need = need, cost = cost, price = p, name = name }
			if cost and (not best or not best.cost or cost < best.cost or (cost == best.cost and have > best.have)) then best = e
			elseif not best then best = e end
		end
	end
	return best
end

local page, list, status, filter = nil, nil, nil, "all"
local function Refresh()
	if not page or not page:IsShown() then return end
	local data, inBags, total = {}, 0, 0
	for _, c in ipairs(CRATES) do
		-- crates you have: in your bags, plus the bank (the game remembers what's in it once you've opened it)
		local inBagsN = Count(c[1]) or 0
		local own = math.max(inBagsN, Count(c[1], true) or 0)
		local inBank = own - inBagsN
		local b = Best(c)
		local show = filter == "all" or (filter == "bags" and own > 0) or (filter == "mats" and b and b.need == 0)
		if show then
			local favor = (c[4] == 2 and FAVOR_GREEN or FAVOR)[c[3]]
			local guess = c[4] == 2 and c[3] == 4
			local crateP = PA.Price(c[1])
			local fill = b and b.cost
			local each = own > 0 and fill or (fill and crateP and fill + crateP)
			local name = (c[4] == 2 and "|cff1eff00" or "|cffffffff") .. c[2] .. "|r" .. (inBagsN > 0 and ("  |cff40ff40x" .. inBagsN .. "|r") or "") .. (inBank > 0 and ("  |cff9d9d9d+" .. inBank .. " bank|r") or "")
			local how = b and (b.need == 0 and ("|cff40ff40" .. b.text .. " (yours)|r") or (b.text .. (b.have > 0 and (" |cff888888(have " .. b.have .. ")|r") or ""))) or "|cff888888?|r"
			local costTxt = not b and "" or (b.need == 0 and "|cff40ff40yours|r") or (fill and PA.Money(fill, true)) or "|cff888888no price|r"
			if own > 0 and fill then total = total + fill * own; inBags = inBags + own end
			data[#data + 1] = { name, how, costTxt, (guess and "~" or "") .. favor,
				texture = select(10, GII(c[1])) or 133652, key = tostring(c[1]), crate = c, best = b, own = own,
				sk = { c[2], b and b.text or "", fill or math.huge, favor },
				tip = "Waylaid Crate: " .. c[2] .. "\nAny one of:\n- " .. table.concat(TipBundles(c[1]) or c[5], "\n- ")
					.. (b and b.price and ("\n\nCheapest to fill: " .. b.text .. "\n" .. b.name .. " " .. PA.Money(b.price) .. " each, " .. b.need .. " to buy") or "")
					.. (own == 0 and crateP and ("\nThe empty crate: " .. PA.Money(crateP) .. " (total " .. PA.Money(each or crateP) .. ")") or "")
					.. "\n" .. (guess and "~" or "") .. favor .. " Merchant's Favor"
					.. (own > 0 and ("\nYou have " .. inBagsN .. " in your bags" .. (inBank > 0 and (", " .. inBank .. " in the bank") or "")) or "") }
		end
	end
	list:Set(data, true)
	status:SetText((filter == "bags" and inBags > 0) and ("%d crate%s in your bags and bank - about %s to fill them all."):format(inBags, inBags == 1 and "" or "s", PA.Money(total))
		or ("Cheapest way to fill each crate at the last scan's prices, counting what you have. Click one, then Buy."))
end
PA.RefreshCrates = Refresh

function PA.BuildCrates(p)
	page = p
	local W = p:GetWidth() > 0 and p:GetWidth() or 330
	local RW = 400
	local function F(text, key, x, w)
		local b = PA.Btn(p, text, w, 20); b:SetPoint("TOPLEFT", x, -4)
		b:SetScript("OnClick", function() filter = key; for _, o in ipairs(p.filters) do o:UnlockHighlight() end; b:LockHighlight(); Refresh() end)
		return b
	end
	p.filters = { F("All crates", "all", 10, 96), F("Bags + bank", "bags", 110, 96), F("Have the goods", "mats", 210, 120) }
	p.filters[1]:LockHighlight()
	-- Refresh: searches the auction house for the shown crates' goods (and the crates themselves) for today's prices
	local rf = PA.Btn(p, "Refresh", 62, 20); rf:SetPoint("TOPLEFT", 336, -4)
	local refreshing
	rf:SetScript("OnClick", function()
		if refreshing then refreshing = nil; if PA.ClearQueue then PA.ClearQueue() end; rf:SetText("Refresh"); Refresh(); return end
		if not (PA.Browse and AuctionHouseFrame and AuctionHouseFrame:IsShown()) then PA.Print("open the auction house to refresh prices."); return end
		local names, seen = {}, {}
		local function Add(n) if n and not seen[n:lower()] then seen[n:lower()] = true; names[#names + 1] = n end end
		for _, row in ipairs(list.data or {}) do
			local c = row.crate
			if c then
				for _, bt in ipairs(TipBundles(c[1]) or c[5]) do Add(bt:match("^%d+ (.+)$")) end
				Add("Waylaid Crate: " .. c[2])
			end
		end
		if #names == 0 then return end
		if PA.ClearQueue then PA.ClearQueue() end
		refreshing = true; rf:SetText("Stop")
		local left = #names
		status:SetText(("Refreshing prices... (%d to go)"):format(left))
		for _, n in ipairs(names) do
			local want = n:lower()
			PA.Browse({ text = n, exact = true }, function(results)
				for _, r in ipairs(results or {}) do
					local info = C_AuctionHouse.GetItemKeyInfo and C_AuctionHouse.GetItemKeyInfo(r.itemKey)
					local nm = (info and info.itemName) or GII(r.itemKey.itemID)
					if r.minPrice and r.minPrice > 0 and (not nm or nm:lower() == want) then PA.Record(tostring(r.itemKey.itemID), r.minPrice) end
				end
				left = left - 1
				if not refreshing then return end
				if left > 0 then status:SetText(("Refreshing prices... (%d to go)"):format(left))
				else refreshing = nil; rf:SetText("Refresh"); Refresh() end
			end)
		end
	end)
	PA.Tip(rf, "Refresh", "Searches the auction house for every good the crates in the list take (and the crates themselves) for current prices. Pick a filter first - \"Bags + bank\" refreshes just your crates. Click again to stop.")
	PA.Tip(p.filters[3], "Have the goods", "Crates you already have everything for - buy the empty crate on the auction house and fill it.")
	list = PA.List(p, RW, 17, 18, { { 140, "LEFT", "Crate", sort = "asc" }, { 130, "LEFT", "Cheapest fill" }, { 62, "RIGHT", "Cost", sort = "asc" }, { 44, "RIGHT", "Favor", sort = "desc" } },
		function(item) list.selected = item; list.selectedKey = item.key; list:Refresh() end)
	list:SetPoint("TOPLEFT", 10, -44)
	local buy = PA.Btn(p, "Buy cheapest fill", 130, 22); buy:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -16)
	buy:SetScript("OnClick", function()
		local it = list.selected
		if not it then PA.Print("pick a crate first."); return end
		local b = it.best
		if not b then PA.Print("no price for that crate's goods yet - do a full scan."); return end
		if b.need == 0 then PA.Print("you already have " .. b.text .. " for it."); return end
		if PA.OpenInBuy then PA.OpenInBuy(C_AuctionHouse.MakeItemKey(b.id), b.name) end
		PA.Print(("buying %d %s for the %s crate (you have %d)."):format(b.need, b.name, it.crate[2], b.have))
	end)
	PA.Tip(buy, "Buy cheapest fill", "Opens the cheapest of the selected crate's goods in the Buy view - the game's own Buy button buys it. Shows how many you still need.")
	local bc = PA.Btn(p, "Buy the crate", 100, 22); bc:SetPoint("LEFT", buy, "RIGHT", 6, 0)
	bc:SetScript("OnClick", function()
		local it = list.selected
		if not it then PA.Print("pick a crate first."); return end
		if PA.OpenInBuy then PA.OpenInBuy(C_AuctionHouse.MakeItemKey(it.crate[1]), "Waylaid Crate: " .. it.crate[2]) end
	end)
	PA.Tip(bc, "Buy the crate", "Opens the empty crate itself in the Buy view (for the crates you have the goods for).")
	local ow = PA.Btn(p, "Open window", 100, 22); ow:SetPoint("LEFT", bc, "RIGHT", 6, 0)
	ow:SetScript("OnClick", function() if PA.ToggleCrates then PA.ToggleCrates(list.selected and list.selected.crate[1]) end end)
	PA.Tip(ow, "Open window", "The Waylaid Crates window: each crate, every bundle that fills it, and what you have of each (bags and bank). Opens anywhere with /pah crates.")
	status = PA.Label(p, "", "GameFontDisableSmall"); status:SetPoint("TOPLEFT", buy, "BOTTOMLEFT", 0, -6); status:SetWidth(RW); status:SetJustifyH("LEFT")
	p.OnOpen = function()
		-- (crate tooltips the game doesn't have yet: ask for them, and look again in a moment)
		for _, c in ipairs(CRATES) do if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, c[1]) end end
		Refresh(); C_Timer.After(1, Refresh)
	end
	local ev = CreateFrame("Frame", nil, p)
	ev:RegisterEvent("BAG_UPDATE_DELAYED")
	ev:SetScript("OnEvent", function() if p:IsShown() then Refresh() end end)
end

---------------------------------------------------------------- a Crates window of its own (anywhere, not only at the auction house)
-- Every crate, and for the one picked: each bundle that fills it, how many you have (bags and bank), how many you're
-- short and what that costs at the last scan's prices. /pah crates, or "Open window" on the Crates tab.
local cw, cwList, cwSel, cwFilter = nil, nil, nil, "all"
local function Have(id)
	local bags = Count(id) or 0
	local all = math.max(bags, Count(id, true) or 0)
	return all, bags, all - bags
end
local function CrateRows()
	local data = {}
	for _, c in ipairs(CRATES) do
		local own = Have(c[1])
		local b = Best(c)
		local show = cwFilter == "all" or (cwFilter == "mine" and own > 0) or (cwFilter == "mats" and b and b.need == 0)
		if show then
			local ready = b and b.need == 0
			data[#data + 1] = { (c[4] == 2 and "|cff1eff00" or "|cffffffff") .. c[2] .. "|r", own > 0 and ("|cff40ff40" .. own .. "|r") or "",
				ready and "|cff40ff40ready|r" or (b and b.cost and PA.Money(b.cost, true)) or "",
				texture = select(10, GII(c[1])) or 133652, key = tostring(c[1]), crate = c, sk = { c[3] * 100 + (c[4] == 2 and 50 or 0) + #data, own, b and b.cost or math.huge } }
		end
	end
	return data
end
local function DrawDetail()
	local d = cw.detail
	for _, r in ipairs(d.rows) do r:Hide() end
	local c = cwSel
	if not c then d.title:SetText("Pick a crate on the left."); d.sub:SetText(""); d.foot:SetText(""); return end
	local own, bags, bank = Have(c[1])
	local favor = (c[4] == 2 and FAVOR_GREEN or FAVOR)[c[3]]
	d.title:SetText((c[4] == 2 and "|cff1eff00" or "|cffffffff") .. "Waylaid Crate: " .. c[2] .. "|r")
	d.sub:SetText(("%s%d Merchant's Favor   -   you have %d (bags %d, bank %d)   -   fill it with any one of:"):format(
		(c[4] == 2 and c[3] == 4) and "~" or "", favor, own, bags, bank))
	local best = Best(c)
	local y = 0
	for i, bt in ipairs(TipBundles(c[1]) or c[5]) do
		local n, name = bt:match("^(%d+) (.+)$"); n = tonumber(n)
		local id = name and ID[name]
		local r = d.rows[i]
		if not r then
			r = CreateFrame("Button", nil, d); r:SetSize(330, 34)
			r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(28, 28); r.icon:SetPoint("LEFT", 2, 0)
			r.a = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); r.a:SetPoint("TOPLEFT", 36, -2); r.a:SetJustifyH("LEFT")
			r.b = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.b:SetPoint("TOPLEFT", 36, -18); r.b:SetWidth(290); r.b:SetJustifyH("LEFT")
			r.hl = r:CreateTexture(nil, "HIGHLIGHT"); r.hl:SetAllPoints(); r.hl:SetColorTexture(1, 0.82, 0, 0.12)
			r:SetScript("OnEnter", function(self) if self.id then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetItemByID(self.id); GameTooltip:Show() end end)
			r:SetScript("OnLeave", function() GameTooltip:Hide() end)
			r:SetScript("OnClick", function(self)
				if not self.id then return end
				if AuctionHouseFrame and AuctionHouseFrame:IsShown() and PA.OpenInBuy then PA.OpenInBuy(C_AuctionHouse.MakeItemKey(self.id), self.name)
				else PA.Print("open the auction house to buy " .. (self.name or "it") .. ".") end
			end)
			d.rows[i] = r
		end
		r.id, r.name = id, name
		r:ClearAllPoints(); r:SetPoint("TOPLEFT", d.title, "BOTTOMLEFT", 0, -34 - y); y = y + 38
		r.icon:SetTexture(id and select(10, GII(id)) or 134400)
		local all, hb, hk = 0, 0, 0
		if id then all, hb, hk = Have(id) end
		local short = math.max(0, (n or 0) - all)
		local p = id and PA.Price(id)
		local isBest = best and best.id == id
		r.a:SetText(((short == 0) and "|cff40ff40" or "|cffffffff") .. (n or "?") .. " " .. (name or bt) .. "|r" .. (isBest and "  |cffffd100(cheapest)|r" or ""))
		r.b:SetText(("have %d  (bags %d, bank %d)"):format(all, hb, hk) .. (short == 0 and "   |cff40ff40enough|r"
			or ("   |cffff8040short %d|r%s"):format(short, p and ("  -  about " .. PA.Money(p * short)) or "  -  no price yet")))
		r:Show()
	end
	d.foot:SetText("Click a bundle to open it in the auction house's Buy view (when the auction house is open).")
end
local function DrawCrates()
	if not (cw and cw:IsShown()) then return end
	cwList:Set(CrateRows(), true)
	DrawDetail()
end
local function BuildWindow()
	cw = CreateFrame("Frame", "PintsAuctionsCrates", UIParent, "BackdropTemplate")
	cw:SetSize(1060, 500); cw:SetPoint("CENTER", 0, 40); cw:SetFrameStrata("HIGH"); cw:SetToplevel(true); cw:SetClampedToScreen(true)
	cw:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 } })
	cw:EnableMouse(true); cw:SetMovable(true); cw:RegisterForDrag("LeftButton")
	cw:SetScript("OnDragStart", cw.StartMoving); cw:SetScript("OnDragStop", cw.StopMovingOrSizing)
	tinsert(UISpecialFrames, "PintsAuctionsCrates")
	local t = cw:CreateFontString(nil, "OVERLAY", "GameFontNormal"); t:SetPoint("TOPLEFT", 16, -14); t:SetText("|cffd4a017Pint's|r " .. PA.DSLName())
	-- two pages: the Waylaid Crates, and the Craftsman's Writs (Writs.lua)
	cw.tabs = {}
	local function Tab(text, key, x, w)
		local b = PA.Btn(cw, text, w, 22); b:SetPoint("TOPLEFT", x, -34)
		b:SetScript("OnClick", function() PA.CratesPage(key) end)
		cw.tabs[key] = b
	end
	Tab("Waylaid Crates", "crates", 16, 120); Tab("Writs", "writs", 140, 80)
	local close = CreateFrame("Button", nil, cw, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -4, -4)
	close:SetScript("OnClick", function() cw:Hide() end)
	local filters = {}
	local function F(text, key, x, w)
		local b = PA.Btn(cw, text, w, 20); b:SetPoint("TOPLEFT", x, -64)
		b:SetScript("OnClick", function() cwFilter = key; for _, o in ipairs(filters) do o:UnlockHighlight() end; b:LockHighlight(); DrawCrates() end)
		filters[#filters + 1] = b
		return b
	end
	F("All crates", "all", 16, 84):LockHighlight(); F("Mine", "mine", 102, 60); F("Have the goods", "mats", 164, 108)
	cw.crateBits = filters
	cwList = PA.List(cw, 270, 18, 20, { { 150, "LEFT", "Crate", sort = "asc" }, { 32, "RIGHT", "Have", sort = "desc" }, { 70, "RIGHT", "To fill", sort = "asc" } },
		function(item) cwSel = item.crate; cwList.selectedKey = item.key; cwList:Refresh(); DrawDetail() end)
	cwList:SetPoint("TOPLEFT", 16, -106)
	local d = CreateFrame("Frame", nil, cw); d:SetPoint("TOPLEFT", cwList, "TOPRIGHT", 14, 18); d:SetPoint("BOTTOMRIGHT", -16, 16); cw.detail = d
	d.title = d:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); d.title:SetPoint("TOPLEFT", 0, 0); d.title:SetWidth(330); d.title:SetJustifyH("LEFT")
	d.sub = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); d.sub:SetPoint("TOPLEFT", d.title, "BOTTOMLEFT", 0, -6); d.sub:SetWidth(330); d.sub:SetJustifyH("LEFT")
	d.foot = d:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); d.foot:SetPoint("BOTTOMLEFT", 0, 4); d.foot:SetWidth(330); d.foot:SetJustifyH("LEFT")
	d.rows = {}
	cw.crateBits[#cw.crateBits + 1] = cwList; cw.crateBits[#cw.crateBits + 1] = d
	if PA.BuildWritsPane then cw.writs = PA.BuildWritsPane(cw) end
	PA.CratesPage(cw.page or "crates")
	local ev = CreateFrame("Frame", nil, cw)
	ev:RegisterEvent("BAG_UPDATE_DELAYED"); pcall(ev.RegisterEvent, ev, "BANKFRAME_OPENED"); pcall(ev.RegisterEvent, ev, "GET_ITEM_INFO_RECEIVED")
	ev:SetScript("OnEvent", function() if cw:IsShown() and not cw.pending then cw.pending = true; C_Timer.After(0.3, function() cw.pending = nil; DrawCrates() end) end end)
	cw:SetScript("OnShow", function()
		for _, c in ipairs(CRATES) do if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, c[1]) end end
		DrawCrates(); C_Timer.After(1, DrawCrates)
	end)
end
-- the window's name: the turn-in folk of your side
function PA.DSLName()
	return (UnitFactionGroup("player") == "Alliance") and "Azeroth Commerce Authority (Waylaid Crates, Writs)" or "Durotar Supply and Logistics (Waylaid Crates, Writs)"
end
-- which page of the window: "crates" or "writs"
function PA.CratesPage(key)
	if not cw then return end
	cw.page = key
	for k, b in pairs(cw.tabs or {}) do if k == key then b:LockHighlight() else b:UnlockHighlight() end end
	for _, f in ipairs(cw.crateBits or {}) do f:SetShown(key == "crates") end
	if cw.writs then cw.writs:SetShown(key == "writs") end
	if key == "crates" then DrawCrates() elseif PA.DrawWritsPane then PA.DrawWritsPane() end
end
function PA.ToggleCrates(crateID)
	-- (a new frame starts shown: hide it first, or the first click would build it and then "toggle" it shut)
	if not cw then BuildWindow(); cw:Hide() end
	if crateID then for _, c in ipairs(CRATES) do if c[1] == crateID then cwSel = c; cwList.selectedKey = tostring(c[1]) end end end
	if cw:IsShown() and not crateID then cw:Hide() else cw:Show(); DrawCrates() end
end
do
	local prev = SlashCmdList.PINTSAUCTIONS
	SlashCmdList.PINTSAUCTIONS = function(msg)
		local m = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
		if m == "crates" or m == "crate" or m == "waylaid" then PA.ToggleCrates()
		elseif prev then prev(msg) end
		if m == "help" or m == "?" then PA.Print("/pah crates - the Waylaid Crates window: each crate, what fills it and what you have") end
	end
end

-- item tooltips: a Waylaid crate's goods say which crates they fill ("Waylaid crates: Expert Ore (20)"), and a crate
-- says which of its bundles you already have
local FILLS = {}
for _, c in ipairs(CRATES) do
	for _, bt in ipairs(c[5]) do
		local n, name = bt:match("^(%d+) (.+)$")
		local id = name and ID[name]
		if id then FILLS[id] = FILLS[id] or {}; table.insert(FILLS[id], { c, tonumber(n) }) end
	end
end
local CRATE = {}
for _, c in ipairs(CRATES) do CRATE[c[1]] = c end
local function TipAdd(tt, id)
	if not id or (PintsAuctionsDB and PintsAuctionsDB.crateTips == false) then return end
	local f = FILLS[id]
	if f then
		local parts = {}
		for _, e in ipairs(f) do parts[#parts + 1] = e[1][2] .. " (" .. e[2] .. ")" end
		tt:AddLine("Waylaid crates: " .. table.concat(parts, ", "), 0.85, 0.65, 0.3, true)
	end
	local c = CRATE[id]
	if c then
		local ok = {}
		for _, bt in ipairs(c[5]) do
			local n, name = bt:match("^(%d+) (.+)$")
			local gid = name and ID[name]
			if gid and Have(gid) >= tonumber(n) then ok[#ok + 1] = bt end
		end
		tt:AddLine(#ok > 0 and ("You can fill it with: " .. table.concat(ok, ", ")) or "You don't have a full bundle for it yet (/pah crates)", 0.85, 0.65, 0.3, true)
	end
	tt:Show()
end
if TooltipDataProcessor and Enum and Enum.TooltipDataType then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
		if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
		local id = data and data.id
		if id and type(id) == "number" and not (issecretvalue and issecretvalue(id)) then TipAdd(tt, id) end
	end)
end

-- a minimap button of its own for the Crates window (drag it around the minimap; /pah cratebutton hides or shows it)
do
	local NAME, ICON, ANGLE = "PintsAuctionsCrates", "Interface\\Icons\\INV_Crate_08", 160
	local btn
	local function Tip(tt)
		tt:AddLine("Pint's " .. PA.DSLName())
		tt:AddLine("Click: each crate, what fills it and what you have (bags and bank).", 1, 1, 1, true)
		tt:AddLine("/pah cratebutton to hide", 0.5, 0.5, 0.5)
	end
	local function Build()
		if btn or not PA.db then return end
		PA.db.crateMinimap = PA.db.crateMinimap or {}
		local store = PA.db.crateMinimap
		local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
		local Icon = LibStub and LibStub("LibDBIcon-1.0", true)
		if LDB and Icon then
			local o = LDB:NewDataObject(NAME, { type = "launcher", text = "Pint's Durotar Supply and Logistics", icon = ICON, OnClick = function() PA.ToggleCrates() end, OnTooltipShow = Tip })
			Icon:Register(NAME, o, store); btn = { lib = Icon }; return
		end
		local b = CreateFrame("Button", NAME .. "MinimapButton", Minimap)
		b:SetSize(31, 31); b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(8)
		b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
		local ic = b:CreateTexture(nil, "BACKGROUND"); ic:SetTexture(ICON); ic:SetSize(20, 20); ic:SetPoint("CENTER", 0, 1); ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		local border = b:CreateTexture(nil, "OVERLAY"); border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder"); border:SetSize(53, 53); border:SetPoint("TOPLEFT")
		local function Place() local a = math.rad(store.angle or ANGLE); b:ClearAllPoints(); b:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(a), 80 * math.sin(a)) end
		Place()
		b:RegisterForDrag("LeftButton")
		b:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter(); local px, py = GetCursorPosition(); local s = Minimap:GetEffectiveScale()
			store.angle = math.deg(math.atan2(py / s - my, px / s - mx)); Place() end) end)
		b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
		b:SetScript("OnClick", function() PA.ToggleCrates() end)
		b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_LEFT"); Tip(GameTooltip); GameTooltip:Show() end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		b:SetShown(not store.hide); btn = b
	end
	function PA.ToggleCrateButton()
		Build()
		local store = PA.db and PA.db.crateMinimap; if not store then return end
		store.hide = not store.hide
		if btn and type(btn.lib) == "table" then if store.hide then btn.lib:Hide(NAME) else btn.lib:Show(NAME) end elseif btn then btn:SetShown(not store.hide) end
		PA.Print("crates minimap button " .. (store.hide and "hidden" or "shown") .. ".")
	end
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("PLAYER_LOGIN")
	ev:SetScript("OnEvent", function() C_Timer.After(1, Build) end)
	local prev = SlashCmdList.PINTSAUCTIONS
	SlashCmdList.PINTSAUCTIONS = function(msg)
		local m = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
		if m == "cratebutton" or m == "crateminimap" then PA.ToggleCrateButton()
		elseif prev then prev(msg) end
	end
end
