-- Pint's Auctions - WoW Forever's auction house (the modern one: Buy / Sell / Auctions tabs).
-- A panel beside the auction window with Shopping lists, an Undercut check and Deals, a full scan for tooltip prices,
-- and automatic undercut pricing on Blizzard's own Sell tab. Classic Era's auction house is in UI.lua / Sell.lua / Cancel.lua.
local ADDON, NS = ...
local PA = NS.PA
if QueryAuctionItems or not C_AuctionHouse then return end

local C = C_AuctionHouse
local Print, Money = PA.Print, PA.Money
local function S() return PA.S end
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local function RF() return PA.RF() end
local PRICE_SORT = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
local W = 420

---------------------------------------------------------------- helpers
-- auction prices on the modern auction house: items go in whole silver; commodities can use copper when the realm allows
local function Round(p, commodity)
	p = math.max(1, math.floor(p))
	local copper = commodity and C.SupportsCopperValues and C.SupportsCopperValues()
	if not copper then p = math.max(100, math.floor(p / 100) * 100) end
	return p
end
local function Undercut(p, commodity)
	local s = S()
	local v
	if s.undercutMode == "pct" then v = p * (1 - (s.undercutPct or 0) / 100) else v = p - (s.undercut or 0) end
	v = math.max(1, math.floor(v))
	if not (commodity and C.SupportsCopperValues and C.SupportsCopperValues()) then
		-- whole silver: go a full silver under unless the price is already a round number below
		local r = math.floor(v / 100) * 100
		if r >= p then r = r - 100 end
		v = math.max(100, r)
	end
	return v
end
local function KeyName(itemKey)
	local info = C.GetItemKeyInfo and C.GetItemKeyInfo(itemKey)
	local name, _, q, _, _, _, _, _, _, icon = GetItemInfo(itemKey.itemID)
	if not (info and info.itemName) and not name and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemKey.itemID) end
	return (info and info.itemName) or name or ("item " .. itemKey.itemID), (info and info.quality) or q, (info and info.iconFileID) or icon, info and info.isCommodity
end
-- the cheapest listing that isn't all yours: unit price, row
local function LowestCommodity(itemID)
	for i = 1, (C.GetNumCommoditySearchResults(itemID) or 0) do
		local r = C.GetCommoditySearchResultInfo(itemID, i)
		if r and r.unitPrice and (not r.containsOwnerItem or (r.numOwnerItems or 0) < (r.quantity or 0)) then return r.unitPrice, r end
	end
end
local function LowestItem(itemKey)
	for i = 1, (C.GetNumItemSearchResults(itemKey) or 0) do
		local r = C.GetItemSearchResultInfo(itemKey, i)
		if r and r.buyoutAmount and r.buyoutAmount > 0 and not r.containsOwnerItem then return r.buyoutAmount, r end   -- (already per item: quantity is how many are listed at it)
	end
end
-- the game sends an update as it clears the old results and again as the new ones arrive: wait for real ones
local function CommodityArrived(itemID)
	return (C.GetNumCommoditySearchResults(itemID) or 0) > 0 or (C.HasFullCommoditySearchResults and C.HasFullCommoditySearchResults(itemID))
end
local function ItemArrived(itemKey)
	return (C.GetNumItemSearchResults(itemKey) or 0) > 0 or (C.HasFullItemSearchResults and C.HasFullItemSearchResults(itemKey))
end
-- your own cheapest listing in the results (so you don't undercut yourself)
local function OwnCommodity(itemID)
	for i = 1, (C.GetNumCommoditySearchResults(itemID) or 0) do
		local r = C.GetCommoditySearchResultInfo(itemID, i)
		if r and r.containsOwnerItem then return r.unitPrice end
	end
end
local function OwnItem(itemKey)
	for i = 1, (C.GetNumItemSearchResults(itemKey) or 0) do
		local r = C.GetItemSearchResultInfo(itemKey, i)
		if r and r.containsOwnerItem and r.buyoutAmount then return r.buyoutAmount end
	end
end

---------------------------------------------------------------- a short log of what the auction house answered (saved; /pah log prints it)
local function Log(m)
	PA.Debug(m)
	local d = PA.db; if not d then return end
	d.modernLog = d.modernLog or {}
	local l = d.modernLog
	l[#l + 1] = date("%H:%M:%S ") .. m
	while #l > 300 do table.remove(l, 1) end
end
PA.Log = Log
local function Arg(v)
	if type(v) == "table" then return "{itemID=" .. tostring(v.itemID) .. "}" end
	return tostring(v)
end

---------------------------------------------------------------- one request at a time (the auction house throttles)
-- req = { send = fn, events = { EVENT = match(...) -> true }, done = fn(event, ...), timeout = s }
local queue, cur = {}, nil
local q = CreateFrame("Frame")
local function Ready() return not C.IsThrottledMessageSystemReady or C.IsThrottledMessageSystemReady() end
local function Open() return AuctionHouseFrame and AuctionHouseFrame:IsShown() end
function PA.Queue(req) queue[#queue + 1] = req end
function PA.ClearQueue() wipe(queue); cur = nil end
q:SetScript("OnUpdate", function()
	if not Open() then if cur or #queue > 0 then PA.ClearQueue() end; return end
	if cur then
		if GetTime() - cur.at > (cur.timeout or 6) then local r = cur; cur = nil; Log("no answer: " .. (r.what or "?")); if r.done then r.done(nil) end end
		return
	end
	if #queue == 0 or not Ready() then return end
	cur = table.remove(queue, 1)
	cur.at = GetTime()
	Log("send " .. (cur.what or "?"))
	local ok, err = pcall(cur.send)
	if not ok then PA.Debug("request failed: " .. tostring(err)); local r = cur; cur = nil; if r.done then r.done(nil) end end
end)
for _, e in ipairs({ "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED",
	"OWNED_AUCTIONS_UPDATED", "REPLICATE_ITEM_LIST_UPDATE", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED", "AUCTION_CANCELED", "AUCTION_HOUSE_AUCTION_CREATED", "AUCTION_HOUSE_CLOSED" }) do
	pcall(q.RegisterEvent, q, e)
end

---------------------------------------------------------------- prices from everything the auction house shows
-- (a search that came back with nothing listed at all: its old price stops showing, so a writ or item that's sold out
-- doesn't keep a price from an earlier scan)
local function RecordCommodity(itemID)
	local p = LowestCommodity(itemID)
	if p then PA.Record(tostring(itemID), p)
	elseif (C.GetNumCommoditySearchResults(itemID) or 0) == 0 and C.HasFullCommoditySearchResults and C.HasFullCommoditySearchResults(itemID) then PA.RecordNone(tostring(itemID)) end
end
local function RecordItem(itemKey)
	local p, r = LowestItem(itemKey)
	if p then
		local key = PA.Key(r.itemLink or itemKey.itemID)
		PA.Record(key, math.floor(p + 0.5))
		-- (and under the plain item number, which is what the writs, shopping lists and tooltips look up)
		if key ~= tostring(itemKey.itemID) then PA.Record(tostring(itemKey.itemID), math.floor(p + 0.5)) end
	elseif (C.GetNumItemSearchResults(itemKey) or 0) == 0 and C.HasFullItemSearchResults and C.HasFullItemSearchResults(itemKey) then PA.RecordNone(tostring(itemKey.itemID)) end
end

---------------------------------------------------------------- full scan (every auction; the game allows it every 15 minutes)
local scan = {}
function PA.FullScanWait()
	local t = PA.db and PA.db.lastAll[RF()]
	if not t then return 0 end
	return math.max(0, 15 * 60 - (time() - t))
end
function PA.CanFullScan() return not PA.scanning and PA.FullScanWait() == 0 and Open() end
function PA.FullScan()
	if not Open() then Print("open the auction house first."); return end
	if PA.scanning then return end
	local w = PA.FullScanWait()
	if w > 0 then Print("the auction house allows a full scan every 15 minutes - about " .. math.ceil(w / 60) .. " min to go."); return end
	PA.ClearQueue()
	PA.scanning = "waiting"
	PA.db.lastAll[RF()] = time()
	if PA.OnScanState then PA.OnScanState("Asking the auction house for everything...") end
	Log("full scan asked")
	C.ReplicateItems()
	C_Timer.After(60, function() if PA.scanning == "waiting" then PA.scanning = nil; if PA.OnScanState then PA.OnScanState("The full scan didn't answer - try again in 15 minutes.") end end end)
end
local reader = CreateFrame("Frame")
reader:SetScript("OnUpdate", function()
	if PA.scanning ~= "reading" then return end
	local stop = math.min(scan.total, scan.i + 500)
	for i = scan.i, stop - 1 do                         -- the replicate list counts from 0
		local _, _, count, _, _, _, _, _, _, buyout, _, _, _, owner, _, _, itemID, hasAll = C.GetReplicateItemInfo(i)
		-- (a row the game hasn't finished filling in can carry another auction's price: those are left out, so a cheap
		-- price from some other item never lands on this one)
		if buyout and buyout > 0 and itemID and hasAll ~= false then
			local link = C.GetReplicateItemLink and C.GetReplicateItemLink(i)
			local key = link and PA.Key(link) or tostring(itemID)
			local unit = buyout / math.max(1, count or 1)
			local l = scan.all[key]; if not l then l = {}; scan.all[key] = l; scan.links[key] = link or ("item:" .. itemID) end
			l[#l + 1] = { unit, count or 1, owner == PA.ME }
			if not scan.lows[key] or unit < scan.lows[key] then scan.lows[key] = unit end
			local base = key:match("^(%d+):")
			if base and (not scan.lows[base] or unit < scan.lows[base]) then scan.lows[base] = unit end
		end
	end
	scan.i = stop
	if PA.OnScanState then PA.OnScanState(("Reading auctions... %d%%"):format(math.floor(scan.i / math.max(1, scan.total) * 100))) end
	if scan.i >= scan.total then
		local n = 0
		for key, unit in pairs(scan.lows) do PA.Record(key, math.floor(unit + 0.5)); n = n + 1 end
		-- (a whole house read: anything not in it is sold out, so its old price stops showing)
		if scan.total > 100 and PA.MarkUnseen then
			local gone = PA.MarkUnseen(scan.lows)
			Log(("full scan: %d items no longer listed"):format(gone))
		end
		Log(("full scan read %d auctions, %d items"):format(scan.total, n))
		local deals = PA.RecordScan(scan.all, scan.links)
		PA.scanning = nil
		scan = {}
		if deals and deals > 0 then Print(("%d deal%s found - see Deals beside the auction window."):format(deals, deals == 1 and "" or "s")) end
		Print(("full scan done - prices for %d items."):format(n))
		if PA.OnScanState then PA.OnScanState(("Last full scan: %d items, just now."):format(n)) end
		if PA.RefreshDeals then PA.RefreshDeals() end
		-- (the Writs and Crates tabs show the new prices straight away, not only when next opened)
		if PA.RefreshWrits then PA.RefreshWrits() end
		if PA.RefreshCrates then PA.RefreshCrates() end
	end
end)

---------------------------------------------------------------- selling: undercut automatically on Blizzard's Sell tab
local sell = { label = nil }
local function SellFrames() local f = AuctionHouseFrame; if f then return { f.CommoditiesSellFrame, f.ItemSellFrame } end return {} end
local function SetPrice(f, p)
	if f.SetPrice then pcall(f.SetPrice, f, p)
	elseif f.PriceInput and f.PriceInput.SetAmount then pcall(f.PriceInput.SetAmount, f.PriceInput, p) end
	if f.UpdatePostState then pcall(f.UpdatePostState, f) end
end
local function SellNote(f, text)
	if not f.pintsNote then
		f.pintsNote = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		local a = f.PriceInput or f
		f.pintsNote:SetPoint("TOPLEFT", a, "BOTTOMLEFT", 0, -4); f.pintsNote:SetWidth(260); f.pintsNote:SetJustifyH("LEFT")
	end
	f.pintsNote:SetText(text or "")
end
local function Priced(f, itemID, commodity, itemKey)
	if not (sell.pending and sell.pending.frame == f and sell.pending.id == itemID) then return end
	sell.pending = nil
	local low, own
	if commodity then low, own = LowestCommodity(itemID), OwnCommodity(itemID) else low, own = LowestItem(itemKey), OwnItem(itemKey) end
	local p, why
	if low and own and own <= low then p, why = Round(own, commodity), "you're already the cheapest - matching your price"
	elseif low then p, why = Undercut(low, commodity), "lowest " .. Money(low) .. " - undercut"
	else
		local known = PA.Typical(itemID) or PA.Price(itemID)
		if known then p, why = Round(known, commodity), "nobody else is selling - your last seen price" end
	end
	if p then
		SetPrice(f, p)
		SellNote(f, "|cffd4a017Pint's:|r " .. why .. " to " .. Money(p) .. (commodity and " each" or ""))
		if low then PA.Record(tostring(itemID), math.floor(low + 0.5)) end
	else
		SellNote(f, "|cffd4a017Pint's:|r nobody is selling this - set your own price.")
	end
end
local function HookSell()
	for _, f in ipairs(SellFrames()) do
		if f and not f.pintsHooked and f.SetItem then
			f.pintsHooked = true
			hooksecurefunc(f, "SetItem", function(self, loc)
				SellNote(self, "")
				if not (loc and loc.IsValid and loc:IsValid()) then sell.pending = nil; return end
				local id = C_Item.GetItemID(loc)
				local p = id and { frame = self, id = id } or nil
				sell.pending = p
				-- results the game already had may not be sent again: price from them after a moment
				if p then
					local commodity = C.GetItemCommodityStatus and C.GetItemCommodityStatus(loc) == Enum.ItemCommodityStatus.Commodity
					C_Timer.After(1.5, function()
						if sell.pending ~= p then return end
						if commodity then Priced(self, id, true)
						else
							local key = C.GetItemKeyFromItem and C.GetItemKeyFromItem(loc)
							if key then Priced(self, id, false, key) end
						end
					end)
				end
			end)
		end
	end
end
local function OnSellResults(e, a1)
	local p = sell.pending
	if not p then return end
	if e == "COMMODITY_SEARCH_RESULTS_UPDATED" and a1 == p.id and CommodityArrived(a1) then
		C_Timer.After(0.05, function() Priced(p.frame, p.id, true) end)       -- after Blizzard fills in its own price
	elseif e == "ITEM_SEARCH_RESULTS_UPDATED" and type(a1) == "table" and a1.itemID == p.id and ItemArrived(a1) then
		C_Timer.After(0.05, function() Priced(p.frame, p.id, false, a1) end)
	end
end

---------------------------------------------------------------- the panel beside the auction window
local panel, pages, tabs = nil, {}, {}
local function Show(name)
	for n, p in pairs(pages) do p:SetShown(n == name) end
	for n, t in pairs(tabs) do if n == name then t:LockHighlight() else t:UnlockHighlight() end end
	panel.page = name
	if pages[name].OnOpen then pages[name].OnOpen() end
end

-- open an item in Blizzard's Buy tab
local function OpenInBuy(itemKey, name, result, tries)
	local f = AuctionHouseFrame
	if not (f and itemKey) then return end
	-- the game only opens an item it already has the details of: ask for them and try again a moment later
	local info = C.GetItemKeyInfo and C.GetItemKeyInfo(itemKey)
	if not info and (tries or 0) < 5 then
		C_Timer.After(0.3, function() OpenInBuy(itemKey, name, result, (tries or 0) + 1) end)
		return
	end
	if f.SetDisplayMode and AuctionHouseFrameDisplayMode and AuctionHouseFrameDisplayMode.Buy and not (f.displayMode == AuctionHouseFrameDisplayMode.Buy) then
		pcall(f.SetDisplayMode, f, AuctionHouseFrameDisplayMode.Buy)
	end
	local r = result or { itemKey = itemKey, minPrice = PA.Price(itemKey.itemID) or 0, totalQuantity = 1 }
	if info and f.SelectBrowseResult and pcall(f.SelectBrowseResult, f, r) then return end
	-- else: search for it by name, with no filters of yours in the way (the game's quality and level filters can hide it)
	local sb = f.SearchBar
	if sb and sb.SearchBox and name then sb.SearchBox:SetText(name) end
	local filters = {}
	for _, k in ipairs({ "PoorQuality", "CommonQuality", "UncommonQuality", "RareQuality", "EpicQuality", "LegendaryQuality", "ArtifactQuality" }) do
		if Enum.AuctionHouseFilter[k] then filters[#filters + 1] = Enum.AuctionHouseFilter[k] end
	end
	pcall(C.SendBrowseQuery, { searchString = name or "", sorts = PRICE_SORT, minLevel = 0, maxLevel = 0, filters = filters, itemClassFilters = {} })
end
PA.OpenInBuy = OpenInBuy          -- (the Profession Planner's Buy button)

---------------------------------------------------------------- shopping
local shop = {}
local function Browse(term, onDone)
	PA.Queue({
		what = "browse \"" .. (term.text or "") .. "\"",
		send = function()
			-- the quality filters are "include these": a search without them finds nothing at all
			local filters = {}
			for _, k in ipairs({ "PoorQuality", "CommonQuality", "UncommonQuality", "RareQuality", "EpicQuality", "LegendaryQuality", "ArtifactQuality" }) do
				if Enum.AuctionHouseFilter[k] then filters[#filters + 1] = Enum.AuctionHouseFilter[k] end
			end
			if term.exact and Enum.AuctionHouseFilter.ExactMatch then filters[#filters + 1] = Enum.AuctionHouseFilter.ExactMatch end
			C.SendBrowseQuery({ searchString = term.text or "", sorts = PRICE_SORT, minLevel = 0, maxLevel = 0, filters = filters, itemClassFilters = {} })
		end,
		-- nothing back yet just means still searching; a search that really finds nothing ends on the timeout
		events = {
			AUCTION_HOUSE_BROWSE_RESULTS_UPDATED = function() return #(C.GetBrowseResults() or {}) > 0 end,
			AUCTION_HOUSE_BROWSE_RESULTS_ADDED = function() return #(C.GetBrowseResults() or {}) > 0 end,
		},
		timeout = 3,
		done = function(e)
			local r = C.GetBrowseResults() or {}
			Log("browse \"" .. (term.text or "") .. "\": " .. #r .. " results")
			onDone(r)
		end,
	})
end
PA.Browse = Browse   -- (the Crates tab's Refresh)
local function RunList(terms, title)
	PA.ClearQueue()
	shop.rows = {}
	shop.results:Set(shop.rows)
	local seen = {}       -- (an item found by two of the list's searches shows once)
	local left = #terms
	shop.status:SetText(("Searching %s... (%d to go)"):format(title, left))
	for _, term in ipairs(terms) do
		Browse(term, function(results)
			left = left - 1
			local want = term.exact and term.text and term.text:lower()
			for _, r in ipairs(results) do
				local name, qual, icon, commodity = KeyName(r.itemKey)
				if r.minPrice and r.minPrice > 0 then PA.Record(tostring(r.itemKey.itemID), r.minPrice) end
				-- an exact list item: only that item (the game's search also finds "Thick Leather Boots" for "Thick Leather");
				-- a name the game hasn't sent yet is kept until it arrives, then checked
				local unknown = name:match("^item %d+$")
				local key = r.itemKey.itemID .. ":" .. (r.itemKey.itemSuffix or 0)
				if (not want or unknown or name:lower() == want) and not seen[key] then
					if not unknown then seen[key] = true end
				local typical = PA.Typical(r.itemKey.itemID)
				local cheap = typical and r.minPrice and r.minPrice < typical * 0.85
				shop.rows[#shop.rows + 1] = { PA.QName(name, qual), (cheap and "|cff40ff40" or "") .. Money(r.minPrice, true) .. (cheap and "|r" or ""), r.totalQuantity or "",
					texture = icon, name = name, itemKey = r.itemKey, result = r, sk = { name, r.minPrice or 0, r.totalQuantity or 0 },
					tip = (name or "") .. "\nLowest " .. Money(r.minPrice) .. (typical and ("\nUsual " .. Money(typical)) or "") .. "\n\nClick to see the auctions in the Buy tab.",
					want = unknown and want or nil }
				end
			end
			if #results == 0 and S().showEmpty then
				shop.rows[#shop.rows + 1] = { "|cff888888" .. (term.text or "") .. "|r", "|cff888888none|r", "", name = term.text or "", sk = { term.text or "", math.huge, 0 } }
			end
			shop.results:Set(shop.rows, true)
			shop.status:SetText(left > 0 and ("Searching %s... (%d to go)"):format(title, left) or ("%s: %d result%s."):format(title, #shop.rows, #shop.rows == 1 and "" or "s"))
		end)
	end
end
-- names the game didn't have yet ("item 2840"): filled in as the game sends them
local nameFix = CreateFrame("Frame")
pcall(nameFix.RegisterEvent, nameFix, "ITEM_KEY_ITEM_INFO_RECEIVED"); pcall(nameFix.RegisterEvent, nameFix, "GET_ITEM_INFO_RECEIVED")
local nameFixPending
nameFix:SetScript("OnEvent", function()
	if nameFixPending or not (shop and shop.rows and shop.results) then return end
	nameFixPending = true
	C_Timer.After(0.3, function()
		nameFixPending = false
		local changed
		local function Key(r) return r.itemKey and (r.itemKey.itemID .. ":" .. (r.itemKey.itemSuffix or 0)) end
		local have = {}
		for _, r in ipairs(shop.rows) do if Key(r) and not (type(r.name) == "string" and r.name:match("^item %d+$")) then have[Key(r)] = true end end
		for i = #shop.rows, 1, -1 do
			local row = shop.rows[i]
			if row.itemKey and type(row.name) == "string" and row.name:match("^item %d+$") then
				local name, qual, icon = KeyName(row.itemKey)
				if not name:match("^item %d+$") then
					row[1] = PA.QName(name, qual); row.texture = icon or row.texture
					if row.tip then row.tip = row.tip:gsub("^item %d+", name, 1) end
					row.name = name; if row.sk then row.sk[1] = name end
					if (row.want and name:lower() ~= row.want) or have[Key(row)] then table.remove(shop.rows, i) else have[Key(row)] = true end
					row.want = nil
					changed = true
				end
			end
		end
		if changed then shop.results:Set(shop.rows, true) end
	end)
end)
local function BuildShop(p)
	local Btn, Label, Edit = PA.Btn, PA.Label, PA.Edit
	shop.box = Edit(p, W - 110); shop.box:SetPoint("TOPLEFT", 10, -6)
	local go = Btn(p, "Search", 80, 22); go:SetPoint("LEFT", shop.box, "RIGHT", 6, 0)
	local function Single()
		local t = shop.box:GetText()
		if t == "" then return end
		shop.box:ClearFocus()
		RunList({ { text = t } }, "\"" .. t .. "\"")
	end
	go:SetScript("OnClick", Single); shop.box:SetScript("OnEnterPressed", Single)
	shop.listBtn = Btn(p, "Shopping list...", 150, 22); shop.listBtn:SetPoint("TOPLEFT", 6, -32)
	shop.listBtn:SetScript("OnClick", function(self)
		local names = {}
		for n in pairs(PA.db.lists) do names[#names + 1] = n end
		table.sort(names)
		local items = {}
		for _, n in ipairs(names) do items[#items + 1] = { text = n .. "  |cff888888(" .. #PA.db.lists[n] .. ")|r", fn = function() shop.list = n; self:SetText(n); RunList(PA.db.lists[n], n) end } end
		if #items == 0 then items[1] = { text = "|cff888888no lists yet - /pah lists adds the starter ones|r" } end
		PA.Menu(self, items)
	end)
	local again = Btn(p, "Search again", 100, 22); again:SetPoint("LEFT", shop.listBtn, "RIGHT", 6, 0)
	again:SetScript("OnClick", function() if shop.list and PA.db.lists[shop.list] then RunList(PA.db.lists[shop.list], shop.list) else Single() end end)
	local RW = W - 20
	shop.results = PA.List(p, RW, 18, 16, { { RW - 150, "LEFT", "Item", sort = "asc" }, { 90, "RIGHT", "Lowest each", sort = "asc" }, { 50, "RIGHT", "Qty", sort = "desc" } },
		function(item) if item.itemKey then shop.results.selected = item; shop.results:Refresh(); OpenInBuy(item.itemKey, item.name, item.result) end end)
	shop.results:SetPoint("TOPLEFT", 10, -76)
	shop.status = Label(p, "Search for an item, or pick a shopping list. Green prices are below the usual price.", "GameFontDisableSmall")
	shop.status:SetPoint("TOPLEFT", shop.results, "BOTTOMLEFT", 0, -18); shop.status:SetWidth(RW); shop.status:SetJustifyH("LEFT")
	p.OnOpen = function()
		if shop.opened then return end
		shop.opened = true
		local d = S().defaultList
		if d and d ~= "" and PA.db.lists[d] then shop.list = d; shop.listBtn:SetText(d); if S().listAutoSearch then RunList(PA.db.lists[d], d) end end
	end
end

---------------------------------------------------------------- undercut check and cancelling
local uc = { rows = {} }
local function Search(itemKey, done)
	PA.Queue({
		what = "search item " .. tostring(itemKey.itemID),
		send = function() C.SendSearchQuery(itemKey, PRICE_SORT, true) end,
		events = {
			COMMODITY_SEARCH_RESULTS_UPDATED = function(id) return id == itemKey.itemID and CommodityArrived(id) end,
			ITEM_SEARCH_RESULTS_UPDATED = function(k) return type(k) == "table" and k.itemID == itemKey.itemID and ItemArrived(k) end,
		},
		timeout = 6,
		done = done,
	})
end
local function UCRefresh()
	table.sort(uc.rows, function(a, b) if a.under ~= b.under then return a.under end return (a.name or "") < (b.name or "") end)
	local data, n = {}, 0
	for _, r in ipairs(uc.rows) do
		if not r.gone then
			local state = r.under and "|cffff4040undercut|r" or (r.checked and (r.low and "|cff40ff40lowest|r" or "|cff40ff40only one|r") or "|cff888888...|r")
			data[#data + 1] = { PA.QName(r.name, r.quality), Money(r.mine, true), r.low and Money(r.low, true) or "", state,
				texture = r.icon, link = r.link, row = r, key = r.auctionID }
			if r.under then n = n + 1 end
		end
	end
	uc.list:Set(data, true)
	uc.cancelBtn:SetText(n > 0 and ("Cancel next undercut (" .. n .. ")") or "Cancel next undercut")
	uc.cancelBtn:SetEnabled(n > 0)
end
local function Check()
	PA.ClearQueue()
	uc.rows = {}
	uc.status:SetText("Asking for your auctions...")
	UCRefresh()
	PA.Queue({
		what = "owned auctions",
		send = function() C.QueryOwnedAuctions({}) end,
		events = { OWNED_AUCTIONS_UPDATED = function() return true end },
		timeout = 8,
		done = function(e)
			if not e then uc.status:SetText("The auction house didn't answer - try again."); return end
			local byItem = {}
			for _, a in ipairs(C.GetOwnedAuctions() or {}) do
				local sold = Enum.AuctionStatus and a.status == Enum.AuctionStatus.Sold
				if not sold and a.buyoutAmount and a.buyoutAmount > 0 and a.itemKey then
					local name, qual, icon, commodity = KeyName(a.itemKey)
					local r = { auctionID = a.auctionID, itemKey = a.itemKey, name = name, quality = qual, icon = icon, link = a.itemLink,
						qty = a.quantity or 1, buyout = a.buyoutAmount, commodity = commodity }
					uc.rows[#uc.rows + 1] = r
					local k = a.itemKey.itemID .. ":" .. (a.itemKey.itemLevel or 0) .. ":" .. (a.itemKey.itemSuffix or 0)
					byItem[k] = byItem[k] or {}; table.insert(byItem[k], r)
				end
			end
			if #uc.rows == 0 then uc.status:SetText("You have no auctions up."); UCRefresh(); return end
			local left = 0
			for _, list in pairs(byItem) do
				left = left + 1
				local key = list[1].itemKey
				Search(key, function(ev)
					left = left - 1
					local commodity = ev == "COMMODITY_SEARCH_RESULTS_UPDATED"
					local low
					if commodity then low = LowestCommodity(key.itemID) elseif ev then low = LowestItem(key) end
					for _, r in ipairs(list) do
						-- commodities list a price each; other items the price for the whole auction
						r.mine = (commodity or r.commodity) and r.buyout or r.buyout / math.max(1, r.qty)
						r.low, r.checked = low, ev ~= nil
						r.under = low ~= nil and low < r.mine and (r.mine - low) >= (S().aheadMin or 0)
					end
					if low then PA.Record(tostring(key.itemID), math.floor(low + 0.5)) end
					UCRefresh()
					uc.status:SetText(left > 0 and ("Checking prices... %d to go"):format(left) or "Done. Red ones have been undercut - cancel them and post again on the Sell tab.")
				end)
			end
			uc.status:SetText(("Checking prices... %d to go"):format(left))
			UCRefresh()
		end,
	})
end
local function CancelRow(r)
	if not r then return end
	if C.CanCancelAuction and not C.CanCancelAuction(r.auctionID) then Print("that auction can't be cancelled (it may have a bid on it)."); return end
	local cost = C.GetCancelCost and C.GetCancelCost(r.auctionID)
	C.CancelAuction(r.auctionID)
	r.gone = true
	Print("cancelled " .. (r.link or r.name or "?") .. (cost and cost > 0 and (" (cost " .. Money(cost) .. ")") or ""))
	UCRefresh()
end
local function BuildUndercut(p)
	local Btn, Label = PA.Btn, PA.Label
	local check = Btn(p, "Check my auctions", 150, 22); check:SetPoint("TOPLEFT", 6, -6)
	check:SetScript("OnClick", Check)
	uc.cancelBtn = Btn(p, "Cancel next undercut", 160, 22); uc.cancelBtn:SetPoint("LEFT", check, "RIGHT", 6, 0); uc.cancelBtn:Disable()
	uc.cancelBtn:SetScript("OnClick", function()
		for _, r in ipairs(uc.rows) do if r.under and not r.gone then CancelRow(r); return end end
	end)
	local RW = W - 20
	uc.list = PA.List(p, RW, 19, 16, { { RW - 200, "LEFT", "Item" }, { 70, "RIGHT", "Mine" }, { 70, "RIGHT", "Lowest" }, { 60, "RIGHT", "" } },
		function(item, b)
			uc.list.selectedKey = item.key; uc.list:Refresh()
			if b == "RightButton" or IsShiftKeyDown() then CancelRow(item.row) end
		end)
	uc.list:SetPoint("TOPLEFT", 10, -50)
	uc.status = Label(p, "Check finds which of your auctions are no longer the cheapest. Shift-click or right-click a row to cancel it.", "GameFontDisableSmall")
	uc.status:SetPoint("TOPLEFT", uc.list, "BOTTOMLEFT", 0, -18); uc.status:SetWidth(RW); uc.status:SetJustifyH("LEFT")
	pcall(q.RegisterEvent, q, "AUCTION_CANCELED")
end

---------------------------------------------------------------- deals (from full scans)
local deals = {}
function PA.RefreshDeals()
	if not deals.list then return end
	local d = PA.Deals()
	local data = {}
	for _, x in ipairs(d and d.list or {}) do
		local name, _, q, _, _, _, _, _, _, icon = GetItemInfo(x.link or x.key:match("^(%d+)"))
		data[#data + 1] = { PA.QName(name or x.key, q), Money(x.low, true), Money(x.avg, true), x.pct .. "%",
			texture = icon, link = x.link, name = name, id = tonumber(x.key:match("^(%d+)")), sk = { name or "", x.low, x.avg, x.pct } }
	end
	deals.list:Set(data)
	local n = PA.ScansThisWeek()
	deals.status:SetText(#data > 0 and ("%d deals from the last full scan. Click one to see it in the Buy tab."):format(#data)
		or ("No deals yet. Deals need %d full scans this week (you have %d) - one every 15 minutes or so."):format(S().dealMinScans or 5, n))
end
local function BuildDeals(p)
	local RW = W - 20
	deals.list = PA.List(p, RW, 20, 16, { { RW - 190, "LEFT", "Item", sort = "asc" }, { 70, "RIGHT", "Lowest", sort = "asc" }, { 70, "RIGHT", "Usual", sort = "desc" }, { 40, "RIGHT", "Off", sort = "desc" } },
		function(item) if item.id then OpenInBuy(C.MakeItemKey(item.id), item.name) end end)
	deals.list:SetPoint("TOPLEFT", 10, -22)
	deals.status = PA.Label(p, "", "GameFontDisableSmall")
	deals.status:SetPoint("TOPLEFT", deals.list, "BOTTOMLEFT", 0, -18); deals.status:SetWidth(RW); deals.status:SetJustifyH("LEFT")
	p.OnOpen = PA.RefreshDeals
end

---------------------------------------------------------------- build
local function Build()
	if panel or not AuctionHouseFrame then return end
	panel = CreateFrame("Frame", "PintsAuctionsSide", AuctionHouseFrame, "BackdropTemplate")
	panel:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 2, 0)
	panel:SetPoint("BOTTOMLEFT", AuctionHouseFrame, "BOTTOMRIGHT", 2, 0)
	panel:SetWidth(W)
	panel:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
	panel:SetBackdropColor(0, 0, 0, 0.92)
	-- a toggle on Blizzard's auction house title bar, next to its close button (remembered between visits)
	do
		local ah = AuctionHouseFrame
		local tb = PA.Btn(ah, "Pint's", 56, 20)
		local cb = ah.CloseButton or _G.AuctionHouseFrameCloseButton
		if cb then tb:SetPoint("RIGHT", cb, "LEFT", -2, 0) else tb:SetPoint("TOPRIGHT", ah, "TOPRIGHT", -30, -2) end
		tb:SetFrameStrata("HIGH"); tb:SetFrameLevel(((cb and cb:GetFrameLevel()) or ah:GetFrameLevel()) + 20); tb:Show()
		local function Apply() if PA.db and PA.db.sideHidden then panel:Hide() else panel:Show() end end
		tb:SetScript("OnClick", function() if PA.db then PA.db.sideHidden = not PA.db.sideHidden end; Apply() end)
		tb:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:AddLine("Show or hide Pint's Auctions"); GameTooltip:Show() end)
		tb:SetScript("OnLeave", function() GameTooltip:Hide() end)
		ah:HookScript("OnShow", Apply)
		C_Timer.After(0, Apply)
	end
	local title = PA.Label(panel, "|cffd4a017Pint's|r Auctions", "GameFontNormal"); title:SetPoint("TOPLEFT", 10, -9)
	-- a close button on the panel itself (the Pint's button on the auction house title bar opens it again)
	local x = CreateFrame("Button", nil, panel, "UIPanelCloseButton"); x:SetSize(24, 24); x:SetPoint("TOPRIGHT", -2, -2)
	x:SetScript("OnClick", function() if PA.db then PA.db.sideHidden = true end; panel:Hide() end)
	local opt = PA.Btn(panel, "Options", 64, 18); opt:SetPoint("TOPRIGHT", -28, -6)
	opt:SetScript("OnClick", function() if PA.OpenOptions then PA.OpenOptions() end end)
	local x = 8
	for _, t in ipairs({ { "shop", "Shopping" }, { "undercut", "Undercut" }, { "deals", "Deals" }, { "crates", "Crates" }, { "writs", "Writs" } }) do
		local b = PA.Btn(panel, t[2], 78, 22); b:SetPoint("TOPLEFT", x, -28); x = x + 81
		b:SetScript("OnClick", function() Show(t[1]) end)
		tabs[t[1]] = b
		local pg = CreateFrame("Frame", nil, panel); pg:SetPoint("TOPLEFT", 0, -54); pg:SetPoint("BOTTOMRIGHT", 0, 40); pg:Hide()
		pages[t[1]] = pg
	end
	BuildShop(pages.shop); BuildUndercut(pages.undercut); BuildDeals(pages.deals)
	if PA.BuildCrates then PA.BuildCrates(pages.crates) end -- Waylaid.lua
	if PA.BuildWrits then PA.BuildWrits(pages.writs) end -- Writs.lua
	-- full scan, along the bottom
	local sb = PA.Btn(panel, "Full scan", 90, 22); sb:SetPoint("BOTTOMLEFT", 8, 10)
	sb:SetScript("OnClick", function() PA.FullScan() end)
	local st = PA.Label(panel, "", "GameFontDisableSmall"); st:SetPoint("LEFT", sb, "RIGHT", 8, 0); st:SetWidth(W - 116); st:SetJustifyH("LEFT")
	local held = 0
	PA.OnScanState = function(text) st:SetText(text); held = GetTime() + 60 end
	local count = 0
	local function Idle()
		if PA.scanning or GetTime() < held then return end
		local w = PA.FullScanWait()
		sb:SetEnabled(w == 0)
		st:SetText(w > 0 and ("Next full scan in about " .. math.ceil(w / 60) .. " min.  " .. count .. " prices saved.") or ("Ready - prices for every item at once.  " .. count .. " saved."))
	end
	local tick = 0
	panel:SetScript("OnUpdate", function(_, e) tick = tick + e; if tick > 1 then tick = 0; Idle() end end)
	panel:SetScript("OnShow", function() count = PA.Count(); Idle() end)
	count = PA.Count()
	Idle()
	local t = S().defaultTab
	Show((t == "deals" or t == "cancel") and (t == "cancel" and "undercut" or "deals") or "shop")
end

---------------------------------------------------------------- events
q:SetScript("OnEvent", function(_, e, ...)
	if e ~= "AUCTION_HOUSE_CLOSED" then Log("event " .. e .. " " .. Arg((...))) end
	if e == "AUCTION_HOUSE_CLOSED" then
		PA.ClearQueue(); sell.pending = nil
		if PA.scanning then PA.scanning = nil; Print("full scan stopped - the auction house closed.") end
		return
	end
	if e == "REPLICATE_ITEM_LIST_UPDATE" then
		if PA.scanning == "waiting" then
			PA.scanning = "reading"
			scan = { i = 0, total = C.GetNumReplicateItems() or 0, lows = {}, all = {}, links = {} }
			Log("replicate list: " .. scan.total)
			if PA.OnScanState then PA.OnScanState(("Reading %d auctions..."):format(scan.total)) end
		end
		return
	end
	if e == "AUCTION_CANCELED" then return end
	-- prices from every result the auction house sends, and the sell tab's undercut
	if e == "COMMODITY_SEARCH_RESULTS_UPDATED" then pcall(RecordCommodity, (...))
	elseif e == "ITEM_SEARCH_RESULTS_UPDATED" and type((...)) == "table" then pcall(RecordItem, (...)) end
	OnSellResults(e, ...)
	-- the request we're waiting on
	if cur and cur.events and cur.events[e] and cur.events[e](...) then
		local r = cur; cur = nil
		if r.done then r.done(e, ...) end
	end
end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("AUCTION_HOUSE_SHOW")
ev:SetScript("OnEvent", function()
	C_Timer.After(0, function() Build(); HookSell() end)
end)

---------------------------------------------------------------- a list made elsewhere (Pint's Professions' shopping list)
function PA.OpenList(name)
	local terms = PA.db and PA.db.lists[name]
	if not terms then return end
	shop.list = name
	if shop.listBtn then shop.listBtn:SetText(name) end
	if AuctionHouseFrame and AuctionHouseFrame:IsShown() then RunList(terms, name) end
end

---------------------------------------------------------------- your auctions: what's sold and what's still listed
-- A line at the bottom of Blizzard's Auctions tab: how many of your auctions sold and for how much (the gold on its
-- way by mail), and how many are still up and what they'd bring.
do
	local line
	local SOLD = Enum and Enum.AuctionStatus and Enum.AuctionStatus.Sold or 1
	local function Totals()
		local f = AuctionHouseFrame and AuctionHouseFrame.AuctionsFrame
		if not (f and C.GetNumOwnedAuctions and C.GetOwnedAuctionInfo) then return end
		if not line then
			line = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			local anchor = f.CancelAuctionButton or f
			line:SetPoint("RIGHT", anchor, "LEFT", -12, 0); line:SetJustifyH("RIGHT")
		end
		local sN, sG, lN, lG, sA, lA = 0, 0, 0, 0, 0, 0
		for i = 1, C.GetNumOwnedAuctions() or 0 do
			local a = C.GetOwnedAuctionInfo(i)
			if a then
				local q = a.quantity or 1
				local v = a.buyoutAmount or a.bidAmount or 0
				if a.status == SOLD then sA = sA + 1; sN = sN + q; sG = sG + v
				else lA = lA + 1; lN = lN + q; lG = lG + v end
			end
		end
		line:SetText(("|cff40ff40Sold:|r %d (%d auctions)  %s     |cffffd100Listed:|r %d (%d auctions)  %s"):format(sN, sA, Money(sG), lN, lA, Money(lG)))
	end
	local t = CreateFrame("Frame")
	for _, e in ipairs({ "OWNED_AUCTIONS_UPDATED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_AUCTION_CREATED", "AUCTION_CANCELED" }) do pcall(t.RegisterEvent, t, e) end
	t:SetScript("OnEvent", function() C_Timer.After(0.2, function() pcall(Totals) end) end)
end
