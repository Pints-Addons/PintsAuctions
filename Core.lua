-- Pint's Auctions - core: price database, tooltip prices, the auction query engine, the full scan.
local ADDON, NS = ...
-- Compatibility: WoW Forever runs on the modern game client, where these older functions moved or were renamed.
local GetItemInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)
local IsAddOnLoaded = IsAddOnLoaded or (C_AddOns and C_AddOns.IsAddOnLoaded)

local PA = {}
NS.PA = PA
_G.PintsAuctions = PA

-- data shared by the whole account
local DATA = { prices = {}, lists = {}, history = {}, lastAll = {}, minimap = {}, settings = {}, scans = {}, deals = {} }
-- settings (account-wide, or per character when that's switched on)
local SETTINGS = {
	-- basic
	defaultTab = "none", craftCost = true, craftProfit = true,
	-- tooltips
	tooltip = true, tipTypical = true, tipVendor = true, tipAge = true, tipShiftStack = false,
	-- shopping
	defaultList = "", listAutoSearch = true, showEmpty = true, allPages = false,
	chainBuy = true, chainWarn = true, chainJump = 0.20, chainJumpFirst = 0.40,
	-- deals (from full scans): an item needs this many scans in the last dealDays before it's judged
	dealMinScans = 5, dealDays = 7, dealMinSavings = 1000, dealTier = 30,   -- after a buy, line up the next stack; warn when it costs 20%+ more each
	-- selling
	chatPosts = true, useBid = false, bidPct = 0.95, confirmLow = true, lowWarn = 0.5, greyPost = true,
	autoNext = true, duration = 3, rememberDur = true, undercutMode = "value", undercut = 1, undercutPct = 2,
	stackMode = "max", gearMult = 3, ignoreSuffix = false,
	-- shortcuts
	altSell = true, spacePost = true, shiftSkip = true, bsPrev = true,
	-- cancelling
	aheadMin = 0, spaceCancel = true,
	-- advanced
	debug = false,
}
PA.SETTINGS = SETTINGS
local db, S
PA.ME = UnitName("player")
function PA.Print(m) print("|cffd4a017Pint's Auctions:|r " .. m) end
local Print = PA.Print
function PA.Debug(m) if S and S.debug then print("|cff888888PAH debug:|r " .. m) end end

---------------------------------------------------------------- money
function PA.Money(v, short)
	if not v then return "|cff888888-|r" end
	v = math.floor(v + 0.5)
	local g, s, c = math.floor(v / 10000), math.floor(v / 100) % 100, v % 100
	local G, S, C = "|cffffd700g|r", "|cffc7c7cfs|r", "|cffeda55fc|r"
	if short and g >= 100 then return g .. G end
	if g > 0 then return ("%d%s %02d%s %02d%s"):format(g, G, s, S, c, C) end
	if s > 0 then return ("%d%s %02d%s"):format(s, S, c, C) end
	return c .. C
end
-- "1g 20s 5c", "1.5g", "250" (copper) or "1 20 5" -> copper
function PA.ParseMoney(t)
	if not t then return nil end
	t = t:lower():gsub("%s+", " ")
	local total, any = 0, false
	for n, u in t:gmatch("([%d%.]+)%s*([gsc]?)") do
		local v = tonumber(n)
		if v then
			any = true
			if u == "g" then total = total + v * 10000 elseif u == "s" then total = total + v * 100 elseif u == "c" then total = total + v
			else total = total + v end
		end
	end
	if not any then return nil end
	return math.floor(total + 0.5)
end

---------------------------------------------------------------- price database
-- prices are kept per realm and faction, shared by every character there. WoW Forever can report the realm as blank
-- for a moment at login, which filed scans under " Horde" apart from the realm's own (each character then saw a
-- different scan): the last realm seen stands in until the game names it, and the blank-realm data is merged back.
local function OkRealm(r) return type(r) == "string" and r ~= "" and r ~= "?" and not (type(issecretvalue) == "function" and issecretvalue(r)) end
local function KnownRealm()
	local r = GetRealmName and GetRealmName()
	if OkRealm(r) then return r end
	r = PintsLedgerDB and PintsLedgerDB.lastRealm         -- (Pint's Alts' last realm: Forever can hide it all session)
	if OkRealm(r) then return r end
end
local function Realm()
	local r = KnownRealm()
	if r then
		if PintsAuctionsDB then PintsAuctionsDB.lastRealm = r end
		return r
	end
	return (PintsAuctionsDB and PintsAuctionsDB.lastRealm) or "?"
end
local function RF() return Realm() .. " " .. (UnitFactionGroup("player") or "") end
PA.RF = RF
local function MergeBlankRealm()
	local r = KnownRealm() or (db and db.lastRealm)
	local fac = UnitFactionGroup("player")
	if not (db and OkRealm(r) and fac) then return false end
	local good, blank = r .. " " .. fac, " " .. fac
	-- prices: per item the newer look wins, and the daily lows of both are kept
	local bp, gp = db.prices and db.prices[blank], db.prices and db.prices[good]
	if bp then
		if not gp then db.prices[good] = bp
		else
			for key, e in pairs(bp) do
				local g = gp[key]
				if not g then gp[key] = e
				else
					local h = {}
					for d, v in pairs(g.h or {}) do h[d] = v end
					for d, v in pairs(e.h or {}) do h[d] = h[d] and math.min(h[d], v) or v end
					if (e.t or 0) > (g.t or 0) then gp[key] = e; e.h = h else g.h = h end
				end
			end
		end
		db.prices[blank] = nil
	end
	-- this week's full scans (for deals): both lists, oldest first
	local bs, gs = db.scans and db.scans[blank], db.scans and db.scans[good]
	if bs then
		if not gs then db.scans[good] = bs
		else
			for key, list in pairs(bs) do
				if type(list) ~= "table" or type(gs[key]) ~= "table" then gs[key] = gs[key] or list
				else for _, x in ipairs(list) do table.insert(gs[key], x) end end
			end
		end
		db.scans[blank] = nil
	end
	if db.lastAll and db.lastAll[blank] then db.lastAll[good] = math.max(db.lastAll[good] or 0, db.lastAll[blank]); db.lastAll[blank] = nil end
	if db.deals and db.deals[blank] then
		if not db.deals[good] or (db.deals[blank].t or 0) > (db.deals[good].t or 0) then db.deals[good] = db.deals[blank] end
		db.deals[blank] = nil
	end
	return true
end
local function Today() return math.floor(time() / 86400) end
-- "id" or "id:suffix" for random-suffix items ("of the Bear")
function PA.Key(linkOrID)
	if type(linkOrID) == "number" then return tostring(linkOrID) end
	if not linkOrID then return nil end
	local id, rest = linkOrID:match("item:(%d+):?([^|]*)")
	if not id then
		local n = tonumber(linkOrID); return n and tostring(n) or nil
	end
	local f = {}
	for v in (rest or ""):gmatch("([^:]*):?") do f[#f + 1] = v end
	local suffix = f[6]
	if suffix and suffix ~= "" and suffix ~= "0" then return id .. ":" .. suffix end
	return id
end
local function Store() db.prices[RF()] = db.prices[RF()] or {}; return db.prices[RF()] end
function PA.Record(key, unit)
	if not key or not unit or unit <= 0 then return end
	local s = Store()
	local e = s[key] or { h = {} }
	s[key] = e
	local d = Today()
	if e.d ~= d or not e.m or unit < e.m then
		if e.d ~= d then e.m = unit else e.m = math.min(e.m, unit) end
	end
	e.d, e.t = d, time()
	e.l = unit            -- the lowest at the latest look (the day's low stays in e.m and the history)
	e.none = nil
	e.h = e.h or {}
	e.h[d] = math.min(e.h[d] or unit, unit)
	for day in pairs(e.h) do if day < d - 30 then e.h[day] = nil end end
end
-- searched for and none listed: no price until it's seen again (the last one is kept for the history)
function PA.RecordNone(key)
	if not key then return end
	local s = Store()
	local e = s[key]
	if e then e.none = time() end
end
-- after a full scan: everything that wasn't listed at all is marked "none listed" (its old price is kept for the history)
function PA.MarkUnseen(seen)
	local s, now, n = Store(), time(), 0
	for key, e in pairs(s) do
		if not seen[key] and not seen[key:match("^(%d+)") or key] and not (e.none and e.none >= (e.t or 0)) then e.none = now; n = n + 1 end
	end
	return n
end
-- the lowest price at the latest look, and when that was (a cheaper one seen earlier today may be sold by now)
function PA.Price(linkOrID)
	local key = PA.Key(linkOrID)
	if not key then return end
	local s = db and db.prices[RF()]
	local base = key:match("^(%d+)")
	local e = s and ((S and S.ignoreSuffix and s[base]) or s[key] or s[base])
	if e and e.none and e.none >= (e.t or 0) then return nil, e.none, true end   -- (none listed at the latest look)
	if e then return e.l or e.m, e.t end
end
-- the typical price over the last two weeks (median of daily lows)
function PA.Typical(linkOrID)
	local key = PA.Key(linkOrID)
	local s = key and db and db.prices[RF()]
	local e = s and s[key]
	if not e or not e.h then return end
	local v, d = {}, Today()
	for day, p in pairs(e.h) do if day >= d - 14 then v[#v + 1] = p end end
	if #v == 0 then return end
	table.sort(v)
	return v[math.floor((#v + 1) / 2)]
end
-- daily lows for the last month, newest first: { {day, price, daysAgo}, ... }
function PA.History(linkOrID)
	local key = PA.Key(linkOrID)
	local s = key and db and db.prices[RF()]
	local e = s and (s[key] or s[key:match("^(%d+)")])
	local out = {}
	if not e or not e.h then return out end
	local d = Today()
	for day, p in pairs(e.h) do out[#out + 1] = { day, p, d - day } end
	table.sort(out, function(a, b) return a[1] > b[1] end)
	return out
end
function PA.Count()
	local s = db and db.prices[RF()]
	local n = 0
	if s then for _ in pairs(s) do n = n + 1 end end
	return n
end
function PA.Ago(t)
	if not t then return "" end
	local d = time() - t
	if d < 3600 then return math.max(1, math.floor(d / 60)) .. " min ago" end
	if d < 86400 then return math.floor(d / 3600) .. " hr ago" end
	return math.floor(d / 86400) .. " days ago"
end

-- for add-ons that ask Auctionator for prices (Pint's Disenchant and others), when Auctionator isn't loaded
local function CompatAPI()
	if _G.Auctionator then return end
	_G.Auctionator = { API = { v1 = {
		GetAuctionPriceByItemLink = function(_, link) return (PA.Price(link)) end,
		GetAuctionPriceByItemID = function(_, id) return (PA.Price(id)) end,
	} }, PintsAuctions = true }
end

---------------------------------------------------------------- tooltip
local function BagCount(tt, link)
	local owner = tt:GetOwner()
	if owner and owner.GetParent and owner:GetParent() then
		local bag, slot = owner:GetParent():GetID(), owner:GetID()
		if bag and slot and C_Container and C_Container.GetContainerItemInfo then
			local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
			if ok and info and info.hyperlink == link then return info.stackCount end
		end
	end
end
-- recipe tooltips report their item twice: add our lines once
local tipDone = setmetatable({}, { __mode = "k" })
local cleared = {}
local function ItemTip(tt)
	if not S then return end
	local _, link = tt:GetItem()
	if not link then return end
	if not cleared[tt] and tt.HookScript then cleared[tt] = true; tt:HookScript("OnTooltipCleared", function(t) tipDone[t] = nil end) end
	if tipDone[tt] == link then return end
	tipDone[tt] = link
	local count = BagCount(tt, link)
	local showStack = count and count > 1 and (not S.tipShiftStack or IsShiftKeyDown())
	local added
	local function line(label, v)
		tt:AddDoubleLine(label, PA.Money(v) .. (showStack and ("  |cffaaaaaax" .. count .. "|r " .. PA.Money(v * count)) or ""), 0.4, 0.8, 1, 1, 1, 1)
		added = true
	end
	if S.tooltip then
		local p, t = PA.Price(link)
		if p then
			local age = (S.tipAge and t and time() - t > 86400 * 2) and ("|cff888888 (" .. PA.Ago(t) .. ")|r") or ""
			line("Auction" .. age, p)
		end
		if S.tipTypical then
			local ty = PA.Typical(link)
			if ty and ty ~= p then line("Auction, usual", ty) end
		end
	end
	if S.tipVendor then
		local v = select(11, GetItemInfo(link))
		if v and v > 0 and not (MerchantFrame and MerchantFrame:IsShown()) then line("Vendor", v) end
	end
	if added then tt:Show() end
end
local function HookTooltips()
	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt)
			if tt == GameTooltip or tt == ItemRefTooltip then ItemTip(tt) end
		end)
	else
		GameTooltip:HookScript("OnTooltipSetItem", ItemTip)
		if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", ItemTip) end
	end
end

---------------------------------------------------------------- query engine (one search at a time, paged)
-- job = { text, minLevel, maxLevel, quality, usable, exact, maxPages, page, onRow(row), onPage(page, n, total), onDone() }
local jobs, job, waiting, sentAt = {}, nil, false, 0
local engine = CreateFrame("Frame")
function PA.Busy() return job ~= nil or #jobs > 0 or PA.scanning end
function PA.Search(j)
	j.page = j.page or 0
	j.maxPages = j.maxPages or 20
	jobs[#jobs + 1] = j
end
function PA.CancelSearches() wipe(jobs); job = nil; waiting = false end
local function ReadRow(i)
	local name, texture, count, quality, canUse, level, _, minBid, minInc, buyout, bidAmount, highBidder, _, owner, _, saleStatus, itemID, hasAll =
		GetAuctionItemInfo("list", i)
	if not name then return end
	return { index = i, name = name, texture = texture, count = count or 1, quality = quality, level = level, minBid = minBid, minInc = minInc,
		buyout = buyout or 0, bid = bidAmount, high = highBidder, owner = owner, itemID = itemID, link = GetAuctionItemLink("list", i), complete = hasAll }
end
PA.ReadRow = ReadRow
local function Send()
	if not job then return end
	local q = job
	PA.Debug(("query \"%s\" page %d"):format(q.text or "", q.page))
	QueryAuctionItems(q.text or "", q.minLevel, q.maxLevel, q.page, q.usable, q.quality, false, q.exact or false, nil)
	waiting, sentAt = true, GetTime()
end
local function PageDone()
	local q = job
	waiting = false
	local n, total = GetNumAuctionItems("list")
	for i = 1, n do
		local r = ReadRow(i)
		if r then
			r.page = q.page
			if q.onRow then q.onRow(r) end
		end
	end
	if q.onPage then q.onPage(q.page, n, total) end
	if (q.page + 1) * (NUM_AUCTION_ITEMS_PER_PAGE or 50) < (total or 0) and q.page + 1 < q.maxPages and not q.stop then
		q.page = q.page + 1
	else
		job = nil
		if q.onDone then q.onDone(total or 0) end
	end
end
engine:SetScript("OnUpdate", function()
	if PA.scanning then return end
	if not (AuctionFrame and AuctionFrame:IsShown()) then if job or #jobs > 0 then PA.CancelSearches() end; return end
	if waiting then
		if GetTime() - sentAt > 8 then waiting = false end      -- no answer: try the page again
		return
	end
	if not job then job = table.remove(jobs, 1) end
	if job and CanSendAuctionQuery() then Send() end
end)
pcall(engine.RegisterEvent, engine, "AUCTION_ITEM_LIST_UPDATE")   -- (not on WoW Forever: Modern.lua does its auction house)
engine:SetScript("OnEvent", function()
	if PA.scanning then PA.ScanArrived(); return end
	if waiting and job then
		-- give the game a moment to fill in sellers and links
		C_Timer.After(0.15, function() if waiting and job then PageDone() end end)
	end
end)

---------------------------------------------------------------- full scan (every auction at once; the game allows it every 15 minutes)
local scanRows, scanI, scanTotal, scanLows, scanAll, scanLinks
function PA.CanFullScan()
	local _, all = CanSendAuctionQuery()
	return all and not PA.scanning
end
function PA.FullScanWait()
	local t = db.lastAll[RF()]
	if not t then return 0 end
	return math.max(0, 15 * 60 - (time() - t))
end
function PA.FullScan()
	if not PA.CanFullScan() then
		local w = PA.FullScanWait()
		Print(w > 0 and ("the auction house allows a full scan every 15 minutes - about " .. math.ceil(w / 60) .. " min to go.") or "the auction house isn't ready for a full scan yet.")
		return
	end
	PA.CancelSearches()
	PA.scanning, scanI, scanLows, scanAll, scanLinks = "waiting", 0, {}, {}, {}
	db.lastAll[RF()] = time()
	if PA.OnScanState then PA.OnScanState("Asking the auction house for everything...") end
	QueryAuctionItems("", nil, nil, 0, nil, nil, true, false, nil)
end
function PA.ScanArrived()
	if PA.scanning ~= "waiting" then return end
	PA.scanning = "reading"
	scanTotal = GetNumAuctionItems("list")
	scanI = 0
	if PA.OnScanState then PA.OnScanState(("Reading %d auctions..."):format(scanTotal)) end
end
local reader = CreateFrame("Frame")
reader:SetScript("OnUpdate", function()
	-- (the Classic scan reader: WoW Forever's own scan in Modern.lua also says "reading", so make sure this one started it)
	if PA.scanning ~= "reading" or not scanI or not scanTotal or not GetAuctionItemInfo then return end
	local stop = math.min(scanTotal, scanI + 400)
	for i = scanI + 1, stop do
		local _, _, count, _, _, _, _, _, _, buyout, _, _, _, owner = GetAuctionItemInfo("list", i)
		if buyout and buyout > 0 then
			local link = GetAuctionItemLink("list", i)
			local key = link and PA.Key(link)
			if key then
				local unit = buyout / math.max(1, count or 1)
				-- every listing (not just the lowest), for the market average and the Deals tab
				local l = scanAll[key]; if not l then l = {}; scanAll[key] = l; scanLinks[key] = link end
				l[#l + 1] = { unit, count or 1, owner == PA.ME }
				if not scanLows[key] or unit < scanLows[key] then scanLows[key] = unit end
				local base = key:match("^(%d+):")
				if base and (not scanLows[base] or unit < scanLows[base]) then scanLows[base] = unit end
			end
		end
	end
	scanI = stop
	if PA.OnScanState then PA.OnScanState(("Reading auctions... %d%%"):format(math.floor(scanI / math.max(1, scanTotal) * 100))) end
	if scanI >= scanTotal then
		local n = 0
		for key, unit in pairs(scanLows) do PA.Record(key, math.floor(unit + 0.5)); n = n + 1 end
		local deals = PA.RecordScan(scanAll, scanLinks)
		scanAll, scanLinks = nil, nil
		PA.scanning = nil
		if deals and deals > 0 then Print(("%d deal%s found - see the Deals tab."):format(deals, deals == 1 and "" or "s")) end
		Print(("full scan done - prices for %d items from %d auctions."):format(n, scanTotal))
		if PA.OnScanState then PA.OnScanState(("Last full scan: %d items, just now."):format(n)) end
	end
end)

---------------------------------------------------------------- deals: market averages from full scans
-- each full scan stores, per item: when, the market price (median of every listing, weighted by quantity), lowest, quantity
-- kept for dealDays (a week); once an item has dealMinScans scans, listings well under its average are deals
local function Median(list)
	table.sort(list, function(a, b) return a[1] < b[1] end)
	local total = 0
	for _, x in ipairs(list) do total = total + x[2] end
	local half, run = total / 2, 0
	for _, x in ipairs(list) do run = run + x[2]; if run >= half then return x[1], total end end
	return list[#list][1], total
end
function PA.RecordScan(all, links)
	if not all then return 0 end
	local scans = db.scans[RF()] or {}; db.scans[RF()] = scans
	local now, keep = time(), (S.dealDays or 7) * 86400
	local need = S.dealMinScans or 5
	local found = {}
	for key, list in pairs(all) do
		local others = {}
		for _, x in ipairs(list) do if not x[3] then others[#others + 1] = x end end   -- not your own
		if #others > 0 then
			local med, qty = Median(others)
			local low = others[1][1]
			-- the item's earlier scans this week
			local h = scans[key]
			if type(h) ~= "table" then h = {}; scans[key] = h end
			local i = 1
			while i <= #h do if now - h[i][1] > keep then table.remove(h, i) else i = i + 1 end end
			if #h + 1 >= need then
				local sum = 0
				for _, e in ipairs(h) do sum = sum + e[2] end
				local avg = sum / #h
				if avg > 0 and low <= avg * 0.7 then
					-- every listing at least 30% under: what it costs to buy them and what you'd save against the average
					-- for each line (30/50/70% under): how many, what they cost, what you'd save against the average
					local tiers = {}
					for _, t in ipairs({ 30, 50, 70 }) do
						local line, cnt, cost, save = avg * (1 - t / 100), 0, 0, 0
						for _, x in ipairs(others) do
							if x[1] <= line then cnt = cnt + x[2]; cost = cost + x[1] * x[2]; save = save + (avg - x[1]) * x[2] end
						end
						if cnt > 0 then tiers[t] = { qty = cnt, cost = math.floor(cost + 0.5), save = math.floor(save + 0.5) } end
					end
					if tiers[30] and tiers[30].save >= (S.dealMinSavings or 0) then
						found[#found + 1] = { key = key, link = links[key], low = math.floor(low + 0.5), avg = math.floor(avg + 0.5),
							pct = math.floor((1 - low / avg) * 100 + 0.5), tiers = tiers, save = tiers[30].save, scans = #h + 1 }
					end
				end
			end
			h[#h + 1] = { now, math.floor(med + 0.5), math.floor(low + 0.5), qty }
			while #h > 10 do table.remove(h, 1) end          -- the 10 most recent are plenty (and keep the saved file small)
		end
	end
	-- items not seen this scan: drop their old scans too
	for key, h in pairs(scans) do
		if not all[key] and type(h) == "table" then
			local i = 1
			while i <= #h do if now - h[i][1] > keep then table.remove(h, i) else i = i + 1 end end
			if #h == 0 then scans[key] = nil end
		end
	end
	table.sort(found, function(a, b) return a.save > b.save end)
	db.deals[RF()] = { t = now, list = found }
	return #found
end
function PA.Deals() return db and db.deals[RF()] end
function PA.ScanCount(key)
	local h = db and db.scans[RF()] and db.scans[RF()][key]
	return type(h) == "table" and #h or 0
end
-- how many full scans this week have been stored (the most any item has)
function PA.ScansThisWeek()
	local s, most = db and db.scans[RF()], 0
	if s then for _, h in pairs(s) do if type(h) == "table" and #h > most then most = #h end end end
	return most
end

---------------------------------------------------------------- start-up
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED"); ev:RegisterEvent("PLAYER_LOGIN"); ev:RegisterEvent("AUCTION_HOUSE_CLOSED")
ev:SetScript("OnEvent", function(_, e, a1)
	if e == "ADDON_LOADED" and a1 == ADDON then
		PintsAuctionsDB = PintsAuctionsDB or {}
		db = PintsAuctionsDB
		for k in pairs(DATA) do if type(db[k]) ~= "table" then db[k] = {} end end
		PintsAuctionsCharDB = PintsAuctionsCharDB or {}
		PintsAuctionsCharDB.settings = PintsAuctionsCharDB.settings or {}
		PA.db = db
		PA.UseProfile()
		PA.AddStarterLists()
	elseif e == "PLAYER_LOGIN" then
		do local n = 0; local function Try() n = n + 1; if not MergeBlankRealm() and n < 30 then C_Timer.After(2, Try) end end; C_Timer.After(1, Try) end
		HookTooltips()
		CompatAPI()
		if PA.BuildMinimap then PA.BuildMinimap() end
		if PA.AuctionatorLoaded() then Print("Auctionator is on too - /pah off-auctionator to switch it off, then /reload.") end
	elseif e == "AUCTION_HOUSE_CLOSED" then
		PA.CancelSearches()
		if PA.scanning then PA.scanning = nil; Print("full scan stopped - the auction house closed.") end
	end
end)
-- starter shopping lists, added once (delete or edit them freely - they won't come back; /pah lists adds them again)
local STARTER_LISTS = {
	{ "Cloth", { "Linen Cloth", "Wool Cloth", "Silk Cloth", "Mageweave Cloth", "Runecloth", "Felcloth", "Mooncloth" } },
	{ "Ore", { "Copper Ore", "Tin Ore", "Silver Ore", "Iron Ore", "Gold Ore", "Mithril Ore", "Truesilver Ore", "Thorium Ore", "Dark Iron Ore", "Elementium Ore" } },
	{ "Bars", { "Copper Bar", "Tin Bar", "Bronze Bar", "Silver Bar", "Iron Bar", "Steel Bar", "Gold Bar", "Mithril Bar", "Truesilver Bar", "Thorium Bar", "Dark Iron Bar", "Arcanite Bar", "Elementium Bar" } },
	{ "Enchanting Supplies", { "Strange Dust", "Soul Dust", "Vision Dust", "Dream Dust", "Illusion Dust", "Lesser Magic Essence", "Greater Magic Essence", "Lesser Astral Essence", "Greater Astral Essence", "Lesser Mystic Essence", "Greater Mystic Essence", "Lesser Nether Essence", "Greater Nether Essence", "Lesser Eternal Essence", "Greater Eternal Essence", "Small Glimmering Shard", "Large Glimmering Shard", "Small Glowing Shard", "Large Glowing Shard", "Small Radiant Shard", "Large Radiant Shard", "Small Brilliant Shard", "Large Brilliant Shard", "Nexus Crystal" } },
	{ "Herbs", { "Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Swiftthistle", "Stranglekelp", "Bruiseweed", "Wild Steelbloom", "Grave Moss", "Kingsblood", "Liferoot", "Fadeleaf", "Goldthorn", "Khadgar's Whisker", "Wintersbite", "Firebloom", "Purple Lotus", "Wildvine", "Arthas' Tears", "Sungrass", "Blindweed", "Ghost Mushroom", "Gromsblood", "Golden Sansam", "Dreamfoil", "Mountain Silversage", "Plaguebloom", "Icecap", "Black Lotus" } },
	{ "Leather", { "Ruined Leather Scraps", "Light Leather", "Medium Leather", "Heavy Leather", "Thick Leather", "Rugged Leather", "Light Hide", "Medium Hide", "Heavy Hide", "Thick Hide", "Rugged Hide", "Devilsaur Leather", "Warbear Leather", "Chimera Leather", "Frostsaber Leather", "Core Leather", "Enchanted Leather", "Worn Dragonscale", "Black Dragonscale", "Red Dragonscale", "Green Dragonscale", "Blue Dragonscale", "Heavy Scorpid Scale", "Scorpid Scale", "Turtle Scale" } },
	{ "Engineering Parts", { "Rough Blasting Powder", "Coarse Blasting Powder", "Heavy Blasting Powder", "Solid Blasting Powder", "Dense Blasting Powder", "Handful of Copper Bolts", "Copper Tube", "Copper Modulator", "Bronze Tube", "Whirring Bronze Gizmo", "Bronze Framework", "Silver Contact", "Gyrochronatom", "Iron Strut", "Gold Power Core", "Mithril Tube", "Unstable Trigger", "Mithril Casing", "Thorium Widget", "Thorium Tube", "Delicate Arcanite Converter", "Fused Wiring" } },
}
function PA.AddStarterLists(force)
	if db.starterLists and not force then return end
	db.lists = db.lists or {}
	local added = 0
	for _, l in ipairs(STARTER_LISTS) do
		-- a list you already have with the same name keeps everything in it; only the missing items are added
		local terms = db.lists[l[1]]
		if not terms then terms = {}; db.lists[l[1]] = terms end
		local have = {}
		for _, t in ipairs(terms) do if t.text then have[t.text:lower()] = true end end
		local n = 0
		for _, name in ipairs(l[2]) do
			if not have[name:lower()] then terms[#terms + 1] = { text = name, exact = true }; n = n + 1 end
		end
		if n > 0 then added = added + 1 end
	end
	db.starterLists = true
	return added
end
-- which settings table is in use: the account's, or this character's own
function PA.UseProfile()
	local c = PintsAuctionsCharDB
	S = c.perChar and c.settings or db.settings
	for k, v in pairs(SETTINGS) do if S[k] == nil then S[k] = v end end
	PA.S = S
end
function PA.SetPerCharacter(on)
	local c = PintsAuctionsCharDB
	if on and not next(c.settings) then for k, v in pairs(db.settings) do c.settings[k] = v end end
	c.perChar = on and true or nil
	PA.UseProfile()
end
function PA.ResetSettings() wipe(S); PA.UseProfile() end
local function Loaded(a) if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(a) end return IsAddOnLoaded and IsAddOnLoaded(a) end
function PA.AuctionatorLoaded() return Loaded("Auctionator") end
function PA.AuctionatorOff()
	local off = (C_AddOns and C_AddOns.DisableAddOn) or DisableAddOn
	pcall(off, "Auctionator")
	Print("Auctionator switched off - /reload to finish.")
end
