-- Pint's Auctions - DEALS
-- Items listed well under their usual price. Every full scan stores each item's market price (the middle of all its
-- listings); once an item has 5 scans from the last week, any listing 30%, 50% or 70% under its average is a deal.
local ADDON, NS = ...
-- Compatibility: WoW Forever runs on the modern game client, where these older functions moved or were renamed.
local GetItemInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)

local PA = NS.PA
local function S() return PA.S end
local Money = PA.Money

function PA.BuildDeals(p)
	local Label, Btn, List = PA.Label, PA.Btn, PA.List
	local tier = S().dealTier or 30
	local h = Label(p, "Deals", "GameFontNormalLarge"); h:SetPoint("TOPLEFT", 4, -4)
	local info = Label(p, "", "GameFontHighlightSmall"); info:SetPoint("TOPLEFT", 4, -26); info:SetWidth(470); info:SetJustifyH("LEFT")

	-- 30 / 50 / 70% under
	local tb = {}
	local x = 480
	for _, t in ipairs({ 30, 50, 70 }) do
		local b = Btn(p, t .. "%+ under", 92, 22); b:SetPoint("TOPLEFT", x, -4); x = x + 96
		b:SetScript("OnClick", function() tier = t; S().dealTier = t; p.OnOpen() end)
		tb[t] = b
	end
	local scan = Btn(p, "Full scan", 100, 22); scan:SetPoint("TOPLEFT", 480, -30)
	scan:SetScript("OnClick", function() PA.FullScan() end)
	local state = Label(p, "", "GameFontDisableSmall"); state:SetPoint("LEFT", scan, "RIGHT", 8, 0); state:SetWidth(180); state:SetJustifyH("LEFT")

	local W = 762
	local list = List(p, W, 13, 16, {
		{ W - 520, "LEFT", "Item", sort = "asc" }, { 80, "RIGHT", "Price now", sort = true }, { 80, "RIGHT", "Average", sort = true },
		{ 60, "RIGHT", "Under", sort = true }, { 50, "RIGHT", "Qty", sort = true }, { 120, "RIGHT", "Cost to buy", sort = true },
		{ 110, "RIGHT", "Savings", sort = true },
	}, function(item)
		-- open it on the Shopping tab with live prices, ready to buy
		PA.SelectTab("shop")
		C_Timer.After(0, function() if PA.OpenItem then PA.OpenItem({ name = item.name, key = item.key }) end end)
	end)
	list:SetPoint("TOPLEFT", 0, -70)
	-- sorted by Savings (biggest first) until you click a header; your choice is remembered
	list.sortCol, list.sortDesc = S().dealSortCol or 7, S().dealSortDesc ~= false
	list.onSort = function(c, desc) S().dealSortCol, S().dealSortDesc = c, desc end

	local total = Label(p, "", "GameFontHighlight"); total:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 4, -20)
	local note = Label(p, "Click an item to open it on the Shopping tab with live prices. Savings = (average - price) x quantity for every listing past the line, "
		.. "before the 5% the auction house keeps when you resell. Prices are from your last full scan - they may have sold since.", "GameFontDisableSmall")
	note:SetPoint("TOPLEFT", total, "BOTTOMLEFT", 0, -6); note:SetWidth(W - 8); note:SetJustifyH("LEFT")

	p.OnOpen = function()
		for t, b in pairs(tb) do if t == tier then b:LockHighlight() else b:UnlockHighlight() end end
		local d = PA.Deals()
		local weeks = PA.ScansThisWeek()
		local need = S().dealMinScans or 5
		if not d or not d.t then
			info:SetText(("No deals yet. Each full scan records every item's market price; items need |cffffffff%d scans|r from the last week before they're judged. "
				.. "Scans so far this week: |cffffffff%d|r."):format(need, weeks))
			list:Set({}); total:SetText("")
		else
			local data, cost, save, n = {}, 0, 0, 0
			for _, e in ipairs(d.list or {}) do
				local tr = e.tiers and e.tiers[tier]
				if tr then
					local name, _, quality, _, _, _, _, _, _, tex = GetItemInfo(e.link or e.key)
					name = name or (e.link and e.link:match("%[(.-)%]")) or ("item " .. e.key)
					local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
					data[#data + 1] = { (c and c.hex or "") .. name .. (c and "|r" or ""), Money(e.low), Money(e.avg), "|cff40ff40" .. e.pct .. "%|r",
						tr.qty, Money(tr.cost), "|cff40ff40" .. Money(tr.save) .. "|r",
						texture = tex, link = e.link, key = e.key, name = name, save = tr.save,
						sk = { name:lower(), e.low or 0, e.avg or 0, e.pct or 0, tr.qty or 0, tr.cost or 0, tr.save or 0 } }
					cost, save, n = cost + tr.cost, save + tr.save, n + 1
				end
			end
			list:Set(data)
			info:SetText(("Listings at least |cffffffff%d%%|r under the item's average price this week. Last full scan: |cffffffff%s|r. "
				.. "Scans this week: |cffffffff%d|r (items need %d)."):format(tier, PA.Ago(d.t), weeks, need))
			total:SetText(n > 0 and ("%d item%s - buying them all costs %s and saves %s against average prices."):format(n, n == 1 and "" or "s", Money(cost), "|cff40ff40" .. Money(save) .. "|r")
				or ("Nothing %d%%+ under right now."):format(tier))
		end
		if not PA.scanning then
			local w = PA.FullScanWait()
			state:SetText(w > 0 and ("Next scan in ~" .. math.ceil(w / 60) .. " min") or "Scan ready")
		end
	end
	local prevState = PA.OnScanState
	PA.OnScanState = function(t)
		if prevState then prevState(t) end
		state:SetText(t)
		if not PA.scanning and p:IsShown() then p.OnOpen() end
	end
end
