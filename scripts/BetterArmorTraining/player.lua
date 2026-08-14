---@diagnostic disable: missing-parameter, param-type-mismatch, need-check-nil
---@omw-context player
local storage = require('openmw.storage')
local self = require("openmw.self")
local I = require("openmw.interfaces")
local async = require("openmw.async")
local types = require("openmw.types")
local core = require("openmw.core")
local ambient = require("openmw.ambient")

local settingsCache = require("scripts.BetterArmorTraining.utils.settingsCache")

local settings = settingsCache.new(storage.playerSection("SettingssBetterArmorTraining"), async)
local animGroupType = {
    walking      = { stopKey = "loop stop", pointsKey = "walking", waterKey = "swimmingSlow" },
    running      = { stopKey = "loop stop", pointsKey = "running", waterKey = "swimmingFast" },
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
local armorClassToName = {
    [armorClasses.unarmored]   = core.getGMST("sSkillUnarmored"),
    [armorClasses.lightarmor]  = core.getGMST("sSkillLightarmor"),
    [armorClasses.mediumarmor] = core.getGMST("sSkillMediumarmor"),
    [armorClasses.heavyarmor]  = core.getGMST("sSkillHeavyarmor"),
}
local skillUpMessage = core.getGMST("sNotifyMessage39")
local selfEffects = types.Actor.activeEffects(self)
local animTimestamps = {}
for animType, _ in pairs(animGroupType) do
    animTimestamps[animType] = 0
end

local trainingPoints = 0

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

local function increaseSkillBrute(skill, skillName, normalizedXp)
    if skill.progress + normalizedXp < 1 then
        skill.progress = skill.progress + normalizedXp
        return
    end

    skill.base = skill.base + 1
    skill.progress = settings.carryXpExcess
        and 1 - skill.progress + normalizedXp
        or 0

    self:sendEvent("ShowMessage", { message = skillUpMessage:format(skillName, skill.base) })
    ambient.playSound("skillraise")
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
        local weightClass = item and types.Armor.objectIsInstance(item)
            and I.Combat.getArmorSkill(item)
            or armorClasses.unarmored
        local fraction = settings.xpDivision[fractionKey] / fractionSum
        local xpForSlot = settings.xpPayout * fraction
        xpByArmorClass[weightClass] = xpByArmorClass[weightClass] + xpForSlot
    end

    for armorClass, rawXp in pairs(xpByArmorClass) do
        local skill = armorClassToSkillHandler[armorClass]
        local globalMult = settings.armorTypeXpMult[armorClass]
        local finalXp = applyCaps(rawXp, skill) * globalMult

        if finalXp > 0 then
            local lastLevel = skill.base
            local lastXp = skill.progress
            local skillId = armorClasses[armorClass]

            if settings.grantXpDirectly then
                increaseSkillBrute(skill, armorClassToName[armorClass], finalXp / 100)
            else
                I.SkillProgression.skillUsed(skillId, { skillGain = finalXp })
            end

            if settings.log.xpGain then
                local finalActualXp = lastLevel == skill.base
                    and skill.progress - lastXp
                    or 1 - lastXp + skill.progress
                print(("[BetterArmorTraining] +%.3f xp -> %s"):format(finalActualXp * 100, skillId))
            end
        end
    end
end

local function grantTrainingPoints(groupname, key)
    if animGroupsData[groupname].stopKey ~= key then return end

    local isLevitating = selfEffects:getEffect(core.magic.EFFECT_TYPE.Levitate).magnitude > 0
    if settings.skipIfLevitating and isLevitating then return end

    local animGroupData = animGroupsData[groupname]
    local animType = animGroupData.waterKey and types.Player.isSwimming(self)
        and animGroupData.waterKey
        or animGroupsData[groupname].pointsKey

    local notAvailableUntil = animTimestamps[animType] + settings.cooldown[animType]
    local now = core.getSimulationTime()
    if notAvailableUntil > now then
        if settings.log.cooldown then
            print(("[BetterArmorTraining] '%s' will be available in %.2fs"):format(
                animType, notAvailableUntil - now
            ))
        end
        return
    end

    animTimestamps[animType] = now
    local tpBonus = settings.trainingPointsFor[animType]
    trainingPoints = trainingPoints + tpBonus

    if trainingPoints >= settings.trainingPointsPerXpPayout then
        trainingPoints = trainingPoints - settings.trainingPointsPerXpPayout
        grantXP()
    end

    if settings.log.trainingPoints then
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
        animTimestamps = animTimestamps
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
