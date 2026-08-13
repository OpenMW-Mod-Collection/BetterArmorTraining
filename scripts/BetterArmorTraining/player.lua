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
local animGroupType = {
    walking      = { stopKey = "loop stop", pointsKey = "walking" },
    running      = { stopKey = "loop stop", pointsKey = "running" },
    jumping      = { stopKey = "start", pointsKey = "jumping" },
    swimmingSlow = { stopKey = "loop stop", pointsKey = "swimmingSlow" },
    swimmingFast = { stopKey = "loop stop", pointsKey = "swimmingFast" },
}
local animGroupsData = {
    walkforward     = animGroupType.walking,
    walkback        = animGroupType.walking,
    walkleft        = animGroupType.walking,
    walkright       = animGroupType.walking,

    runforward      = animGroupType.running,
    runback         = animGroupType.running,
    runleft         = animGroupType.running,
    runright        = animGroupType.running,

    jump            = animGroupType.jumping,

    swimwalkforward = animGroupType.swimmingSlow,
    swimwalkback    = animGroupType.swimmingSlow,
    swimwalkleft    = animGroupType.swimmingSlow,
    swimwalkright   = animGroupType.swimmingSlow,

    swimrunforward  = animGroupType.swimmingFast,
    swimrunback     = animGroupType.swimmingFast,
    swimrunleft     = animGroupType.swimmingFast,
    swimrunright    = animGroupType.swimmingFast,
}
local eqSlot = types.Actor.EQUIPMENT_SLOT
local armorSlotToFractionKeys = {
    [eqSlot.Cuirass]       = "chest",
    [eqSlot.CarriedLeft]   = "shield",
    [eqSlot.Helmet]        = "head",
    [eqSlot.Greaves]       = "legs",
    [eqSlot.Boots]         = "feet",
    [eqSlot.RightPauldron] = "rShoulder",
    [eqSlot.LeftPauldron]  = "lShoulder",
    [eqSlot.RightGauntlet] = "rHand",
    [eqSlot.LeftGauntlet]  = "lHand",
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
local armorClasses = {
    unarmored   = "unarmored",
    lightarmor  = "lightarmor",
    mediumarmor = "mediumarmor",
    heavyarmor  = "heavyarmor",
}
local armorClassToSkillHandler = {
    [armorClasses.unarmored]   = types.Player.stats.skills.unarmored(self),
    [armorClasses.lightarmor]  = types.Player.stats.skills.lightarmor(self),
    [armorClasses.mediumarmor] = types.Player.stats.skills.mediumarmor(self),
    [armorClasses.heavyarmor]  = types.Player.stats.skills.heavyarmor(self),
}
local fLightMaxMod = core.getGMST("fLightMaxMod")
local fMedMaxMod = core.getGMST("fMedMaxMod")
local epsilon = 5e-4
local selfEffects = types.Actor.activeEffects(self)

local trainingPoints = 0

local function getArmorWeightClass(record)
    local referenceWeight = armorTypeGMSTs[record.type]

    if record.weight == 0 then
        return armorClasses.unarmored
    elseif record.weight <= referenceWeight * fLightMaxMod + epsilon then
        return armorClasses.lightarmor
    elseif record.weight <= referenceWeight * fMedMaxMod + epsilon then
        return armorClasses.mediumarmor
    else
        return armorClasses.heavyarmor
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
        [armorClasses.unarmored]   = 0,
        [armorClasses.lightarmor]  = 0,
        [armorClasses.mediumarmor] = 0,
        [armorClasses.heavyarmor]  = 0,
    }
    local equipment = types.Actor.getEquipment(self) or {}

    local fractionSum = 0
    for _, fraction in pairs(settings.xpDivision) do
        fractionSum = fractionSum + fraction
    end

    for slotName, fractionKey in pairs(armorSlotToFractionKeys) do
        local item = equipment[slotName]
        if item then
            local weightClass = types.Clothing.objectIsInstance(item)
                and armorClasses.unarmored
                or getArmorWeightClass(item.type.records[item.recordId])
            local fraction = settings.xpDivision[fractionKey] / fractionSum
            local xpForSlot = settings.xpPayout * fraction
            xpByArmorClass[weightClass] = xpByArmorClass[weightClass] + xpForSlot
        end
    end

    for armorClass, rawXp in pairs(xpByArmorClass) do
        local skill = armorClassToSkillHandler[armorClass]
        local globalMult = settings.armorTypeXpMult[armorClass]
        local finalXp = applyCaps(rawXp, skill) * globalMult

        if finalXp > 0 then
            local skillId = armorClasses[armorClass]
            I.SkillProgression.skillUsed(skillId, { skillGain = finalXp / 10 }) -- TODO why /10 ???

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

    local tpBonus = settings.trainingPointsFor[animGroupsData[groupname].pointsKey]
    trainingPoints = trainingPoints + tpBonus

    if trainingPoints > settings.trainingPointsPerXpPayout then
        trainingPoints = trainingPoints - settings.trainingPointsPerXpPayout
        grantXP()
    end

    if settings.log.movement then
        print(("[BetterArmorTraining] +%d training points -> %d"):format(
            tpBonus, trainingPoints
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
        trainingPoints = trainingPoints,
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
