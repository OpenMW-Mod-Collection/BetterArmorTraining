---@diagnostic disable: missing-fields
---@omw-context menu
local I = require("openmw.interfaces")
local core = require("openmw.core")

local l10n = core.l10n("BetterArmorTraining")

I.Settings.registerPage {
    key = "BetterArmorTraining",
    l10n = "BetterArmorTraining",
    name = "page_name",
    description = "page_description",
}

I.Settings.registerGroup {
    key = "SettingssBetterArmorTraining",
    page = "BetterArmorTraining",
    l10n = "BetterArmorTraining",
    name = "settings_groupName",
    description = "settings_groupDesc",
    permanentStorage = true,
    order = 1,
    settings = {
        {
            key = 'trainingPointsFor',
            name = 'trainingPointsFor_name',
            description = 'trainingPointsFor_desc',
            renderer = 'multinumber',
            default = {
                walking      = 4,
                running      = 5,
                jumping      = 15,
                swimmingSlow = 6,
                swimmingFast = 8,
            },
            argument = {
                integer = true,
                keys = {
                    "walking",
                    "running",
                    "jumping",
                    "swimmingSlow",
                    "swimmingFast",
                },
                aliases = {
                    walking      = l10n("trainingPointsFor_walking"),
                    running      = l10n("trainingPointsFor_running"),
                    jumping      = l10n("trainingPointsFor_jumping"),
                    swimmingSlow = l10n("trainingPointsFor_swimmingSlow"),
                    swimmingFast = l10n("trainingPointsFor_swimmingFast"),
                },
            },
        },
        {
            key = 'trainingPointsPerXpPayout',
            name = 'trainingPointsPerXpPayout_name',
            description = 'trainingPointsPerXpPayout_desc',
            renderer = 'number',
            integer = true,
            default = 500,
            min = 0,
        },
        {
            key = 'xpPayout',
            name = 'xpPayout_name',
            description = 'xpPayout_desc',
            renderer = 'number',
            integer = false,
            default = 15,
            min = 0,
        },
        {
            key = 'xpDivision',
            name = 'xpDivision_name',
            description = 'xpDivision_desc',
            renderer = 'multinumber',
            default = {
                chest     = 30,
                shield    = 0,
                head      = 10,
                legs      = 10,
                feet      = 10,
                rShoulder = 10,
                lShoulder = 10,
                rHand     = 5,
                lHand     = 5,
            },
            argument = {
                integer = false,
                keys = {
                    "chest",
                    "shield",
                    "head",
                    "legs",
                    "feet",
                    "rShoulder",
                    "lShoulder",
                    "rHand",
                    "lHand",
                },
                aliases = {
                    chest     = l10n("xpDivision_chest"),
                    shield    = l10n("xpDivision_shield"),
                    head      = l10n("xpDivision_head"),
                    legs      = l10n("xpDivision_legs"),
                    feet      = l10n("xpDivision_feet"),
                    rShoulder = l10n("xpDivision_rShoulder"),
                    lShoulder = l10n("xpDivision_lShoulder"),
                    rHand     = l10n("xpDivision_rHand"),
                    lHand     = l10n("xpDivision_lHand"),
                },
            },
        },
        {
            key = 'armorTypeXpMult',
            name = 'armorTypeXpMult_name',
            description = 'armorTypeXpMult_desc',
            renderer = 'multinumber',
            default = {
                heavy     = 1,
                medium    = .75,
                light     = .5,
                unarmored = 0,
            },
            argument = {
                integer = false,
                keys = {
                    "heavy",
                    "medium",
                    "light",
                    "unarmored",
                },
                aliases = {
                    heavy     = l10n("armorTypeXpMult_heavy"),
                    medium    = l10n("armorTypeXpMult_medium"),
                    light     = l10n("armorTypeXpMult_light"),
                    unarmored = l10n("armorTypeXpMult_unarmored"),
                },
            },
        },
        {
            key = 'softCap',
            name = 'softCap_name',
            description = 'softCap_desc',
            renderer = 'multinumber',
            default = {
                capLvl       = 40,
                falloff      = 5,
                maxReduction = 75,
            },
            argument = {
                integer = false,
                keys = {
                    "capLvl",
                    "falloff",
                    "maxReduction",
                },
                aliases = {
                    capLvl     = l10n("softCap_capLvl"),
                    falloff = l10n("softCap_falloff"),
                    maxReduction = l10n("softCap_maxReduction"),
                },
            },
        },
        {
            key = 'hardCap',
            name = 'hardCap_name',
            description = 'hardCap_desc',
            renderer = 'number',
            integer = true,
            default = 75,
            min = 0,
        },
        {
            key = 'log',
            name = 'log_name',
            renderer = 'multiselect',
            default = {
                movement = false,
                xpGain   = false,
            },
            argument = {
                keys = {
                    "movement",
                    "xpGain",
                },
                aliases = {
                    movement = l10n("log_movement"),
                    xpGain   = l10n("log_xpGain"),
                },
                buttonWidth = 120,
            },
        },
    }
}
