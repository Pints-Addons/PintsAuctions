-- Pint's Auctions - the Cancelling and Pint's tabs, plus start-up, Alt-click selling, slash command and minimap button.
local ADDON, NS = ...
-- Compatibility: WoW Forever runs on the modern game client, where these older functions moved or were renamed.
local GetItemInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)

local PA = NS.PA
local Print, Money = PA.Print, PA.Money
local ME = UnitName("player")
local function S() return PA.S end

---------------------------------------------------------------- Cancelling
local mine = { rows = {} }
local TIMELEFT = { "|cffff4040< 30m|r", "|cffffa040< 2h|r", "|cffffff40< 8h|r", "|cff40ff40> 8h|r" }
local others = {}            -- name -> { {unit, count}, ... } from the last undercut scan; false = nobody else
local function ReadOwned()
	local out = {}
	for i = 1, (GetNumAuctionItems("owner")) do
		local name, texture, count, quality, _, _, _, minBid, _, buyout, bidAmount, highBidder, _, _, _, saleStatus = GetAuctionItemInfo("owner", i)
		if name then
			out[#out + 1] = { index = i, name = name, texture = texture, count = count or 1, quality = quality, buyout = buyout or 0, minBid = minBid,
				bid = bidAmount, bidder = highBidder, sold = saleStatus == 1, left = GetAuctionItemTimeLeft and GetAuctionItemTimeLeft("owner", i), link = GetAuctionItemLink("owner", i) }
		end
	end
	return out
end
local function ShowOwned()
	if not mine.list then return end
	local rows = ReadOwned()
	mine.rows = rows
	local data, under = {}, 0
	for _, r in ipairs(rows) do
		local unit = r.buyout > 0 and r.buyout / r.count or nil
		local o = others[r.name]
		local state, ahead = "", ""
		r.under = nil
		if r.sold then state = "|cff40ff40sold|r"
		elseif o == nil then state = "|cff888888-|r"
		else
			local n = 0
			if o and unit then for _, a in ipairs(o) do if a[1] < unit then n = n + a[2] end end end
			ahead = n
			if n > (S().aheadMin or 0) then state = "|cffff4040undercut|r"; under = under + 1; r.under = true
			elseif n > 0 then state = "|cffffff40close|r"
			else state = "|cff40ff40lowest|r" end
		end
		if r.bid and r.bid > 0 and not r.sold then state = state .. " |cffffd100bid|r" end
		data[#data + 1] = { PA.QName and PA.QName(r.name, r.quality) or r.name, r.count, Money(unit), TIMELEFT[r.left or 4] or "", state, ahead,
			texture = r.texture, link = r.link, owned = r }
	end
	mine.list:Set(data, true)
	mine.status:SetText(#rows .. " auction" .. (#rows == 1 and "" or "s") .. (under > 0 and (", |cffff4040" .. under .. " undercut|r") or "") .. ". Click one to cancel it.")
	mine.cancelNext:SetEnabled(under > 0)
	mine.cancelNext:SetText(under > 0 and ("Cancel undercut (" .. under .. ")") or "Cancel undercut")
end
PA.ShowOwned = ShowOwned
local function Scan()
	local names, list = {}, {}
	for _, r in ipairs(ReadOwned()) do if not r.sold and not names[r.name] then names[r.name] = true; list[#list + 1] = r.name end end
	wipe(others)
	PA.CancelSearches()
	if #list == 0 then mine.status:SetText("Nothing up for sale."); return end
	for k, n in ipairs(list) do
		local seen = false
		PA.Search({ text = n, exact = true, maxPages = 5,
			onPage = function() mine.status:SetText(("Checking %s (%d of %d)..."):format(n, k, #list)) end,
			onRow = function(r)
				if r.owner ~= ME and r.buyout > 0 and r.name == n then
					seen = seen or {}
					seen[#seen + 1] = { r.buyout / r.count, r.count }
				end
			end,
			onDone = function()
				others[n] = seen
				if k == #list then ShowOwned() end
			end })
	end
end
PA.UndercutScan = Scan
local function Cancel(r)
	if not r or r.sold then return end
	local name, _, count, _, _, _, _, _, _, buyout = GetAuctionItemInfo("owner", r.index)
	if name ~= r.name or count ~= r.count or buyout ~= r.buyout then Print("your list moved - try again."); ShowOwned(); return end
	CancelAuction(r.index)
	if r.bid and r.bid > 0 then Print("note: that one had a bid on it.") end
	Print(("cancelled %d %s."):format(count, name))
end
function PA.CancelNext()
	for _, r in ipairs(mine.rows or {}) do if r.under then Cancel(r); r.under = nil; return end end
end
function PA.BuildCancel(p)
	local Label, Btn, List = PA.Label, PA.Btn, PA.List
	local scan = Btn(p, "Undercut scan", 120, 22); scan:SetPoint("TOPLEFT", 0, 0); scan:SetScript("OnClick", Scan)
	mine.cancelNext = Btn(p, "Cancel undercut", 150, 22); mine.cancelNext:SetPoint("LEFT", scan, "RIGHT", 6, 0)
	mine.cancelNext:SetScript("OnClick", PA.CancelNext)
	PA.Tip(mine.cancelNext, "Cancel undercut", "Cancels the next auction someone has undercut. Space does the same when you're not typing.")
	local ref = Btn(p, "Refresh", 80, 22); ref:SetPoint("LEFT", mine.cancelNext, "RIGHT", 6, 0)
	ref:SetScript("OnClick", function() if GetOwnerAuctionItems then GetOwnerAuctionItems() end; ShowOwned() end)
	mine.status = Label(p, "", "GameFontDisableSmall"); mine.status:SetPoint("LEFT", ref, "RIGHT", 12, 0); mine.status:SetWidth(380); mine.status:SetJustifyH("LEFT")
	mine.list = List(p, 762, 18, 17, { { 300, "LEFT", "Name" }, { 60, "RIGHT", "Quantity" }, { 120, "RIGHT", "Unit price" }, { 80, "RIGHT", "Time left" }, { 110, "RIGHT", "Undercut?" }, { 70, "RIGHT", "Items ahead" } },
		function(item) Cancel(item.owned) end)
	mine.list:SetPoint("TOPLEFT", 0, -44)
	p.OnOpen = function() if GetOwnerAuctionItems then GetOwnerAuctionItems() end; ShowOwned() end
end

---------------------------------------------------------------- Pint's (prices, full scan, help)
function PA.BuildPints(p)
	local Label, Btn = PA.Label, PA.Btn
	local h = Label(p, "Prices", "GameFontNormalLarge"); h:SetPoint("TOPLEFT", 4, -4)
	local info = Label(p, "A full scan reads every auction at once and remembers the lowest price of each item. The auction house allows one every 15 minutes. "
		.. "Searches on the other tabs keep prices up to date too. Prices show in item tooltips everywhere, and other Pint's add-ons use them.")
	info:SetPoint("TOPLEFT", 4, -30); info:SetWidth(560); info:SetJustifyH("LEFT")
	local scan = Btn(p, "Full scan", 140, 26); scan:SetPoint("TOPLEFT", 4, -80)
	local state = Label(p, ""); state:SetPoint("LEFT", scan, "RIGHT", 10, 0); state:SetWidth(420); state:SetJustifyH("LEFT")
	scan:SetScript("OnClick", function() PA.FullScan() end)
	PA.OnScanState = function(t) state:SetText(t) end
	local count = Label(p, ""); count:SetPoint("TOPLEFT", 4, -114)
	local keys = Label(p, "", "GameFontNormal"); keys:SetPoint("TOPLEFT", 4, -150)
	keys:SetText("Shortcuts")
	local kt = Label(p, "Selling:  Space posts  -  Shift-Space skips to the next item  -  Backspace goes back  -  Alt-click a bag item to sell it\n"
		.. "Cancelling:  Space cancels the next undercut auction\n"
		.. "Shopping:  right-click a search in a list to remove it\n\n"
		.. "Options:  the Options button at the top, or Esc > Options > AddOns > Pint's Auctions, or /pah options")
	kt:SetPoint("TOPLEFT", 4, -170); kt:SetWidth(700); kt:SetJustifyH("LEFT"); kt:SetSpacing(4)
	local off = Btn(p, "Switch Auctionator off", 180, 22); off:SetPoint("TOPLEFT", 4, -260)
	off:SetScript("OnClick", PA.AuctionatorOff)
	p.OnOpen = function()
		off:SetShown(PA.AuctionatorLoaded())
		count:SetText("Prices remembered on this realm: |cffffffff" .. PA.Count() .. "|r")
		if not PA.scanning then
			local w = PA.FullScanWait()
			state:SetText(w > 0 and ("Next full scan in about " .. math.ceil(w / 60) .. " min.") or "Ready.")
		end
	end
end

---------------------------------------------------------------- start-up and hooks
local ev = CreateFrame("Frame")
ev:RegisterEvent("AUCTION_HOUSE_SHOW"); pcall(ev.RegisterEvent, ev, "AUCTION_OWNED_LIST_UPDATE")
ev:SetScript("OnEvent", function(_, e)
	if not AuctionFrame then return end      -- WoW Forever: the modern auction house (Modern.lua)
	if e == "AUCTION_HOUSE_SHOW" then
		PA.BuildHost()
		local t = S().defaultTab
		if t and t ~= "none" then C_Timer.After(0, function() if AuctionFrame:IsShown() then PA.SelectTab(t) end end) end
	elseif e == "AUCTION_OWNED_LIST_UPDATE" then
		if PA.HostShown() and PA.page == "cancel" then ShowOwned() end
	end
end)
-- Alt-click an item in your bags at the auction house: sell it
hooksecurefunc("HandleModifiedItemClick", function(link)
	if not (S() and S().altSell and AuctionFrame and AuctionFrame:IsShown() and IsAltKeyDown() and link) then return end
	PA.BuildHost()
	if not (PA.HostShown() and PA.page == "sell") then PA.SelectTab("sell") end
	local key = PA.Key(link)
	for i, g in ipairs(PA.sell.bags) do if g.key == key then PA.SellSelect(i); return end end
end)

-- Shift-click any item (bags, recipe reagents in a profession window, chat links...) while the auction house is open
-- and you're not typing in chat: look it up on the Shopping tab. Profession windows send shift-clicks two different
-- ways depending on the window, so both are watched; a click seen by both only searches once.
local lastLookup, lastAt = nil, 0
local function Typing()
	local eb = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
	return eb and eb:IsShown() and eb:HasFocus()
end
local function Lookup(link)
	if type(link) ~= "string" or not link:find("|Hitem:") then return end
	if not (S() and AuctionFrame and AuctionFrame:IsShown()) or IsAltKeyDown() or Typing() then return end
	if link == lastLookup and GetTime() - lastAt < 0.3 then return end
	lastLookup, lastAt = link, GetTime()
	local name = GetItemInfo(link) or link:match("%[(.-)%]")
	if not name then return end
	if S().debug then Print("shift-click lookup: " .. name) end
	PA.BuildHost()
	if not (PA.HostShown() and PA.page == "shop") then PA.SelectTab("shop") end
	C_Timer.After(0, function() if PA.OpenItem then PA.OpenItem({ name = name, key = PA.Key(link) }) end end)
end
local function Dbg(from, link) if S() and S().debug then Print("shift-click seen (" .. from .. "): " .. tostring(link)) end end
hooksecurefunc("HandleModifiedItemClick", function(link) Dbg("item click", link); if IsModifiedClick("CHATLINK") then Lookup(link) end end)
if type(ChatEdit_InsertLink) == "function" then hooksecurefunc("ChatEdit_InsertLink", function(text) Dbg("chat link", text); Lookup(text) end) end
-- and the reagent buttons of the profession windows themselves, in case they hand the click on some other way
local function HookReagents(prefix, linkFn, selFn)
	for i = 1, 12 do
		local b = _G[prefix .. i]
		if b and not b.pintsHooked then
			b.pintsHooked = true
			b:HookScript("OnClick", function(self)
				if not IsShiftKeyDown() then return end
				local f, sel = _G[linkFn], _G[selFn]
				local link = f and sel and f(sel(), self:GetID())
				Dbg("reagent button", link)
				Lookup(link)
			end)
		end
	end
end
local rh = CreateFrame("Frame")
rh:RegisterEvent("ADDON_LOADED"); rh:RegisterEvent("PLAYER_LOGIN")
rh:SetScript("OnEvent", function()
	HookReagents("TradeSkillReagent", "GetTradeSkillReagentItemLink", "GetTradeSkillSelectionIndex")
	HookReagents("CraftReagent", "GetCraftReagentItemLink", "GetCraftSelectionIndex")
end)

---------------------------------------------------------------- slash and minimap
SLASH_PINTSAUCTIONS1 = "/pah"
SLASH_PINTSAUCTIONS2 = "/pintsauctions"
SlashCmdList.PINTSAUCTIONS = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "off-auctionator" then PA.AuctionatorOff()
	elseif msg == "lists" then local n = PA.AddStarterLists(true); Print(n > 0 and ("added back " .. n .. " starter shopping list" .. (n == 1 and "" or "s") .. ".") or "all the starter shopping lists are already there.")
	elseif msg == "shop" then if PA.ToggleLists then PA.ToggleLists() end
	elseif msg == "scan" then PA.FullScan()
	elseif msg == "minimap" then PA.ToggleMinimap()
	elseif msg == "debug" then S().debug = not S().debug; Print("debug " .. (S().debug and "on" or "off"))
	elseif msg == "options" or msg == "" then if PA.OpenOptions then PA.OpenOptions() end
	else
		Print("/pah - options   /pah scan - full scan (at the auction house)   /pah minimap - hide or show the minimap button")
		Print("At the auction house: the Shopping, Selling, Cancelling and Pint's tabs are along the bottom of the auction window.")
	end
end
do
	local NAME, ICON, ANGLE = "PintsAuctions", "Interface\\AddOns\\PintsAuctions\\Icon", 120
	local btn
	local function Open() if PA.OpenOptions then PA.OpenOptions() end end
	local function Tip(tt) tt:AddLine("Pint's Auctions"); tt:AddLine("Click: options. The tabs are at the bottom of the auction window.", 1, 1, 1, true); tt:AddLine("/pah minimap to hide", 0.5, 0.5, 0.5) end
	function PA.BuildMinimap()
		local store = PA.db.minimap
		local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
		local Icon = LibStub and LibStub("LibDBIcon-1.0", true)
		if LDB and Icon then
			local obj = LDB:NewDataObject(NAME, { type = "launcher", text = "Pint's Auctions", icon = ICON, OnClick = Open, OnTooltipShow = Tip })
			Icon:Register(NAME, obj, store); btn = { lib = Icon }; return
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
		b:SetScript("OnClick", Open)
		b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_LEFT"); Tip(GameTooltip); GameTooltip:Show() end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		b:SetShown(not store.hide); btn = b
	end
	function PA.ToggleMinimap()
		local store = PA.db.minimap; store.hide = not store.hide
		if btn and btn.lib then if store.hide then btn.lib:Hide(NAME) else btn.lib:Show(NAME) end elseif btn then btn:SetShown(not store.hide) end
	end
end
