-- Pint's Auctions - PROFESSION PLANNER: the cheapest way to level a profession at today's auction house prices,
-- and Flip: things you can buy the reagents for, craft, and sell (to a vendor or on the auction house) for a profit.
-- Prices come from your full scans (the middle price of every listing of an item - what buying a pile really costs);
-- after each full scan the guide and the Flip list are worked out again.
local ADDON, NS = ...
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo      -- (WoW Forever: the old one answers nothing)
local GetSpellInfo = GetSpellInfo or function(id)
	local i = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
	if i then return i.name, nil, i.iconID end
end
local PA = NS.PA
local PROF = NS.PROF
local Money = PA.Money
local P = {}
PA.Planner = P

local NAMES = { [171] = "Alchemy", [164] = "Blacksmithing", [333] = "Enchanting", [202] = "Engineering", [165] = "Leatherworking",
	[197] = "Tailoring", [185] = "Cooking", [129] = "First Aid", [186] = "Mining (smelting)", [40] = "Poisons" }
local ORDER = { 171, 164, 333, 202, 165, 197, 185, 129, 186, 40 }
local LINE_OF = {}
for id, n in pairs(NAMES) do LINE_OF[n] = id end
LINE_OF["Mining"] = 186; LINE_OF["Smelting"] = 186
-- training ranks: past these you need the next rank from a trainer (and the character level it asks for)
local RANKS = { { 75, "Journeyman", 10 }, { 150, "Expert", 20 }, { 225, "Artisan", 35 } }

-- reagents vendors sell (approximate prices; the real ones replace these as soon as you visit a vendor that sells them)
local VENDOR = {
	[2320] = 10, [2321] = 100, [4291] = 500, [8343] = 2000, [14341] = 5000,                  -- threads
	[2324] = 25, [2604] = 50, [6260] = 50, [2605] = 100, [4340] = 350, [4341] = 500, [2325] = 1000, [4342] = 2500, [10290] = 2500, -- bleach, dyes
	[3371] = 4, [3372] = 40, [8925] = 200, [18256] = 2000,                                    -- vials
	[2678] = 10, [2692] = 40, [3713] = 160, [2665] = 20, [159] = 25, [1179] = 125, [2596] = 50, [2894] = 50, -- cooking
	[4470] = 38, [2880] = 100, [3466] = 2000, [3857] = 500, [4289] = 50, [6217] = 124,       -- wood, flux, coal, salt, copper rod
	[4399] = 200, [4400] = 2000, [10647] = 2000, [10648] = 125,                               -- engineering
	[2928] = 20, [8924] = 100, [2930] = 20, [8923] = 300, [5140] = 25,                        -- poisons
}

local function RF() return (GetRealmName() or "?") .. " " .. (UnitFactionGroup("player") or "") end
local function DB() return PA.db end
local function CDB()
	PintsAuctionsCharDB = PintsAuctionsCharDB or {}
	local c = PintsAuctionsCharDB
	c.known = c.known or {}; c.skill = c.skill or {}; c.plan = c.plan or {}
	return c
end

---------------------------------------------------------------- prices
local function VendorBuy(id)
	local d = DB()
	local v = d and d.vendorBuy and d.vendorBuy[id]
	return v or VENDOR[id], v == nil and VENDOR[id] ~= nil
end
local function LastScan(id)
	local d = DB()
	local s = d and d.scans and d.scans[RF()]
	local h = s and s[tostring(id)]
	return type(h) == "table" and h[#h] or nil      -- { time, market price, lowest, how many listed }
end
-- the auction house price to BUY a pile: the market price of the last full scan (the lowest is often just one)
local function AHBuy(id)
	local e = LastScan(id)
	if e and e[2] and e[2] > 0 then return e[2], e[4] end
	local p = PA.Price(id)
	return p, nil
end
-- what you'd get SELLING one on the auction house if the market holds: the lowest listing, less the 5% the house keeps
local function AHSell(id)
	local p = PA.Price(id)
	local e = LastScan(id)
	if e and e[3] and e[3] > 0 then p = e[3] end
	return p and math.floor(p * 0.95) or nil
end
-- what a vendor pays: remembered once known (account-wide), so lists don't keep changing while the game loads items
local asked, loading = {}, 0
local function VendorSell(id)
	local d = DB()
	local m = d and d.sellPrice
	if m and m[id] ~= nil then return m[id] > 0 and m[id] or nil end
	local sp = select(11, GetItemInfo(id))
	if sp then
		if d then d.sellPrice = d.sellPrice or {}; d.sellPrice[id] = sp end
		return sp > 0 and sp or nil
	end
	if not asked[id] then
		asked[id] = true; loading = loading + 1
		if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
	end
end
P.Loading = function() return loading end
P.AHBuy, P.AHSell, P.VendorBuy = AHBuy, AHSell, VendorBuy

---------------------------------------------------------------- what each recipe costs to make
local madeBy = {}               -- item -> { spell, ... } (to make a reagent yourself when that's cheaper)
for sp, r in pairs(PROF) do if r[2] > 0 then madeBy[r[2]] = madeBy[r[2]] or {}; table.insert(madeBy[r[2]], sp) end end

local cache, missing = {}, {}
-- cheapest way to get one of an item: { price, "ah" | "vendor" | "craft", spell }
local Cost
local function CraftCost(sp, depth)
	local r = PROF[sp]
	local total = 0
	local regs = r[7]
	for i = 1, #regs, 2 do
		local c = Cost(regs[i], depth + 1)
		if not c then missing[regs[i]] = true; return nil end
		total = total + c[1] * regs[i + 1]
	end
	return total
end
Cost = function(id, depth)
	depth = depth or 0
	local hit = cache[id]
	if hit ~= nil then return hit or nil end
	local best
	local v = VendorBuy(id)
	if v then best = { v, "vendor" } end
	local a = AHBuy(id)
	if a and (not best or a < best[1]) then best = { a, "ah" } end
	if depth < 3 and madeBy[id] then
		cache[id] = false                     -- (no loops)
		for _, sp in ipairs(madeBy[id]) do
			local c = CraftCost(sp, depth)
			if c then
				c = c / math.max(1, PROF[sp][3])
				if not best or c < best[1] then best = { c, "craft", sp } end
			end
		end
	end
	cache[id] = best or false
	return best
end
P.Cost = function(id) return Cost(id, 0) end
local adj = {}                  -- recipe -> its skill-up colour points, fitted to what you've seen
local function Reset() wipe(cache); wipe(missing); wipe(adj) end

---------------------------------------------------------------- what this character knows and their skill
local function ScanSkills()
	local c = CDB()
	if GetNumSkillLines then
		for i = 1, GetNumSkillLines() do
			local name, header, _, rank, _, _, max = GetSkillLineInfo(i)
			local line = name and not header and LINE_OF[name]
			if line then c.skill[line] = { rank, max } end
		end
	end
	if GetProfessions and GetProfessionInfo then
		for _, ix in ipairs({ GetProfessions() }) do
			if ix then
				local name, _, rank, max, _, _, line = GetProfessionInfo(ix)
				line = (line and NAMES[line] and line) or (name and LINE_OF[name])
				if line then c.skill[line] = { rank, max } end
			end
		end
	end
end
-- the skill-up colours each recipe really shows in your profession window, at the skill you had (account-wide).
-- WoW Forever changed some of them (Bolt of Silk Cloth goes grey far earlier than in Classic), so what you've seen wins.
local COL = { optimal = "o", medium = "y", easy = "g", trivial = "x", [0] = "o", [1] = "y", [2] = "g", [3] = "x" }
local function Observe(sp, kind, rank)
	local c = COL[kind]
	local d = DB()
	if not (c and rank and sp and PROF[sp] and d) then return end
	d.colors = d.colors or {}
	local o = d.colors[sp] or {}
	o[c .. "1"] = math.min(o[c .. "1"] or rank, rank)
	o[c .. "2"] = math.max(o[c .. "2"] or rank, rank)
	d.colors[sp] = o
end
-- orange from, yellow from, grey from for a recipe: the built-in numbers, moved to fit what you've seen
local function T(sp)
	local hit = adj[sp]
	if hit then return hit end
	local r = PROF[sp]
	local o, y, g = r[4], r[5], r[6]
	local seen = DB() and DB().colors and DB().colors[sp]
	if seen then
		o = math.min(o, seen.o1 or o, seen.y1 or o, seen.g1 or o)       -- learnable earlier than the built-in number
		if seen.o2 then y = math.max(y, seen.o2 + 1) end                -- still orange at this skill
		if seen.y1 then y = math.min(y, seen.y1) end                    -- already yellow here
		local notGrey = math.max(seen.o2 or 0, seen.y2 or 0, seen.g2 or 0)
		if seen.x1 and seen.x1 > notGrey then g = math.min(g, seen.x1) end   -- grey here
		g = math.max(g, notGrey + 1)
		if seen.g1 then y = math.min(y, seen.g1) end
		y = math.max(o, math.min(y, g - 1))
	end
	hit = { nil, nil, nil, o, y, g }
	adj[sp] = hit
	return hit
end
P.T = T
local function SpellFromLink(l) return l and tonumber(l:match("enchant:(%d+)") or l:match("spell:(%d+)")) end
local function ScanBook()
	local c = CDB()
	local function save(name, n, linkFn)
		local line = name and LINE_OF[name]
		if not line or not n or n == 0 then return end
		local k = c.known[line] or {}
		for i = 1, n do
			local ok, l = pcall(linkFn, i)
			local sp = ok and SpellFromLink(l)
			if sp then k[sp] = true end
		end
		c.known[line] = k
	end
	if GetTradeSkillLine and GetNumTradeSkills and GetTradeSkillRecipeLink then
		local name, rank, max = GetTradeSkillLine()
		local line = name and LINE_OF[name]
		if line and rank then c.skill[line] = { rank, max } end
		save(name, GetNumTradeSkills(), GetTradeSkillRecipeLink)
		if line and rank and GetTradeSkillInfo then
			for i = 1, GetNumTradeSkills() do
				local _, kind = GetTradeSkillInfo(i)
				local ok, l = pcall(GetTradeSkillRecipeLink, i)
				if ok then Observe(SpellFromLink(l), kind, rank) end
			end
		end
	elseif C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
		-- WoW Forever: the modern profession window
		local info = C_TradeSkillUI.GetChildProfessionInfo and C_TradeSkillUI.GetChildProfessionInfo()
		if not (info and info.professionName and info.professionName ~= "") then info = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo() end
		local name = info and (info.parentProfessionName or info.professionName)
		local line = name and LINE_OF[name]
		if not line and name then for n, id in pairs(LINE_OF) do if name:find(n, 1, true) or n:find(name, 1, true) then line = id; break end end end
		local rank = info and info.skillLevel
		if line and rank and rank > 0 then
			c.skill[line] = { rank, info.maxSkillLevel }
			local k = c.known[line] or {}
			for _, id in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do
				local r = C_TradeSkillUI.GetRecipeInfo(id)
				if r and r.learned then k[id] = true; Observe(id, r.relativeDifficulty, rank) end
			end
			c.known[line] = k
		end
	end
	if GetCraftDisplaySkillLine and GetNumCrafts and GetCraftRecipeLink then
		local name, rank, max = GetCraftDisplaySkillLine()
		local line = name and LINE_OF[name]
		if line and rank then c.skill[line] = { rank, max } end
		save(name, GetNumCrafts(), GetCraftRecipeLink)
		if line and rank and GetCraftInfo then
			for i = 1, GetNumCrafts() do
				local _, _, kind = GetCraftInfo(i)
				local ok, l = pcall(GetCraftRecipeLink, i)
				if ok then Observe(SpellFromLink(l), kind, rank) end
			end
		end
	end
end
local function Knows(line, sp) local k = CDB().known[line]; return k and k[sp] end
local function KnowsAny(line) local k = CDB().known[line]; return k and next(k) ~= nil end

---------------------------------------------------------------- the levelling guide
-- chance one craft gives a skill point: orange always, yellow to grey falls off, grey never
-- The game's rule is (grey - skill) / (grey - yellow). Your own crafts are also logged (see "skill-up log" below), and once
-- there are enough of them at a point in the yellow-green range, what really happened is blended in.
local BUCKETS = 10
local function Bucket(r, s) return math.min(BUCKETS - 1, math.floor((s - r[5]) / (r[6] - r[5]) * BUCKETS)) end
local function Chance(r, s)
	if s < r[4] or s >= r[6] then return 0 end
	if s < r[5] then return 1 end
	local f = (r[6] - s) / (r[6] - r[5])
	local log = DB() and DB().skillups
	local b = log and log[Bucket(r, s)]
	if b and b[1] >= 30 then f = (b[2] + f * 20) / (b[1] + 20) end      -- (20 crafts' worth of the rule keeps a short run honest)
	return math.max(0.02, math.min(1, f))
end
P.Chance = Chance
-- what you get back for what you make (vendor: for sure; auction house: if the market holds)
local function Back(r, opt)
	if r[2] == 0 then return 0 end
	local best = 0
	if opt.backVendor then best = math.max(best, (VendorSell(r[2]) or 0) * r[3]) end
	if opt.backAH then best = math.max(best, (AHSell(r[2]) or 0) * r[3]) end
	return best
end
local function Usable(line, sp, r, opt)
	if Knows(line, sp) then return true, 0 end
	if r[8] == "t" then return true, r[9] or 0 end
	if r[8] == "v" and opt.vendorRecipes then return true, r[9] or 0 end
	return false
end
-- plan from skill `from` to `to`: steps { spell, from, to, crafts, cost }, shopping, totals
function P.Plan(line, from, to, opt)
	Reset()
	local list = {}
	for sp, r in pairs(PROF) do if r[1] == line then list[#list + 1] = sp end end
	local learned, steps, gaps = {}, {}, {}
	local total, train, back = 0, 0, 0
	local cur
	for s = from, to - 1 do
		local best, bestEff, bestP, bestC, bestOne
		for _, sp in ipairs(list) do
			local r = PROF[sp]
			local t = T(sp)
			local p = Chance(t, s)
			if p > 0 then
				local ok, one = Usable(line, sp, r, opt)
				if ok then
					local c = CraftCost(sp, 0)
					if c then
						c = c - Back(r, opt)
						one = learned[sp] and 0 or one
						-- a recipe's training is spread over the levels it can still give points for
						local eff = c / p + one / math.max(1, math.min(t[6], to) - s)
						if not bestEff or eff < bestEff then best, bestEff, bestP, bestC, bestOne = sp, eff, p, c, one end
					end
				end
			end
		end
		if best then
			if not learned[best] then learned[best] = true; train = train + bestOne end
			-- crafts for this point: on average 1 / chance, give or take (1 - chance) / chance^2 (bad luck adds up over a step)
			local var = (1 - bestP) / (bestP * bestP)
			if cur and cur.spell == best then cur.to = s + 1; cur.crafts = cur.crafts + 1 / bestP; cur.var = cur.var + var; cur.cost = cur.cost + bestC / bestP
			else cur = { spell = best, from = s, to = s + 1, crafts = 1 / bestP, var = var, cost = bestC / bestP, unit = bestC, learn = bestOne }; steps[#steps + 1] = cur end
		else
			gaps[#gaps + 1] = s; cur = nil
		end
	end
	-- shopping list: every reagent each step needs (made yourself where that's cheaper - then what goes into it)
	local shop = {}
	local function Need(id, n, depth)
		local c = Cost(id, depth)
		if c and c[2] == "craft" and depth < 3 then
			local r = PROF[c[3]]
			local times = n / math.max(1, r[3])
			for i = 1, #r[7], 2 do Need(r[7][i], times * r[7][i + 1], depth + 1) end
		else
			shop[id] = (shop[id] or 0) + n
		end
	end
	for _, st in ipairs(steps) do
		-- how many to plan for: the average, plus extra for bad luck (85% sure by default: 1 step in 7 might need more)
		st.avg = st.crafts
		local z = (opt.safety == 0 and 0) or (opt.safety == 95 and 1.645) or 1.04
		st.crafts = math.ceil(st.avg + z * math.sqrt(st.var or 0) - 0.05)
		st.extra = math.max(0, st.crafts - math.ceil(st.avg - 0.05))
		local r = PROF[st.spell]
		for i = 1, #r[7], 2 do Need(r[7][i], st.crafts * r[7][i + 1], 1) end
		total = total + st.cost
		back = back + Back(r, opt) * st.crafts
	end
	return { steps = steps, shop = shop, total = total, train = train, back = back, gaps = gaps, missing = missing }
end

---------------------------------------------------------------- Flip: craft for a profit
function P.Flips(opt)
	Reset()
	local out = {}
	local onlyKnown = opt.flipKnown
	for sp, r in pairs(PROF) do
		if r[2] > 0 and (not onlyKnown or Knows(r[1], sp)) and (onlyKnown or r[8] ~= "o" or Knows(r[1], sp)) then
			local c = CraftCost(sp, 0)
			if c and c > 0 then
				local n = r[3]
				local v = opt.flipVendor and VendorSell(r[2])
				local a = opt.flipAH and AHSell(r[2])
				local pv = v and (v * n - c)
				local pa = a and (a * n - c)
				local best = math.max(pv or -1e12, pa or -1e12)
				if best > 0 then out[#out + 1] = { kind = "craft", spell = sp, item = r[2], n = n, cost = c, vend = v and v * n, ah = a and a * n, pv = pv, pa = pa, best = best } end
			end
		end
	end
	-- no crafting at all: listed for less than a vendor pays for it
	if opt.flipBuyVendor then
		local s = DB() and DB().prices[RF()]
		for key, e in pairs(s or {}) do
			local id = tonumber(key)
			if id and e.m and e.m > 0 then
				local v = VendorSell(id)
				if v and v > e.m then
					local ls = LastScan(id)
					out[#out + 1] = { kind = "buy", item = id, n = 1, cost = e.m, vend = v, pv = v - e.m, best = v - e.m, qty = ls and ls[4] }
				end
			end
		end
	end
	table.sort(out, function(x, y) if x.best ~= y.best then return x.best > y.best end return x.item < y.item end)
	return out
end

---------------------------------------------------------------- buying from here: open it in the auction house's Buy view
-- (the purchase itself is always the game's own Buy button - add-ons may not buy on their own)
local function BuyItem(id, name)
	if not id then return end
	if AuctionHouseFrame and AuctionHouseFrame:IsShown() and C_AuctionHouse and C_AuctionHouse.MakeItemKey then
		if PA.OpenInBuy then PA.OpenInBuy(C_AuctionHouse.MakeItemKey(id), name) return true end
	elseif AuctionFrame and AuctionFrame:IsShown() and PA.SelectTab then
		PA.SelectTab("shop"); C_Timer.After(0, function() if PA.OpenItem then PA.OpenItem({ name = name, key = tostring(id) }) end end)
		return true
	end
	PA.Print("open the auction house to buy.")
end

---------------------------------------------------------------- the window
local win
local function IName(id)
	local name, link, q, _, _, _, _, _, _, tex = GetItemInfo(id)
	if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
	if not tex then tex = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or (GetItemIcon and GetItemIcon(id)) end
	if not name and C_Item and C_Item.GetItemNameByID then name = C_Item.GetItemNameByID(id) end
	local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
	return (c and c.hex or "|cffffffff") .. (name or ("item " .. id)) .. "|r", link, tex, name
end
local function SName(sp) return (GetSpellInfo(sp)) or ("recipe " .. sp) end
local function Opt()
	local o = CDB().plan
	if o.backVendor == nil then o.backVendor = true end
	if o.vendorRecipes == nil then o.vendorRecipes = true end
	if o.flipVendor == nil then o.flipVendor = true end
	if o.flipAH == nil then o.flipAH = true end
	if o.flipBuyVendor == nil then o.flipBuyVendor = true end
	if o.safety == nil then o.safety = 85 end
	return o
end
local function Check(parent, label, key, onChange, tip)
	local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate"); c:SetSize(22, 22)
	local t = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); t:SetPoint("LEFT", c, "RIGHT", 0, 1); t:SetText(label)
	c:SetScript("OnShow", function(self) self:SetChecked(Opt()[key] and true or false) end)
	c:SetScript("OnClick", function(self) Opt()[key] = self:GetChecked() and true or false; onChange() end)
	if tip then PA.Tip(c, label, tip) end
	c.label = t
	return c
end
local function ScanAge()
	local t = DB() and DB().lastAll and DB().lastAll[RF()]
	return t and ("last full scan " .. PA.Ago(t)) or "|cffff8040no full scan yet - do one at the auction house (/pah scan)|r"
end

local function BuildLevel(p)
	local Label, Btn, List, Edit = PA.Label, PA.Btn, PA.List, PA.Edit
	local o = Opt()
	o.line = o.line or 197
	local profBtn = Btn(p, "", 170, 22); profBtn:SetPoint("TOPLEFT", 4, -4)
	local fl = Label(p, "From skill", "GameFontNormalSmall"); fl:SetPoint("LEFT", profBtn, "RIGHT", 12, 0)
	local fromBox = Edit(p, 36, true); fromBox:SetPoint("LEFT", fl, "RIGHT", 8, 0); fromBox:SetMaxLetters(3)
	local tl = Label(p, "to", "GameFontNormalSmall"); tl:SetPoint("LEFT", fromBox, "RIGHT", 6, 0)
	local toBox = Edit(p, 36, true); toBox:SetPoint("LEFT", tl, "RIGHT", 8, 0); toBox:SetMaxLetters(3)
	local mine = Btn(p, "Mine", 50, 22); mine:SetPoint("LEFT", toBox, "RIGHT", 6, 0)
	PA.Tip(mine, "Start from your skill", "Uses this character's current skill (open the profession once if it isn't known yet).")
	local go = Btn(p, "Work it out", 100, 22); go:SetPoint("LEFT", mine, "RIGHT", 6, 0)
	local c1 = Check(p, "Count what I can vendor what I make for", "backVendor", function() p.OnOpen() end,
		"Takes off what a vendor pays for everything you make - money you're sure to get back.")
	c1:SetPoint("TOPLEFT", 0, -30)
	local c2 = Check(p, "...or auction it", "backAH", function() p.OnOpen() end,
		"Takes off what it sells for on the auction house instead, when that's more - only if the market holds.")
	c2:SetPoint("LEFT", c1.label, "RIGHT", 14, -1)
	local c3 = Check(p, "Vendor recipes", "vendorRecipes", function() p.OnOpen() end,
		"Also use recipes you can buy from a vendor (their price counts). Drop and quest recipes are only used once you know them.")
	c3:SetPoint("LEFT", c2.label, "RIGHT", 14, -1)
	-- yellow and green recipes miss sometimes: buy enough that bad luck doesn't leave you short
	local SAFE = { { 0, "Average only" }, { 85, "85% sure" }, { 95, "95% sure" } }
	local safe = Btn(p, "", 150, 22); safe:SetPoint("LEFT", c3.label, "RIGHT", 16, 1)
	PA.Tip(safe, "Extra for bad luck", "Yellow and green recipes don't always give a point. Average only plans for typical luck (half the time you'd need more); "
		.. "85% sure buys enough for all but about 1 run in 7; 95% sure for all but 1 in 20. The extra shows as (+n) in Times.")
	safe:SetScript("OnClick", function()
		local i = 1; for k, v in ipairs(SAFE) do if v[1] == o.safety then i = k end end
		o.safety = SAFE[i % #SAFE + 1][1]; p.OnOpen()
	end)
	p.safe, p.SAFE = safe, SAFE
	local info = Label(p, "", "GameFontHighlightSmall"); info:SetPoint("TOPLEFT", 4, -56); info:SetWidth(770); info:SetJustifyH("LEFT")

	local W = 520
	local steps = List(p, W, 15, 18, {
		{ 70, "LEFT", "Skill" }, { W - 300, "LEFT", "Craft" }, { 50, "RIGHT", "Times" }, { 90, "RIGHT", "Cost" }, { 70, "RIGHT", "Each point" },
	}, function(item) if item.link and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then ChatEdit_InsertLink(item.link) end end)
	steps:SetPoint("TOPLEFT", 0, -92)
	local SW = 248
	local shop = List(p, SW, 15, 18, { { SW - 150, "LEFT", "Shopping list" }, { 46, "RIGHT", "Need" }, { 82, "RIGHT", "Cost" } },
		function(item, b, row)
			if item.link and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then ChatEdit_InsertLink(item.link); return end
			BuyItem(tonumber(item.key), item.name)
		end)
	shop:SetPoint("TOPLEFT", steps, "TOPRIGHT", 10, 0)
	local total = Label(p, "", "GameFontHighlight"); total:SetPoint("TOPLEFT", steps, "BOTTOMLEFT", 4, -18); total:SetWidth(770); total:SetJustifyH("LEFT")
	local note = Label(p, "Each step uses the cheapest way to earn every point at the prices from your last full scan: what the reagents cost "
		.. "(bought, or made yourself when that's cheaper), less what you get back, divided by the chance of a point (yellow and green recipes miss "
		.. "sometimes - the Times column allows for that). Training costs count once. It's worked out again after every full scan.", "GameFontDisableSmall")
	note:SetPoint("TOPLEFT", total, "BOTTOMLEFT", 0, -6); note:SetWidth(770); note:SetJustifyH("LEFT")

	local function Range()
		local line = o.line
		local sk = CDB().skill[line]
		local from = tonumber(fromBox:GetText() or "") or (o.from and o.from[line]) or (sk and sk[1]) or 1
		local to = tonumber(toBox:GetText() or "") or 300
		from = math.max(1, math.min(299, from)); to = math.max(from + 1, math.min(300, to))
		return from, to
	end
	profBtn:SetScript("OnClick", function(self)
		local items = {}
		for _, line in ipairs(ORDER) do
			local sk = CDB().skill[line]
			items[#items + 1] = { text = (line == o.line and "|cff40ff40" or "") .. NAMES[line] .. "|r" .. (sk and ("  |cff909090(" .. sk[1] .. ")|r") or ""),
				fn = function() o.line = line; fromBox:SetText(""); toBox:SetText(""); p.OnOpen() end }
		end
		PA.Menu(self, items)
	end)
	mine:SetScript("OnClick", function() ScanSkills(); o.from = o.from or {}; o.from[o.line] = nil; fromBox:SetText(""); p.OnOpen() end)
	go:SetScript("OnClick", function()
		fromBox:ClearFocus(); toBox:ClearFocus()
		o.from = o.from or {}; o.from[o.line] = tonumber(fromBox:GetText() or "")
		p.OnOpen()
	end)
	fromBox:SetScript("OnEnterPressed", function() go:Click() end); toBox:SetScript("OnEnterPressed", function() go:Click() end)

	p.OnOpen = function(keep)
		p.keepNext = keep
		ScanSkills()
		for _, v in ipairs(p.SAFE) do if v[1] == o.safety then p.safe:SetText("Buy: " .. v[2]) end end
		local line = o.line
		profBtn:SetText(NAMES[line] .. "  |cffaaaaaav|r")
		local from, to = Range()
		if not fromBox:HasFocus() then fromBox:SetText(tostring(from)) end
		if not toBox:HasFocus() then toBox:SetText(tostring(to)) end
		local plan = P.Plan(line, from, to, o)
		local data = {}
		for _, st in ipairs(plan.steps) do
			local r = PROF[st.spell]
			local name, link, tex
			if r[2] > 0 then name, link, tex = IName(r[2])
			else name = "|cffffffff" .. SName(st.spell) .. "|r"; tex = select(3, GetSpellInfo(st.spell)) end
			local learn = ""
			if st.learn and st.learn > 0 then learn = "  |cff80c0ff(learn: " .. Money(st.learn) .. ")|r"
			elseif not Knows(line, st.spell) then learn = (r[8] == "v") and "  |cff80c0ff(vendor recipe)|r" or "  |cff80c0ff(trainer)|r" end
			-- the colour it is when you start it
			local t = T(st.spell)
			local col = (st.from < t[5] and "|cffff8040") or (st.from < (t[5] + t[6]) / 2 and "|cffffff00") or "|cff40bf40"
			data[#data + 1] = { col .. st.from .. " - " .. st.to .. "|r", name .. learn, st.crafts .. (st.extra > 0 and (" |cff909090(+" .. st.extra .. ")|r") or ""), Money(math.max(0, st.cost)) .. (st.cost < 0 and " |cff40ff40profit|r" or ""),
				Money(math.max(0, math.floor(st.cost / math.max(1, st.to - st.from)))), texture = tex, link = link, name = name,
				tip = (not link) and SName(st.spell) or nil }
		end
		-- the training ranks you'll need on the way
		for _, rk in ipairs(RANKS) do
			if from < rk[1] and to > rk[1] then
				for i, d in ipairs(data) do
					local a = tonumber((d[1]:gsub("|c%x%x%x%x%x%x%x%x", ""):match("^(%d+)")))
					if a and a >= rk[1] then table.insert(data, i, { "|cff80c0ff" .. rk[1] .. "|r", "|cff80c0ffTrain " .. rk[2] .. " " .. (NAMES[line]:gsub(" %(.*", "")) .. " (character level " .. rk[3] .. ")|r", "", "", "" }); break end
				end
			end
		end
		steps:Set(data, p.keepNext)
		local sd, buy = {}, 0
		for id, n in pairs(plan.shop) do
			local c = Cost(id, 9)
			local name, link, tex, plain = IName(id)
			local need = math.ceil(n - 0.01)
			local cost = c and c[1] * need or 0
			local _, listed = AHBuy(id)
			local warn = (c and c[2] == "ah" and listed and listed < need) and (" |cffff8040(" .. listed .. " listed)|r") or ""
			sd[#sd + 1] = { name .. ((c and c[2] == "vendor") and " |cff909090v|r" or "") .. warn, need, Money(cost), texture = tex, link = link, name = plain, key = tostring(id),
				sk = { (plain or ""):lower(), need, cost } }
			buy = buy + cost
		end
		shop.sortCol, shop.sortDesc = 3, true
		shop:Set(sd, p.keepNext)
		local nmiss = 0; for _ in pairs(plan.missing) do nmiss = nmiss + 1 end
		info:SetText(("%s %d to %d - %s%s"):format(NAMES[line], from, to, ScanAge(),
			(nmiss > 0) and ("  |cff909090(" .. nmiss .. " reagents have no price yet, so recipes that need them are left out)|r") or ""))
		local gap = ""
		if #plan.gaps > 0 then gap = ("  |cffff8040No priced recipe for %d level%s (from %d) - scan again, or check those reagents.|r"):format(#plan.gaps, #plan.gaps == 1 and "" or "s", plan.gaps[1]) end
		total:SetText(("Reagents about %s%s%s, training %s - total |cffffd100%s|r%s"):format(Money(buy),
			o.safety ~= 0 and " |cff909090(with extra for bad luck)|r" or "",
			plan.back > 0 and (", less about " .. Money(math.floor(plan.back)) .. " back for what you make") or "",
			Money(plan.train), Money(math.max(0, buy - math.floor(plan.back)) + plan.train), gap))
	end
end

local function BuildFlip(p)
	local Label, Btn, List = PA.Label, PA.Btn, PA.List
	local c1 = Check(p, "Sell to a vendor", "flipVendor", function() p.OnOpen() end, "A sure thing: vendors always pay the same.")
	c1:SetPoint("TOPLEFT", 0, -2)
	local c2 = Check(p, "Sell on the auction house", "flipAH", function() p.OnOpen() end,
		"If the market holds: the lowest listing from your last scan, less the 5% the auction house keeps. It may sell slowly, or be undercut.")
	c2:SetPoint("LEFT", c1.label, "RIGHT", 14, -1)
	local c3 = Check(p, "Only recipes I know", "flipKnown", function() p.OnOpen() end,
		"Off: every trainer and vendor recipe (learn it to use it). Open a profession once on each character so its recipes are known.")
	c3:SetPoint("LEFT", c2.label, "RIGHT", 14, -1)
	local c4 = Check(p, "Buy and vendor (no crafting)", "flipBuyVendor", function() p.OnOpen() end, "Listed on the auction house for less than a vendor pays for it.")
	c4:SetPoint("LEFT", c3.label, "RIGHT", 14, -1)
	local info = Label(p, "", "GameFontHighlightSmall"); info:SetPoint("TOPLEFT", 4, -28); info:SetWidth(770); info:SetJustifyH("LEFT")
	local W = 778
	local list = List(p, W, 18, 18, {
		{ W - 540, "LEFT", "Item", sort = "asc" }, { 120, "LEFT", "How" }, { 80, "RIGHT", "Cost", sort = true }, { 85, "RIGHT", "Vendor", sort = true },
		{ 85, "RIGHT", "Profit", sort = true }, { 85, "RIGHT", "Auction", sort = true }, { 85, "RIGHT", "Profit", sort = true },
	}, function(item, b)
		if item.link and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then ChatEdit_InsertLink(item.link); return end
		-- click: pick it; the Buy button (or a double look) opens it to buy
		list.selected = item; list.selectedKey = item.key; list:Refresh()
		p.buy:Enable()
	end)
	p.buy = Btn(p, "Buy selected", 120, 22); p.buy:SetPoint("TOPRIGHT", list, "BOTTOMRIGHT", 0, -4); p.buy:Disable()
	p.buy:SetScript("OnClick", function()
		local it = list.selected
		if not it then return end
		-- crafting: the reagents, one at a time (the first now - click again for the next); buy & vendor: the item
		if it.buyList and #it.buyList > 0 then
			it.buyAt = (it.buyAt or 0) % #it.buyList + 1
			local r = it.buyList[it.buyAt]
			BuyItem(r[1], r[2])
			p.buy:SetText(("Buy %d/%d: next"):format(it.buyAt, #it.buyList))
		else BuyItem(tonumber(it.key), it.name) end
	end)
	PA.Tip(p.buy, "Buy at the auction house", "Opens it in the auction house's Buy view, where the game's Buy button buys it. "
		.. "For a craft, each click opens the next reagent to buy.")
	list:SetPoint("TOPLEFT", 0, -60)
	list.sortCol, list.sortDesc = nil, true
	local note = Label(p, "Cost = the reagents at their market price from your last full scan (or a vendor's price), or what you pay for it. "
		.. "Vendor profit is certain; auction profit holds only if the market does. Prices may have moved since the scan - check before buying a lot.", "GameFontDisableSmall")
	note:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 4, -20); note:SetWidth(770); note:SetJustifyH("LEFT")
	local function M(v, profit)
		if not v then return "|cff606060-|r" end
		if profit then return (v > 0 and "|cff40ff40" or "|cffff6060") .. (v < 0 and "-" or "") .. Money(math.abs(math.floor(v))) .. "|r" end
		return Money(math.floor(v))
	end
	p.OnOpen = function(keep)
		local o = Opt()
		local flips = P.Flips(o)
		local data = {}
		for i, f in ipairs(flips) do
			if i > 300 then break end
			local name, link, tex, plain = IName(f.item)
			local how
			if f.kind == "buy" then how = "|cffffd100buy & vendor|r" .. (f.qty and ("  |cff909090x" .. f.qty .. "|r") or "")
			else
				local r = PROF[f.spell]
				how = (NAMES[r[1]] or "?"):gsub(" %(.*", "") .. " " .. r[4] .. ((not Knows(r[1], f.spell)) and " |cff80c0ff(learn)|r" or "")
					.. (SName(f.spell):find("^Transmute") and " |cffff8040(cooldown)|r" or "")
			end
			data[#data + 1] = { name .. (f.n > 1 and (" |cff909090x" .. f.n .. "|r") or ""), how, M(f.cost), M(f.vend), M(f.pv, true), M(f.ah), M(f.pa, true),
				texture = tex, link = link, name = plain, key = tostring(f.item),
				sk = { (plain or ""):lower(), how, f.cost, f.vend or -1, f.pv or -1e12, f.ah or -1, f.pa or -1e12 } }
			if f.kind == "craft" then
				-- what to buy for it: the reagents the auction house is the cheapest place for
				local bl, r = {}, PROF[f.spell]
				for k = 1, #r[7], 2 do
					local c = Cost(r[7][k], 1)
					if c and c[2] == "ah" then local _, _, _, pl = IName(r[7][k]); bl[#bl + 1] = { r[7][k], pl } end
				end
				data[#data].buyList = bl
			end
		end
		list:Set(data, keep)
		-- keep what you picked picked
		local selKey = list.selectedKey
		list.selected = nil
		if selKey then for _, d in ipairs(data) do if d.key == selKey then list.selected = d end end end
		if not list.selected then list.selectedKey = nil; p.buy:Disable(); p.buy:SetText("Buy selected") end
		list:Refresh()
		if not (o.flipVendor or o.flipAH) then info:SetText("|cffff8040Pick vendor, auction house or both.|r")
		else info:SetText(("%d ways to make money - %s. Click one, then Buy selected (at the auction house).%s"):format(#flips, ScanAge(),
			P.Loading() > 0 and ("  |cffffd100Loading %d items' prices...|r"):format(P.Loading()) or "")) end
	end
end

function P.Open(which)
	if not win then
		win = CreateFrame("Frame", "PintsAuctionsPlanner", UIParent, "BackdropTemplate")
		win:SetSize(810, 520); win:SetPoint("CENTER"); win:SetFrameStrata("HIGH"); win:SetToplevel(true); win:SetClampedToScreen(true)
		win:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 32, edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 } })
		win:EnableMouse(true); win:SetMovable(true); win:RegisterForDrag("LeftButton")
		win:SetScript("OnDragStart", win.StartMoving); win:SetScript("OnDragStop", win.StopMovingOrSizing)
		tinsert(UISpecialFrames, "PintsAuctionsPlanner")
		local title = PA.Label(win, "|cffd4a017Pint's|r Profession Planner", "GameFontNormal"); title:SetPoint("TOPLEFT", 16, -12)
		local close = CreateFrame("Button", nil, win, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -2, -2)
		win.pages, win.tabs = {}, {}
		local x = 230
		for _, d in ipairs({ { "level", "Cheapest levelling" }, { "flip", "Flip for profit" } }) do
			local pg = CreateFrame("Frame", nil, win); pg:SetPoint("TOPLEFT", 14, -40); pg:SetPoint("BOTTOMRIGHT", -14, 12); pg:Hide()
			win.pages[d[1]] = pg
			local t = PA.Btn(win, d[2], 140, 22); t:SetPoint("TOPLEFT", x, -8); x = x + 144
			t:SetScript("OnClick", function() P.Open(d[1]) end)
			win.tabs[d[1]] = t
		end
		BuildLevel(win.pages.level); BuildFlip(win.pages.flip)
	end
	which = which or win.cur or "level"
	win.cur = which
	for k, pg in pairs(win.pages) do pg:SetShown(k == which) end
	for k, t in pairs(win.tabs) do if k == which then t:LockHighlight() else t:UnlockHighlight() end end
	win:Show()
	win.pages[which].OnOpen()
end
function P.Toggle(which) if win and win:IsShown() and (not which or which == win.cur) then win:Hide() else P.Open(which) end end
function P.Refresh(keep) if win and win:IsShown() then win.pages[win.cur].OnOpen(keep) end end

---------------------------------------------------------------- keeping things up to date
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "TRADE_SKILL_LIST_UPDATE", "CRAFT_SHOW", "CRAFT_UPDATE", "SKILL_LINES_CHANGED", "MERCHANT_SHOW", "GET_ITEM_INFO_RECEIVED" }) do
	pcall(ev.RegisterEvent, ev, e)
end
local wait
ev:SetScript("OnEvent", function(_, e)
	if e == "MERCHANT_SHOW" then
		-- what vendors charge for what they sell (the reagents' real prices)
		local d = DB(); if not d then return end
		d.vendorBuy = d.vendorBuy or {}
		for i = 1, (GetMerchantNumItems and GetMerchantNumItems() or 0) do
			local ok, _, _, price, qty = pcall(GetMerchantItemInfo, i)
			local link = GetMerchantItemLink and GetMerchantItemLink(i)
			local id = link and tonumber(link:match("item:(%d+)"))
			if ok and id and price and price > 0 then d.vendorBuy[id] = math.floor(price / math.max(1, qty or 1) + 0.5) end
		end
		return
	end
	if e == "GET_ITEM_INFO_RECEIVED" then
		if loading > 0 then loading = loading - 1 end
		if not (win and win:IsShown()) or wait then return end
		wait = true
		C_Timer.After(3, function() wait = false; P.Refresh(true) end)
		return
	end
	if e == "PLAYER_LOGIN" then C_Timer.After(5, function() pcall(ScanSkills) end); return end
	C_Timer.After(0.3, function() pcall(ScanBook); pcall(ScanSkills) end)
end)
---------------------------------------------------------------- skill-up log: how often yellow and green crafts really give a point
-- Every craft you make in the yellow-green range is counted (account-wide), by how far it is from yellow to grey;
-- each tenth of that range needs 30 crafts before what really happened starts to count. /pah skillups shows it.
local pend
local SKILLUP = (SKILL_RANK_UP or "Your skill in %s has increased to %d."):gsub("%.", "%%."):gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
local function Settle()
	if not pend then return end
	local d = DB()
	if d then
		d.skillups = d.skillups or {}
		local b = d.skillups[pend.b] or { 0, 0 }
		b[1] = b[1] + 1; if pend.up then b[2] = b[2] + 1 end
		d.skillups[pend.b] = b
	end
	pend = nil
end
local log = CreateFrame("Frame")
pcall(log.RegisterEvent, log, "UNIT_SPELLCAST_SUCCEEDED"); pcall(log.RegisterEvent, log, "CHAT_MSG_SKILL")
log:SetScript("OnEvent", function(_, e, a1, _, a3)
	if e == "UNIT_SPELLCAST_SUCCEEDED" then
		if a1 ~= "player" then return end
		local sp = a3
		if type(issecretvalue) == "function" and issecretvalue(sp) then return end
		local r = sp and PROF[sp]
		if not r then return end
		Settle()
		local sk = CDB().skill[r[1]]
		local s = sk and sk[1]
		local t = T(sp)
		if s and s >= t[5] and s < t[6] then
			pend = { line = r[1], b = Bucket(t, s) }
			C_Timer.After(2, function() if pend and pend.line == r[1] and not pend.up then Settle() end end)
		end
	elseif e == "CHAT_MSG_SKILL" then
		local name, val = tostring(a1 or ""):match(SKILLUP)
		local line = name and LINE_OF[name]
		if not line then return end
		local c = CDB(); c.skill[line] = c.skill[line] or { 0, 0 }; c.skill[line][1] = tonumber(val) or c.skill[line][1]
		if pend and pend.line == line then pend.up = true; Settle() end
	end
end)
function P.SkillupReport()
	local d = DB() and DB().skillups or {}
	PA.Print("skill-ups on yellow and green crafts (0% = just turned yellow, 90% = nearly grey):")
	local any = false
	for b = 0, BUCKETS - 1 do
		local x = d[b]
		if x and x[1] > 0 then
			any = true
			local mid = (b + 0.5) / BUCKETS
			PA.Print(("  %d-%d%%: %d crafts, %d points - %.0f%% (the rule says ~%.0f%%)%s"):format(b * 10, b * 10 + 10, x[1], x[2], x[2] / x[1] * 100,
				(1 - mid) * 100, x[1] >= 30 and "" or " |cff909090(needs 30 to count)|r"))
		end
	end
	if not any then PA.Print("  nothing yet - it counts as you craft yellow and green recipes.") end
end

-- after every full scan: work it all out again (the scan's last step records each item's market price)
if type(PA.RecordScan) == "function" then
	hooksecurefunc(PA, "RecordScan", function()
		C_Timer.After(0.5, function()
			P.Refresh()
			PA.Print("profession guide and Flip list updated with the new prices - /pah level or /pah flip.")
		end)
	end)
end
-- /pah level, /pah flip
do
	local prev = SlashCmdList.PINTSAUCTIONS
	SlashCmdList.PINTSAUCTIONS = function(msg)
		local m = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
		if m == "level" or m == "plan" or m == "planner" then P.Toggle("level")
		elseif m == "flip" then P.Toggle("flip")
		elseif m == "skillups" then P.SkillupReport()
		elseif prev then prev(msg) end
		if m == "help" or m == "?" then PA.Print("/pah level - cheapest way to level a profession   /pah flip - craft (or buy) and sell for a profit") end
	end
end
-- a button on Pint's Auctions' panel beside the auction house (or on the auction window itself)
local function AddButton(parent, point, x, y, w)
	if not parent or parent.pintsPlan then return end
	local b = PA.Btn(parent, "Profession planner", w or 130, 18)
	b:SetPoint(point, parent, point, x, y)
	b:SetFrameLevel(parent:GetFrameLevel() + 30)
	b:SetScript("OnClick", function() P.Toggle() end)
	PA.Tip(b, "Pint's Profession Planner", "Cheapest way to level a profession, and what to craft and sell for a profit, at the prices from your full scans.")
	parent.pintsPlan = b
end
local function Place(tries)
	if _G.PintsAuctionsSide then AddButton(_G.PintsAuctionsSide, "TOPRIGHT", -76, -6, 124)        -- WoW Forever: left of Options
	elseif _G.PintsAuctionsFrame then AddButton(_G.PintsAuctionsFrame, "TOPRIGHT", -110, -8)    -- Classic Era: left of Options
	elseif tries < 10 then C_Timer.After(0.3, function() Place(tries + 1) end) end
end
local hook = CreateFrame("Frame")
pcall(hook.RegisterEvent, hook, "AUCTION_HOUSE_SHOW")
hook:SetScript("OnEvent", function() C_Timer.After(0.2, function() Place(0) end) end)
