---@diagnostic disable: missing-parameter, param-type-mismatch
---@omw-context player
local storage = require('openmw.storage')
local self = require("openmw.self")
local I = require("openmw.interfaces")
local async = require("openmw.async")
local types = require("openmw.types")
local core = require("openmw.core")

local settingsCache = require("scripts.BetterArmorTraining.utils.settingsCache")

local settings = settingsCache.new(storage.playerSection("SettingssBetterArmorTraining"), async)
local animGroupsData = {
    -- walking
    walkforward     = { stopKey = "loop stop", points = settings.trainingPointsFor.walking },
    walkback        = { stopKey = "loop stop", points = settings.trainingPointsFor.walking },
    walkleft        = { stopKey = "loop stop", points = settings.trainingPointsFor.walking },
    walkright       = { stopKey = "loop stop", points = settings.trainingPointsFor.walking },
    -- running
    runforward      = { stopKey = "loop stop", points = settings.trainingPointsFor.running },
    runback         = { stopKey = "loop stop", points = settings.trainingPointsFor.running },
    runleft         = { stopKey = "loop stop", points = settings.trainingPointsFor.running },
    runright        = { stopKey = "loop stop", points = settings.trainingPointsFor.running },
    -- jumping
    jump            = { stopKey = "stop", points = settings.trainingPointsFor.jumping },
    -- swimming slow
    swimwalkforward = { stopKey = "loop stop", points = settings.trainingPointsFor.swimmingSlow },
    swimwalkback    = { stopKey = "loop stop", points = settings.trainingPointsFor.swimmingSlow },
    swimwalkleft    = { stopKey = "loop stop", points = settings.trainingPointsFor.swimmingSlow },
    swimwalkright   = { stopKey = "loop stop", points = settings.trainingPointsFor.swimmingSlow },
    -- swimming fast
    swimrunforward  = { stopKey = "loop stop", points = settings.trainingPointsFor.swimmingFast },
    swimrunback     = { stopKey = "loop stop", points = settings.trainingPointsFor.swimmingFast },
    swimrunleft     = { stopKey = "loop stop", points = settings.trainingPointsFor.swimmingFast },
    swimrunright    = { stopKey = "loop stop", points = settings.trainingPointsFor.swimmingFast },
}
local eqSlot = types.Actor.EQUIPMENT_SLOT
local fractionSum = 0
for _, fraction in pairs(settings.xpDivision) do
    fractionSum = fractionSum + fraction
end
local armorSlotToFraction = {
    [eqSlot.Cuirass]       = settings.xpDivision.chest / fractionSum,
    [eqSlot.CarriedLeft]   = settings.xpDivision.shield / fractionSum,
    [eqSlot.Helmet]        = settings.xpDivision.head / fractionSum,
    [eqSlot.Greaves]       = settings.xpDivision.legs / fractionSum,
    [eqSlot.Boots]         = settings.xpDivision.feet / fractionSum,
    [eqSlot.RightPauldron] = settings.xpDivision.rShoulder / fractionSum,
    [eqSlot.LeftPauldron]  = settings.xpDivision.lShoulder / fractionSum,
    [eqSlot.RightGauntlet] = settings.xpDivision.rHand / fractionSum,
    [eqSlot.LeftGauntlet]  = settings.xpDivision.lHand / fractionSum,
}
local armorType = types.Armor.TYPE
local armorTypeGMSTs = {
    [armorType.Cuirass]   = core.getGMST("iCuirassWeight"),
    [armorType.Shield]    = core.getGMST("iShieldWeight"),
    [armorType.Helmet]    = core.getGMST("iHelmWeight"),
    [armorType.Greaves]   = core.getGMST("iGreavesWeight"),
    [armorType.Boots]     = core.getGMST("iBootsWeight"),
    [armorType.RPauldron] = core.getGMST("iPauldronWeight"),
    [armorType.LPauldron] = core.getGMST("iPauldronWeight"),
    [armorType.RGauntlet] = core.getGMST("iGauntletWeight"),
    [armorType.LGauntlet] = core.getGMST("iGauntletWeight"),
    [armorType.RBracer]   = core.getGMST("iGauntletWeight"),
    [armorType.LBracer]   = core.getGMST("iGauntletWeight"),
}
local armorClassesEnum = {
    unarmored = "unarmored",
    light     = "lightarmor",
    medium    = "mediumarmor",
    heavy     = "heavyarmor",
}
local armorClassToSkillId = {
    [armorClassesEnum.unarmored] = "unarmored",
    [armorClassesEnum.light]     = "lightarmor",
    [armorClassesEnum.medium]    = "mediumarmor",
    [armorClassesEnum.heavy]     = "heavyarmor",
}
local armorClassToSkillHandler = {
    [armorClassesEnum.unarmored] = types.Player.stats.skills.unarmored(self),
    [armorClassesEnum.light]     = types.Player.stats.skills.lightarmor(self),
    [armorClassesEnum.medium]    = types.Player.stats.skills.mediumarmor(self),
    [armorClassesEnum.heavy]     = types.Player.stats.skills.heavyarmor(self),
}
local armorClassXPMults = {
    [armorClassesEnum.unarmored] = settings.armorTypeXpMult.unarmored,
    [armorClassesEnum.light]     = settings.armorTypeXpMult.light,
    [armorClassesEnum.medium]    = settings.armorTypeXpMult.medium,
    [armorClassesEnum.heavy]     = settings.armorTypeXpMult.heavy,
}
local fLightMaxMod = core.getGMST("fLightMaxMod")
local fMedMaxMod = core.getGMST("fMedMaxMod")
local epsilon = 5e-4
local selfEffects = types.Actor.activeEffects(self)

local trainingPoints = 0

local function getArmorWeightClass(record)
    local referenceWeight = armorTypeGMSTs[record.type]

    if record.weight == 0 then
        return armorClassesEnum.unarmored
    elseif record.weight <= referenceWeight * fLightMaxMod + epsilon then
        return armorClassesEnum.light
    elseif record.weight <= referenceWeight * fMedMaxMod + epsilon then
        return armorClassesEnum.medium
    else
        return armorClassesEnum.heavy
    end
end

local function applyCaps(rawXp, skill)
    if rawXp <= 0 then return 0 end

    local skillLevel = skill.base
    if skillLevel >= settings.hardCap then
        return 0
    end

    local softCap = settings.softCap
    if skillLevel <= softCap.capLvl then
        return rawXp
    end

    local excess = skillLevel - softCap.capLvl
    local reduction = math.min((softCap.falloff / 100) * excess, softCap.maxReduction / 100)
    local multiplier = 1 - reduction

    return rawXp * multiplier
end

local function grantXP()
    local xpByArmorClass = {
        [armorClassesEnum.unarmored] = 0,
        [armorClassesEnum.light]     = 0,
        [armorClassesEnum.medium]    = 0,
        [armorClassesEnum.heavy]     = 0,
    }
    local equipment = types.Actor.getEquipment(self) or {}

    for slotName, fraction in pairs(armorSlotToFraction) do
        local item = equipment[slotName]
        if item then
            local weightClass = types.Clothing.objectIsInstance(item)
                and armorClassesEnum.unarmored
                or getArmorWeightClass(item.type.records[item.recordId])
            local xpForSlot = settings.xpPayout * fraction
            xpByArmorClass[weightClass] = xpByArmorClass[weightClass] + xpForSlot
        end
    end

    for armorClass, rawXp in pairs(xpByArmorClass) do
        local skill = armorClassToSkillHandler[armorClass]
        local globalMult = armorClassXPMults[armorClass]
        local finalXp = applyCaps(rawXp, skill) * globalMult

        if finalXp > 0 then
            local skillId = armorClassToSkillId[armorClass]
            I.SkillProgression.skillUsed(skillId, { skillGain = finalXp/10 })

            if settings.log.xpGain then
                print(("[BetterArmorTraining] +%.3f xp -> %s"):format(finalXp, skillId))
            end
        end
    end
end

local function grantTrainingPoints(groupname, key)
    if animGroupsData[groupname].stopKey ~= key then return end

    local isLevitating = selfEffects:getEffect(core.magic.EFFECT_TYPE.Levitate).magnitude > 0
    if isLevitating then return end

    trainingPoints = trainingPoints + animGroupsData[groupname].points

    if trainingPoints > settings.trainingPointsPerXpPayout then
        trainingPoints = trainingPoints - settings.trainingPointsPerXpPayout
        grantXP()
    end

    -- print(storage.playerSection("SettingssBetterArmorTraining"):get("armorTypeXpMult").unarmored)
    -- print(settings.armorTypeXpMult.unarmored)

    if settings.log.movement then
        print(("[BetterArmorTraining] +%d training points -> %d"):format(
            animGroupsData[groupname].points,
            trainingPoints
        ))
    end
end

for group, _ in pairs(animGroupsData) do
    I.AnimationController.addTextKeyHandler(group, grantTrainingPoints)
end

-- I.AnimationController.addTextKeyHandler(
--     "",
--     function(groupname, key)
--         if groupname:find("^idle") or groupname == "soundgen" then return end
--         print(groupname, "|", key)
--     end
-- )

local function onSave()
    return {
        trainingPoints = trainingPoints
    }
end

local function onLoad(data)
    if not data then return end
    trainingPoints = data.trainingPoints or trainingPoints
end

return {
    engineHandlers = {
        onSave = onSave,
        onLoad = onLoad,
    }
}
