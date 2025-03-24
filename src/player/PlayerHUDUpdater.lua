RW_PlayerHUDUpdater = {}

function RW_PlayerHUDUpdater:fieldAddField(fieldState, box)
    box:addLine(g_i18n:getText("rw_ui_moisture"), string.format("%.2f", (fieldState.moisture or 0.2) * 100) .. "%")

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

PlayerHUDUpdater.fieldAddField = Utils.appendedFunction(PlayerHUDUpdater.fieldAddField, RW_PlayerHUDUpdater.fieldAddField)