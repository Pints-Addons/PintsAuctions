-- Pint's Auctions - options pages (Esc > Options > AddOns > Pint's Auctions, or /pah).
local ADDON, NS = ...
local PA = NS.PA
local Money = PA.Money
local function S() return PA.S end

local pages, category = {}, nil

local function Page(name, intro)
	local p = CreateFrame("Frame"); p.name = name; p:Hide()
	p.refresh = {}
	local t = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); t:SetPoint("TOPLEFT", 16, -16); t:SetText(#pages == 0 and "Pint's Auctions" or ("Pint's Auctions - " .. name))
	if intro then
		local i = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); i:SetPoint("TOPLEFT", 16, -42); i:SetWidth(560); i:SetJustifyH("LEFT"); i:SetText(intro)
	end
	p.y = intro and -70 or -48
	p:SetScript("OnShow", function(self) for _, f in ipairs(self.refresh) do f() end end)
	pages[#pages + 1] = p
	return p
end
local function Heading(p, text)
	p.y = p.y - 6
	local h = p:CreateFontString(nil, "OVERLAY", "GameFontNormal"); h:SetPoint("TOPLEFT", 16, p.y); h:SetText(text)
	p.y = p.y - 20
end
local function Check(p, label, key, tip, x)
	local c = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate"); c:SetSize(24, 24); c:SetPoint("TOPLEFT", x or 16, p.y)
	local t = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); t:SetPoint("LEFT", c, "RIGHT", 2, 0); t:SetText(label)
	local get = type(key) == "table" and key[1] or function() return S()[key] end
	local set = type(key) == "table" and key[2] or function(v) S()[key] = v end
	c:SetScript("OnClick", function(self) set(self:GetChecked() and true or false); if p.changed then p.changed() end end)
	table.insert(p.refresh, function() c:SetChecked(get() and true or false) end)
	if tip then PA.Tip(c, label, tip) end
	p.y = p.y - 26
	return c
end
-- radio row: options = { {value, label}, ... }
local function Choice(p, label, key, options, tip)
	local t = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); t:SetPoint("TOPLEFT", 20, p.y - 4); t:SetText(label)
	local x, btns = 200, {}
	for i, o in ipairs(options) do
		local r = CreateFrame("CheckButton", nil, p, "UIRadioButtonTemplate"); r:SetSize(16, 16); r:SetPoint("TOPLEFT", x, p.y - 2)
		local l = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); l:SetPoint("LEFT", r, "RIGHT", 2, 0); l:SetText(o[2])
		r:SetScript("OnClick", function() S()[key] = o[1]; for j, b in ipairs(btns) do b:SetChecked(j == i) end end)
		btns[i] = r
		x = x + 24 + math.max(50, l:GetStringWidth() or 50)
	end
	if tip then PA.Tip(btns[1], label, tip) end
	table.insert(p.refresh, function() for i, b in ipairs(btns) do b:SetChecked(S()[key] == options[i][1]) end end)
	p.y = p.y - 24
end
local function Stepper(p, label, key, lo, hi, inc, fmt, tip)
	local t = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); t:SetPoint("TOPLEFT", 20, p.y - 4); t:SetText(label)
	local m = PA.Btn(p, "-", 22, 20); m:SetPoint("TOPLEFT", 300, p.y)
	local v = p:CreateFontString(nil, "OVERLAY", "GameFontNormal"); v:SetPoint("LEFT", m, "RIGHT", 4, 0); v:SetWidth(60)
	local pl = PA.Btn(p, "+", 22, 20); pl:SetPoint("LEFT", v, "RIGHT", 4, 0)
	local function show() v:SetText(fmt(S()[key])) end
	local function step(d) S()[key] = math.max(lo, math.min(hi, math.floor((S()[key] + d) * 100 + 0.5) / 100)); show() end
	m:SetScript("OnClick", function() step(-inc) end); pl:SetScript("OnClick", function() step(inc) end)
	if tip then PA.Tip(m, label, tip) end
	table.insert(p.refresh, show)
	p.y = p.y - 26
end
local function Pct(x) return math.floor(x * 100 + 0.5) .. "%" end

local function Build()
	-------------------------------------------------- basic
	local b = Page("Basic", "Shopping, Selling, Cancelling and Pint's tabs sit along the bottom of the auction window. Prices are kept per realm and faction, and show in item tooltips.")
	Heading(b, "Auction house")
	Choice(b, "Open on this tab", "defaultTab", { { "none", "Game's own" }, { "shop", "Shopping" }, { "sell", "Selling" }, { "cancel", "Cancelling" }, { "pints", "Pint's" } },
		"Which tab the auction window opens on.")
	Heading(b, "Crafting")
	Check(b, "Show what the reagents cost on the profession window", "craftCost")
	Check(b, "Show the profit (what it sells for, less the reagents)", "craftProfit")
	Heading(b, "Other")
	Check(b, "Minimap button", { function() return not PA.db.minimap.hide end, function(v) if (not PA.db.minimap.hide) ~= v then PA.ToggleMinimap() end end })
	local off = PA.Btn(b, "Switch Auctionator off", 180, 22); off:SetPoint("TOPLEFT", 20, b.y - 4)
	off:SetScript("OnClick", PA.AuctionatorOff)
	table.insert(b.refresh, function() off:SetShown(PA.AuctionatorLoaded()) end)

	-------------------------------------------------- tooltips
	local t = Page("Tooltips", "Extra lines on item tooltips, everywhere: bags, bank, mail, chat links.")
	Check(t, "Latest auction price", "tooltip")
	Check(t, "Usual price (middle of the last two weeks' lows), when it differs", "tipTypical")
	Check(t, "Say how old the price is, when it's over two days old", "tipAge")
	Check(t, "Vendor sell price (hidden at a vendor, which shows its own)", "tipVendor")
	Check(t, "Only show the whole-stack value while Shift is held", "tipShiftStack")

	-------------------------------------------------- shopping
	local sh = Page("Shopping", "Shopping lists are saved searches you can run together.")
	do
		local lbl = sh:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lbl:SetPoint("TOPLEFT", 20, sh.y - 4); lbl:SetText("Default list")
		local btn = PA.Btn(sh, "", 200, 22); btn:SetPoint("TOPLEFT", 200, sh.y)
		local function show() local d = S().defaultList; btn:SetText((d and d ~= "" and PA.db.lists[d]) and d or "None") end
		btn:SetScript("OnClick", function()
			local names = { "" }
			for n in pairs(PA.db.lists) do names[#names + 1] = n end
			table.sort(names)
			local cur = 1
			for i, n in ipairs(names) do if n == (S().defaultList or "") then cur = i end end
			S().defaultList = names[cur % #names + 1]; show()
		end)
		PA.Tip(btn, "Default list", "Click to cycle through your lists. It's picked when you open the Shopping tab.")
		table.insert(sh.refresh, show)
		sh.y = sh.y - 28
	end
	Check(sh, "Search a list as soon as you pick it", "listAutoSearch")
	Check(sh, "Show list searches that found nothing", "showEmpty")
	Check(sh, "Load every page of results (slower on big searches)", "allPages")
	Check(sh, "Chain buying: after a buy, the next cheapest stack is ready to buy", "chainBuy")
	Check(sh, "Chain buying: warn when the next stack costs much more", "chainWarn")
	Stepper(sh, "  ...than the stack you just bought", "chainJump", 0.05, 1, 0.05, function(x) return "+" .. math.floor(x * 100 + 0.5) .. "%" end,
		"Warn when the next stack costs this much more each than the one you just bought.")
	Stepper(sh, "  ...than the first stack you bought", "chainJumpFirst", 0.05, 2, 0.05, function(x) return "+" .. math.floor(x * 100 + 0.5) .. "%" end,
		"Catches prices creeping up a little at a time: warn when the next stack costs this much more each than the first one in the chain.")

	-------------------------------------------------- selling
	local se = Page("Selling")
	Heading(se, "Price")
	Choice(se, "Undercut by", "undercutMode", { { "value", "A set amount" }, { "pct", "A percentage" } })
	do
		local lbl = se:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); lbl:SetPoint("TOPLEFT", 20, se.y - 4); lbl:SetText("Set amount")
		local mb = PA.MoneyBox(se, function(user) if user then S().undercut = se.mb:Get() or 0 end end); mb:SetPoint("TOPLEFT", 194, se.y); se.mb = mb
		table.insert(se.refresh, function() mb:Set(S().undercut or 0) end)
		se.y = se.y - 26
	end
	Stepper(se, "Percentage", "undercutPct", 0, 50, 1, function(x) return x .. "%" end)
	Stepper(se, "No auction price: vendor price x", "gearMult", 1, 20, 0.5, function(x) return x .. "x" end, "Used when nothing is on sale and no price has been seen.")
	Check(se, "Treat random-suffix items (\"of the Bear\") as one item", "ignoreSuffix")
	Heading(se, "Bids")
	Check(se, "Set a starting bid below the buyout", "useBid")
	Stepper(se, "Starting bid, % of buyout", "bidPct", 0.5, 1, 0.05, Pct)
	local sp = Page("Selling: Posting")
	se = sp
	Choice(se, "Default duration", "duration", { { 1, "2 hours" }, { 2, "8 hours" }, { 3, "24 hours" } })
	Check(se, "Remember the last duration used", "rememberDur")
	Choice(se, "Stacks", "stackMode", { { "max", "Full stacks, all I have" }, { "single", "One stack as placed" }, { "ones", "Singles" } })
	Check(se, "Ask again before posting well under the usual price", "confirmLow")
	Stepper(se, "\"Well under\" means below", "lowWarn", 0.1, 1, 0.05, Pct)
	Check(se, "Grey out Post when you can't pay the deposit", "greyPost")
	Check(se, "After posting, go on to the next item", "autoNext")
	Check(se, "Say what was posted in chat", "chatPosts")

	-------------------------------------------------- shortcuts
	local k = Page("Shortcuts", "These work at the auction house when you're not typing in a box.")
	Check(k, "Alt-click a bag item to sell it", "altSell")
	Check(k, "Selling: Space posts", "spacePost")
	Check(k, "Selling: Shift-Space skips to the next item", "shiftSkip")
	Check(k, "Selling: Backspace goes back an item", "bsPrev")
	Check(k, "Cancelling: Space cancels the next undercut auction", "spaceCancel")

	-------------------------------------------------- cancelling
	local c = Page("Cancelling")
	Stepper(c, "Undercut once more than this many are cheaper", "aheadMin", 0, 200, 1, function(x) return tostring(x) end,
		"0 means any cheaper auction counts. Raise it to ignore a few cheap ones.")

	-------------------------------------------------- profile and advanced
	local pr = Page("Profile", "Settings are shared by all your characters unless you give this one its own.")
	Check(pr, "This character has its own settings", { function() return PintsAuctionsCharDB and PintsAuctionsCharDB.perChar end,
		function(v) PA.SetPerCharacter(v); for _, pg in ipairs(pages) do if pg:IsShown() then pg:GetScript("OnShow")(pg) end end end })
	local reset = PA.Btn(pr, "Reset these settings", 160, 22); reset:SetPoint("TOPLEFT", 20, pr.y - 4)
	reset:SetScript("OnClick", function() PA.ResetSettings(); pr:GetScript("OnShow")(pr); PA.Print("settings reset.") end)
	pr.y = pr.y - 40
	Heading(pr, "Advanced")
	Check(pr, "Debug messages (each auction house search)", "debug")
end

local function Register()
	if Settings and Settings.RegisterCanvasLayoutCategory then
		category = Settings.RegisterCanvasLayoutCategory(pages[1], "Pint's Auctions")
		for i = 2, #pages do Settings.RegisterCanvasLayoutSubcategory(category, pages[i], pages[i].name) end
		Settings.RegisterAddOnCategory(category)
	elseif InterfaceOptions_AddCategory then
		pages[1].name = "Pint's Auctions"
		for i, p in ipairs(pages) do if i > 1 then p.parent = "Pint's Auctions" end; InterfaceOptions_AddCategory(p) end
	end
end
function PA.OpenOptions()
	if category and Settings and Settings.OpenToCategory then Settings.OpenToCategory(category:GetID())
	elseif InterfaceOptionsFrame_OpenToCategory then InterfaceOptionsFrame_OpenToCategory(pages[1]); InterfaceOptionsFrame_OpenToCategory(pages[1]) end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function() Build(); Register() end)
