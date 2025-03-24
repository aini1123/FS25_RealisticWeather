RW_FieldState = {}

function RW_FieldState:saveToXMLFile(xmlFile, key)
    xmlFile:setFloat(key .. "#moisture", self.moisture or (math.random(12, 30) / 100))
end

FieldState.saveToXMLFile = Utils.appendedFunction(FieldState.saveToXMLFile, RW_FieldState.saveToXMLFile)


function RW_FieldState:loadFromXMLFile(xmlFile, key)
    self.moisture = xmlFile:getFloat(key .. "#moisture", math.random(12, 30) / 100)
end

FieldState.loadFromXMLFile = Utils.appendedFunction(FieldState.loadFromXMLFile, RW_FieldState.loadFromXMLFile)


function RW_FieldState:update(x, z)
    local farmlandId = g_farmlandManager:getFarmlandIdAtWorldPosition(x, z)
    local field = g_fieldManager:getFieldById(farmlandId)

    if field ~= nil then self.moisture = field.fieldState.moisture or (math.random(12, 30) / 100) end
end

FieldState.update = Utils.appendedFunction(FieldState.update, RW_FieldState.update)


function RW_FieldState:getHarvestScaleMultiplier()
    local missionInfo = g_currentMission.missionInfo
    local fieldGroundSystem = g_currentMission.fieldGroundSystem
    local maxSprayLevel = fieldGroundSystem:getMaxValue(FieldDensityMap.SPRAY_LEVEL)
    local maxPlowLevel = fieldGroundSystem:getMaxValue(FieldDensityMap.PLOW_LEVEL)
    local maxLimeLevel = fieldGroundSystem:getMaxValue(FieldDensityMap.LIME_LEVEL)
    local maxRollerLevel = fieldGroundSystem:getMaxValue(FieldDensityMap.ROLLER_LEVEL)

    local plowLevel = not missionInfo.plowingRequiredEnabled and 1 or self.plowLevel / maxPlowLevel
    local limeLevel = not (Platform.gameplay.useLimeCounter and missionInfo.limeRequired) and 1 or self.limeLevel / maxLimeLevel
    local rollerLevel = not Platform.gameplay.useRolling and 1 or 1 - self.rollerLevel / maxRollerLevel
    local weedsLevel = not missionInfo.weedsEnabled and 1 or 1 - self.weedFactor
    local stubbleLevel = not Platform.gameplay.useStubbleShred and 1 or self.stubbleShredLevel

    return g_currentMission:getHarvestScaleMultiplier(self.fruitTypeIndex, self.sprayLevel / maxSprayLevel, plowLevel, limeLevel, weedsLevel, stubbleLevel, rollerLevel, 0, self.moisture)
end

FieldState.getHarvestScaleMultiplier = Utils.overwrittenFunction(FieldState.getHarvestScaleMultiplier, RW_FieldState.getHarvestScaleMultiplier)