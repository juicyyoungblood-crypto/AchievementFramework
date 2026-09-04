--[[ AF_Catalog
  Action + modifier dropdowns that map ONLY to live AF_Track keys.
  signature = action|modifier|amount
]]
AF = AF or {}
AF.Catalog = AF.Catalog or {}
local C = AF.Catalog

C.ACTIONS = {
    { id = "kill",          label = "Kill (zombies)",      layer = "killed", total = "total" },
    { id = "damage",        label = "Damage (to zombies)", layer = "damage", total = "total" },
    { id = "eat",           label = "Eat / drink",         layer = "eaten",  total = "total" },
    { id = "fish",          label = "Fish (catch)",        layer = "fished", total = "total" },
    { id = "made",          label = "Craft / build",       layer = "made",   total = "total" },
    { id = "repair",        label = "Repair / fix",        layer = "repaired", total = "total" },
    { id = "read",          label = "Read",                layer = "read",   total = "total" },
    { id = "daysSurvived",  label = "Days survived",       layer = nil,     scalar = "daysSurvived" },
    { id = "distance",      label = "Distance traveled",   layer = "distance", total = "total" },
    -- amount = target level (use 5–10). Progress = live getPerkLevel (no AF_Track hooks).
    { id = "skill_level",  label = "Skill level (5–10)",  kind = "skill_level" },
}

-- Weapon families (killed.type.* / damage.type.*)
local WEAPON_TYPES = {
    { id = "type.axe",        label = "Axe" },
    { id = "type.longblunt",  label = "Long blunt" },
    { id = "type.shortblunt", label = "Short blunt" },
    { id = "type.longblade",  label = "Long blade" },
    { id = "type.shortblade", label = "Short blade" },
    { id = "type.spear",      label = "Spear" },
    { id = "type.firearm",    label = "Firearm" },
    { id = "type.barehands",  label = "Bare hands" },
    { id = "type.blunt",      label = "Blunt (any)" },
    { id = "type.bladed",     label = "Bladed (any)" },
    { id = "type.other",      label = "Other" },
}

-- Specific weapons by B42 script Categories (wiki melee families)
-- Built from ProjectZomboid/media/scripts item Categories=
local WEAPON_ITEMS_BY_FAMILY = {
    ["axe"] = {
        { id = "base.axe", fullType = "Base.Axe", label = "Axe" },
        { id = "base.axe_old", fullType = "Base.Axe_Old", label = "Axe Old" },
        { id = "base.axe_sawblade", fullType = "Base.Axe_Sawblade", label = "Axe Sawblade" },
        { id = "base.axe_sawblade_hatchet", fullType = "Base.Axe_Sawblade_Hatchet", label = "Axe Sawblade Hatchet" },
        { id = "base.axe_scrapcleaver", fullType = "Base.Axe_ScrapCleaver", label = "Axe Scrap Cleaver" },
        { id = "base.axestone", fullType = "Base.AxeStone", label = "Axe Stone" },
        { id = "base.baseballbat_metal_sawblade", fullType = "Base.BaseballBat_Metal_Sawblade", label = "Baseball Bat Metal Sawblade" },
        { id = "base.baseballbat_railspike", fullType = "Base.BaseballBat_RailSpike", label = "Baseball Bat Rail Spike" },
        { id = "base.baseballbat_sawblade", fullType = "Base.BaseballBat_Sawblade", label = "Baseball Bat Sawblade" },
        { id = "base.cudgel_brake", fullType = "Base.Cudgel_Brake", label = "Cudgel Brake" },
        { id = "base.cudgel_sawblade", fullType = "Base.Cudgel_Sawblade", label = "Cudgel Sawblade" },
        { id = "base.cudgel_spadehead", fullType = "Base.Cudgel_SpadeHead", label = "Cudgel Spade Head" },
        { id = "base.entrenchingtool", fullType = "Base.EntrenchingTool", label = "Entrenching Tool" },
        { id = "base.fieldhockeystick_sawblade", fullType = "Base.FieldHockeyStick_Sawblade", label = "Field Hockey Stick Sawblade" },
        { id = "base.handaxe", fullType = "Base.HandAxe", label = "Hand Axe" },
        { id = "base.handaxe_old", fullType = "Base.HandAxe_Old", label = "Hand Axe Old" },
        { id = "base.handaxeforged", fullType = "Base.HandAxeForged", label = "Hand Axe Forged" },
        { id = "base.handscythe", fullType = "Base.HandScythe", label = "Hand Scythe" },
        { id = "base.handscytheforged", fullType = "Base.HandScytheForged", label = "Hand Scythe Forged" },
        { id = "base.hatchet_bone", fullType = "Base.Hatchet_Bone", label = "Hatchet Bone" },
        { id = "base.iceaxe", fullType = "Base.IceAxe", label = "Ice Axe" },
        { id = "base.jawbonebovide_axe", fullType = "Base.JawboneBovide_Axe", label = "Jawbone Bovide Axe" },
        { id = "base.largeboneclub_spiked", fullType = "Base.LargeBoneClub_Spiked", label = "Large Bone Club Spiked" },
        { id = "base.longhandle_railspike", fullType = "Base.LongHandle_Railspike", label = "Long Handle Railspike" },
        { id = "base.longhandle_sawblade", fullType = "Base.LongHandle_Sawblade", label = "Long Handle Sawblade" },
        { id = "base.meatcleaver", fullType = "Base.MeatCleaver", label = "Meat Cleaver" },
        { id = "base.meatcleaver_scrap", fullType = "Base.MeatCleaver_Scrap", label = "Meat Cleaver Scrap" },
        { id = "base.meatcleaverforged", fullType = "Base.MeatCleaverForged", label = "Meat Cleaver Forged" },
        { id = "base.metalpipe_railspike", fullType = "Base.MetalPipe_Railspike", label = "Metal Pipe Railspike" },
        { id = "base.pickaxe", fullType = "Base.PickAxe", label = "Pick Axe" },
        { id = "base.pickaxeforged", fullType = "Base.PickAxeForged", label = "Pick Axe Forged" },
        { id = "base.plank_brake", fullType = "Base.Plank_Brake", label = "Plank Brake" },
        { id = "base.plank_sawblade", fullType = "Base.Plank_Sawblade", label = "Plank Sawblade" },
        { id = "base.primitivescythe", fullType = "Base.PrimitiveScythe", label = "Primitive Scythe" },
        { id = "base.saw_flint", fullType = "Base.Saw_Flint", label = "Saw Flint" },
        { id = "base.scrapweapon_brake", fullType = "Base.ScrapWeapon_Brake", label = "Scrap Weapon Brake" },
        { id = "base.scrapweapongardenfork", fullType = "Base.ScrapWeaponGardenFork", label = "Scrap Weapon Garden Fork" },
        { id = "base.scrapweaponspade", fullType = "Base.ScrapWeaponSpade", label = "Scrap Weapon Spade" },
        { id = "base.shortbat_railspike", fullType = "Base.ShortBat_RailSpike", label = "Short Bat Rail Spike" },
        { id = "base.shortbat_sawblade", fullType = "Base.ShortBat_Sawblade", label = "Short Bat Sawblade" },
        { id = "base.stoneaxelarge", fullType = "Base.StoneAxeLarge", label = "Stone Axe Large" },
        { id = "base.tableleg_sawblade", fullType = "Base.TableLeg_Sawblade", label = "Table Leg Sawblade" },
        { id = "base.treebranch_railspike", fullType = "Base.TreeBranch_Railspike", label = "Tree Branch Railspike" },
        { id = "base.woodaxe", fullType = "Base.WoodAxe", label = "Wood Axe" },
        { id = "base.woodaxeforged", fullType = "Base.WoodAxeForged", label = "Wood Axe Forged" },
    },
    ["longblunt"] = {
        { id = "base.banjo", fullType = "Base.Banjo", label = "Banjo" },
        { id = "base.barbell", fullType = "Base.BarBell", label = "Bar Bell" },
        { id = "base.barbell_forged", fullType = "Base.BarBell_Forged", label = "Bar Bell Forged" },
        { id = "base.baseballbat", fullType = "Base.BaseballBat", label = "Baseball Bat" },
        { id = "base.baseballbat_can", fullType = "Base.BaseballBat_Can", label = "Baseball Bat Can" },
        { id = "base.baseballbat_crafted", fullType = "Base.BaseballBat_Crafted", label = "Baseball Bat Crafted" },
        { id = "base.baseballbat_gardenforkhead", fullType = "Base.BaseballBat_GardenForkHead", label = "Baseball Bat Garden Fork Head" },
        { id = "base.baseballbat_metal", fullType = "Base.BaseballBat_Metal", label = "Baseball Bat Metal" },
        { id = "base.baseballbat_metal_bolts", fullType = "Base.BaseballBat_Metal_Bolts", label = "Baseball Bat Metal Bolts" },
        { id = "base.baseballbat_nails", fullType = "Base.BaseballBat_Nails", label = "Baseball Bat Nails" },
        { id = "base.baseballbat_rakehead", fullType = "Base.BaseballBat_RakeHead", label = "Baseball Bat Rake Head" },
        { id = "base.baseballbat_scrapsheet", fullType = "Base.BaseballBat_ScrapSheet", label = "Baseball Bat Scrap Sheet" },
        { id = "base.baseballbat_spiked", fullType = "Base.BaseballBat_Spiked", label = "Baseball Bat Spiked" },
        { id = "base.blockmaul", fullType = "Base.BlockMaul", label = "Block Maul" },
        { id = "base.boltcutters", fullType = "Base.BoltCutters", label = "Bolt Cutters" },
        { id = "base.broom", fullType = "Base.Broom", label = "Broom" },
        { id = "base.broom_barbedwire", fullType = "Base.Broom_BarbedWire", label = "Broom Barbed Wire" },
        { id = "base.broom_twig", fullType = "Base.Broom_Twig", label = "Broom Twig" },
        { id = "base.bucketmace_metal", fullType = "Base.BucketMace_Metal", label = "Bucket Mace Metal" },
        { id = "base.bucketmace_wood", fullType = "Base.BucketMace_Wood", label = "Bucket Mace Wood" },
        { id = "base.canoepadel", fullType = "Base.CanoePadel", label = "Canoe Padel" },
        { id = "base.canoepadelx2", fullType = "Base.CanoePadelX2", label = "Canoe Padel X2" },
        { id = "base.canoepadelx2_broken", fullType = "Base.CanoePadelX2_Broken", label = "Canoe Padel X2 Broken" },
        { id = "base.craftedfishingrod", fullType = "Base.CraftedFishingRod", label = "Crafted Fishing Rod" },
        { id = "base.crowbar", fullType = "Base.Crowbar", label = "Crowbar" },
        { id = "base.crowbarforged", fullType = "Base.CrowbarForged", label = "Crowbar Forged" },
        { id = "base.cudgel_bone", fullType = "Base.Cudgel_Bone", label = "Cudgel Bone" },
        { id = "base.cudgel_gardenforkhead", fullType = "Base.Cudgel_GardenForkHead", label = "Cudgel Garden Fork Head" },
        { id = "base.cudgel_nails", fullType = "Base.Cudgel_Nails", label = "Cudgel Nails" },
        { id = "base.cudgel_railspike", fullType = "Base.Cudgel_Railspike", label = "Cudgel Railspike" },
        { id = "base.cudgel_scrapsheet", fullType = "Base.Cudgel_ScrapSheet", label = "Cudgel Scrap Sheet" },
        { id = "base.cudgel_spike", fullType = "Base.Cudgel_Spike", label = "Cudgel Spike" },
        { id = "base.enginemaul", fullType = "Base.EngineMaul", label = "Engine Maul" },
        { id = "base.fieldhockeystick", fullType = "Base.FieldHockeyStick", label = "Field Hockey Stick" },
        { id = "base.fieldhockeystick_nails", fullType = "Base.FieldHockeyStick_Nails", label = "Field Hockey Stick Nails" },
        { id = "base.fish_dev_item", fullType = "Base.FISH_DEV_ITEM", label = "FISH DEV ITEM" },
        { id = "base.fishingrod", fullType = "Base.FishingRod", label = "Fishing Rod" },
        { id = "base.fishingrodbreak", fullType = "Base.FishingRodBreak", label = "Fishing Rod Break" },
        { id = "base.gaffhook", fullType = "Base.Gaffhook", label = "Gaffhook" },
        { id = "base.gardenforkhead", fullType = "Base.GardenForkHead", label = "Garden Fork Head" },
        { id = "base.gardenforkhead_forged", fullType = "Base.GardenForkHead_Forged", label = "Garden Fork Head Forged" },
        { id = "base.gardenhoe", fullType = "Base.GardenHoe", label = "Garden Hoe" },
        { id = "base.gardenhoeforged", fullType = "Base.GardenHoeForged", label = "Garden Hoe Forged" },
        { id = "base.golfclub", fullType = "Base.Golfclub", label = "Golfclub" },
        { id = "base.guitaracoustic", fullType = "Base.GuitarAcoustic", label = "Guitar Acoustic" },
        { id = "base.guitarelectric", fullType = "Base.GuitarElectric", label = "Guitar Electric" },
        { id = "base.guitarelectricbass", fullType = "Base.GuitarElectricBass", label = "Guitar Electric Bass" },
        { id = "base.hobbyhorse", fullType = "Base.HobbyHorse", label = "Hobby Horse" },
        { id = "base.icehockeystick", fullType = "Base.IceHockeyStick", label = "Ice Hockey Stick" },
        { id = "base.icehockeystick_barbedwire", fullType = "Base.IceHockeyStick_BarbedWire", label = "Ice Hockey Stick Barbed Wire" },
        { id = "base.ironbar", fullType = "Base.IronBar", label = "Iron Bar" },
        { id = "base.jawbonebovide_morningstar", fullType = "Base.JawboneBovide_Morningstar", label = "Jawbone Bovide Morningstar" },
        { id = "base.kettlemace_metal", fullType = "Base.KettleMace_Metal", label = "Kettle Mace Metal" },
        { id = "base.kettlemace_wood", fullType = "Base.KettleMace_Wood", label = "Kettle Mace Wood" },
        { id = "base.keytar", fullType = "Base.Keytar", label = "Keytar" },
        { id = "base.lacrossestick", fullType = "Base.LaCrosseStick", label = "La Crosse Stick" },
        { id = "base.largebranch", fullType = "Base.LargeBranch", label = "Large Branch" },
        { id = "base.leafrake", fullType = "Base.LeafRake", label = "Leaf Rake" },
        { id = "base.longhandle", fullType = "Base.LongHandle", label = "Long Handle" },
        { id = "base.longhandle_brake", fullType = "Base.LongHandle_Brake", label = "Long Handle Brake" },
        { id = "base.longhandle_can", fullType = "Base.LongHandle_Can", label = "Long Handle Can" },
        { id = "base.longhandle_nails", fullType = "Base.LongHandle_Nails", label = "Long Handle Nails" },
        { id = "base.longhandle_rakehead", fullType = "Base.LongHandle_RakeHead", label = "Long Handle Rake Head" },
        { id = "base.longmace", fullType = "Base.LongMace", label = "Long Mace" },
        { id = "base.longmace_stone", fullType = "Base.LongMace_Stone", label = "Long Mace Stone" },
        { id = "base.longspikedclub", fullType = "Base.LongSpikedClub", label = "Long Spiked Club" },
        { id = "base.longstick", fullType = "Base.LongStick", label = "Long Stick" },
        { id = "base.mop", fullType = "Base.Mop", label = "Mop" },
        { id = "base.morningstar_scrap", fullType = "Base.Morningstar_Scrap", label = "Morningstar Scrap" },
        { id = "base.plank", fullType = "Base.Plank", label = "Plank" },
        { id = "base.plank_nails", fullType = "Base.Plank_Nails", label = "Plank Nails" },
        { id = "base.plank_saw", fullType = "Base.Plank_Saw", label = "Plank Saw" },
        { id = "base.poolcue", fullType = "Base.Poolcue", label = "Poolcue" },
        { id = "base.railroadspikepuller", fullType = "Base.RailroadSpikePuller", label = "Railroad Spike Puller" },
        { id = "base.railroadspikepullerold", fullType = "Base.RailroadSpikePullerOld", label = "Railroad Spike Puller Old" },
        { id = "base.rake", fullType = "Base.Rake", label = "Rake" },
        { id = "base.sapling", fullType = "Base.Sapling", label = "Sapling" },
        { id = "base.saxophone", fullType = "Base.Saxophone", label = "Saxophone" },
        { id = "base.scrapmaul", fullType = "Base.ScrapMaul", label = "Scrap Maul" },
        { id = "base.scrapweaponrakehead", fullType = "Base.ScrapWeaponRakeHead", label = "Scrap Weapon Rake Head" },
        { id = "base.shovel", fullType = "Base.Shovel", label = "Shovel" },
        { id = "base.shovel2", fullType = "Base.Shovel2", label = "Shovel2" },
        { id = "base.sledgehammer", fullType = "Base.Sledgehammer", label = "Sledgehammer" },
        { id = "base.sledgehammer2", fullType = "Base.Sledgehammer2", label = "Sledgehammer2" },
        { id = "base.sledgehammerforged", fullType = "Base.SledgehammerForged", label = "Sledgehammer Forged" },
        { id = "base.snowshovel", fullType = "Base.SnowShovel", label = "Snow Shovel" },
        { id = "base.spadeforged", fullType = "Base.SpadeForged", label = "Spade Forged" },
        { id = "base.spadehead", fullType = "Base.SpadeHead", label = "Spade Head" },
        { id = "base.spadewood", fullType = "Base.SpadeWood", label = "Spade Wood" },
        { id = "base.steelbar", fullType = "Base.SteelBar", label = "Steel Bar" },
        { id = "base.stonemaul", fullType = "Base.StoneMaul", label = "Stone Maul" },
        { id = "base.tableleg", fullType = "Base.TableLeg", label = "Table Leg" },
        { id = "base.tableleg_chain", fullType = "Base.TableLeg_Chain", label = "Table Leg Chain" },
        { id = "base.tableleg_nails", fullType = "Base.TableLeg_Nails", label = "Table Leg Nails" },
        { id = "base.trumpet", fullType = "Base.Trumpet", label = "Trumpet" },
        { id = "base.woodenstick_can", fullType = "Base.WoodenStick_Can", label = "Wooden Stick Can" },
    },
    ["shortblunt"] = {
        { id = "base.animalbone", fullType = "Base.AnimalBone", label = "Animal Bone" },
        { id = "base.badmintonracket", fullType = "Base.BadmintonRacket", label = "Badminton Racket" },
        { id = "base.ballpeenhammer", fullType = "Base.BallPeenHammer", label = "Ball Peen Hammer" },
        { id = "base.ballpeenhammerforged", fullType = "Base.BallPeenHammerForged", label = "Ball Peen Hammer Forged" },
        { id = "base.banjoneck_broken", fullType = "Base.BanjoNeck_Broken", label = "Banjo Neck Broken" },
        { id = "base.baseballbat_broken", fullType = "Base.BaseballBat_Broken", label = "Baseball Bat Broken" },
        { id = "base.baseballbat_broken_nails", fullType = "Base.BaseballBat_Broken_Nails", label = "Baseball Bat Broken Nails" },
        { id = "base.blockmace", fullType = "Base.BlockMace", label = "Block Mace" },
        { id = "base.boneclub", fullType = "Base.BoneClub", label = "Bone Club" },
        { id = "base.boneclub_spiked", fullType = "Base.BoneClub_Spiked", label = "Bone Club Spiked" },
        { id = "base.bowlingpin", fullType = "Base.BowlingPin", label = "Bowling Pin" },
        { id = "base.bowlingpin_nails", fullType = "Base.BowlingPin_Nails", label = "Bowling Pin Nails" },
        { id = "base.branch_broken", fullType = "Base.Branch_Broken", label = "Branch Broken" },
        { id = "base.branch_broken_nails", fullType = "Base.Branch_Broken_Nails", label = "Branch Broken Nails" },
        { id = "base.brassnameplate", fullType = "Base.BrassNameplate", label = "Brass Nameplate" },
        { id = "base.carpentrychisel", fullType = "Base.CarpentryChisel", label = "Carpentry Chisel" },
        { id = "base.chairleg", fullType = "Base.ChairLeg", label = "Chair Leg" },
        { id = "base.chairleg_nails", fullType = "Base.ChairLeg_Nails", label = "Chair Leg Nails" },
        { id = "base.clubhammer", fullType = "Base.ClubHammer", label = "Club Hammer" },
        { id = "base.clubhammerforged", fullType = "Base.ClubHammerForged", label = "Club Hammer Forged" },
        { id = "base.drumstick", fullType = "Base.Drumstick", label = "Drumstick" },
        { id = "base.dumbbell", fullType = "Base.DumbBell", label = "Dumb Bell" },
        { id = "base.dumbbell_forged", fullType = "Base.DumbBell_Forged", label = "Dumb Bell Forged" },
        { id = "base.fieldhockeystick_broken", fullType = "Base.FieldHockeyStick_Broken", label = "Field Hockey Stick Broken" },
        { id = "base.fieldhockeystick_broken_nails", fullType = "Base.FieldHockeyStick_Broken_Nails", label = "Field Hockey Stick Broken Nails" },
        { id = "base.file", fullType = "Base.File", label = "File" },
        { id = "base.fireplacepoker", fullType = "Base.FireplacePoker", label = "Fireplace Poker" },
        { id = "base.firewood", fullType = "Base.Firewood", label = "Firewood" },
        { id = "base.firewood_nails", fullType = "Base.Firewood_Nails", label = "Firewood Nails" },
        { id = "base.flute", fullType = "Base.Flute", label = "Flute" },
        { id = "base.gardentoolhandle_broken", fullType = "Base.GardenToolHandle_Broken", label = "Garden Tool Handle Broken" },
        { id = "base.gavel", fullType = "Base.Gavel", label = "Gavel" },
        { id = "base.gridlepan", fullType = "Base.GridlePan", label = "Gridle Pan" },
        { id = "base.guitaracousticneck_broken", fullType = "Base.GuitarAcousticNeck_Broken", label = "Guitar Acoustic Neck Broken" },
        { id = "base.guitarelectricbassneck_broken", fullType = "Base.GuitarElectricBassNeck_Broken", label = "Guitar Electric Bass Neck Broken" },
        { id = "base.guitarelectricneck_broken", fullType = "Base.GuitarElectricNeck_Broken", label = "Guitar Electric Neck Broken" },
        { id = "base.hammer", fullType = "Base.Hammer", label = "Hammer" },
        { id = "base.hammerforged", fullType = "Base.HammerForged", label = "Hammer Forged" },
        { id = "base.hammerstone", fullType = "Base.HammerStone", label = "Hammer Stone" },
        { id = "base.handle", fullType = "Base.Handle", label = "Handle" },
        { id = "base.handle_can", fullType = "Base.Handle_Can", label = "Handle Can" },
        { id = "base.handle_nails", fullType = "Base.Handle_Nails", label = "Handle Nails" },
        { id = "base.ironbarhalf", fullType = "Base.IronBarHalf", label = "Iron Bar Half" },
        { id = "base.jawbonebovide", fullType = "Base.JawboneBovide", label = "Jawbone Bovide" },
        { id = "base.jawbonebovide_club", fullType = "Base.JawboneBovide_Club", label = "Jawbone Bovide Club" },
        { id = "base.largeanimalbone", fullType = "Base.LargeAnimalBone", label = "Large Animal Bone" },
        { id = "base.largeboneclub", fullType = "Base.LargeBoneClub", label = "Large Bone Club" },
        { id = "base.largehook", fullType = "Base.LargeHook", label = "Large Hook" },
        { id = "base.leadpipe", fullType = "Base.LeadPipe", label = "Lead Pipe" },
        { id = "base.longhandle_broken", fullType = "Base.LongHandle_Broken", label = "Long Handle Broken" },
        { id = "base.longhandle_broken_nails", fullType = "Base.LongHandle_Broken_Nails", label = "Long Handle Broken Nails" },
        { id = "base.longstick_broken", fullType = "Base.LongStick_Broken", label = "Long Stick Broken" },
        { id = "base.mace", fullType = "Base.Mace", label = "Mace" },
        { id = "base.mace_stone", fullType = "Base.Mace_Stone", label = "Mace Stone" },
        { id = "base.masonschisel", fullType = "Base.MasonsChisel", label = "Masons Chisel" },
        { id = "base.metalbar", fullType = "Base.MetalBar", label = "Metal Bar" },
        { id = "base.metalpipe", fullType = "Base.MetalPipe", label = "Metal Pipe" },
        { id = "base.metalpipe_broken", fullType = "Base.MetalPipe_Broken", label = "Metal Pipe Broken" },
        { id = "base.metalworkingchisel", fullType = "Base.MetalworkingChisel", label = "Metalworking Chisel" },
        { id = "base.metalworkingpunch", fullType = "Base.MetalworkingPunch", label = "Metalworking Punch" },
        { id = "base.morningstar_scrap_short", fullType = "Base.Morningstar_Scrap_Short", label = "Morningstar Scrap Short" },
        { id = "base.nightstick", fullType = "Base.Nightstick", label = "Nightstick" },
        { id = "base.pan", fullType = "Base.Pan", label = "Pan" },
        { id = "base.panforged", fullType = "Base.PanForged", label = "Pan Forged" },
        { id = "base.pipewrench", fullType = "Base.PipeWrench", label = "Pipe Wrench" },
        { id = "base.plank_broken", fullType = "Base.Plank_Broken", label = "Plank Broken" },
        { id = "base.plank_broken_nails", fullType = "Base.Plank_Broken_Nails", label = "Plank Broken Nails" },
        { id = "base.plunger", fullType = "Base.Plunger", label = "Plunger" },
        { id = "base.plunger_barbedwire", fullType = "Base.Plunger_BarbedWire", label = "Plunger Barbed Wire" },
        { id = "base.ratchet", fullType = "Base.Ratchet", label = "Ratchet" },
        { id = "base.rollingpin", fullType = "Base.RollingPin", label = "Rolling Pin" },
        { id = "base.saucepan", fullType = "Base.Saucepan", label = "Saucepan" },
        { id = "base.saucepancopper", fullType = "Base.SaucepanCopper", label = "Saucepan Copper" },
        { id = "base.sheetmetalsnips", fullType = "Base.SheetMetalSnips", label = "Sheet Metal Snips" },
        { id = "base.shortbat", fullType = "Base.ShortBat", label = "Short Bat" },
        { id = "base.shortbat_can", fullType = "Base.ShortBat_Can", label = "Short Bat Can" },
        { id = "base.shortbat_nails", fullType = "Base.ShortBat_Nails", label = "Short Bat Nails" },
        { id = "base.shortbat_rakehead", fullType = "Base.ShortBat_RakeHead", label = "Short Bat Rake Head" },
        { id = "base.smithinghammer", fullType = "Base.SmithingHammer", label = "Smithing Hammer" },
        { id = "base.spikedshortbat", fullType = "Base.SpikedShortBat", label = "Spiked Short Bat" },
        { id = "base.steelbarhalf", fullType = "Base.SteelBarHalf", label = "Steel Bar Half" },
        { id = "base.steelrodhalf", fullType = "Base.SteelRodHalf", label = "Steel Rod Half" },
        { id = "base.tableleg_broken", fullType = "Base.TableLeg_Broken", label = "Table Leg Broken" },
        { id = "base.tableleg_broken_nails", fullType = "Base.TableLeg_Broken_Nails", label = "Table Leg Broken Nails" },
        { id = "base.tennisracket", fullType = "Base.TennisRacket", label = "Tennis Racket" },
        { id = "base.tireiron", fullType = "Base.TireIron", label = "Tire Iron" },
        { id = "base.treebranch2", fullType = "Base.TreeBranch2", label = "Tree Branch2" },
        { id = "base.treebranch_bone", fullType = "Base.TreeBranch_Bone", label = "Tree Branch Bone" },
        { id = "base.treebranch_can", fullType = "Base.TreeBranch_Can", label = "Tree Branch Can" },
        { id = "base.treebranch_nails", fullType = "Base.TreeBranch_Nails", label = "Tree Branch Nails" },
        { id = "base.violin", fullType = "Base.Violin", label = "Violin" },
        { id = "base.woodenmallet", fullType = "Base.WoodenMallet", label = "Wooden Mallet" },
        { id = "base.woodenstick2", fullType = "Base.WoodenStick2", label = "Wooden Stick2" },
        { id = "base.woodenstick_broken", fullType = "Base.WoodenStick_Broken", label = "Wooden Stick Broken" },
        { id = "base.woodenstick_broken_nails", fullType = "Base.WoodenStick_Broken_Nails", label = "Wooden Stick Broken Nails" },
        { id = "base.woodenstick_nails", fullType = "Base.WoodenStick_Nails", label = "Wooden Stick Nails" },
        { id = "base.wrench", fullType = "Base.Wrench", label = "Wrench" },
        { id = "base.yardstickdebug", fullType = "Base.YardstickDEBUG", label = "Yardstick DEBUG" },
    },
    ["longblade"] = {
        { id = "base.crudeshortsword", fullType = "Base.CrudeShortSword", label = "Crude Short Sword" },
        { id = "base.crudesword", fullType = "Base.CrudeSword", label = "Crude Sword" },
        { id = "base.crudesword_broken", fullType = "Base.CrudeSword_Broken", label = "Crude Sword Broken" },
        { id = "base.katana", fullType = "Base.Katana", label = "Katana" },
        { id = "base.katana_broken", fullType = "Base.Katana_Broken", label = "Katana Broken" },
        { id = "base.machete", fullType = "Base.Machete", label = "Machete" },
        { id = "base.machete_crude", fullType = "Base.Machete_Crude", label = "Machete Crude" },
        { id = "base.macheteforged", fullType = "Base.MacheteForged", label = "Machete Forged" },
        { id = "base.shortsword", fullType = "Base.ShortSword", label = "Short Sword" },
        { id = "base.shortsword_scrap", fullType = "Base.ShortSword_Scrap", label = "Short Sword Scrap" },
        { id = "base.sword", fullType = "Base.Sword", label = "Sword" },
        { id = "base.sword_broken", fullType = "Base.Sword_Broken", label = "Sword Broken" },
        { id = "base.sword_scrap", fullType = "Base.Sword_Scrap", label = "Sword Scrap" },
        { id = "base.sword_scrap_broken", fullType = "Base.Sword_Scrap_Broken", label = "Sword Scrap Broken" },
    },
    ["shortblade"] = {
        { id = "base.breadknife", fullType = "Base.BreadKnife", label = "Bread Knife" },
        { id = "base.butterknife", fullType = "Base.ButterKnife", label = "Butter Knife" },
        { id = "base.butterknife_gold", fullType = "Base.ButterKnife_Gold", label = "Butter Knife Gold" },
        { id = "base.butterknife_silver", fullType = "Base.ButterKnife_Silver", label = "Butter Knife Silver" },
        { id = "base.carvingfork2", fullType = "Base.CarvingFork2", label = "Carving Fork2" },
        { id = "base.crudeknife", fullType = "Base.CrudeKnife", label = "Crude Knife" },
        { id = "base.dullboneknife", fullType = "Base.DullBoneKnife", label = "Dull Bone Knife" },
        { id = "base.fightingknife", fullType = "Base.FightingKnife", label = "Fighting Knife" },
        { id = "base.flintknife", fullType = "Base.FlintKnife", label = "Flint Knife" },
        { id = "base.fork", fullType = "Base.Fork", label = "Fork" },
        { id = "base.fork_bone", fullType = "Base.Fork_Bone", label = "Fork Bone" },
        { id = "base.fork_gold", fullType = "Base.Fork_Gold", label = "Fork Gold" },
        { id = "base.fork_silver", fullType = "Base.Fork_Silver", label = "Fork Silver" },
        { id = "base.forkforged", fullType = "Base.ForkForged", label = "Fork Forged" },
        { id = "base.glassshiv", fullType = "Base.GlassShiv", label = "Glass Shiv" },
        { id = "base.handfork", fullType = "Base.HandFork", label = "Hand Fork" },
        { id = "base.handguarddagger", fullType = "Base.HandguardDagger", label = "Handguard Dagger" },
        { id = "base.handiknife", fullType = "Base.Handiknife", label = "Handiknife" },
        { id = "base.handshovel", fullType = "Base.HandShovel", label = "Hand Shovel" },
        { id = "base.huntingknife", fullType = "Base.HuntingKnife", label = "Hunting Knife" },
        { id = "base.huntingknifeforged", fullType = "Base.HuntingKnifeForged", label = "Hunting Knife Forged" },
        { id = "base.icepick", fullType = "Base.IcePick", label = "Ice Pick" },
        { id = "base.kitchenknife", fullType = "Base.KitchenKnife", label = "Kitchen Knife" },
        { id = "base.kitchenknifeforged", fullType = "Base.KitchenKnifeForged", label = "Kitchen Knife Forged" },
        { id = "base.knifebutterfly", fullType = "Base.KnifeButterfly", label = "Knife Butterfly" },
        { id = "base.knifefillet", fullType = "Base.KnifeFillet", label = "Knife Fillet" },
        { id = "base.knifeparing", fullType = "Base.KnifeParing", label = "Knife Paring" },
        { id = "base.knifepocket", fullType = "Base.KnifePocket", label = "Knife Pocket" },
        { id = "base.knifeshiv", fullType = "Base.KnifeShiv", label = "Knife Shiv" },
        { id = "base.knifesushi", fullType = "Base.KnifeSushi", label = "Knife Sushi" },
        { id = "base.largeknife", fullType = "Base.LargeKnife", label = "Large Knife" },
        { id = "base.largeknife_scrap", fullType = "Base.LargeKnife_Scrap", label = "Large Knife Scrap" },
        { id = "base.letteropener", fullType = "Base.LetterOpener", label = "Letter Opener" },
        { id = "base.longcrudeknife", fullType = "Base.LongCrudeKnife", label = "Long Crude Knife" },
        { id = "base.macheteknife", fullType = "Base.MacheteKnife", label = "Machete Knife" },
        { id = "base.masonstrowel", fullType = "Base.MasonsTrowel", label = "Masons Trowel" },
        { id = "base.multitool", fullType = "Base.Multitool", label = "Multitool" },
        { id = "base.railroadspike", fullType = "Base.RailroadSpike", label = "Railroad Spike" },
        { id = "base.railroadspikeknife", fullType = "Base.RailroadSpikeKnife", label = "Railroad Spike Knife" },
        { id = "base.scalpel", fullType = "Base.Scalpel", label = "Scalpel" },
        { id = "base.scissors", fullType = "Base.Scissors", label = "Scissors" },
        { id = "base.scissorsforged", fullType = "Base.ScissorsForged", label = "Scissors Forged" },
        { id = "base.screwdriver", fullType = "Base.Screwdriver", label = "Screwdriver" },
        { id = "base.screwdriver_improvised", fullType = "Base.Screwdriver_Improvised", label = "Screwdriver Improvised" },
        { id = "base.screwdriver_old", fullType = "Base.Screwdriver_Old", label = "Screwdriver Old" },
        { id = "base.sharpbone_long", fullType = "Base.SharpBone_Long", label = "Sharp Bone Long" },
        { id = "base.smallknife", fullType = "Base.SmallKnife", label = "Small Knife" },
        { id = "base.smashedbottle", fullType = "Base.SmashedBottle", label = "Smashed Bottle" },
        { id = "base.spoon", fullType = "Base.Spoon", label = "Spoon" },
        { id = "base.spoon_bone", fullType = "Base.Spoon_Bone", label = "Spoon Bone" },
        { id = "base.spoon_gold", fullType = "Base.Spoon_Gold", label = "Spoon Gold" },
        { id = "base.spoon_silver", fullType = "Base.Spoon_Silver", label = "Spoon Silver" },
        { id = "base.spoonforged", fullType = "Base.SpoonForged", label = "Spoon Forged" },
        { id = "base.stake", fullType = "Base.Stake", label = "Stake" },
        { id = "base.steakknife", fullType = "Base.SteakKnife", label = "Steak Knife" },
        { id = "base.stoneknifelong", fullType = "Base.StoneKnifeLong", label = "Stone Knife Long" },
        { id = "base.switchknife", fullType = "Base.SwitchKnife", label = "Switch Knife" },
        { id = "base.tinopener_old", fullType = "Base.TinOpener_Old", label = "Tin Opener Old" },
        { id = "base.toothbrush_shiv", fullType = "Base.Toothbrush_Shiv", label = "Toothbrush Shiv" },
    },
    ["spear"] = {
        { id = "base.closedumbrellablack", fullType = "Base.ClosedUmbrellaBlack", label = "Closed Umbrella Black" },
        { id = "base.closedumbrellablue", fullType = "Base.ClosedUmbrellaBlue", label = "Closed Umbrella Blue" },
        { id = "base.closedumbrellared", fullType = "Base.ClosedUmbrellaRed", label = "Closed Umbrella Red" },
        { id = "base.closedumbrellatinted", fullType = "Base.ClosedUmbrellaTINTED", label = "Closed Umbrella TINTED" },
        { id = "base.closedumbrellawhite", fullType = "Base.ClosedUmbrellaWhite", label = "Closed Umbrella White" },
        { id = "base.gardenfork", fullType = "Base.GardenFork", label = "Garden Fork" },
        { id = "base.gardenfork_forged", fullType = "Base.GardenFork_Forged", label = "Garden Fork Forged" },
        { id = "base.spear_bone", fullType = "Base.Spear_Bone", label = "Spear Bone" },
        { id = "base.spear_bonelong", fullType = "Base.Spear_BoneLong", label = "Spear Bone Long" },
        { id = "base.spear_plunger", fullType = "Base.Spear_Plunger", label = "Spear Plunger" },
        { id = "base.spearcrafted", fullType = "Base.SpearCrafted", label = "Spear Crafted" },
        { id = "base.spearcraftedfirehardened", fullType = "Base.SpearCraftedFireHardened", label = "Spear Crafted Fire Hardened" },
        { id = "base.spearcrude", fullType = "Base.SpearCrude", label = "Spear Crude" },
        { id = "base.spearcrudelong", fullType = "Base.SpearCrudeLong", label = "Spear Crude Long" },
        { id = "base.spearfightingknife", fullType = "Base.SpearFightingKnife", label = "Spear Fighting Knife" },
        { id = "base.spearglass", fullType = "Base.SpearGlass", label = "Spear Glass" },
        { id = "base.spearhandfork", fullType = "Base.SpearHandFork", label = "Spear Hand Fork" },
        { id = "base.spearhuntingknife", fullType = "Base.SpearHuntingKnife", label = "Spear Hunting Knife" },
        { id = "base.spearknife", fullType = "Base.SpearKnife", label = "Spear Knife" },
        { id = "base.spearknifesmall", fullType = "Base.SpearKnifeSmall", label = "Spear Knife Small" },
        { id = "base.spearlargeknife", fullType = "Base.SpearLargeKnife", label = "Spear Large Knife" },
        { id = "base.spearlong", fullType = "Base.SpearLong", label = "Spear Long" },
        { id = "base.spearscissors", fullType = "Base.SpearScissors", label = "Spear Scissors" },
        { id = "base.spearscrapknife", fullType = "Base.SpearScrapKnife", label = "Spear Scrap Knife" },
        { id = "base.spearscrewdriver", fullType = "Base.SpearScrewdriver", label = "Spear Screwdriver" },
        { id = "base.spearshort", fullType = "Base.SpearShort", label = "Spear Short" },
        { id = "base.spearsteakknife", fullType = "Base.SpearSteakKnife", label = "Spear Steak Knife" },
        { id = "base.spearstone", fullType = "Base.SpearStone", label = "Spear Stone" },
        { id = "base.spearstonelong", fullType = "Base.SpearStoneLong", label = "Spear Stone Long" },
    },
        ["firearm"] = {
        { id = "base.assaultrifle", fullType = "Base.AssaultRifle", label = "Assault Rifle" },
        { id = "base.assaultrifle2", fullType = "Base.AssaultRifle2", label = "Assault Rifle2" },
        { id = "base.doublebarrelshotgun", fullType = "Base.DoubleBarrelShotgun", label = "Double Barrel Shotgun" },
        { id = "base.doublebarrelshotgunsawnoff", fullType = "Base.DoubleBarrelShotgunSawnoff", label = "Double Barrel Shotgun Sawnoff" },
        { id = "base.huntingrifle", fullType = "Base.HuntingRifle", label = "Hunting Rifle" },
        { id = "base.js14_rifle", fullType = "Base.JS14_Rifle", label = "JS14 Rifle" },
        { id = "base.js3t_shotgun", fullType = "Base.JS3T_Shotgun", label = "JS3 T Shotgun" },
        { id = "base.l92_carbine", fullType = "Base.L92_Carbine", label = "L92 Carbine" },
        { id = "base.l94_rifle", fullType = "Base.L94_Rifle", label = "L94 Rifle" },
        { id = "base.msr7t_rifle", fullType = "Base.MSR7T_Rifle", label = "MSR7 T Rifle" },
        { id = "base.pistol", fullType = "Base.Pistol", label = "Pistol" },
        { id = "base.pistol2", fullType = "Base.Pistol2", label = "Pistol2" },
        { id = "base.pistol3", fullType = "Base.Pistol3", label = "Pistol3" },
        { id = "base.revolver", fullType = "Base.Revolver", label = "Revolver" },
        { id = "base.revolver_capgun", fullType = "Base.Revolver_CapGun", label = "Revolver Cap Gun" },
        { id = "base.revolver_long", fullType = "Base.Revolver_Long", label = "Revolver Long" },
        { id = "base.revolver_short", fullType = "Base.Revolver_Short", label = "Revolver Short" },
        { id = "base.rifle_capgun", fullType = "Base.Rifle_CapGun", label = "Rifle Cap Gun" },
        { id = "base.shotgun", fullType = "Base.Shotgun", label = "Shotgun" },
        { id = "base.shotgunsawnoff", fullType = "Base.ShotgunSawnoff", label = "Shotgun Sawnoff" },
        { id = "base.trappercarbine", fullType = "Base.TrapperCarbine", label = "Trapper Carbine" },
        { id = "base.varmintrifle", fullType = "Base.VarmintRifle", label = "Varmint Rifle" },
    },
    ["barehands"] = {
        { id = "barehands", fullType = nil, label = "Bare Hands" },
    },
}

local WEAPON_ITEMS = {}
do
    local seen = {}
    local order = { "axe", "longblunt", "shortblunt", "longblade", "shortblade", "spear", "firearm", "barehands" }
    for _, fam in ipairs(order) do
        for _, row in ipairs(WEAPON_ITEMS_BY_FAMILY[fam] or {}) do
            if not seen[row.id] then
                seen[row.id] = true
                WEAPON_ITEMS[#WEAPON_ITEMS + 1] = row
            end
        end
    end
end

local FOOD_ITEMS = {
    { id = "base.egg",                  label = "Egg" },
    { id = "base.apple",                label = "Apple" },
    { id = "base.banana",               label = "Banana" },
    { id = "base.orange",               label = "Orange" },
    { id = "base.chips",                label = "Chips" },
    { id = "base.crisps",               label = "Crisps" },
    { id = "base.crisps2",              label = "Crisps 2" },
    { id = "base.cannedbeans",          label = "Canned Beans" },
    { id = "base.cannedchili",          label = "Canned Chili" },
    { id = "base.cannedcorn",           label = "Canned Corn" },
    { id = "base.cannedtuna",           label = "Canned Tuna" },
    { id = "base.tinnedsoup",           label = "Tinned Soup" },
    { id = "base.tinnedbeans",          label = "Tinned Beans" },
    { id = "base.panfriedvegetables2",  label = "Pan Fried Vegetables" },
    { id = "base.bacon",                label = "Bacon" },
    { id = "base.steak",                label = "Steak" },
    { id = "base.chicken",              label = "Chicken" },
    { id = "base.bread",                label = "Bread" },
    { id = "base.butter",               label = "Butter" },
    { id = "base.cheese",               label = "Cheese" },
    { id = "base.beefjerky",            label = "Beef Jerky" },
    { id = "base.salami",               label = "Salami" },
    { id = "base.icecream",             label = "Ice Cream" },
    { id = "base.icecreamsandwich",     label = "Ice Cream Sandwich" },
    { id = "base.doughnutjelly",        label = "Doughnut (Jelly)" },
    { id = "base.pieapple",             label = "Apple Pie" },
    { id = "base.chocolate_smirkers",   label = "Chocolate" },
    { id = "base.fudgeepop",            label = "Fudgesicle" },
    { id = "base.hihis",                label = "Hi-His" },
    { id = "base.milk",                 label = "Milk" },
    { id = "base.waterbottle",          label = "Water Bottle" },
    { id = "base.pop",                  label = "Pop" },
    { id = "base.whiskey",              label = "Whiskey" },
}

local FISH_ITEMS = {
    { id = "base.bass",              label = "Bass" },
    { id = "base.smallmouthbass",    label = "Smallmouth Bass" },
    { id = "base.largemouthbass",    label = "Largemouth Bass" },
    { id = "base.catfish",           label = "Catfish" },
    { id = "base.perch",             label = "Perch" },
    { id = "base.yellowperch",       label = "Yellow Perch" },
    { id = "base.pike",              label = "Pike" },
    { id = "base.trout",             label = "Trout" },
    { id = "base.whitecrappie",      label = "White Crappie" },
    { id = "base.blackcrappie",      label = "Black Crappie" },
    { id = "base.redear",            label = "Redear" },
    { id = "base.sunfish",           label = "Sunfish" },
    { id = "base.fishfillet",        label = "Fish Fillet" },
}

-- Curated craft keys matching Track.addMade / AF_check paths
local MADE_CURATED = {
    { id = "recipe.carvesmallhandle",      label = "Recipe: Carve small handle" },
    { id = "recipe.collectseeds",          label = "Recipe: Collect seeds" },
    { id = "recipe.fillsaw",               label = "Recipe: Fill saw" },
    { id = "recipe.fixwithglue",         label = "Recipe: Fix with glue" },
    { id = "recipe.maketinfoilhat",        label = "Recipe: Make tinfoil hat" },
    { id = "recipe.makewoodenshinglemold", label = "Recipe: Wooden shingle mold" },
    { id = "recipe.openeggcarton",         label = "Recipe: Open egg carton" },
    { id = "recipe.placeinbox",            label = "Recipe: Place in box" },
    { id = "recipe.ripdenimclothing",      label = "Recipe: Rip denim clothing" },
    { id = "recipe.sharpenblade",          label = "Recipe: Sharpen blade" },
    { id = "recipe.slicefillet",           label = "Recipe: Slice fillet" },
    { id = "base.barbedwire",              label = "Result: Barbed wire" },
    { id = "base.holstershoulder",         label = "Result: Shoulder holster" },
    { id = "craft.isadditeminrecipe",      label = "Craft step: add item in recipe" },
    { id = "build.isbuildaction",          label = "Build: timed build action" },
}


-- Craft/build skill buckets (made.skill.<id>)
local MADE_SKILLS = {
    { id = "skill.knapping", label = "Knapping" },
    { id = "skill.carving", label = "Carving" },
    { id = "skill.carpentry", label = "Carpentry" },
    { id = "skill.metalworking", label = "Metalworking" },
    { id = "skill.welding", label = "Welding" },
    { id = "skill.blacksmithing", label = "Blacksmithing" },
    { id = "skill.masonry", label = "Masonry" },
    { id = "skill.stonemasonry", label = "Stonemasonry" },
    { id = "skill.pottery", label = "Pottery" },
    { id = "skill.glassmaking", label = "Glassmaking" },
    { id = "skill.cooking", label = "Cooking" },
    { id = "skill.butchering", label = "Butchering" },
    { id = "skill.farming", label = "Farming" },
    { id = "skill.fishing", label = "Fishing" },
    { id = "skill.tailoring", label = "Tailoring" },
    { id = "skill.electrical", label = "Electrical" },
    { id = "skill.medical", label = "Medical" },
    { id = "skill.assembly", label = "Assembly" },
    { id = "skill.packing", label = "Packing" },
    { id = "skill.survival", label = "Survival" },
    { id = "skill.outdoors", label = "Outdoors" },
    { id = "skill.trapping", label = "Trapping" },
    { id = "skill.weaponry", label = "Weaponry" },
    { id = "skill.animal", label = "Animal" },
    { id = "skill.maintenance", label = "Maintenance" },
}

local DISTANCE_MODS = {
    { id = "combat",          label = "Combat stance" },
    { id = "walking",         label = "Walking" },
    { id = "running",         label = "Running" },
    { id = "sprinting",       label = "Sprinting" },
    { id = "sneaking",        label = "Any sneaking" },
    { id = "sneak_walking",   label = "Sneak walking" },
    { id = "sneak_running",   label = "Sneak running" },
    { id = "sneak_sprinting", label = "Sneak sprinting" },
    { id = "sneak_combat",    label = "Sneak combat stance" },
    { id = "vehicle",         label = "By car / vehicle" },
    { id = "day",             label = "During day" },
    { id = "night",           label = "During night" },
}

local READ_BUCKETS = {
    { id = "magazinecomic", label = "Magazine / comic / newspaper" },
    { id = "recipe",        label = "Recipe / schematic" },
    { id = "book",          label = "Book (leisure)" },
    { id = "skillbook",     label = "Skill book" },
}

local function noneFirst(list, noneLabel)
    noneLabel = noneLabel or "(Total)"
    local out = { { id = "none", label = noneLabel } }
    for i = 1, #list do out[#out + 1] = list[i] end
    return out
end

local function displayItemName(fullType, fallback)
    local name = fallback or fullType or "?"
    if not fullType or fullType == "" then return name end
    pcall(function()
        if getItemNameFromFullType then
            local n = getItemNameFromFullType(fullType)
            if n and n ~= "" then name = n end
        end
    end)
    return name
end

local function prettyWeaponItem(row)
    local lab = row.label or row.id
    if row.fullType then
        lab = displayItemName(row.fullType, lab)
    end
    -- Force B42 Firefighter Axe naming for Base.Axe track key
    if row.id == "base.axe" then
        lab = displayItemName("Base.Axe", "Firefighter Axe")
        if lab == "Axe" or lab == "Base.Axe" then
            lab = "Firefighter Axe"
        end
    end
    return { id = row.id, label = lab, fullType = row.fullType }
end

--- Walk made/eaten/etc tree into modifier ids (dot path under layer)
local function collectTrackMods(node, prefix, out, seen)
    if type(node) ~= "table" then return end
    for k, v in pairs(node) do
        if k ~= "total" and k ~= "type" then
            local path = (prefix == "" and tostring(k)) or (prefix .. "." .. tostring(k))
            if type(v) == "number" then
                if not seen[path] then
                    seen[path] = true
                    local lab = path
                    -- nicer labels for known prefixes
                    if path:sub(1, 7) == "recipe." then
                        lab = "Recipe: " .. path:sub(8)
                    elseif path:sub(1, 6) == "craft." then
                        lab = "Craft step: " .. path:sub(7)
                    elseif path:sub(1, 6) == "build." then
                        lab = "Build: " .. path:sub(7)
                    elseif path:sub(1, 5) == "base." then
                        local ft = "Base." .. path:sub(6)
                        -- camel-ish: barbedwire stays; try Base.BarbedWire via script manager is hard
                        lab = "Result: " .. displayItemName(ft, path:sub(6))
                    end
                    out[#out + 1] = { id = path, label = lab .. "  [" .. tostring(v) .. "]" }
                end
            elseif type(v) == "table" then
                collectTrackMods(v, path, out, seen)
            end
        end
    end
end

local function liveMadeModifiers()
    local out = {}
    local seen = {}
    pcall(function()
        local p = getSpecificPlayer and getSpecificPlayer(0) or getPlayer and getPlayer()
        if not p or not AF.Track or not AF.Track.getData then return end
        local d = AF.Track.getData(p)
        if d and type(d.made) == "table" then
            collectTrackMods(d.made, "", out, seen)
        end
    end)
    table.sort(out, function(a, b) return tostring(a.label) < tostring(b.label) end)
    return out, seen
end

function C.getActions()
    return C.ACTIONS
end


-- =====================================================================
-- Skill level achievements (live IsoGameCharacter:getPerkLevel — MP-safe)
-- amount in the Browser = required level (5..10 recommended).
-- modifier:
--   none              → highest level among any trainable base skill
--   cat.<category>    → highest among that category (melee, firearms, crafting, …)
--   perk.<PerksField> → that skill only (e.g. perk.Woodwork, perk.SmallBlunt)
-- Categories are broad (one Melee bucket — not separate blunt/blade categories).
-- =====================================================================

-- Category headers map to fixed Perks.* field names (B42). Parent scan also used.
local SKILL_LEVEL_CATS = {
    {
        id = "cat.melee",
        label = "Melee (any weapon skill)",
        perks = { "Axe", "Blunt", "SmallBlunt", "LongBlade", "SmallBlade", "Spear" },
        -- also match parents named like these
        parents = { "Combat", "CombatMelee" },
    },
    {
        id = "cat.firearms",
        label = "Firearms / shooting",
        perks = { "Aiming", "Reloading" },
        parents = { "Firearm", "CombatFirearms", "Accuracy" },
    },
    {
        id = "cat.crafting",
        label = "Crafting",
        perks = {
            "Woodwork", "Electricity", "MetalWelding", "Mechanics", "Tailoring",
            "Cooking", "Pottery", "Masonry", "Glassmaking", "Carving", "Blacksmith",
            "FlintKnapping", "Maintenance",
        },
        parents = { "Crafting" },
    },
    {
        id = "cat.agility",
        label = "Agility",
        perks = { "Sprinting", "Lightfoot", "Lightfooted", "Nimble", "Sneak", "Sneaking" },
        parents = { "Agility" },
    },
    {
        id = "cat.survival",
        label = "Survival / outdoors",
        perks = { "Fishing", "Trapping", "PlantScavenging", "Tracking", "Foraging" },
        parents = { "Survivalist" },
    },
    {
        id = "cat.farming",
        label = "Farming / animals",
        perks = { "Farming", "Husbandry", "Butchering" },
        parents = { "FarmingCategory" },
    },
    {
        id = "cat.medical",
        label = "First Aid / medical",
        perks = { "Doctor" },
        parents = {},
    },
    {
        id = "cat.physical",
        label = "Physical (Fitness / Strength)",
        perks = { "Fitness", "Strength" },
        parents = { "Passiv", "Passive", "PhysicalCategory" },
    },
}

local SKILL_LEVEL_SKIP = {
    MAX = true, None = true, Passiv = true, Passive = true,
    Combat = true, CombatMelee = true, CombatFirearms = true,
    Agility = true, Crafting = true, Firearm = true,
    Survivalist = true, FarmingCategory = true, PhysicalCategory = true,
    Accuracy = true, Guard = true,
}

local function skillDisplayName(id)
    if AF.Rewards and AF.Rewards.perkDisplayName then
        return AF.Rewards.perkDisplayName(id)
    end
    return id
end

local function resolvePerkObj(name)
    if AF.Rewards and AF.Rewards.resolvePerk then
        local p = AF.Rewards.resolvePerk(name)
        if p ~= nil then return p end
    end
    name = tostring(name or "")
    if name == "" or not Perks then return nil end
    if Perks[name] ~= nil then return Perks[name] end
    local ok, p = pcall(function()
        if Perks.FromString then return Perks.FromString(name) end
    end)
    if ok and p ~= nil then return p end
    return nil
end

local function getPerkLevelSafe(player, perkObj)
    if not player or perkObj == nil then return 0 end
    local lv = 0
    pcall(function()
        if player.getPerkLevel then
            lv = tonumber(player:getPerkLevel(perkObj)) or 0
        end
    end)
    return lv
end

local function parentNameOf(perkObj)
    local n = ""
    pcall(function()
        if not perkObj or not perkObj.getParent then return end
        local par = perkObj:getParent()
        if par == nil then return end
        if par.getName then n = tostring(par:getName() or "") end
        if n == "" then n = tostring(par) end
    end)
    return n
end

local function perkTypeName(perkObj)
    local n = ""
    pcall(function()
        if perkObj and perkObj.getType then n = tostring(perkObj:getType() or "") end
    end)
    if n == "" then
        pcall(function()
            if perkObj and perkObj.getName then n = tostring(perkObj:getName() or "") end
        end)
    end
    return n
end

--- Max level among a list of Perks field names.
local function maxLevelAmongNames(player, names)
    local best = 0
    if type(names) ~= "table" then return 0 end
    for i = 1, #names do
        local obj = resolvePerkObj(names[i])
        if obj ~= nil then
            local lv = getPerkLevelSafe(player, obj)
            if lv > best then best = lv end
        end
    end
    return best
end

--- Walk all leaf perks; optional filter(fn(perkObj, typeName, parentName) -> bool)
local function maxLevelFiltered(player, filterFn)
    local best = 0
    pcall(function()
        if not Perks or not Perks.getMaxIndex or not Perks.fromIndex then return end
        if not PerkFactory or not PerkFactory.getPerk then return end
        local maxi = Perks.getMaxIndex() or 0
        for i = 0, maxi - 1 do
            local pEnum = Perks.fromIndex(i)
            if pEnum ~= nil then
                local perk = PerkFactory.getPerk(pEnum)
                if perk then
                    local tname = perkTypeName(perk)
                    local pname = parentNameOf(perk)
                    -- skip category roots (parent is None)
                    local skip = false
                    pcall(function()
                        if perk.getParent and perk:getParent() == Perks.None then skip = true end
                    end)
                    if tname ~= "" and SKILL_LEVEL_SKIP[tname] then skip = true end
                    if not skip then
                        local ok = true
                        if filterFn then ok = filterFn(perk, tname, pname) and true or false end
                        if ok then
                            local lv = getPerkLevelSafe(player, pEnum)
                            -- also try perk object if enum differs
                            if lv == 0 then lv = getPerkLevelSafe(player, perk) end
                            if lv > best then best = lv end
                        end
                    end
                end
            end
        end
    end)
    return best
end

local function catDefById(modId)
    for i = 1, #SKILL_LEVEL_CATS do
        if SKILL_LEVEL_CATS[i].id == modId then return SKILL_LEVEL_CATS[i] end
    end
    return nil
end

--- Live skill-level progress for achievements (client UI + server claim).
function C.readSkillLevelProgress(player, modifierId)
    if not player then return 0 end
    modifierId = modifierId or "none"

    if modifierId == "none" then
        -- Any trainable skill
        local best = maxLevelFiltered(player, nil)
        -- also explicit common list in case factory walk fails
        local fixed = maxLevelAmongNames(player, {
            "Fitness", "Strength", "Sprinting", "Lightfoot", "Nimble", "Sneak",
            "Axe", "Blunt", "SmallBlunt", "LongBlade", "SmallBlade", "Spear",
            "Maintenance", "Aiming", "Reloading", "Farming", "Fishing", "Trapping",
            "PlantScavenging", "Cooking", "Tailoring", "Woodwork", "Electricity",
            "MetalWelding", "Mechanics", "Doctor", "Blacksmith", "Pottery", "Masonry",
            "Glassmaking", "Carving", "Butchering", "Husbandry", "Tracking", "FlintKnapping",
        })
        if fixed > best then best = fixed end
        return best
    end

    if modifierId:sub(1, 4) == "cat." then
        local cat = catDefById(modifierId)
        if not cat then return 0 end
        local best = maxLevelAmongNames(player, cat.perks)
        -- parent-based extras (modded skills under same parent)
        local parents = {}
        local parentCount = 0
        for i = 1, #(cat.parents or {}) do
            local pk = string.lower(tostring(cat.parents[i] or ""))
            if pk ~= "" then
                parents[pk] = true
                parentCount = parentCount + 1
            end
        end
        local named = {}
        for i = 1, #(cat.perks or {}) do
            named[string.lower(tostring(cat.perks[i] or ""))] = true
        end
        -- Do NOT use Lua next() — missing/unsafe under Kahlua (Break on Error).
        if parentCount > 0 then
            local extra = maxLevelFiltered(player, function(perk, tname, pname)
                if named[string.lower(tostring(tname or ""))] then return true end
                local pl = string.lower(tostring(pname or ""))
                if parents[pl] then return true end
                -- parent may tostring as Perks.Crafting etc.
                for pk, _ in pairs(parents) do
                    if pl:find(pk, 1, true) then return true end
                end
                return false
            end)
            if extra > best then best = extra end
        end
        return best
    end

    if modifierId:sub(1, 5) == "perk." then
        local name = modifierId:sub(6)
        return maxLevelAmongNames(player, { name })
    end

    return 0
end

local function listSpecificPerks()
    local list = {}
    if AF.Rewards and AF.Rewards.getSkills then
        local skills = AF.Rewards.getSkills() or {}
        for i = 1, #skills do
            local s = skills[i]
            if s and s.id and not SKILL_LEVEL_SKIP[s.id] then
                list[#list + 1] = {
                    id = "perk." .. s.id,
                    label = skillDisplayName(s.id),
                }
            end
        end
    end
    if #list == 0 then
        local fixed = {
            "Fitness", "Strength", "Sprinting", "Lightfoot", "Nimble", "Sneak",
            "Axe", "Blunt", "SmallBlunt", "LongBlade", "SmallBlade", "Spear",
            "Maintenance", "Aiming", "Reloading", "Farming", "Fishing", "Trapping",
            "PlantScavenging", "Cooking", "Tailoring", "Woodwork", "Electricity",
            "MetalWelding", "Mechanics", "Doctor", "Blacksmith", "Pottery", "Masonry",
            "Glassmaking", "Carving", "Butchering", "Husbandry", "Tracking", "FlintKnapping",
        }
        for i = 1, #fixed do
            list[#list + 1] = { id = "perk." .. fixed[i], label = skillDisplayName(fixed[i]) }
        end
    end
    table.sort(list, function(a, b) return tostring(a.label) < tostring(b.label) end)
    return list
end


local REPAIR_KINDS = {
    { id = "kind.item", label = "Item repair (glue/tape/fix)" },
    { id = "kind.vehicle", label = "Vehicle repair" },
    { id = "kind.furniture", label = "Furniture / moveable repair" },
    { id = "kind.craft", label = "Repair recipe (craft menu)" },
}

function C.getModifiersForAction(actionId)
    if actionId == "kill" or actionId == "damage" then
        local out = noneFirst({})
        out[#out + 1] = { id = "_hdr_time", label = "— Time of day —", header = true }
        out[#out + 1] = { id = "day", label = "During day" }
        out[#out + 1] = { id = "night", label = "During night" }
        out[#out + 1] = { id = "_hdr_family", label = "— Weapon family —", header = true }
        for _, r in ipairs(WEAPON_TYPES) do out[#out + 1] = r end
        -- Specific weapons by wiki/B42 sub-category (script Categories)
        local famOrder = {
            { key = "axe",        title = "— Axes —" },
            { key = "longblunt",  title = "— Long blunt —" },
            { key = "shortblunt", title = "— Short blunt —" },
            { key = "longblade",  title = "— Long blade —" },
            { key = "shortblade", title = "— Short blade —" },
            { key = "spear",      title = "— Spears —" },
            { key = "firearm",    title = "— Firearms —" },
            { key = "barehands",  title = "— Bare hands —" },
        }
        for _, fam in ipairs(famOrder) do
            local rows = WEAPON_ITEMS_BY_FAMILY and WEAPON_ITEMS_BY_FAMILY[fam.key] or {}
            if rows and #rows > 0 then
                out[#out + 1] = { id = "_hdr_w_" .. fam.key, label = fam.title, header = true }
                for _, r in ipairs(rows) do
                    out[#out + 1] = prettyWeaponItem(r)
                end
            end
        end
        return out
    end
    if actionId == "eat" then
        local out = noneFirst({})
        out[#out + 1] = { id = "_hdr_food", label = "— Food / drink —", header = true }
        for _, r in ipairs(FOOD_ITEMS) do out[#out + 1] = r end
        return out
    end
    if actionId == "fish" then
        local out = noneFirst({})
        out[#out + 1] = { id = "_hdr_fish", label = "— Fish —", header = true }
        for _, r in ipairs(FISH_ITEMS) do out[#out + 1] = r end
        return out
    end
    if actionId == "read" then
        return noneFirst(READ_BUCKETS)
    end
    if actionId == "distance" then
        return noneFirst(DISTANCE_MODS, "(All Non-Vehicle)")
    end
    if actionId == "made" then
        local out = noneFirst({})
        out[#out + 1] = { id = "_hdr_made_skill", label = "— By skill / category —", header = true }
        for _, r in ipairs(MADE_SKILLS) do out[#out + 1] = r end
        out[#out + 1] = { id = "_hdr_made_curated", label = "— Common crafts —", header = true }
        local seen = {}
        for _, r in ipairs(MADE_CURATED) do
            out[#out + 1] = r
            seen[r.id] = true
        end
        -- live keys from this character's made counters
        local live, liveSeen = liveMadeModifiers()
        local anyLive = false
        for i = 1, #live do
            if not seen[live[i].id] then
                if not anyLive then
                    out[#out + 1] = { id = "_hdr_made_live", label = "— Seen on this character —", header = true }
                    anyLive = true
                end
                out[#out + 1] = live[i]
                seen[live[i].id] = true
            end
        end
        return out
    end
    if actionId == "repair" then
        local out = noneFirst({})
        out[#out + 1] = { id = "_hdr_repair_kind", label = "— Repair type —", header = true }
        for _, r in ipairs(REPAIR_KINDS) do out[#out + 1] = r end
        -- live repaired keys
        local live = {}
        local seen = {}
        pcall(function()
            local p = getSpecificPlayer and getSpecificPlayer(0) or getPlayer and getPlayer()
            if not p or not AF.Track or not AF.Track.getData then return end
            local d = AF.Track.getData(p)
            if d and type(d.repaired) == "table" then
                collectTrackMods(d.repaired, "", live, seen)
            end
        end)
        table.sort(live, function(a, b) return tostring(a.label) < tostring(b.label) end)
        if #live > 0 then
            out[#out + 1] = { id = "_hdr_repair_live", label = "— Seen on this character —", header = true }
            for i = 1, #live do
                -- skip nested kind.* already listed as headers
                if not tostring(live[i].id):match("^kind%.") then
                    out[#out + 1] = live[i]
                end
            end
        end
        return out
    end
    if actionId == "skill_level" then
        local out = noneFirst({}, "(Any skill)")
        out[#out + 1] = { id = "_hdr_skill_cat", label = "— By category —", header = true }
        for i = 1, #SKILL_LEVEL_CATS do
            local cat = SKILL_LEVEL_CATS[i]
            out[#out + 1] = { id = cat.id, label = cat.label }
        end
        out[#out + 1] = { id = "_hdr_skill_perk", label = "— Specific skill —", header = true }
        local specs = listSpecificPerks()
        for i = 1, #specs do
            out[#out + 1] = specs[i]
        end
        return out
    end
    if actionId == "daysSurvived" then
        return noneFirst({})
    end
    return noneFirst({})
end

function C.isModifierHeader(modId)
    return type(modId) == "string" and modId:sub(1, 5) == "_hdr_"
end

function C.mapToTrack(actionId, modifierId)
    modifierId = modifierId or "none"
    if C.isModifierHeader(modifierId) then return nil end

    local act
    for _, a in ipairs(C.ACTIONS) do
        if a.id == actionId then act = a; break end
    end
    if not act then return nil end

    -- Live perk levels (no AF_Track). Valid on client + server for MP claims.
    if actionId == "skill_level" or act.kind == "skill_level" then
        if modifierId == "none" then
            return { kind = "skill_level", modifier = "none", label = "skill_level.any" }
        end
        if modifierId:sub(1, 4) == "cat." and catDefById(modifierId) then
            return { kind = "skill_level", modifier = modifierId, label = "skill_level." .. modifierId }
        end
        if modifierId:sub(1, 5) == "perk." and #modifierId > 5 then
            return { kind = "skill_level", modifier = modifierId, label = "skill_level." .. modifierId }
        end
        return nil
    end

    if act.scalar then
        if modifierId ~= "none" then return nil end
        return { kind = "scalar", key = act.scalar }
    end

    local layer = act.layer
    if not layer then return nil end

    if modifierId == "none" then
        return { kind = "layer", layer = layer, path = {}, label = layer .. ".total" }
    end

    if modifierId == "barehands" then
        return { kind = "layer", layer = layer, path = { "BareHands" }, label = layer .. ".BareHands" }
    end

    -- type.axe -> path type, axe
    if modifierId:sub(1, 5) == "type." then
        local fam = modifierId:sub(6)
        return { kind = "layer", layer = layer, path = { "type", fam }, label = layer .. ".type." .. fam }
    end

    -- base.egg / recipe.foo / craft.x / build.y
    if modifierId:find(".", 1, true) then
        local parts = {}
        for p in string.gmatch(modifierId, "[^%.]+") do parts[#parts + 1] = p end
        if #parts >= 2 then
            return { kind = "layer", layer = layer, path = parts, label = layer .. "." .. table.concat(parts, ".") }
        end
    end

    -- skill.knapping -> made.skill.knapping
    if modifierId:sub(1, 6) == "skill." then
        local sk = modifierId:sub(7)
        return { kind = "layer", layer = layer, path = { "skill", sk }, label = layer .. ".skill." .. sk }
    end
    if layer == "read" then
        return { kind = "layer", layer = "read", path = { modifierId }, label = "read." .. modifierId }
    end
    if layer == "distance" then
        return { kind = "layer", layer = "distance", path = { modifierId }, label = "distance." .. modifierId }
    end
    -- flat keys on kill/damage/etc (day, night, …)
    if modifierId == "day" or modifierId == "night" then
        return { kind = "layer", layer = layer, path = { modifierId }, label = layer .. "." .. modifierId }
    end

    return nil
end

function C.signature(actionId, modifierId, amount)
    return tostring(actionId) .. "|" .. tostring(modifierId or "none") .. "|" .. tostring(amount)
end

function C.parseSignature(sig)
    if type(sig) ~= "string" then return nil end
    local a, m, n = sig:match("^([^|]+)|([^|]+)|([^|]+)$")
    if not a then return nil end
    return a, m, tonumber(n)
end

function C.goalLabel(actionId, modifierId, amount)
    local actLabel = actionId
    for _, a in ipairs(C.ACTIONS) do
        if a.id == actionId then actLabel = a.label; break end
    end
    amount = tonumber(amount) or 0
    modifierId = modifierId or "none"

    local withPart
    if modifierId == "none" then
        if actionId == "kill" or actionId == "damage" then
            withPart = "with any weapon"
        elseif actionId == "eat" then
            withPart = "any food/drink"
        elseif actionId == "fish" then
            withPart = "any catch"
        elseif actionId == "made" then
            withPart = "any craft/build"
        elseif actionId == "repair" then
            withPart = "any repair"
        elseif actionId == "read" then
            withPart = "any reading"
        elseif actionId == "distance" then
            withPart = "all non-vehicle"
        elseif actionId == "daysSurvived" then
            withPart = nil
        elseif actionId == "skill_level" then
            withPart = "in any skill"
        else
            withPart = "any"
        end
    else
        local modLabel = modifierId
        for _, m in ipairs(C.getModifiersForAction(actionId) or {}) do
            if m.id == modifierId and not m.header then
                modLabel = m.label
                break
            end
        end
        modLabel = tostring(modLabel):gsub("%s+%[.-%]$", "")
        if actionId == "kill" or actionId == "damage" then
            if modifierId == "day" or modifierId == "night" then
                withPart = tostring(modLabel):lower()
            elseif modifierId:sub(1, 5) == "type." then
                withPart = "with any " .. modLabel
            else
                withPart = "with " .. modLabel
            end
        elseif actionId == "eat" then
            withPart = "only " .. modLabel
        elseif actionId == "fish" then
            withPart = "only " .. modLabel
        elseif actionId == "read" then
            withPart = "only " .. modLabel
        elseif actionId == "distance" then
            withPart = modLabel
        elseif actionId == "made" then
            if modifierId:sub(1, 6) == "skill." then
                withPart = "using " .. modLabel
            else
                withPart = "only " .. modLabel
            end
        elseif actionId == "repair" then
            if modifierId:sub(1, 5) == "kind." then
                withPart = modLabel
            else
                withPart = "only " .. modLabel
            end
        elseif actionId == "skill_level" then
            if modifierId:sub(1, 4) == "cat." then
                withPart = "in " .. modLabel
            elseif modifierId:sub(1, 5) == "perk." then
                withPart = "in " .. modLabel
            else
                withPart = modLabel
            end
        else
            withPart = modLabel
        end
    end

    if actionId == "skill_level" then
        return string.format("%s, reach level %s %s", actLabel, tostring(amount), withPart or "")
    end
    if actionId == "daysSurvived" then
        return string.format("%s, %s day(s)", actLabel, tostring(amount))
    end
    if withPart then
        return string.format("%s, %s, %s", actLabel, tostring(amount), withPart)
    end
    return string.format("%s, %s", actLabel, tostring(amount))
end

function C.rewardLabel(rewardType, reward, rewardAmount)
    rewardType = tostring(rewardType or "item")
    reward = tostring(reward or "")
    rewardAmount = tonumber(rewardAmount) or 1
    if reward == "" then return "no reward" end
    if rewardType == "trait" then
        return "trait " .. reward
    end
    if rewardType == "skill_xp" then
        local skillName = reward
        if AF.Rewards and AF.Rewards.perkDisplayName then
            skillName = AF.Rewards.perkDisplayName(reward)
        end
        return tostring(rewardAmount) .. " " .. skillName .. " XP"
    end
    local itemName = displayItemName(reward, reward)
    if rewardAmount ~= 1 then
        return "x" .. tostring(rewardAmount) .. " " .. itemName
    end
    return itemName
end

function C.rowLabel(def)
    if type(def) ~= "table" then return tostring(def) end
    local name = tostring(def.name or "?")
    local goal = C.goalLabel(def.action, def.modifier, def.amount)
    local rew = C.rewardLabel(def.rewardType, def.reward, def.rewardAmount)
    return name .. " | " .. goal .. " | " .. rew
end

function C.readProgress(player, actionId, modifierId)
    if not player then return 0 end
    local map = C.mapToTrack(actionId, modifierId)
    if not map then return 0 end
    -- Skill levels: engine perk API only (works on dedicated server for MP claims)
    if map.kind == "skill_level" or actionId == "skill_level" then
        return C.readSkillLevelProgress(player, map.modifier or modifierId) or 0
    end
    if not AF.Track or not AF.Track.getData then return 0 end
    local d = AF.Track.getData(player)
    if not d then return 0 end
    if map.kind == "scalar" then
        return tonumber(d[map.key]) or 0
    end
    local node = d[map.layer]
    if type(node) ~= "table" then return 0 end
    if not map.path or #map.path == 0 then
        return tonumber(node.total) or 0
    end
    for i = 1, #map.path do
        local k = map.path[i]
        if type(node) ~= "table" then return 0 end
        node = node[k]
    end
    if type(node) == "number" then return node end
    if type(node) == "table" and type(node.total) == "number" then return node.total end
    if type(node) == "table" and type(node._n) == "number" then return node._n end
    return tonumber(node) or 0
end

print("[AF] AF_Catalog loaded")
