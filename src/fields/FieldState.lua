RW_FieldState = {}

function RW_FieldState:update(x, z)

    local moistureSystem = g_currentMission.moistureSystem

    if moistureSystem == nil then return end

    local values = moistureSystem:getValuesAtCoords(x, z, { "moisture", "retention" } )

    if values == nil or values.moisture == nil then
        self.moisture = nil
    else
        self.moisture = values.moisture
        local isBeingIrrigated, _ = moistureSystem:getIsFieldBeingIrrigated(self.farmlandId)
        local updater = moistureSystem:getUpdaterAtX(x)
        local irrigationFactor = isBeingIrrigated and (MoistureSystem.IRRIGATION_FACTOR * updater.timeSinceLastUpdate) or 0
        self.moisture = math.clamp(self.moisture + irrigationFactor * (values.retention or 1), 0, 1)
    end


end

FieldState.update = Utils.appendedFunction(FieldState.update, RW_FieldState.update)

function RW_FieldState:getHarvestScaleMultiplier(superFunc)

    if self.moisture == nil then return superFunc(self) end

    local sprayLevel, plowLevel, limeLevel, weedsLevel, stubbleLevel, rollerLevel = self:getHarvestScaleFactors()

    return g_currentMission:getHarvestScaleMultiplier(self.fruitTypeIndex, sprayLevel, plowLevel, limeLevel, weedsLevel, stubbleLevel, rollerLevel, 0, self.moisture)

end

FieldState.getHarvestScaleMultiplier = Utils.overwrittenFunction(FieldState.getHarvestScaleMultiplier, RW_FieldState.getHarvestScaleMultiplier)