RW_PlayerHUDUpdater = {}
RW_PlayerHUDUpdater.TICKS_PER_FILLTYPE_UPDATE = 50

function RW_PlayerHUDUpdater:fieldAddField(fieldState, box)

    box:addLine(g_i18n:getText("rw_ui_moisture"), string.format("%.2f", (g_currentMission.environment.weather.moisture or 0.2) * 100) .. "%")

    local fruitType = g_fruitTypeManager:getFruitTypeNameByIndex(fieldState.fruitTypeIndex)
    local fruit = g_fruitTypeManager:getFruitTypeByIndex(fieldState.fruitTypeIndex)
    local fruitTypeMoistureFactor = RW_FSBaseMission.FRUIT_TYPES_MOISTURE[fruitType]

    if fruitTypeMoistureFactor ~= nil then
        box:addLine(g_i18n:getText("rw_ui_idealMoisture"), string.format("%.2f", fruitTypeMoistureFactor.LOW * 100) .. "% - " .. string.format("%.2f", fruitTypeMoistureFactor.HIGH * 100) .. "%")
        box:addLine(g_i18n:getText("rw_ui_perfectMoisture"), string.format("%.2f", ((fruitTypeMoistureFactor.LOW + fruitTypeMoistureFactor.HIGH) / 2) * 100) .. "%")
    end

    local growthState = fieldState.growthState

    if fruit ~= nil and (fruit:getIsGrowing(growthState) or fruit:getIsPreparable(growthState) or fruit:getIsHarvestable(growthState)) then
        local yield = fieldState:getHarvestScaleMultiplier()
        box:addLine(g_i18n:getText("rw_ui_currentYield"), string.format("%.2f", yield * 100) .. "%")
    end

end

--PlayerHUDUpdater.fieldAddField = Utils.appendedFunction(PlayerHUDUpdater.fieldAddField, RW_PlayerHUDUpdater.fieldAddField)


local function resolveOwnerFarm(id)
    local ownerFarmId = g_farmlandManager:getFarmlandOwner(id)

    if ownerFarmId == nil or ownerFarmId == FarmlandManager.NO_OWNER_FARM_ID or ownerFarmId == FarmManager.SPECTATOR_FARM_ID or ownerFarmId == FarmManager.INVALID_FARM_ID then return false end

    if g_localPlayer == nil then return false end

    return g_localPlayer:getFarmId() == ownerFarmId
end

function RW_PlayerHUDUpdater:showFieldInfo(x, z)

    if self.moistureBox == nil then self.moistureBox = g_currentMission.hud.infoDisplay:createBox(RW_InfoDisplayKeyValueBox) end

    local box = self.moistureBox

    if box == nil then return end

    box:clear()
    local moistureSystem = g_currentMission.moistureSystem

    if moistureSystem == nil or moistureSystem.moistureOverlayBehaviour == 1 or (self.fieldInfo.groundType == FieldGroundType.NONE and moistureSystem.moistureOverlayBehaviour == 2) then return end

    local values = moistureSystem:getValuesAtCoords(x, z, { "moisture", "witherChance", "retention" })

    if values == nil then return end

    local moisture, witherChance, retention = values.moisture, values.witherChance, values.retention

    box:setTitle(g_i18n:getText("rw_ui_moisture"))

    local isBeingIrrigated, pendingIrrigationCost = moistureSystem:getIsFieldBeingIrrigated(self.fieldInfo.farmlandId)
    local irrigationFactor = isBeingIrrigated and (MoistureSystem.IRRIGATION_FACTOR * (x <= 0 and moistureSystem.timeSinceLastUpdateLower or moistureSystem.timeSinceLastUpdateUpper)) or 0

    if self.fieldInfo.groundType ~= FieldGroundType.NONE then

        local id = self.fieldInfo.farmlandId
        local isOwner = false

        if id ~= nil then isOwner = resolveOwnerFarm(id) end

        if id == nil or not isOwner then

            if moistureSystem.isShowingIrrigationInput then
                moistureSystem.isShowingIrrigationInput = false
                g_inputBinding:setActionEventActive(moistureSystem.irrigationEventId, false)
            end

        else

            if not moistureSystem.isShowingIrrigationInput or moistureSystem:getIrrigationInputField() ~= id then

                moistureSystem.isShowingIrrigationInput = true
                moistureSystem:setIrrigationInputField(id)

                g_inputBinding:setActionEventActive(moistureSystem.irrigationEventId, true)
                g_inputBinding:setActionEventText(moistureSystem.irrigationEventId, g_i18n:getText("rw_ui_irrigation_" .. (isBeingIrrigated and "stop" or "start")))

            elseif moistureSystem.isShowingIrrigationInput and moistureSystem:getIrrigationInputField() == id then

                g_inputBinding:setActionEventActive(moistureSystem.irrigationEventId, true)
                g_inputBinding:setActionEventText(moistureSystem.irrigationEventId, g_i18n:getText("rw_ui_irrigation_" .. (isBeingIrrigated and "stop" or "start")))

            end

        end

        local fruitType = g_fruitTypeManager:getFruitTypeNameByIndex(self.fieldInfo.fruitTypeIndex)
        local fruit = g_fruitTypeManager:getFruitTypeByIndex(self.fieldInfo.fruitTypeIndex)
        local fruitTypeMoistureFactor = RW_FSBaseMission.FRUIT_TYPES_MOISTURE[fruitType]
        local growthState = self.fieldInfo.growthState
        local isPlanted = fruit ~= nil and (fruit:getIsGrowing(growthState) or fruit:getIsPreparable(growthState) or fruit:getIsHarvestable(growthState))

        local colour = nil

        if isPlanted and fruitTypeMoistureFactor ~= nil then

            local moistureDiff = math.clamp((moisture + irrigationFactor * retention) / ((fruitTypeMoistureFactor.LOW + fruitTypeMoistureFactor.HIGH) / 2), 0, 2)

            local r, g = 0, 0

            if moistureDiff < 1 then

                r = 1 - moistureDiff
                g = moistureDiff

            else

                r = moistureDiff - 1
                g = 2 - moistureDiff

            end

            colour = { r, g, 0, 1 }

        end

        box:addLine(g_i18n:getText("rw_ui_moisture"), string.format("%.3f%%", math.clamp(moisture + irrigationFactor * retention, 0, 1) * 100), colour)

        if fruitTypeMoistureFactor ~= nil then
            box:addLine(g_i18n:getText("rw_ui_idealMoisture"), string.format("%.2f", fruitTypeMoistureFactor.LOW * 100) .. "% - " .. string.format("%.2f", fruitTypeMoistureFactor.HIGH * 100) .. "%")
            box:addLine(g_i18n:getText("rw_ui_perfectMoisture"), string.format("%.2f", ((fruitTypeMoistureFactor.LOW + fruitTypeMoistureFactor.HIGH) / 2) * 100) .. "%")
        end

        if isPlanted then
            local yield = self.fieldInfo:getHarvestScaleMultiplier()
            box:addLine(g_i18n:getText("rw_ui_currentYield"), string.format("%.2f", yield * 100) .. "%")
        end

        box:addLine(g_i18n:getText("rw_ui_witherChance"), string.format("%.2f%%", witherChance * 100), { witherChance, 1 - witherChance, 0, 1 })

    else

        box:addLine(g_i18n:getText("rw_ui_moisture"), string.format("%.3f%%", math.clamp(moisture + irrigationFactor * retention, 0, 1) * 100), { 1, 1, 1, 1})

        if moistureSystem.isShowingIrrigationInput then
            moistureSystem.isShowingIrrigationInput = false
            g_inputBinding:setActionEventActive(moistureSystem.irrigationEventId, false)
            
        end

    end

    local retentionDiff = math.abs(1 - retention)

    box:addLine(g_i18n:getText("rw_ui_retention"), string.format("%.2f%%", retention * 100), { retentionDiff, 1 - retentionDiff, 0, 1 })
    box:addLine(g_i18n:getText("input_Irrigation"), g_i18n:getText("rw_ui_" .. (isBeingIrrigated and "active" or "inactive")))

    if pendingIrrigationCost > 0 then box:addLine(g_i18n:getText("rw_ui_pendingIrrigationCost"), g_i18n:formatMoney(pendingIrrigationCost, 2, true, true)) end

    box:showNextFrame()

end

PlayerHUDUpdater.showFieldInfo = Utils.appendedFunction(PlayerHUDUpdater.showFieldInfo, RW_PlayerHUDUpdater.showFieldInfo)


function RW_PlayerHUDUpdater:setCurrentRaycastFillTypeCoords(x, y, z, dirX, dirY, dirZ)

    if x == nil or y == nil or z == nil or dirX == nil or dirY == nil or dirZ == nil then
        self.currentRaycastFillTypeCoords = nil
        return
    end

    if self.currentRaycastFillTypeCoords ~= nil then
        local curX, curY, curZ, curDirX, curDirY, curDirZ = unpack(self.currentRaycastFillTypeCoords)

        if curX == x and curY == y and curZ == z and curDirX == dirX and curDirY == dirY and curDirZ == dirZ then return end
    end

    self.currentRaycastFillTypeCoords = table.pack(x, y, z, dirX, dirY, dirZ)
    --self.ticksSinceLastFillTypeUpdate = RW_PlayerHUDUpdater.TICKS_PER_FILLTYPE_UPDATE + 1

end

PlayerHUDUpdater.setCurrentRaycastFillTypeCoords = RW_PlayerHUDUpdater.setCurrentRaycastFillTypeCoords


function RW_PlayerHUDUpdater:showFillTypeInfo()

    if self.currentRaycastFillTypeCoords == nil then return end

    if self.ticksSinceLastFillTypeUpdate == nil then self.ticksSinceLastFillTypeUpdate = RW_PlayerHUDUpdater.TICKS_PER_FILLTYPE_UPDATE + 1 end
    if self.currentRaycastFillType == nil then
        self.currentRaycastFillType = {
            name = "UNKNOWN",
            title = "Unknown"
        }
    end

    if self.ticksSinceLastFillTypeUpdate >= RW_PlayerHUDUpdater.TICKS_PER_FILLTYPE_UPDATE then

        self.ticksSinceLastFillTypeUpdate = 0

        local x, y, z, dirX, dirY, dirZ = unpack(self.currentRaycastFillTypeCoords)
        local fillTypeIndex = DensityMapHeightUtil.getFillTypeAtArea(x, z, x - 2, z - 2, x + 2, z + 2)
        local fillType = g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex)

        if fillType ~= "GRASS_WINDROW" then

            self.currentRaycastFillType = {
                name = fillType
            }

        else

            local amount = DensityMapHeightUtil.getFillLevelAtArea(fillTypeIndex, x, z, x - 2, z - 2, x + 2, z + 2)
            --local found, moisture = g_currentMission.grassMoistureSystem:getMoistureAtArea(x, y, z, x, y, z)
            local found, moisture = g_currentMission.grassMoistureSystem:getMoistureAtArea(x, z)
            local title = g_fillTypeManager:getFillTypeTitleByIndex(fillTypeIndex)

            self.currentRaycastFillType = {
                name = fillType,
                title = title,
                amount = amount
            }

            if found then self.currentRaycastFillType.moisture = moisture end

        end

    end

    self.ticksSinceLastFillTypeUpdate = self.ticksSinceLastFillTypeUpdate + 1


    if self.fillTypeBox == nil then self.fillTypeBox = g_currentMission.hud.infoDisplay:createBox(InfoDisplayKeyValueBox) end

    local box = self.fillTypeBox
    if box == nil then return end

    if self.currentRaycastFillType.name ~= "GRASS_WINDROW" then
        box:clear()
        return
    end

    local fillType = self.currentRaycastFillType

    box:clear()
    box:setTitle(fillType.title)
    box:addLine(g_i18n:getText("rw_ui_amount"), g_i18n:formatVolume(fillType.amount, 0))
    if fillType.moisture ~= nil then
        box:addLine(g_i18n:getText("rw_ui_moisture"), string.format("%.2f%%", fillType.moisture * 100))
        box:addLine(g_i18n:getText("rw_ui_requiredMoisture"), string.format("%.2f%%", GrassMoistureSystem.HAY_MOISTURE * 100))
        box:addLine(g_i18n:getText("rw_ui_needsTedding"), g_i18n:getText("rw_ui_no"))
    else
        box:addLine(g_i18n:getText("rw_ui_needsTedding"), g_i18n:getText("rw_ui_yes"))
    end
    box:showNextFrame()

end

PlayerHUDUpdater.showFillTypeInfo = RW_PlayerHUDUpdater.showFillTypeInfo


function RW_PlayerHUDUpdater:update(_, _, _, _, _)

    self:showFillTypeInfo()

end


function RW_PlayerHUDUpdater:delete()

    if self.fillTypeBox ~= nil then g_currentMission.hud.infoDisplay:destroyBox(self.fillTypeBox) end
    if self.moistureBox ~= nil then g_currentMission.hud.infoDisplay:destroyBox(self.moistureBox) end

end

PlayerHUDUpdater.delete = Utils.appendedFunction(PlayerHUDUpdater.delete, RW_PlayerHUDUpdater.delete)