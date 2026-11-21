-- Pint's Auctions: Craftsman's Writs (WoW Forever). Every writ, what it costs on the auction house, the cheapest way to
-- get what it asks for (counting what you already have), the total, the reputation it gives (Azeroth Commerce Authority
-- or Durotar Supply and Logistics - yours) and what 100 reputation costs that way. Scan writs: one search finds every
-- writ for sale, then each listed writ's item is priced. Buy buttons open the writ, or its item, in the Buy view.
-- Writs, what they ask for and their reputation: Wowhead's WoW Forever database (November 2026).
local ADDON, NS = ...
local PA = NS.PA
if not (PA and C_AuctionHouse) or QueryAuctionItems then return end
local GII = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local Count = (C_Item and C_Item.GetItemCount) or GetItemCount

-- { writ quest, writ item, name, item it asks for, how many, its name, { { faction, reputation }, ... }, coin pouch (copper, about) }
local WRITS = {
	{ 94004, 264011, "Elixir of Ogre's Strength", 3391, 1, "Elixir of Ogre's Strength", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94212, 264012, "Elixir of Wisdom", 3383, 1, "Elixir of Wisdom", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94213, 264013, "Lesser Mana Potion", 3385, 1, "Lesser Mana Potion", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94214, 264014, "Shadow Protection Potion", 6048, 1, "Shadow Protection Potion", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94215, 264015, "Free Action Potion", 5634, 1, "Free Action Potion", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94216, 264016, "Elixir of Lesser Agility", 3390, 1, "Elixir of Lesser Agility", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94217, 264017, "Lesser Troll's Blood Elixir", 3388, 1, "Lesser Troll's Blood Elixir", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94218, 264018, "Elixir of Defense", 8951, 1, "Elixir of Defense", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94219, 264019, "Draught of Water Breathing", 5996, 1, "Draught of Water Breathing", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94220, 264020, "Pearl-Handled Dagger", 5540, 1, "Pearl-Handled Dagger", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94221, 264021, "Golden Rod", 11128, 1, "Golden Rod", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94222, 264022, "Iridescent Hammer", 5541, 1, "Iridescent Hammer", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94223, 264023, "Silver Skeleton Key", 15869, 1, "Silver Skeleton Key", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94224, 264024, "Heavy Bronze Mace", 3491, 1, "Heavy Bronze Mace", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94225, 264025, "Rough Bronze Leggings", 2865, 1, "Rough Bronze Leggings", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94226, 264026, "Green Iron Gauntlets", 3485, 1, "Green Iron Gauntlets", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94227, 264027, "Big Bronze Knife", 3848, 1, "Big Bronze Knife", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94228, 264028, "Green Iron Boots", 3484, 1, "Green Iron Boots", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94229, 264029, "Ornate Spyglass", 5507, 1, "Ornate Spyglass", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94230, 264030, "Explosive Sheep", 4384, 1, "Explosive Sheep", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94231, 264031, "Moonsight Rifle", 4383, 1, "Moonsight Rifle", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94232, 264032, "Minor Recombobulator", 4381, 1, "Minor Recombobulator", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94233, 264033, "Practice Lock", 6712, 1, "Practice Lock", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94234, 264034, "Shadow Goggles", 4373, 1, "Shadow Goggles", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94235, 264035, "Gnomish Universal Remote", 7506, 1, "Gnomish Universal Remote", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94236, 264036, "Big Bronze Bomb", 4380, 1, "Big Bronze Bomb", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94237, 264037, "Crafted Solid Shot", 8069, 200, "Crafted Solid Shot", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94238, 264038, "Heavy Leather Ball", 18662, 1, "Heavy Leather Ball", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94239, 264039, "Fine Leather Pants", 5958, 1, "Fine Leather Pants", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94240, 264040, "Herbalist's Gloves", 7349, 1, "Herbalist's Gloves", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94241, 264041, "Dark Leather Tunic", 2317, 1, "Dark Leather Tunic", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94242, 264042, "Pilferer's Gloves", 7358, 1, "Pilferer's Gloves", { { 2586, 75 }, { 2587, 75 } }, 0 },
	{ 94243, 264043, "Heavy Quiver", 7371, 1, "Heavy Quiver", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94244, 264044, "Dark Leather Shoulders", 4252, 1, "Dark Leather Shoulders", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94245, 264045, "Barbaric Gloves", 4254, 1, "Barbaric Gloves", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94246, 264046, "Red Whelp Gloves", 7284, 1, "Red Whelp Gloves", { { 2586, 75 }, { 2587, 75 } }, 0 },
	{ 94247, 264047, "Lesser Wizard's Robe", 5766, 1, "Lesser Wizard's Robe", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94248, 264048, "Blue Overalls", 6263, 1, "Blue Overalls", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94249, 264049, "Azure Silk Hood", 7048, 1, "Azure Silk Hood", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94250, 264050, "Small Silk Pack", 4245, 1, "Small Silk Pack", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94251, 264051, "Phoenix Pants", 4317, 1, "Phoenix Pants", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94252, 264052, "Red Woolen Boots", 4313, 1, "Red Woolen Boots", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94253, 264053, "Colorful Kilt", 10048, 1, "Colorful Kilt", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94254, 264054, "Greater Adept's Robe", 6264, 1, "Greater Adept's Robe", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94255, 264055, "Spider Silk Slippers", 4321, 1, "Spider Silk Slippers", { { 2586, 75 }, { 2587, 75 } }, 3471 },
	{ 94256, 264056, "Frost Protection Potion", 6050, 1, "Frost Protection Potion", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94257, 264057, "Lesser Invisibility Potion", 3823, 1, "Lesser Invisibility Potion", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94258, 264058, "Lesser Stoneshield Potion", 4623, 1, "Lesser Stoneshield Potion", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94259, 264059, "Nature Protection Potion", 6052, 1, "Nature Protection Potion", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94260, 264060, "Catseye Draught", 10592, 1, "Catseye Draught", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94261, 264061, "Great Rage Potion", 5633, 1, "Great Rage Potion", { { 2586, 125 }, { 2587, 125 } }, 0 },
	{ 94262, 264062, "Mana Potion", 3827, 1, "Mana Potion", { { 2586, 75 }, { 2587, 75 } }, 7536 },
	{ 94263, 264063, "Fire Protection Potion", 6049, 1, "Fire Protection Potion", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94264, 264064, "Shadow Oil", 3824, 1, "Shadow Oil", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94265, 264065, "Goblin Rocket Fuel", 9061, 1, "Goblin Rocket Fuel", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94266, 264066, "Elixir of Agility", 8949, 1, "Elixir of Agility", { { 2586, 75 }, { 2587, 75 } }, 7536 },
	{ 94267, 264067, "Wildvine Potion", 9144, 1, "Wildvine Potion", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94268, 264068, "Steel Plate Helm", 7922, 1, "Steel Plate Helm", { { 2586, 125 }, { 2587, 125 } }, 0 },
	{ 94269, 264069, "Inlaid Mithril Cylinder", 9060, 1, "Inlaid Mithril Cylinder", { { 2586, 125 }, { 2587, 125 } }, 0 },
	{ 94270, 264070, "Steel Weapon Chain", 6041, 1, "Steel Weapon Chain", { { 2586, 125 }, { 2587, 125 } }, 0 },
	{ 94271, 264071, "Ornate Mithril Shoulders", 7928, 1, "Ornate Mithril Shoulders", { { 2586, 125 }, { 2587, 125 } }, 0 },
	{ 94272, 264072, "Blue Glittering Axe", 7942, 1, "Blue Glittering Axe", { { 2586, 125 }, { 2587, 125 } }, 0 },
	{ 94273, 264073, "Moonsteel Broadsword", 3853, 1, "Moonsteel Broadsword", { { 2586, 125 }, { 2587, 125 } }, 0 },
	{ 94274, 264074, "Golden Scale Coif", 3837, 1, "Golden Scale Coif", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94275, 264075, "Solid Sharpening Stone", 7964, 1, "Solid Sharpening Stone", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94276, 264076, "Wicked Mithril Blade", 7943, 1, "Wicked Mithril Blade", { { 2586, 125 }, { 2587, 125 } }, 0 },
	{ 94277, 264077, "Truesilver Rod", 11144, 1, "Truesilver Rod", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94278, 264078, "Golden Scale Gauntlets", 9366, 1, "Golden Scale Gauntlets", { { 2586, 125 }, { 2587, 125 } }, 0 },
	{ 94279, 264079, "Heavy Mithril Axe", 7941, 1, "Heavy Mithril Axe", { { 2586, 125 }, { 2587, 125 } }, 0 },
	{ 94280, 264080, "Mechanical Dragonling", 4396, 1, "Mechanical Dragonling", { { 2586, 125 }, { 2587, 125 } }, 0 },
	{ 94281, 264081, "Advanced Target Dummy", 4392, 1, "Advanced Target Dummy", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94282, 264082, "Craftsman's Monocle", 4393, 1, "Craftsman's Monocle", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94283, 264083, "Goblin Land Mine", 4395, 1, "Goblin Land Mine", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94284, 264084, "Catseye Ultra Goggles", 10501, 1, "Catseye Ultra Goggles", { { 2586, 125 }, { 2587, 125 } }, 0 },
	{ 94285, 264085, "Unstable Trigger", 10560, 1, "Unstable Trigger", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94286, 264086, "Flash Bomb", 4852, 1, "Flash Bomb", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94287, 264087, "Fire Goggles", 10500, 1, "Fire Goggles", { { 2586, 125 }, { 2587, 125 } }, 0 },
	{ 94288, 264088, "Mithril Frag Bomb", 10514, 1, "Mithril Frag Bomb", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94289, 264089, "Gyromatic Micro-Adjuster", 10498, 1, "Gyromatic Micro-Adjuster", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94290, 264090, "Mechanical Repair Kit", 11590, 1, "Mechanical Repair Kit", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94291, 264091, "Dark Iron Bomb", 16005, 1, "Dark Iron Bomb", { { 2586, 125 }, { 2587, 125 } }, 0 },
	{ 94292, 264092, "Comfortable Leather Hat", 8174, 1, "Comfortable Leather Hat", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94293, 264093, "Guardian Cloak", 5965, 1, "Guardian Cloak", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94294, 264094, "Dusky Bracers", 7378, 1, "Dusky Bracers", { { 2586, 125 }, { 2587, 125 } }, 0 },
	{ 94295, 264095, "Wild Leather Helmet", 8214, 1, "Wild Leather Helmet", { { 2586, 125 }, { 2587, 125 } }, 0 },
	{ 94296, 264096, "Wild Leather Shoulders", 8210, 1, "Wild Leather Shoulders", { { 2586, 125 }, { 2587, 125 } }, 0 },
	{ 94297, 264097, "Quickdraw Quiver", 8217, 1, "Quickdraw Quiver", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94298, 264098, "Swift Boots", 7391, 1, "Swift Boots", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94299, 264099, "Nightscape Shoulders", 8192, 1, "Nightscape Shoulders", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94300, 264100, "Big Voodoo Mask", 8201, 1, "Big Voodoo Mask", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94301, 264101, "Big Voodoo Robe", 8200, 1, "Big Voodoo Robe", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94302, 264102, "Turtle Scale Breastplate", 8189, 1, "Turtle Scale Breastplate", { { 2586, 125 }, { 2587, 125 } }, 0 },
	{ 94303, 264103, "Thick Leather Ammo Pouch", 8218, 1, "Thick Leather Ammo Pouch", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94304, 264104, "Mageweave Bag", 10050, 1, "Mageweave Bag", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94305, 264105, "Shadoweave Gloves", 10023, 1, "Shadoweave Gloves", { { 2586, 125 }, { 2587, 125 } }, 0 },
	{ 94306, 264106, "Crimson Silk Robe", 7063, 1, "Crimson Silk Robe", { { 2586, 125 }, { 2587, 125 } }, 0 },
	{ 94307, 264107, "Shadoweave Robe", 10004, 1, "Shadoweave Robe", { { 2586, 125 }, { 2587, 125 } }, 0 },
	{ 94308, 264108, "Enchanted Mageweave Pouch", 22246, 1, "Enchanted Mageweave Pouch", { { 2586, 125 }, { 2587, 125 } }, 0 },
	{ 94309, 264109, "Star Belt", 4329, 1, "Star Belt", { { 2586, 125 }, { 2587, 125 } }, 0 },
	{ 94310, 264110, "Black Mageweave Vest", 9998, 1, "Black Mageweave Vest", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94311, 264111, "Red Mageweave Pants", 10009, 1, "Red Mageweave Pants", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94312, 264112, "Orange Martial Shirt", 10052, 1, "Orange Martial Shirt", { { 2586, 125 }, { 2587, 125 } }, 0 },
	{ 94313, 264113, "White Bandit Mask", 10008, 1, "White Bandit Mask", { { 2586, 125 }, { 2587, 125 } }, 7536 },
	{ 94314, 264114, "Cindercloth Robe", 10042, 1, "Cindercloth Robe", { { 2586, 125 }, { 2587, 125 } }, 0 },
	{ 94315, 264115, "Earthen Silk Belt", 7061, 1, "Earthen Silk Belt", { { 2586, 125 }, { 2587, 125 } }, 0 },
	{ 94316, 264116, "Potion of Demonslaying", 9224, 1, "Potion of Demonslaying", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94317, 264117, "Dreamless Sleep Potion", 12190, 1, "Dreamless Sleep Potion", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94318, 264118, "Greater Fire Protection Potion", 13457, 1, "Greater Fire Protection Potion", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94319, 264119, "Draught of Detect Demon", 9233, 1, "Draught of Detect Demon", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94320, 264120, "Gift of Arthas", 9088, 1, "Gift of Arthas", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94321, 264121, "Flask of Chromatic Resistance", 13513, 1, "Flask of Chromatic Resistance", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94322, 264122, "Limited Invulnerability Potion", 3387, 1, "Limited Invulnerability Potion", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94323, 264123, "Major Rejuvenation Potion", 18253, 1, "Major Rejuvenation Potion", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94324, 264124, "Distilled Firewater", 246948, 1, "Distilled Firewater", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94325, 264125, "Radiant Circlet", 12417, 1, "Radiant Circlet", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94326, 264126, "Radiant Belt", 12416, 1, "Radiant Belt", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94327, 264127, "Orcish War Leggings", 7929, 1, "Orcish War Leggings", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94328, 264128, "Mithril Spurs", 7969, 1, "Mithril Spurs", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94329, 264129, "Imperial Plate Chest", 12422, 1, "Imperial Plate Chest", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94330, 264130, "Darkrune Gauntlets", 20549, 1, "Darkrune Gauntlets", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94331, 264131, "Huge Thorium Battleaxe", 12775, 1, "Huge Thorium Battleaxe", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94332, 264132, "Arcanite Skeleton Key", 15872, 1, "Arcanite Skeleton Key", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94333, 264133, "Ebon Shiv", 7947, 1, "Ebon Shiv", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94334, 264134, "Masterwork Target Dummy", 16023, 1, "Masterwork Target Dummy", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94335, 264135, "Green Lens", 10504, 1, "Green Lens", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94336, 264136, "Lifelike Mechanical Toad", 15996, 1, "Lifelike Mechanical Toad", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94337, 264137, "Gnomish Alarm-O-Bot", 18645, 1, "Gnomish Alarm-O-Bot", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94338, 264138, "Goblin Jumper Cables XL", 18587, 1, "Goblin Jumper Cables XL", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94339, 264139, "Field Repair Bot 74A", 18232, 1, "Field Repair Bot 74A", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94340, 264140, "Truesilver Transformer", 18631, 1, "Truesilver Transformer", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94341, 264141, "Sniper Scope", 10548, 1, "Sniper Scope", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94342, 264142, "Tranquil Mechanical Yeti", 21277, 1, "Tranquil Mechanical Yeti", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94343, 264143, "Wicked Leather Pants", 15087, 1, "Wicked Leather Pants", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94344, 264144, "Gordok Ogre Suit", 18258, 1, "Gordok Ogre Suit", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94345, 264145, "Volcanic Breastplate", 15053, 1, "Volcanic Breastplate", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94346, 264146, "Runic Leather Headband", 15094, 1, "Runic Leather Headband", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94347, 264147, "Wicked Leather Bracers", 15084, 1, "Wicked Leather Bracers", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94348, 264148, "Chimeric Vest", 15075, 1, "Chimeric Vest", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94349, 264149, "Heavy Scorpid Helm", 15080, 1, "Heavy Scorpid Helm", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94350, 264150, "Runic Leather Bracers", 15092, 1, "Runic Leather Bracers", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94351, 264151, "Frostsaber Boots", 15071, 1, "Frostsaber Boots", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94352, 264152, "Wizardweave Turban", 14130, 1, "Wizardweave Turban", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94353, 264153, "Runecloth Bag", 14046, 1, "Runecloth Bag", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94354, 264154, "Runecloth Boots", 13864, 1, "Runecloth Boots", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94355, 264155, "Tuxedo Jacket", 10036, 1, "Tuxedo Jacket", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94356, 264156, "Felcloth Boots", 14108, 1, "Felcloth Boots", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94357, 264157, "Cenarion Herb Bag", 22251, 1, "Cenarion Herb Bag", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94358, 264158, "Shadoweave Mask", 10025, 1, "Shadoweave Mask", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94359, 264159, "Ghostweave Vest", 14141, 1, "Ghostweave Vest", { { 2586, 200 }, { 2587, 200 } }, 0 },
	{ 94360, 264160, "Soul Pouch", 21340, 1, "Soul Pouch", { { 2586, 200 }, { 2587, 200 } }, 0 },
}
PA.WRITS = WRITS

-- where each writ is turned in: END[writ quest] = { NPC, zone, x, y } (Wowhead's WoW Forever database, November 2026)
local END = {
	[94004] = { "Sos'mol", "Alterac Mountains", 38.4, 61.2 },
	[94212] = { "Muggol Breezebeard", "Arathi Highlands", 48.8, 55.8 },
	[94213] = { "Ash'alari", "Ashenvale", 60.2, 72.6 },
	[94214] = { "Kzixx", "Duskwood", 81.8, 19.8 },
	[94215] = { "Webbed Mudsnout Gnoll", "Hillsbrad Foothills", 62.4, 69 },
	[94216] = { "Ziz Fizziks", "Stonetalon Mountains", 59, 62.4 },
	[94217] = { "Short John Mithril", "Stranglethorn Vale", 29.6, 47.4 },
	[94218] = { "Rizzle Brassbolts", "Thousand Needles", 77.2, 77.4 },
	[94219] = { "Kixxle", "Wetlands", 50.2, 37.8 },
	[94220] = { "Alan Sneeks", "Alterac Mountains", 30.4, 61 },
	[94221] = { "Muggol Breezebeard", "Arathi Highlands", 48.8, 55.8 },
	[94222] = { "Cowardly Peon", "Ashenvale", 78.4, 68.8 },
	[94223] = { "Battered Trunk", "Duskwood", 26.2, 36.2 },
	[94224] = { "Gorgrash", "Hillsbrad Foothills", 80, 48.2 },
	[94225] = { "Ziz Fizziks", "Stonetalon Mountains", 59, 62.4 },
	[94226] = { "\"Sea Wolf\" MacKinley", "Stranglethorn Vale", 27.8, 77 },
	[94227] = { "\"Plucky\" Johnson", "Thousand Needles", 79.6, 75.6 },
	[94228] = { "Kixxle", "Wetlands", 50.2, 37.8 },
	[94229] = { "Alan Sneeks", "Alterac Mountains", 30.4, 61 },
	[94230] = { "Alyce", "Arathi Highlands", 34, 23.2 },
	[94231] = { "Grembly", "Ashenvale", 82.2, 50.8 },
	[94232] = { "Kzixx", "Duskwood", 81.8, 19.8 },
	[94233] = { "Gorgrash", "Hillsbrad Foothills", 80, 48.2 },
	[94234] = { "Ziz Fizziks", "Stonetalon Mountains", 59, 62.4 },
	[94235] = { "Scooty", "Stranglethorn Vale", 27.6, 77.4 },
	[94236] = { "Razzeric", "Thousand Needles", 80.2, 76 },
	[94237] = { "Kixxle", "Wetlands", 50.2, 37.8 },
	[94238] = { "Sos'mol", "Alterac Mountains", 38.4, 61.2 },
	[94239] = { "Alyce", "Arathi Highlands", 34, 23.2 },
	[94240] = { "Murache", "Ashenvale", 64.6, 80 },
	[94241] = { "Kzixx", "Duskwood", 81.8, 19.8 },
	[94242] = { "Kris Legace", "Hillsbrad Foothills", 80, 39 },
	[94243] = { "Ziz Fizziks", "Stonetalon Mountains", 59, 62.4 },
	[94244] = { "Narkk", "Stranglethorn Vale", 28.2, 74.4 },
	[94245] = { "Goblin Pit Boss", "Thousand Needles", 79.8, 76.6 },
	[94246] = { "Kixxle", "Wetlands", 50.2, 37.8 },
	[94247] = { "Alan Sneeks", "Alterac Mountains", 30.4, 61 },
	[94248] = { "Alyce", "Arathi Highlands", 34, 23.2 },
	[94249] = { "Cowardly Peon", "Ashenvale", 78.4, 68.8 },
	[94250] = { "Kzixx", "Duskwood", 81.8, 19.8 },
	[94251] = { "Bath'rah the Windwatcher", "Alterac Mountains", 80.4, 66.8 },
	[94252] = { "Ziz Fizziks", "Stonetalon Mountains", 59, 62.4 },
	[94253] = { "Hekshi", "Stranglethorn Vale", 50.6, 19.2 },
	[94254] = { "Magus Tirth", "Thousand Needles", 78.2, 75.8 },
	[94255] = { "Kixxle", "Wetlands", 50.2, 37.8 },
	[94256] = { "Lotwil Veriatus", "Badlands", 25.8, 45 },
	[94257] = { "Centaur Pariah", "Desolace", 50.4, 86.6 },
	[94258] = { "Mudcrush Durtfeet", "Dustwallow Marsh", 35, 38.2 },
	[94259] = { "Greta Mosshoof", "Felwood", 51.2, 82.2 },
	[94260] = { "Scout Raroul", "Feralas", 72.4, 52.4 },
	[94261] = { "Dendrite Starblaze", "Moonglade", 56.2, 30.4 },
	[94262] = { "Spek", "Riverglades", 76.8, 54 },
	[94263] = { "Durganon", "Searing Gorge", 41, 58.4 },
	[94264] = { "Mukomonji", "Swamp of Sorrows", 62.2, 52.8 },
	[94265] = { "Alchemist Pestlezugg", "Tanaris", 50.8, 27 },
	[94266] = { "Juo", "The Hinterlands", 80, 55.4 },
	[94267] = { "Spark Nilminer", "Un'Goro Crater", 43.6, 7.4 },
	[94268] = { "Furious Shadowforge Digger", "Badlands", 44.4, 11.4 },
	[94269] = { "Bibbly F'utzbuckle", "Desolace", 62.2, 38.8 },
	[94270] = { "Ugbert", "Dustwallow Marsh", 40.8, 28 },
	[94271] = { "Taronn Redfeather", "Felwood", 50.8, 81.6 },
	[94272] = { "Scout Raroul", "Feralas", 72.4, 52.4 },
	[94273] = { "Meliri", "Moonglade", 51.2, 42.2 },
	[94274] = { "Spek", "Riverglades", 76.8, 54 },
	[94275] = { "Master Smith Burninate", "Searing Gorge", 38.6, 28.4 },
	[94276] = { "Mukomonji", "Swamp of Sorrows", 62.2, 52.8 },
	[94277] = { "Spigot Operator Luglunket", "Tanaris", 52.4, 28.4 },
	[94278] = { "Gilveradin Sunchaser", "The Hinterlands", 26.6, 48.4 },
	[94279] = { "Torwa Pathfinder", "Un'Goro Crater", 71.6, 76 },
	[94280] = { "Garyanne Fleezlebop", "Badlands", 67.6, 51.8 },
	[94281] = { "Bibbly F'utzbuckle", "Desolace", 62.2, 38.8 },
	[94282] = { "The Ravenous", "Dustwallow Marsh", 54, 56.4 },
	[94283] = { "Jessir Moonbow", "Felwood", 51.2, 82 },
	[94284] = { "Scout Raroul", "Feralas", 72.4, 52.4 },
	[94285] = { "Narianna", "Moonglade", 53.2, 42.6 },
	[94286] = { "Spek", "Riverglades", 76.8, 54 },
	[94287] = { "Durganon", "Searing Gorge", 41, 58.4 },
	[94288] = { "Bullets Bigblast", "Swamp of Sorrows", 70, 41.4 },
	[94289] = { "Jhordy Lapforge", "Tanaris", 52.2, 26.8 },
	[94290] = { "Rhapsody Shindigger", "The Hinterlands", 26.8, 48.4 },
	[94292] = { "Garek", "Badlands", 61.8, 54.2 },
	[94293] = { "Azore Aldamort", "Desolace", 38.8, 27.2 },
	[94294] = { "The Ravenous", "Dustwallow Marsh", 54, 56.4 },
	[94295] = { "Ivy Leafrunner", "Felwood", 50.8, 81.6 },
	[94296] = { "Scout Raroul", "Feralas", 72.4, 52.4 },
	[94297] = { "Narianna", "Moonglade", 53.2, 42.6 },
	[94298] = { "Spek", "Riverglades", 76.8, 54 },
	[94299] = { "Evonice Sootsmoker", "Searing Gorge", 38.4, 27.8 },
	[94300] = { "Mukomonji", "Swamp of Sorrows", 62.2, 52.8 },
	[94301] = { "Yeh'kinya", "Tanaris", 67, 22.4 },
	[94302] = { "Juo", "The Hinterlands", 80, 55.4 },
	[94303] = { "Nergal", "Un'Goro Crater", 43.2, 7.8 },
	[94304] = { "Rigglefuzz", "Badlands", 42.4, 52.8 },
	[94305] = { "Willow", "Desolace", 62.2, 39.6 },
	[94306] = { "Tabetha", "Dustwallow Marsh", 46, 57 },
	[94307] = { "Eridan Bluewind", "Felwood", 51.2, 81.6 },
	[94308] = { "Impsy", "Felwood", 41.4, 44.8 },
	[94309] = { "Mylentha Riverbend", "Moonglade", 51.8, 32.8 },
	[94310] = { "Spek", "Riverglades", 76.8, 54 },
	[94311] = { "Lookout Captain Lolo Longstriker", "Searing Gorge", 37.6, 26.6 },
	[94312] = { "Bullets Bigblast", "Swamp of Sorrows", 70, 41.4 },
	[94313] = { "Vizzklick", "Tanaris", 51, 27.4 },
	[94314] = { "Atal'ai Exile", "The Hinterlands", 33.6, 75.2 },
	[94315] = { "Petra Grossen", "Un'Goro Crater", 43.6, 7.2 },
	[94316] = { "Archmage Xylem", "Azshara", 29.2, 40.2 },
	[94317] = { "Kum'isha the Collector", "Blasted Lands", 51.8, 35.6 },
	[94319] = { "Hastings", "Deadwind Pass", 47.2, 75 },
	[94320] = { "Adon", "Eastern Plaguelands", 58.4, 17.2 },
	[94322] = { "Jarund Stoutstrider", "Silithus", 82, 18 },
	[94323] = { "Kirala Fairgrass", "Western Plaguelands", 59.4, 53 },
	[94324] = { "Bor'dorc", "Winterspring", 64.8, 33.2 },
	[94328] = { "Calliard", "Deadwind Pass", 48.2, 68.6 },
	[94334] = { "Rayan Dawnrisen", "Azshara", 30, 40.2 },
	[94335] = { "Kum'isha the Collector", "Blasted Lands", 51.8, 35.6 },
	[94340] = { "Khur Hornstriker", "Silithus", 48.8, 37 },
	[94341] = { "Suspicious Adventurer", "Western Plaguelands", 65.6, 75.8 },
	[94346] = { "Hastings", "Deadwind Pass", 47.2, 75 },
	[94347] = { "Quartermaster Miranda Breechlock", "Eastern Plaguelands", 81.6, 60 },
	[94350] = { "Fallen Adventurer", "Western Plaguelands", 38, 72.4 },
	[94353] = { "Kum'isha the Collector", "Blasted Lands", 51.8, 35.6 },
	[94354] = { "Gorzeeki Wildeyes", "Burning Steppes", 12.4, 31.6 },
	[94355] = { "Hastings", "Deadwind Pass", 47.2, 75 },
	[94358] = { "Hermit Ortell", "Silithus", 67, 69.6 },
}
PA.WRIT_END = END
local BY_ITEM = {}
for _, w in ipairs(WRITS) do BY_ITEM[w[2]] = w end
-- turn-ins Wowhead doesn't know yet are learned in game: when you hand a writ in, who took it and where you stood
local function Learned() PintsAuctionsDB = PintsAuctionsDB or {}; PintsAuctionsDB.writEnd = PintsAuctionsDB.writEnd or {}; return PintsAuctionsDB.writEnd end
local function EndOf(q) return END[q] or (PintsAuctionsDB and PintsAuctionsDB.writEnd and PintsAuctionsDB.writEnd[q]) end
do
	local QUEST = {}
	for _, w in ipairs(WRITS) do QUEST[w[1]] = true end
	local f = CreateFrame("Frame")
	f:RegisterEvent("QUEST_COMPLETE")
	f:SetScript("OnEvent", function()
		local q = GetQuestID and GetQuestID()
		if not (q and QUEST[q]) or END[q] then return end
		local who = UnitName("npc")
		local m = C_Map.GetBestMapForUnit("player")
		local pos = m and C_Map.GetPlayerMapPosition(m, "player")
		local info = m and C_Map.GetMapInfo(m)
		if who and not (issecretvalue and issecretvalue(who)) and info then
			local x, y = pos and pos:GetXY()
			Learned()[q] = { who, info.name, x and math.floor(x * 1000 + 0.5) / 10, y and math.floor(y * 1000 + 0.5) / 10 }
		end
	end)
end
-- "Sos'mol - Alterac Mountains (38.4, 61.2)"
local function Where(w, short)
	local e = EndOf(w[1])
	if not e then return nil end
	if short then return e[2] end
	return ("%s - %s%s"):format(e[1], e[2], e[3] and (" (%.1f, %.1f)"):format(e[3], e[4]) or "")
end
PA.WritWhere = Where
-- a map pin on the turn-in (the game's own waypoint; it shows on the map and the minimap)
local mapIDs
local function MapID(zone)
	if not mapIDs then
		mapIDs = {}
		local function Walk(id, depth)
			if depth > 4 then return end
			for _, c in ipairs(C_Map.GetMapChildrenInfo(id) or {}) do
				if c.mapType == Enum.UIMapType.Zone and not mapIDs[c.name] then mapIDs[c.name] = c.mapID end
				Walk(c.mapID, depth + 1)
			end
		end
		pcall(Walk, 946, 0)
		for _, top in ipairs({ 1414, 1415, 947 }) do pcall(Walk, top, 0) end
	end
	return mapIDs[zone]
end
-- the continent a zone is on (Kalimdor, Eastern Kingdoms), for the route's headings
local contOf = {}
local function Continent(zone)
	if contOf[zone] ~= nil then return contOf[zone] or nil end
	local id, name = MapID(zone), false
	for _ = 1, 6 do
		local info = id and C_Map.GetMapInfo(id)
		if not info then break end
		if info.mapType == Enum.UIMapType.Continent then name = info.name; break end
		id = info.parentMapID
	end
	contOf[zone] = name
	return name or nil
end
function PA.WritWaypoint(w)
	local e = EndOf(w[1])
	if not (e and e[3]) then PA.Print("no turn-in spot known for " .. w[3] .. "."); return end
	local m = MapID(e[2])
	if not (m and C_Map.SetUserWaypoint and UiMapPoint) then PA.Print(("turn in %s to %s."):format(w[3], Where(w))); return end
	C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(m, e[3] / 100, e[4] / 100))
	if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
	PA.Print(("map pin set: %s."):format(Where(w)))
end

local FACTION_ACA, FACTION_DSL = 2586, 2587
local function MyRep(w)
	local horde = UnitFactionGroup("player") == "Horde"
	local want = horde and FACTION_DSL or FACTION_ACA
	for _, r in ipairs(w[7] or {}) do if r[1] == want then return r[2] end end
	return (w[7] and w[7][1] and w[7][1][2]) or 0
end
-- the mailbox: the game doesn't count what's waiting in the mail, so it's read each time the mailbox is open
-- (and remembered for this character until you next open it)
-- (Pint's Alts reads the mailbox too: whichever of the two looked last is used, so mail you checked before this
-- add-on learned to read it still counts)
local function AltsMail()
	local db = PintsLedgerDB and PintsLedgerDB.chars
	local name = GetUnitName and GetUnitName("player", false) or UnitName("player")
	local rec = db and db[GetRealmName() or ""] and db[GetRealmName() or ""][name or ""]
	if rec and rec.items and rec.items.mail then return rec.items.mail, rec.mailSeen or 0 end
end
local function Mail(id)
	local c = PintsAuctionsCharDB
	local m, t = c and c.writMail, c and c.writMailT or 0
	local am, at = AltsMail()
	if am and (not m or at > t) then m = am end
	return (m and m[id]) or 0
end
local strangers = {}      -- Craftsman's Writs in your bags or mail that aren't in the list above (Wowhead hadn't seen them)
do
	local f = CreateFrame("Frame")
	pcall(f.RegisterEvent, f, "MAIL_INBOX_UPDATE")
	f:SetScript("OnEvent", function()
		if not (GetInboxNumItems and GetInboxItem) then return end
		PintsAuctionsCharDB = PintsAuctionsCharDB or {}
		local m = {}
		for i = 1, GetInboxNumItems() or 0 do
			for a = 1, ATTACHMENTS_MAX_RECEIVE or 16 do
				local name, itemID, _, count = GetInboxItem(i, a)
				if itemID then
					m[itemID] = (m[itemID] or 0) + (count or 1)
					if name and name:find("^Craftsman's Writ") and not BY_ITEM[itemID] then strangers[itemID] = name end
				end
			end
		end
		PintsAuctionsCharDB.writMail, PintsAuctionsCharDB.writMailT = m, time()
	end)
end
local function Have(id) return math.max(Count(id) or 0, Count(id, true) or 0) + Mail(id) end
-- writs in your bags this add-on doesn't know (shown on the route, listed by /pah writs missing)
local function Strangers()
	local CI = C_Container
	if CI and CI.GetContainerNumSlots then
		for bag = 0, (NUM_BAG_SLOTS or 4) + (NUM_REAGENTBAG_SLOTS or 0) do
			for slot = 1, CI.GetContainerNumSlots(bag) or 0 do
				local info = CI.GetContainerItemInfo(bag, slot)
				local id, link = info and info.itemID, info and info.hyperlink
				local name = link and link:match("%[(.-)%]")
				if id and name and name:find("^Craftsman's Writ") and not BY_ITEM[id] then strangers[id] = name end
			end
		end
	end
	local out = {}
	for id, name in pairs(strangers) do if (Count(id) or 0) + Mail(id) > 0 then out[#out + 1] = { id, name } end end
	table.sort(out, function(a, b) return a[2] < b[2] end)
	return out
end
PA.WritStrangers = Strangers
-- what a writ asks for, not counting copies you can't hand in: a bag you're using (in a bag slot, yours or the bank's)
-- or a soulbound copy. Your bags are checked as they are; the bank is remembered from the last time it was open.
local CI = C_Container
local function BagSlotCount(id, first, last)
	local n = 0
	if not (CI and CI.ContainerIDToInventoryID) then return 0 end
	for bag = first, last do
		local ok, inv = pcall(CI.ContainerIDToInventoryID, bag)
		if ok and inv and GetInventoryItemID("player", inv) == id then n = n + 1 end
	end
	return n
end
local function BoundIn(id, first, last, bags)
	local n = 0
	if not (CI and CI.GetContainerNumSlots and CI.GetContainerItemInfo) then return 0 end
	local function One(bag)
		for slot = 1, CI.GetContainerNumSlots(bag) or 0 do
			local info = CI.GetContainerItemInfo(bag, slot)
			if info and info.itemID == id and info.isBound then n = n + (info.stackCount or 1) end
		end
	end
	if bags then for _, b in ipairs(bags) do One(b) end end
	if first then for bag = first, last do One(bag) end end
	return n
end
local NBAG = NUM_BAG_SLOTS or 4
local LASTBAG = NBAG + (NUM_REAGENTBAG_SLOTS or 0)        -- WoW Forever: the reagent bag
local NBANK = NUM_BANKBAGSLOTS or 7
local GIII = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local function Unusable(id)
	local n = BagSlotCount(id, 1, LASTBAG) + BoundIn(id, 0, LASTBAG)
	local skip = PintsAuctionsCharDB and PintsAuctionsCharDB.writSkipBank
	if skip then return n, skip[id] or 0 end
	-- bank not looked at yet on this character: a bag in the bank is most likely in one of its bag slots, so it isn't
	-- counted until the bank has been opened once
	local classID = GIII and select(6, GIII(id))
	if classID == 1 then return n, math.max(0, (Count(id, true) or 0) - (Count(id) or 0)) end
	return n, 0
end
-- items in your bags you can hand in
local function ItemBags(id)
	local live = Unusable(id)
	return math.max(0, (Count(id) or 0) - live)
end
-- everywhere (bags, bank, mail) you can hand in
local function ItemHave(id)
	local live, bank = Unusable(id)
	return math.max(0, math.max(Count(id) or 0, Count(id, true) or 0) + Mail(id) - live - bank)
end
-- the bank, while it's open: bags in its bag slots and soulbound copies of anything a writ asks for
do
	local f = CreateFrame("Frame")
	local open
	local function Scan()
		if not open then return end
		PintsAuctionsCharDB = PintsAuctionsCharDB or {}
		local skip = {}
		local first = (Enum and Enum.BagIndex and Enum.BagIndex.BankBag_1) or (LASTBAG + 1)
		local last = first + NBANK - 1
		for _, w in ipairs(WRITS) do
			local id = w[4]
			if not skip[id] then
				local n = BagSlotCount(id, first, last) + BoundIn(id, first, last, { BANK_CONTAINER or -1 })
				if n > 0 then skip[id] = n end
			end
		end
		PintsAuctionsCharDB.writSkipBank = skip
	end
	for _, e in ipairs({ "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED", "BAG_UPDATE_DELAYED" }) do pcall(f.RegisterEvent, f, e) end
	f:SetScript("OnEvent", function(_, e)
		if e == "BANKFRAME_OPENED" then open = true elseif e == "BANKFRAME_CLOSED" then open = nil; return end
		Scan()
	end)
end
-- each writ can be handed in once a day: done today = the game has it flagged completed until the daily reset
local function DoneToday(q)
	local f = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted or IsQuestFlaggedCompleted
	if not f then return false end
	local ok, r = pcall(f, q)
	return ok and r and true or false
end
PA.WritDoneToday = DoneToday

local page, list, status, filter = nil, nil, nil, "sale"
local function Rows(flt)
	local filter = flt or filter
	local data, n = {}, 0
	for _, w in ipairs(WRITS) do
		local wp, wpT = PA.Price(w[2])
		local ip, ipT, ipNone = PA.Price(w[4])
		local old = ip and ipT and (time() - ipT) > 6 * 3600     -- (an item price more than 6 hours old)
		local oldW = wp and wpT and (time() - wpT) > 6 * 3600
		local have = ItemHave(w[4])
		local need = math.max(0, w[5] - have)
		local itemCost = need == 0 and 0 or (ip and ip * need)
		local ownWrit = Have(w[2]) > 0
		local writCost = ownWrit and 0 or wp
		local total = writCost and itemCost and (writCost + itemCost)
		local rep = MyRep(w)
		local per = total and rep > 0 and total * 100 / rep
		local done = DoneToday(w[1])
		local show = filter == "all" or (filter == "sale" and (wp or ownWrit)) or ((filter == "mine" or filter == "turnin" or filter == "route") and ownWrit)
			or (filter == "fresh" and not done)
		if show then
			n = n + 1
			data[#data + 1] = {
				(done and "|cff808080" or "") .. w[3] .. (done and " (done today)|r" or "") .. (ownWrit and "  |cff40ff40(yours)|r" or ""),
				Where(w, true) and ((done and "|cff808080" or "|cffd0d0d0") .. Where(w, true) .. "|r") or "|cff808080?|r",
				ownWrit and "|cff40ff40yours|r" or (wp and ((oldW and "|cff999999~" or "") .. PA.Money(wp, true) .. (oldW and "|r" or ""))) or "|cff888888-|r",
				need == 0 and "|cff40ff40have|r" or (itemCost and ((old and "|cff999999~" or "") .. PA.Money(itemCost, true) .. (old and "|r" or ""))) or (ipNone and "|cffff6060none|r") or "|cff888888?|r",
				total and PA.Money(total, true) or "|cff888888?|r",
				rep > 0 and tostring(rep) or "",
				per and PA.Money(per, true) or "|cff888888?|r",
				texture = select(10, GII(w[4])) or select(10, GII(w[2])) or 134939, key = tostring(w[1]), writ = w, dim = done,
				sk = { w[3], Where(w, true) or "~", wp or math.huge, itemCost or math.huge, total or math.huge, rep, per or math.huge },
				tip = "Craftsman's Writ: " .. w[3] .. "\nAsks for " .. w[5] .. " " .. w[6] .. (have > 0 and (" (you have " .. have .. ")") or "")
					.. (Where(w) and ("\nTurn in: " .. Where(w)) or "")
					.. "\n\nWrit: " .. (ownWrit and "you have one" or (wp and (PA.Money(wp) .. (oldW and "  (an old price - Scan writs)" or "")) or "none listed at the last scan"))
					.. "\n" .. w[6] .. ": " .. (ip and (PA.Money(ip) .. " each" .. (old and "  (an old price - Scan writs)" or "")) or (ipNone and "none listed at the last scan") or "no price yet") .. (need > 0 and ("  - " .. need .. " to buy") or "  - you have them")
					.. "\nReputation: " .. rep .. "\nThe turn-in also gives a Coin Pouch (about " .. PA.Money(w[8] or 0) .. ")"
					.. (total and ("\nTotal " .. PA.Money(total) .. ", after the pouch " .. PA.Money(math.max(0, total - (w[8] or 0)))) or "") }
		end
	end
	return data, n
end
local function Refresh()
	if not (page and page:IsShown()) then return end
	local data, n = Rows()
	list:Set(data, true)
	local nd = 0
	for _, w in ipairs(WRITS) do if DoneToday(w[1]) then nd = nd + 1 end end
	status:SetText(("%d writ%s%s. Prices from the last scan; Scan writs to update. Cost per 100 reputation counts the writ and the item."):format(n, n == 1 and "" or "s",
		nd > 0 and ((filter == "fresh" and " (%d done today hidden)" or " (%d done today, greyed)"):format(nd)) or ""))
end
PA.RefreshWrits = function() Refresh(); if PA.DrawWritsPane then PA.DrawWritsPane() end end

---------------------------------------------------------------- the Writs page of the Durotar Supply and Logistics window
-- (opens anywhere: /pah crates or the minimap button, then Writs) - every writ, and for the one picked what it asks for,
-- what you have of it, the prices, reputation and the coin pouch
local pane, pList, pFilter, pSel = nil, nil, "sale", nil
local function DrawDetail()
	local d = pane.detail
	local w = pSel
	d.pop:Hide()
	if pFilter == "turnin" then PA.DrawTurnIns(); return end
	if pFilter == "route" then PA.DrawRoute(); return end
	d.pin:Hide(); d.scroll:Hide(); d.key:Hide(); d.foot:Show()
	d.foot:SetText("Prices from your last scan at the auction house (Writs tab: Scan writs).  " .. (pane.doneNote or ""))
	if not w then d.title:SetText("Pick a writ on the left."); d.body:SetText(""); d.bw:Hide(); d.bi:Hide(); return end
	local wp = PA.Price(w[2])
	local ip, ipT, ipNone = PA.Price(w[4])
	local all = ItemHave(w[4]); local bags = ItemBags(w[4])
	local need = math.max(0, w[5] - all)
	local ownWrit = Have(w[2]) > 0
	local itemCost = need == 0 and 0 or (ip and ip * need)
	local writCost = ownWrit and 0 or wp
	local total = writCost and itemCost and writCost + itemCost
	local rep = MyRep(w)
	local L = {}
	L[#L + 1] = ("Asks for |cffffffff%d %s|r"):format(w[5], w[6])
	L[#L + 1] = ("You have %d  (bags %d, bank %d)  -  %s"):format(all, bags, all - bags, need == 0 and "|cff40ff40enough|r" or ("|cffff8040short " .. need .. "|r"))
	if Where(w) then L[#L + 1] = "Turn in: |cffffffff" .. Where(w) .. "|r" end
	L[#L + 1] = " "
	L[#L + 1] = "Writ: " .. (ownWrit and "|cff40ff40you have one|r" or (wp and PA.Money(wp) or "|cff888888none listed at the last scan|r"))
	L[#L + 1] = w[6] .. ": " .. (ip and (PA.Money(ip) .. " each" .. (need > 0 and ("  -  " .. need .. " to buy: " .. PA.Money(itemCost)) or "")) or (ipNone and "|cffff6060none listed|r") or "|cff888888no price yet|r")
	L[#L + 1] = "Total: " .. (total and ("|cffffffff" .. PA.Money(total) .. "|r") or "|cff888888?|r")
	L[#L + 1] = " "
	L[#L + 1] = ("Reputation: |cffffffff%d|r with %s"):format(rep, UnitFactionGroup("player") == "Alliance" and "Azeroth Commerce Authority" or "Durotar Supply and Logistics")
	L[#L + 1] = "Per 100 reputation: " .. ((total and rep > 0) and ("|cffffffff" .. PA.Money(total * 100 / rep) .. "|r") or "|cff888888?|r")
	if (w[8] or 0) > 0 then L[#L + 1] = "The turn-in also gives a Coin Pouch, about " .. PA.Money(w[8]) .. (total and ("  (after it: " .. PA.Money(math.max(0, total - w[8])) .. ")") or "") end
	d.title:SetText("Craftsman's Writ: " .. w[3])
	d.body:SetText(table.concat(L, "\n"))
	d.bw:Show(); d.bi:Show(); d.pin:SetShown(EndOf(w[1]) and EndOf(w[1])[3] and true or false)
end
---------------------------------------------------------------- turn-ins and the route
-- where things are: map positions turned into the world's own coordinates, so distances between zones can be compared
local function MapAt(zone) return MapID(zone) end
local function World(map, x, y)
	if not (map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return end
	local ok, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x / 100, y / 100))
	if ok and cont and pos then local a, b = pos:GetXY(); return cont, a, b end
end
local function Me()
	local m = C_Map.GetBestMapForUnit("player")
	local p = m and C_Map.GetPlayerMapPosition(m, "player")
	if not p then return end
	local x, y = p:GetXY()
	local info = C_Map.GetMapInfo(m)
	local cont, a, b = World(m, x * 100, y * 100)
	return cont, a, b, info and info.name
end
-- where you arrive on the other continent (the zeppelins / boats)
local PORT = { Horde = { { 1411, 50.6, 12.6 }, { 1420, 60.8, 58.8 } }, Alliance = { { 1445, 71.6, 56.4 }, { 1437, 4.6, 57 } } }
local function PortOn(cont)
	for _, p in ipairs(PORT[UnitFactionGroup("player")] or PORT.Horde) do
		local c, a, b = World(p[1], p[2], p[3])
		if c == cont then return a, b end
	end
end
local function D(a1, b1, a2, b2) return math.sqrt((a1 - a2) ^ 2 + (b1 - b2) ^ 2) end

-- your writs, by turn-in stop: { key, npc, zone, x, y, cont, wx, wy, writs = { w, ... } }
local function Stops()
	local stops, byKey, unknown, done = {}, {}, {}, {}
	for _, w in ipairs(WRITS) do
		if Have(w[2]) > 0 and DoneToday(w[1]) then done[#done + 1] = w
		elseif Have(w[2]) > 0 then
			local e = EndOf(w[1])
			if e and e[3] then
				local key = e[1] .. "|" .. e[2]
				local st = byKey[key]
				if not st then
					st = { key = key, npc = e[1], zone = e[2], x = e[3], y = e[4], writs = {} }
					st.cont, st.wx, st.wy = World(MapAt(e[2]), e[3], e[4])
					byKey[key] = st; stops[#stops + 1] = st
				end
				st.writs[#st.writs + 1] = w
			else
				unknown[#unknown + 1] = w
			end
		end
	end
	return stops, unknown, done
end
-- shortest-looking order: nearest stop next, then any two legs that cross are swapped (2-opt)
local function Order(list, sa, sb)
	local out, left = {}, {}
	for _, s in ipairs(list) do left[#left + 1] = s end
	local a, b = sa, sb
	while #left > 0 do
		local bi, bd = 1, math.huge
		for i, s in ipairs(left) do local d = D(a, b, s.wx, s.wy); if d < bd then bi, bd = i, d end end
		local s = table.remove(left, bi); out[#out + 1] = s; a, b = s.wx, s.wy
	end
	local function P(i) if i == 0 then return sa, sb end return out[i].wx, out[i].wy end
	local better = true
	local guard = 0
	while better and guard < 50 do
		better = false; guard = guard + 1
		for i = 1, #out - 1 do
			for j = i + 1, #out do
				local ax, ay = P(i - 1); local bx, by = P(i); local cx, cy = P(j)
				local d0 = D(ax, ay, bx, by) + (j < #out and D(cx, cy, out[j + 1].wx, out[j + 1].wy) or 0)
				local d1 = D(ax, ay, cx, cy) + (j < #out and D(bx, by, out[j + 1].wx, out[j + 1].wy) or 0)
				if d1 + 0.5 < d0 then
					local k, l = i, j
					while k < l do out[k], out[l] = out[l], out[k]; k = k + 1; l = l - 1 end
					better = true
				end
			end
		end
	end
	return out
end
-- the route: this continent's stops from where you stand, then the other continent's from where the zeppelin / boat lands
local function Route()
	local stops, unknown, done = Stops()
	local cont, a, b = Me()
	local here, there, nowhere = {}, {}, {}
	for _, s in ipairs(stops) do
		if not s.cont then nowhere[#nowhere + 1] = s
		elseif cont and s.cont == cont then here[#here + 1] = s
		else there[#there + 1] = s end
	end
	local route = {}
	if a then for _, s in ipairs(Order(here, a, b)) do route[#route + 1] = s end else for _, s in ipairs(here) do route[#route + 1] = s end end
	local cross = #route
	if #there > 0 then
		local pa, pb = PortOn(there[1].cont)
		if not pa then pa, pb = there[1].wx, there[1].wy end
		for _, s in ipairs(Order(there, pa, pb)) do route[#route + 1] = s end
	end
	for _, s in ipairs(nowhere) do route[#route + 1] = s end
	return route, cross, unknown, (#there > 0), done
end
PA.WritRoute = Route

-- the scrolling list in the detail panel: rows of { left, right, indent, zone (a header: click to fold), color }
local function ListRows(d, rows)
	local sf = d.scroll
	sf:Show(); d.body:SetText("")
	local c = sf.child
	local w = math.max(200, (sf:GetWidth() or 400) - 4)
	c:SetWidth(w)
	for i, r in ipairs(rows) do
		local b = sf.rows[i]
		if not b then
			b = CreateFrame("Button", nil, c); b:SetHeight(16)
			b.l = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); b.l:SetPoint("LEFT", 0, 0); b.l:SetJustifyH("LEFT"); b.l:SetWordWrap(false)
			b.r = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.r:SetPoint("RIGHT", 0, 0); b.r:SetJustifyH("RIGHT"); b.r:SetWordWrap(false)
			b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
			b:SetScript("OnClick", function(self)
				if not self.zone then return end
				PintsAuctionsDB = PintsAuctionsDB or {}; PintsAuctionsDB.writFold = PintsAuctionsDB.writFold or {}
				PintsAuctionsDB.writFold[self.zone] = not PintsAuctionsDB.writFold[self.zone] or nil
				DrawDetail()
			end)
			sf.rows[i] = b
		end
		b:ClearAllPoints(); b:SetPoint("TOPLEFT", c, "TOPLEFT", r.indent or 0, -(i - 1) * 16); b:SetWidth(w - (r.indent or 0))
		b.zone = r.zone
		b.l:SetFontObject(r.zone and "GameFontNormal" or "GameFontHighlight")
		b.l:SetText(r.left or ""); b.r:SetText(r.right or "")
		b.r:SetWidth(r.right and math.min(w * 0.55, (b.r:GetUnboundedStringWidth() or 0) + 4) or 1)
		b.l:SetPoint("RIGHT", b.r, "LEFT", -6, 0)
		if r.zone then b:GetHighlightTexture():SetAlpha(1) else b:GetHighlightTexture():SetAlpha(0) end
		b:Show()
	end
	for i = #rows + 1, #sf.rows do sf.rows[i]:Hide() end
	c:SetHeight(math.max(1, #rows * 16))
end
local function WritLine(w, withItems)
	local n = Have(w[2])
	local ready = ItemHave(w[4]) >= w[5]
	local col = ready and "|cff40ff40" or "|cffff8040"
	local left = col .. w[3] .. "|r" .. (n > 1 and (" x" .. n) or "")
	if withItems then
		local bags = ItemBags(w[4])
		local where = bags >= w[5] and "|cff40ff40in bags|r" or (ready and "|cffb0b0b0bank / mail|r" or "|cffff8040short|r")
		return left, ("|cffb0b0b0writ + %d %s|r  %s"):format(w[5], w[6], where)
	end
	return left
end
-- the writs you have, by the zone they're turned in: where you are first, then nearest to farthest. Click a zone to fold it.
function PA.DrawTurnIns()
	local d = pane.detail
	d.bw:Hide(); d.bi:Hide(); d.foot:Hide()
	d.pin:SetShown(pSel and Have(pSel[2]) > 0 and EndOf(pSel[1]) and EndOf(pSel[1])[3] and true or false)
	local stops, unknown, done = Stops()
	local cont, a, b, hereName = Me()
	local zones, order = {}, {}
	for _, s in ipairs(stops) do
		local z = zones[s.zone]
		if not z then z = { name = s.zone, stops = {}, dist = math.huge }; zones[s.zone] = z; order[#order + 1] = z end
		z.stops[#z.stops + 1] = s
		local dd
		if s.zone == hereName then dd = -1
		elseif cont and s.cont == cont and a then dd = D(a, b, s.wx, s.wy)
		elseif s.cont then local pa, pb = PortOn(s.cont); dd = 1e6 + (pa and D(pa, pb, s.wx, s.wy) or 0) end
		if dd and dd < z.dist then z.dist = dd end
	end
	table.sort(order, function(x, y) if x.dist ~= y.dist then return x.dist < y.dist end return x.name < y.name end)
	local fold = PintsAuctionsDB and PintsAuctionsDB.writFold or {}
	local rows = {}
	local function Zone(name, count, list)
		rows[#rows + 1] = { left = (fold[name] and "|cff909090+|r " or "|cff909090-|r ") .. name, right = ("|cff909090%d writ%s|r"):format(count, count == 1 and "" or "s"), zone = name }
		if not fold[name] then for _, l in ipairs(list) do rows[#rows + 1] = l end end
	end
	for _, z in ipairs(order) do
		local list, count = {}, 0
		for _, s in ipairs(z.stops) do
			for _, w in ipairs(s.writs) do
				count = count + 1
				list[#list + 1] = { left = WritLine(w), right = ("|cff909090%s  %.0f, %.0f|r"):format(s.npc, s.x, s.y), indent = 14 }
			end
		end
		Zone(z.name .. (z.dist == -1 and "  |cff40ff40(you're here)|r" or ""), count, list)
		rows[#rows].zone = z.name
	end
	if #unknown > 0 then
		local list = {}
		for _, w in ipairs(unknown) do list[#list + 1] = { left = WritLine(w), right = "|cff909090noted when you hand one in|r", indent = 14 } end
		Zone("Turn-in not known yet", #unknown, list)
	end
	if #done > 0 then
		local list = {}
		for _, w in ipairs(done) do local e = EndOf(w[1]); list[#list + 1] = { left = "|cff808080" .. w[3] .. "|r", right = "|cff909090" .. (e and (e[1] .. " - " .. e[2]) or "") .. "|r", indent = 14 } end
		Zone("Done today - hand in tomorrow", #done, list)
	end
	d.title:SetText("Your writs - where to turn them in")
	if #rows == 0 then d.scroll:Hide(); d.body:SetText("You have no writs in your bags or bank."); return end
	ListRows(d, rows)
	d.key:SetText("Click a zone to fold it.  |cff40ff40green|r: you have what it asks for   |cffff8040orange|r: not yet"); d.key:Show()
end
local docked   -- Pint's Quest Book's tracker shows the route on its Writs tab (then the pop-out stays away)
-- the best order to hand them all in, and what to take out of the mailbox for each stop
function PA.DrawRoute()
	local d = pane.detail
	d.bw:Hide(); d.bi:Hide(); d.foot:Hide(); d.pin:Hide()
	local route, cross, unknown, other, done = Route()
	local rows = {}
	for i, s in ipairs(route) do
		if other and i == cross + 1 then rows[#rows + 1] = { left = "|cff80c0ff- take the zeppelin / boat to the other continent -|r" } end
		rows[#rows + 1] = { left = ("|cffffd200%d.|r |cffffd200%s|r"):format(i, s.zone), right = ("|cffe0e0e0%s|r  |cff909090%.1f, %.1f|r"):format(s.npc, s.x, s.y) }
		for _, w in ipairs(s.writs) do local l, r = WritLine(w, true); rows[#rows + 1] = { left = l, right = r, indent = 18 } end
	end
	if #unknown > 0 then
		rows[#rows + 1] = { left = "|cff909090Turn-in not known yet (not on the route):|r" }
		for _, w in ipairs(unknown) do local l, r = WritLine(w, true); rows[#rows + 1] = { left = l, right = r, indent = 18 } end
	end
	if done and #done > 0 then
		rows[#rows + 1] = { left = "|cff909090Done today - hand in tomorrow (not on the route):|r" }
		for _, w in ipairs(done) do rows[#rows + 1] = { left = "|cff808080" .. w[3] .. "|r", indent = 18 } end
	end
	d.title:SetText(#route > 0 and ("Route - %d stop%s"):format(#route, #route == 1 and "" or "s") or "Route")
	if #rows == 0 then d.scroll:Hide(); d.body:SetText("You have no writs in your bags or bank."); return end
	ListRows(d, rows)
	d.key:SetText("From where you stand: nearest stop next, shortened where legs cross. Take each stop's writs and items from the mailbox before you set off."); d.key:Show()
	d.pop:SetText(docked and "Track it" or "Pop out"); d.pop:Show()
end

---------------------------------------------------------------- the route, popped out: a small tracker at the side of the screen
-- (like the quest tracker: drag its title to move it, click a stop to put a map pin on it; it keeps itself up to date as
-- you hand writs in, open bags or change zone. /pah route shows or hides it)
local tracker
local function OnQuest(q)
	if C_QuestLog and C_QuestLog.IsOnQuest then local ok, r = pcall(C_QuestLog.IsOnQuest, q); if ok then return r and true or false end end
	return GetQuestLogIndexByID and (GetQuestLogIndexByID(q) or 0) > 0 or false
end
local function TDB() PintsAuctionsDB = PintsAuctionsDB or {}; PintsAuctionsDB.routeTracker = PintsAuctionsDB.routeTracker or {}; return PintsAuctionsDB.routeTracker end
-- draws the route's lines into frame t (its own pop-out, or the Writs tab of Pint's Quest Book's tracker), starting
-- top px down and w wide. Returns the height it used and the title.
local function DrawRoute(t, top, w)
	t.rows = t.rows or {}
	local route, cross, unknown, other, done = Route()
	local lines = {}
	local lastCont
	for i, s in ipairs(route) do
		if other and i == cross + 1 then lines[#lines + 1] = { text = "|cff80c0ff~ zeppelin / boat ~|r" } end
		-- the continent above its zones, a size up from them
		local cont = Continent(s.zone)
		if cont and cont ~= lastCont then lines[#lines + 1] = { text = "|cffffffff" .. cont .. "|r", big = true }; lastCont = cont end
		lines[#lines + 1] = { text = ("|cffffd200%d. %s|r  |cffb0b0b0%s %.0f, %.0f|r"):format(i, s.zone, s.npc, s.x, s.y), stop = s, first = (i == 1) }
		for _, w in ipairs(s.writs) do
			local bags = ItemBags(w[4])
			-- the name in the colour of the reputation it gives (like item quality: 75 green, 125 blue, 200 purple)
			local rep = MyRep(w)
			local col = rep >= 200 and "|cffc080ff" or rep >= 125 and "|cff40a0ff" or rep >= 75 and "|cff40e040" or "|cffd0d0d0"
			-- and where what it asks for is: nothing said when it's in your bags; in the bank / mail; or still short
			local where = bags >= w[5] and "" or (ItemHave(w[4]) >= w[5] and " |cffb0b0b0(mail/bank)|r" or " |cffff8040(short)|r")
			-- quest accepted: a white ?, yellow once what it asks for is in your bags (ready to hand in)
			local q = OnQuest(w[1]) and (bags >= w[5] and "yellow" or "white") or nil
			local copies = Have(w[2])
			lines[#lines + 1] = { text = "     " .. col .. w[3] .. " +" .. rep .. "|r" .. (copies > 1 and (" |cffd0d0d0x" .. copies .. "|r") or "") .. where .. (Count(w[2]) == 0 and not q and " |cff909090(writ not in bags)|r" or ""), stop = s, q = q }
		end
	end
	if #unknown > 0 then lines[#lines + 1] = { text = ("|cff909090+ %d writ%s, turn-in not known yet|r"):format(#unknown, #unknown == 1 and "" or "s") } end
	local st = Strangers()
	if #st > 0 then lines[#lines + 1] = { text = ("|cffff8040+ %d writ%s this add-on doesn't know yet (/pah writs missing)|r"):format(#st, #st == 1 and "" or "s") } end
	if done and #done > 0 then lines[#lines + 1] = { text = ("|cff909090+ %d done today - tomorrow|r"):format(#done) } end
	if #route == 0 and #unknown == 0 then lines[#lines + 1] = { text = "|cff909090No writs in your bags or bank.|r" } end
	-- reputation this route gives: each writ on it once (a writ is handed in once a day - extra copies of the same
	-- one wait for later days, so they're counted apart, not added to today's total)
	local total, later, nw = 0, 0, 0
	for _, st in ipairs(route) do
		for _, w in ipairs(st.writs) do
			nw = nw + 1
			total = total + MyRep(w)
			later = later + math.max(0, Have(w[2]) - 1) * MyRep(w)
		end
	end
	local fmt = function(v) return BreakUpLargeNumbers and BreakUpLargeNumbers(v) or tostring(v) end
	local title = ("Writ route  |cff909090%d stop%s  %d writ%s|r  |cff40c0ff+%s rep|r%s"):format(#route, #route == 1 and "" or "s", nw, nw == 1 and "" or "s", fmt(total),
		later > 0 and ("  |cff909090(+" .. fmt(later) .. " later)|r") or "")
	local y = top
	for i, l in ipairs(lines) do
		local b = t.rows[i]
		if not b then
			b = CreateFrame("Button", nil, t); b:SetHeight(14)
			b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.fs:SetAllPoints(); b.fs:SetJustifyH("LEFT"); b.fs:SetWordWrap(false)
			b.font = { b.fs:GetFont() }
			-- the big ? for a writ taken as a quest
			b.q = b:CreateFontString(nil, "OVERLAY"); b.q:SetFont(STANDARD_TEXT_FONT, 17, "OUTLINE"); b.q:SetPoint("LEFT", 6, 0); b.q:SetText("?")
			b:SetScript("OnClick", function(self) if self.stop and self.stop.writs[1] then PA.WritWaypoint(self.stop.writs[1]) end end)
			b:SetScript("OnEnter", function(self)
				if not self.stop then return end
				GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:AddLine(self.stop.npc .. " - " .. self.stop.zone)
				for _, w in ipairs(self.stop.writs) do GameTooltip:AddDoubleLine(w[3], ("%d %s (have %d)"):format(w[5], w[6], ItemHave(w[4])), 1, 1, 1, 0.8, 0.8, 0.8) end
				GameTooltip:AddLine("Click: map pin", 0.6, 0.8, 1); GameTooltip:Show()
			end)
			b:SetScript("OnLeave", function() GameTooltip:Hide() end)
			t.rows[i] = b
		end
		local h = l.big and 20 or 15
		if i == 1 then y = top end
		b:ClearAllPoints(); b:SetPoint("TOPLEFT", t, "TOPLEFT", 8, y); b:SetWidth(w - 16); b:SetHeight(h)
		y = y - h
		if b.font[1] then b.fs:SetFont(b.font[1], (b.font[2] or 10) + (l.big and 3 or 0), b.font[3]) end
		b.fs:SetJustifyV(l.big and "BOTTOM" or "MIDDLE")
		b.stop = l.stop; b.fs:SetText(l.text); b:Show()
		if l.q == "yellow" then b.q:SetTextColor(1, 0.82, 0); b.q:Show() elseif l.q == "white" then b.q:SetTextColor(1, 1, 1); b.q:Show() else b.q:Hide() end
	end
	for i = #lines + 1, #t.rows do t.rows[i]:Hide() end
	return top - (y or top), title
end
local function DrawTracker()
	if docked then if docked.Changed then docked.Changed() end; return end
	local t = tracker
	if not (t and t:IsShown()) then return end
	local w = TDB().width or 260
	local h, title = DrawRoute(t, -24, w)
	t.title:SetText(title)
	t:SetSize(w, 30 + h)
end
local function Tracker()
	if tracker then return tracker end
	local t = CreateFrame("Frame", "PintsAuctionsWritRoute", UIParent, "BackdropTemplate")
	t:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	t:SetBackdropColor(0, 0, 0, 0.55); t:SetBackdropBorderColor(0.8, 0.65, 0.2, 0.6)
	t:SetFrameStrata("MEDIUM"); t:SetClampedToScreen(true); t:SetMovable(true); t:EnableMouse(true)
	local db = TDB()
	if db.pos then t:SetPoint(db.pos[1], UIParent, db.pos[2], db.pos[3], db.pos[4]) else t:SetPoint("TOPRIGHT", UIParent, "RIGHT", -20, 120) end
	t.title = t:CreateFontString(nil, "OVERLAY", "GameFontNormal"); t.title:SetPoint("TOPLEFT", 8, -6)
	t:RegisterForDrag("LeftButton")
	t:SetScript("OnDragStart", function(self) if not TDB().locked then self:StartMoving() end end)
	t:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local a, _, b, x, y = self:GetPoint(1); TDB().pos = { a, b, x, y }
	end)
	local x = CreateFrame("Button", nil, t, "UIPanelCloseButtonNoScripts"); x:SetSize(20, 20); x:SetPoint("TOPRIGHT", 0, 0)
	x:SetScript("OnClick", function() PA.ToggleRouteTracker(false) end)
	local r = CreateFrame("Button", nil, t); r:SetSize(16, 16); r:SetPoint("RIGHT", x, "LEFT", -2, 0)
	r:SetNormalTexture("Interface\\Buttons\\UI-RefreshButton")
	r:SetScript("OnClick", DrawTracker)
	r:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:AddLine("Work the route out again from here"); GameTooltip:Show() end)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	t.rows = {}
	-- kept up to date: writs handed in, bags changed, a new zone
	local ev = CreateFrame("Frame", nil, t)
	for _, e in ipairs({ "BAG_UPDATE_DELAYED", "QUEST_TURNED_IN", "QUEST_ACCEPTED", "QUEST_REMOVED", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD", "MAIL_INBOX_UPDATE" }) do pcall(ev.RegisterEvent, ev, e) end
	ev:SetScript("OnEvent", function() C_Timer.After(0.3, DrawTracker) end)
	tracker = t
	return t
end
function PA.ToggleRouteTracker(on)
	-- docked in the quest tracker: show (or leave) its Writs tab instead
	if docked then if docked.Show then docked.Show(on) end; return end
	local t = Tracker()
	if on == nil then on = not t:IsShown() end
	TDB().shown = on and true or nil
	t:SetShown(on)
	if on then DrawTracker() end
end
-- for Pint's Quest Book: its tracker gets Quests / Writs tabs and draws the route on the Writs one.
--   PintsWritRoute.Draw(frame, width) -> height, title     PintsWritRoute.Dock({ Changed = fn, Show = fn(on) })
PintsWritRoute = {
	Draw = function(frame, width) return DrawRoute(frame, 0, width) end,
	Dock = function(host)
		docked = host
		if tracker and tracker:IsShown() then tracker:Hide(); TDB().shown = nil end
		if not docked.ev then
			-- kept up to date: writs handed in, bags changed, a new zone
			local ev = CreateFrame("Frame")
			for _, e in ipairs({ "BAG_UPDATE_DELAYED", "QUEST_TURNED_IN", "QUEST_ACCEPTED", "QUEST_REMOVED", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD", "MAIL_INBOX_UPDATE" }) do pcall(ev.RegisterEvent, ev, e) end
			ev:SetScript("OnEvent", function() C_Timer.After(0.3, function() if docked and docked.Changed then docked.Changed() end end) end)
			docked.ev = ev
		end
	end,
	Undock = function() docked = nil end,
}
-- back where you left it after a reload
do
	local f = CreateFrame("Frame")
	f:RegisterEvent("PLAYER_LOGIN")
	f:SetScript("OnEvent", function() C_Timer.After(2, function() if not docked and PintsAuctionsDB and PintsAuctionsDB.routeTracker and PintsAuctionsDB.routeTracker.shown then PA.ToggleRouteTracker(true) end end) end)
end
function PA.DrawWritsPane()
	if not (pane and pane:IsShown()) then return end
	local data = Rows(pFilter)
	local rows = {}
	for _, r in ipairs(data) do
		rows[#rows + 1] = { r[1], r[2], r[5], r[7], texture = r.texture, key = r.key, writ = r.writ, tip = r.tip, dim = r.dim, sk = { r.sk[1], r.sk[2], r.sk[5], r.sk[7] } }
	end
	pList:Set(rows, true)
	-- how many are done today (hidden in "Not done today", greyed everywhere else)
	local nd = 0
	for _, w in ipairs(WRITS) do if DoneToday(w[1]) then nd = nd + 1 end end
	pane.doneNote = nd > 0 and (pFilter == "fresh" and ("%d writ%s done today hidden - they're back after the daily reset."):format(nd, nd == 1 and "" or "s")
		or ("%d writ%s done today (greyed)."):format(nd, nd == 1 and "" or "s")) or "No writs done today yet."
	DrawDetail()
end
function PA.BuildWritsPane(parent)
	pane = CreateFrame("Frame", nil, parent); pane:SetAllPoints(parent); pane:Hide()
	local fl = {}
	local function F(text, key, x, w)
		local b = PA.Btn(pane, text, w, 20); b:SetPoint("TOPLEFT", x, -64)
		b:SetScript("OnClick", function() pFilter = key; for _, o in ipairs(fl) do o:UnlockHighlight() end; b:LockHighlight(); PA.DrawWritsPane() end)
		fl[#fl + 1] = b
		return b
	end
	F("For sale", "sale", 16, 80):LockHighlight(); F("All writs", "all", 98, 80); F("Mine", "mine", 180, 60)
	local ti = F("Turn-ins", "turnin", 242, 70)
	PA.Tip(ti, "Turn-ins", "The writs you have, grouped by the zone they're turned in (where you are first, then nearest to farthest), with who takes them. Click a zone to fold it.")
	local ro = F("Route", "route", 314, 60)
	PA.Tip(F("Not done today", "fresh", 376, 104), "Writs not done today", "Every writ you can still hand in today (each writ can be handed in once a day).")
	PA.Tip(ro, "Route", "The best order to hand in all your writs from where you stand, and what to take out of the mailbox for each stop.")
	pList = PA.List(pane, 520, 18, 20, { { 220, "LEFT", "Writ", sort = "asc", pad = 10 }, { 130, "LEFT", "Zone", sort = "asc", pad = 8 },
		{ 64, "RIGHT", "Total", sort = "asc" }, { 72, "RIGHT", "Per 100", sort = "asc" } },
		function(item) pSel = item.writ; pList.selectedKey = item.key; pList:Refresh(); DrawDetail() end)
	pList:SetPoint("TOPLEFT", 16, -106)
	pList.sortCol, pList.sortDesc = 4, false
	local d = CreateFrame("Frame", nil, pane); d:SetPoint("TOPLEFT", pList, "TOPRIGHT", 14, 18); d:SetPoint("BOTTOMRIGHT", -16, 16); pane.detail = d
	d.title = d:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); d.title:SetPoint("TOPLEFT", 0, 0); d.title:SetPoint("RIGHT", 0, 0); d.title:SetJustifyH("LEFT")
	d.body = d:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); d.body:SetPoint("TOPLEFT", d.title, "BOTTOMLEFT", 0, -10); d.body:SetPoint("RIGHT", 0, 0)
	d.scroll = CreateFrame("ScrollFrame", nil, d, "UIPanelScrollFrameTemplate")
	d.scroll:SetPoint("TOPLEFT", d.title, "BOTTOMLEFT", 0, -8); d.scroll:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -24, 40)
	d.scroll.child = CreateFrame("Frame", nil, d.scroll); d.scroll.child:SetSize(1, 1); d.scroll:SetScrollChild(d.scroll.child)
	d.scroll.rows = {}; d.scroll:Hide()
	d.key = d:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); d.key:SetPoint("BOTTOMLEFT", 0, 4); d.key:SetPoint("RIGHT", 0, 0)
	d.key:SetJustifyH("LEFT"); d.key:Hide()
	d.body:SetJustifyH("LEFT"); d.body:SetSpacing(3)
	d.bw = PA.Btn(d, "Buy writ", 90, 22); d.bw:SetPoint("BOTTOMLEFT", 0, 28)
	d.bi = PA.Btn(d, "Buy item", 90, 22); d.bi:SetPoint("LEFT", d.bw, "RIGHT", 6, 0)
	d.pin = PA.Btn(d, "Map pin", 80, 22); d.pin:SetPoint("LEFT", d.bi, "RIGHT", 6, 0); d.pin:Hide()
	d.pop = PA.Btn(d, "Pop out", 80, 20); d.pop:SetPoint("TOPRIGHT", 0, 0); d.pop:Hide()
	d.pop:SetScript("OnClick", function() PA.ToggleRouteTracker(true) end)
	PA.Tip(d.pop, "Track the route", "Shows the route beside your quests (the Writs tab of Pint's Quest Book's tracker), or in its own small tracker at the side of the screen without Quest Book - kept up to date as you go (/pah route).")
	d.pin:SetScript("OnClick", function() if pSel then PA.WritWaypoint(pSel) end end)
	PA.Tip(d.pin, "Map pin", "Puts a pin on your map (and minimap) where this writ is turned in.")
	local function AH() if AuctionHouseFrame and AuctionHouseFrame:IsShown() then return true end; PA.Print("open the auction house to buy."); end
	d.bw:SetScript("OnClick", function() if pSel and AH() and PA.OpenInBuy then PA.OpenInBuy(C_AuctionHouse.MakeItemKey(pSel[2]), "Craftsman's Writ: " .. pSel[3]) end end)
	d.bi:SetScript("OnClick", function() if pSel and AH() and PA.OpenInBuy then PA.OpenInBuy(C_AuctionHouse.MakeItemKey(pSel[4]), pSel[6]) end end)
	d.foot = d:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); d.foot:SetPoint("BOTTOMLEFT", 0, 4); d.foot:SetPoint("RIGHT", 0, 0); d.foot:SetJustifyH("LEFT")
	d.foot:SetText("Prices from your last scan at the auction house (Writs tab: Scan writs).")
	pane:SetScript("OnShow", function()
		for _, w in ipairs(WRITS) do if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, w[4]) end end
		PA.DrawWritsPane(); C_Timer.After(1, PA.DrawWritsPane)
	end)
	return pane
end
-- a writ's tooltip (in your bags, the bank, the auction house, chat links): where it's turned in and what it asks for
if TooltipDataProcessor and Enum and Enum.TooltipDataType then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
		if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
		local id = data and data.id
		if type(id) ~= "number" or (issecretvalue and issecretvalue(id)) then return end
		local w = BY_ITEM[id]
		if not w or (PintsAuctionsDB and PintsAuctionsDB.writTips == false) then return end
		local have = ItemHave(w[4])
		tt:AddLine(" ")
		if Where(w) then tt:AddLine("Turn in: " .. Where(w), 1, 0.82, 0, true) else tt:AddLine("Turn in: not known yet - noted when you hand one in", 0.7, 0.7, 0.7, true) end
		tt:AddLine(("Asks for %d %s - you have %d"):format(w[5], w[6], have), have >= w[5] and 0.25 or 1, have >= w[5] and 1 or 0.5, 0.25, true)
		tt:AddLine(("Reputation %d"):format(MyRep(w)), 0.7, 0.7, 0.7)
		tt:Show()
	end)
end
-- /pah price <item name>: what Pint's Auctions has for an item and where it came from (for checking a price)
do
	local prev = SlashCmdList.PINTSAUCTIONS
	SlashCmdList.PINTSAUCTIONS = function(msg)
		if (msg or ""):lower():match("^%s*route%s*$") then PA.ToggleRouteTracker(); return end
		if (msg or ""):lower():match("^%s*writs%s+missing%s*$") then
			local st = Strangers()
			if #st == 0 then PA.Print("every writ in your bags and mail is one this add-on knows."); return end
			PA.Print(#st .. " writ" .. (#st == 1 and "" or "s") .. " this add-on doesn't know yet (send this list to Claude):")
			for _, w in ipairs(st) do PA.Print(("  %d  %s"):format(w[1], w[2])) end
			return
		end
		local name = (msg or ""):match("^%s*[Pp]rice%s+(.+)$")
		if not name then if prev then prev(msg) end; return end
		name = name:gsub("%s+$", "")
		local id = tonumber(name)
		if not id then
			for _, w in ipairs(WRITS) do
				if w[6]:lower() == name:lower() then id = w[4] end
				if ("craftsman's writ: " .. w[3]):lower() == name:lower() then id = w[2] end
			end
			if not id then local _, link = GII(name); id = link and tonumber(link:match("item:(%d+)")) end
		end
		if not id then PA.Print("don't know the item \"" .. name .. "\" - try its item number."); return end
		local p, t, none = PA.Price(id)
		local function Ago(x) if not x then return "never" end; local m = math.floor((time() - x) / 60); return m < 60 and (m .. " min ago") or (math.floor(m / 60) .. " h ago") end
		local hist = PA.History and PA.History(id) or {}
		PA.Print(("%s (item %d): %s - last seen %s%s; usual %s; you have %d."):format(name, id,
			none and "none listed at the latest look" or (p and PA.Money(p) or "no price"), Ago(t),
			none and "" or "", PA.Typical(id) and PA.Money(PA.Typical(id)) or "-", Have(id)))
	end
end

function PA.BuildWrits(p)
	page = p
	-- the side panel widens while Writs is open (room for the zone and some space between columns), back after
	local WIDE = 640
	local RW = WIDE - 20
	local panel = p:GetParent()
	local narrow
	p:HookScript("OnShow", function() narrow = narrow or panel:GetWidth(); panel:SetWidth(WIDE) end)
	p:HookScript("OnHide", function() if narrow then panel:SetWidth(narrow) end end)
	local filters = {}
	local function F(text, key, x, w)
		local b = PA.Btn(p, text, w, 20); b:SetPoint("TOPLEFT", x, -4)
		b:SetScript("OnClick", function() filter = key; for _, o in ipairs(filters) do o:UnlockHighlight() end; b:LockHighlight(); Refresh() end)
		filters[#filters + 1] = b
		return b
	end
	F("For sale", "sale", 10, 70):LockHighlight(); F("All", "all", 82, 50); F("Mine", "mine", 134, 50)
	PA.Tip(F("Not done today", "fresh", 186, 108), "Writs not done today", "Every writ you can still hand in today (each writ can be handed in once a day).")
	PA.Tip(filters[1], "For sale", "Writs on the auction house at the last scan (and ones you already have).")
	local scan = PA.Btn(p, "Scan writs", 100, 20); scan:SetPoint("TOPLEFT", 298, -4)
	local scanning
	scan:SetScript("OnClick", function()
		if scanning then scanning = nil; if PA.ClearQueue then PA.ClearQueue() end; scan:SetText("Scan writs"); Refresh(); return end
		if not (PA.Browse and AuctionHouseFrame and AuctionHouseFrame:IsShown()) then PA.Print("open the auction house to scan."); return end
		if PA.ClearQueue then PA.ClearQueue() end
		scanning = true; scan:SetText("Stop")
		status:SetText("Finding every writ for sale...")
		-- one search finds every writ on sale
		PA.Browse({ text = "Craftsman's Writ" }, function(results)
			local byWrit, listed, onSale = {}, {}, {}
			for _, w in ipairs(WRITS) do byWrit[w[2]] = w end
			for _, r in ipairs(results or {}) do
				local w = byWrit[r.itemKey.itemID]
				if w and r.minPrice and r.minPrice > 0 and (r.totalQuantity or 1) > 0 then PA.Record(tostring(w[2]), r.minPrice); listed[#listed + 1] = w; onSale[w[2]] = true end
			end
			-- writs not for sale any more lose their old price
			if results and #results > 0 and PA.RecordNone then
				for _, w in ipairs(WRITS) do if not onSale[w[2]] then PA.RecordNone(tostring(w[2])) end end
			end
			for _, w in ipairs(WRITS) do if Have(w[2]) > 0 then listed[#listed + 1] = w end end
			-- then what each listed writ asks for (each item once)
			local seen, todo = {}, {}
			for _, w in ipairs(listed) do if not seen[w[4]] then seen[w[4]] = true; todo[#todo + 1] = w end end
			local left = #todo
			if left == 0 or not scanning then scanning = nil; scan:SetText("Scan writs"); Refresh(); return end
			status:SetText(("Pricing what the writs ask for... (%d to go)"):format(left))
			for _, w in ipairs(todo) do
				local want = w[6]:lower()
				PA.Browse({ text = w[6], exact = true }, function(res)
					local found
					for _, r in ipairs(res or {}) do
						if r.itemKey.itemID == w[4] and r.minPrice and r.minPrice > 0 and (r.totalQuantity or 1) > 0 then PA.Record(tostring(w[4]), r.minPrice); found = true end
					end
					if not found and PA.RecordNone then PA.RecordNone(tostring(w[4])) end
					left = left - 1
					if not scanning then return end
					if left > 0 then status:SetText(("Pricing what the writs ask for... (%d to go)"):format(left))
					else scanning = nil; scan:SetText("Scan writs"); Refresh() end
				end)
			end
		end)
	end)
	PA.Tip(scan, "Scan writs", "Searches the auction house for every Craftsman's Writ for sale, then prices what each one asks for. Click again to stop.")
	-- (pad: room kept clear on a column's right, so the next one doesn't run into it)
	list = PA.List(p, RW, 17, 18, { { 170, "LEFT", "Writ", sort = "asc", pad = 10 }, { 112, "LEFT", "Zone", sort = "asc", pad = 8 },
		{ 62, "RIGHT", "Writ", sort = "asc" }, { 62, "RIGHT", "Item", sort = "asc" },
		{ 66, "RIGHT", "Total", sort = "asc" }, { 40, "RIGHT", "Rep", sort = "desc" }, { 76, "RIGHT", "Per 100", sort = "asc" } },
		function(item) list.selected = item; list.selectedKey = item.key; list:Refresh() end)
	list:SetPoint("TOPLEFT", 10, -44)
	list.sortCol, list.sortDesc = 7, false
	local bw = PA.Btn(p, "Buy writ", 90, 22); bw:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -16)
	bw:SetScript("OnClick", function()
		local it = list.selected; if not it then PA.Print("pick a writ first."); return end
		if PA.OpenInBuy then PA.OpenInBuy(C_AuctionHouse.MakeItemKey(it.writ[2]), "Craftsman's Writ: " .. it.writ[3]) end
	end)
	local bi = PA.Btn(p, "Buy item", 90, 22); bi:SetPoint("LEFT", bw, "RIGHT", 6, 0)
	bi:SetScript("OnClick", function()
		local it = list.selected; if not it then PA.Print("pick a writ first."); return end
		local w = it.writ
		if PA.OpenInBuy then PA.OpenInBuy(C_AuctionHouse.MakeItemKey(w[4]), w[6]) end
		PA.Print(("%s asks for %d %s (you have %d)."):format(w[3], w[5], w[6], ItemHave(w[4])))
	end)
	PA.Tip(bw, "Buy writ", "Opens the selected writ in the Buy view - the game's own Buy button buys it.")
	PA.Tip(bi, "Buy item", "Opens what the selected writ asks for in the Buy view.")
	status = PA.Label(p, "", "GameFontDisableSmall"); status:SetPoint("TOPLEFT", bw, "BOTTOMLEFT", 0, -6); status:SetWidth(RW); status:SetJustifyH("LEFT")
	p.OnOpen = function()
		for _, w in ipairs(WRITS) do if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, w[4]) end end
		Refresh(); C_Timer.After(1, Refresh)
	end
	local ev = CreateFrame("Frame", nil, p)
	ev:RegisterEvent("BAG_UPDATE_DELAYED")
	-- a writ or item looked at in the Buy view: its new price (or "none listed") shows straight away
	pcall(ev.RegisterEvent, ev, "ITEM_SEARCH_RESULTS_UPDATED"); pcall(ev.RegisterEvent, ev, "COMMODITY_SEARCH_RESULTS_UPDATED")
	ev:SetScript("OnEvent", function() if p:IsShown() then C_Timer.After(0.2, Refresh) end end)
end
