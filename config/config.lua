Config = Config or {}

Config.MaxAlliances = 3

Config.AlertGang = 100              -- Percentage for alerting gang members

Config.MaximumPoints = 1500         -- Maximum points a gang can have
Config.PointsAddAmount = 1          -- How many points to add when selling drugs
Config.PointsRemoveAmount = 1       -- How many points to remove when a opposing gang member is selling drugs

Config.PopularDrugMultiplier = 1.05 -- Multiplier for popular drugs
Config.OwnedZoneMultiplier = 1.1    -- Multiplier for selling in your own zone

Config.AdminCommand = "adminzones"  -- Admin command to open the admin menu
Config.ZoneCommand = "zone"         -- Command to open the zone menu

-- Math Example: Config.ReducePointsAmount = 1
-- Note: This is per 10 minutes and will be rounded to the nearest whole number

-- Per minute: Config.Config.ReducePointsAmount / Config.ReducePointsCheck = 0.1
-- Per hour: 60 / Config.ReducePointsCheck * Config.ReducePointsAmount = 6
-- Per day: 60 * 24 / Config.ReducePointsCheck * Config.ReducePointsAmount = 144
-- Per week: 60 * 24 * 7 / Config.ReducePointsCheck * Config.ReducePointsAmount = 1008
-- Per month: 60 * 24 * 30 / Config.ReducePointsCheck * Config.ReducePointsAmount = 4320
Config.ReducePointsEnabled = true
Config.ReducePointsCheck = 10      -- How often in minutes to check for reducing points rounds to nearest whole number
Config.ReducePointsTimer = 1       -- How long in hours before the points start to reduce
Config.ReducePointsAmount = 1      -- Will run every 10 minutes and remove Config.ReducePointsAmount points

Config.PhoneContactName = "Ukendt" -- Name of the contact in the phone when alerting gang members

Config.AllowedGangs = {
    "police",
    "ambulance",
    "taxi"
}

Config.AllowedGroups = { -- Groups for admin menu
    "admin",
    "superadmin"
}

Config.PopularZoneDrugs = { --
    ["BEACH"] = { "burger" },
    ["DTVINE"] = { "water" }
}

Config.Zones = {
    ["AIRP"] = "Los Santos International Airport",
    ["ALAMO"] = "Alamo Sea",
    ["ALTA"] = "Alta",
    ["ARMYB"] = "Fort Zancudo",
    ["BANHAMC"] = "Banham Canyon Dr",
    ["BANNING"] = "Banning",
    ["BEACH"] = "Vespucci Beach",
    ["BHAMCA"] = "Banham Canyon",
    ["BRADP"] = "Braddock Pass",
    ["BRADT"] = "Braddock Tunnel",
    ["BURTON"] = "Burton",
    ["CALAFB"] = "Calafia Bridge",
    ["CANNY"] = "Raton Canyon",
    ["CCREAK"] = "Cassidy Creek",
    ["CHAMH"] = "Chamberlain Hills",
    ["CHIL"] = "Vinewood Hills",
    ["CHU"] = "Chumash",
    ["CMSW"] = "Chiliad Mountain State Wilderness",
    ["CYPRE"] = "Cypress Flats",
    ["DAVIS"] = "Davis",
    ["DELBE"] = "Del Perro Beach",
    ["DELPE"] = "Del Perro",
    ["DELSOL"] = "La Puerta",
    ["DESRT"] = "Grand Senora Desert",
    ["DOWNT"] = "Downtown",
    ["DTVINE"] = "Downtown Vinewood",
    ["EAST_V"] = "East Vinewood",
    ["EBURO"] = "El Burro Heights",
    ["ELGORL"] = "El Gordo Lighthouse",
    ["ELYSIAN"] = "Elysian Island",
    ["GALFISH"] = "Galilee",
    ["GOLF"] = "GWC and Golfing Society",
    ["GRAPES"] = "Grapeseed",
    ["GREATC"] = "Great Chaparral",
    ["HARMO"] = "Harmony",
    ["HAWICK"] = "Hawick",
    ["HORS"] = "Vinewood Racetrack",
    ["HUMLAB"] = "Humane Labs and Research",
    ["JAIL"] = "Bolingbroke Penitentiary",
    ["KOREAT"] = "Little Seoul",
    ["LACT"] = "Land Act Reservoir",
    ["LAGO"] = "Lago Zancudo",
    ["LDAM"] = "Land Act Dam",
    ["LEGSQU"] = "Legion Square",
    ["LMESA"] = "La Mesa",
    ["LOSPUER"] = "La Puerta",
    ["MIRR"] = "Mirror Park",
    ["MORN"] = "Morningwood",
    ["MOVIE"] = "Richards Majestic",
    ["MTCHIL"] = "Mount Chiliad",
    ["MTGORDO"] = "Mount Gordo",
    ["MTJOSE"] = "Mount Josiah",
    ["MURRI"] = "Murrieta Heights",
    ["NCHU"] = "North Chumash",
    ["NOOSE"] = "N.O.O.S.E",
    ["OCEANA"] = "Pacific Ocean",
    ["PALCOV"] = "Paleto Cove",
    ["PALETO"] = "Paleto Bay",
    ["PALFOR"] = "Paleto Forest",
    ["PALHIGH"] = "Palomino Highlands",
    ["PALMPOW"] = "Palmer-Taylor Power Station",
    ["PBLUFF"] = "Pacific Bluffs",
    ["PBOX"] = "Pillbox Hill",
    ["PROCOB"] = "Procopio Beach",
    ["RANCHO"] = "Rancho",
    ["RGLEN"] = "Richman Glen",
    ["RICHM"] = "Richman",
    ["ROCKF"] = "Rockford Hills",
    ["RTRAK"] = "Redwood Lights Track",
    ["SANAND"] = "San Andreas",
    ["SANCHIA"] = "San Chianski Mountain Range",
    ["SANDY"] = "Sandy Shores",
    ["SKID"] = "Mission Row",
    ["SLAB"] = "Stab City",
    ["STAD"] = "Maze Bank Arena",
    ["STRAW"] = "Strawberry",
    ["TATAMO"] = "Tataviam Mountains",
    ["TERMINA"] = "Terminal",
    ["TEXTI"] = "Textile City",
    ["TONGVAH"] = "Tongva Hills",
    ["TONGVAV"] = "Tongva Valley",
    ["VCANA"] = "Vespucci Canals",
    ["VESP"] = "Vespucci",
    ["VINE"] = "Vinewood",
    ["WINDF"] = "Ron Alternates Wind Farm",
    ["WVINE"] = "West Vinewood",
    ["ZANCUDO"] = "Zancudo River",
    ["ZP_ORT"] = "Port of South Los Santos",
    ["ZQ_UAR"] = "Davis Quartz",
}
