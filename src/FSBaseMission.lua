RW_FSBaseMission = {}

RW_FSBaseMission.FRUIT_TYPES_MOISTURE = {
    ["BARLEY"] = {
        ["LOW"] = 0.12,
        ["HIGH"] = 0.135
    },
    ["WHEAT"] = {
        ["LOW"] = 0.12,
        ["HIGH"] = 0.145
    },
    ["OAT"] = {
        ["LOW"] = 0.12,
        ["HIGH"] = 0.18
    },
    ["CANOLA"] = {
        ["LOW"] = 0.08,
        ["HIGH"] = 0.1
    },
    ["SOYBEAN"] = {
        ["LOW"] = 0.125,
        ["HIGH"] = 0.135
    },
    ["SORGHUM"] = {
        ["LOW"] = 0.17,
        ["HIGH"] = 0.2
    },
    ["RICELONGGRAIN"] = {
        ["LOW"] = 0.19,
        ["HIGH"] = 0.22
    },
    ["MAIZE"] = {
        ["LOW"] = 0.15,
        ["HIGH"] = 0.2
    },
    ["SUNFLOWER"] = {
        ["LOW"] = 0.09,
        ["HIGH"] = 0.1
    },
    ["GRASS"] = {
        ["LOW"] = 0.18,
        ["HIGH"] = 0.22
    },
    ["OILSEEDRADISH"] = {
        ["LOW"] = 0.2,
        ["HIGH"] = 0.22
    },
    ["PEA"] = {
        ["LOW"] = 0.14,
        ["HIGH"] = 0.15
    },
    ["SPINACH"] = {
        ["LOW"] = 0.2,
        ["HIGH"] = 0.22
    },
    ["SUGARCANE"] = {
        ["LOW"] = 0.22,
        ["HIGH"] = 0.26
    },
    ["SUGARBEET"] = {
        ["LOW"] = 0.22,
        ["HIGH"] = 0.26
    },
    ["COTTON"] = {
        ["LOW"] = 0.1,
        ["HIGH"] = 0.12
    },
    ["GREENBEAN"] = {
        ["LOW"] = 0.175,
        ["HIGH"] = 0.185
    },
    ["CARROT"] = {
        ["LOW"] = 0.135,
        ["HIGH"] = 0.155
    },
    ["PARSNIP"] = {
        ["LOW"] = 0.135,
        ["HIGH"] = 0.155
    },
    ["BEETROOT"] = {
        ["LOW"] = 0.15,
        ["HIGH"] = 0.17
    },
    ["RICE"] = {
        ["LOW"] = 0.22,
        ["HIGH"] = 0.24
    },
    ["POTATO"] = {
        ["LOW"] = 0.18,
        ["HIGH"] = 0.2
    }
}

function RW_FSBaseMission:getHarvestScaleMultiplier(superFunc, fruitTypeIndex, sprayLevel, plowLevel, limeLevel, weedsLevel, stubbleLevel, rollerLevel, beeYieldBonusPercentage, moisture)

    local baseYield = superFunc(self, fruitTypeIndex, sprayLevel, plowLevel, limeLevel, weedsLevel, stubbleLevel, rollerLevel, beeYieldBonusPercentage)

    if moisture == nil then return baseYield end


    local moistureFactor = 1
    local fruitType = g_fruitTypeManager:getFruitTypeNameByIndex(fruitTypeIndex)
    local fruitTypeMoistureFactor = RW_FSBaseMission.FRUIT_TYPES_MOISTURE[fruitType]

    if fruitTypeMoistureFactor ~= nil then

        local lowMoisture = fruitTypeMoistureFactor.LOW
        local highMoisture = fruitTypeMoistureFactor.HIGH
        local perfectMoisture = (highMoisture + lowMoisture) / 2

        if moisture >= perfectMoisture - 0.0025 and moisture <= perfectMoisture + 0.0025 then
            moistureFactor = 1.5
        elseif moisture < lowMoisture then
            moistureFactor = moisture / lowMoisture
        elseif moisture < perfectMoisture then
            moistureFactor = 1 + (moisture / perfectMoisture) * 0.2
        elseif moisture > highMoisture then
            moistureFactor = highMoisture / moisture
        elseif moisture > perfectMoisture then
            moistureFactor = 1 + (perfectMoisture / moisture) * 0.2
        end

    end

    return baseYield * math.clamp(moistureFactor, 0.5, 1.5)

end

FSBaseMission.getHarvestScaleMultiplier = Utils.overwrittenFunction(FSBaseMission.getHarvestScaleMultiplier, RW_FSBaseMission.getHarvestScaleMultiplier)


function RW_FSBaseMission:onStartMission()
    removeModEventListener(GrassMoistureSystem)
    if g_modIsLoaded["FS25_RealisticLivestock"] then RW_Weather.isRealisticLivestockLoaded = true end
    if g_modIsLoaded["FS25_ExtendedGameInfoDisplay"] then RW_GameInfoDisplay.isExtendedGameInfoDisplayLoaded = true end
end

FSBaseMission.onStartMission = Utils.prependedFunction(FSBaseMission.onStartMission, RW_FSBaseMission.onStartMission)