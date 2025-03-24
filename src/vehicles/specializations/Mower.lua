RW_Mower = {}

function RW_Mower:processMowerArea(_, workArea, _)

    local spec = self.spec_mower
    local startX, _, startZ = getWorldTranslation(workArea.start)
    local widthX, _, widthZ = getWorldTranslation(workArea.width)
    local heightX, _, heightZ = getWorldTranslation(workArea.height)

    if self:getLastSpeed() > 1 then
        spec.isWorking = true
        spec.stoneLastState = FSDensityMapUtil.getStoneArea(startX, startZ, widthX, widthZ, heightX, heightZ)
    else
        spec.stoneLastState = 0
    end

    local isAI = self:getIsAIActive()

    for fruitTypeIndex, fillType in pairs(spec.fruitTypeConverters) do

        local changedArea, totalArea, sprayLevel, plowLevel, limeLevel, weedsLevel, stubbleLevel, rollerLevel, beeYieldBonusPercentage, growthState, _ = FSDensityMapUtil.updateMowerArea(fruitTypeIndex, startX, startZ, widthX, widthZ, heightX, heightZ, isAI)

        if changedArea > 0 then

            local farmland = g_farmlandManager:getFarmlandAtWorldPosition(startX, startZ)
            local moisture
            if farmland ~= nil then
                local fieldId = farmland:getId()
                if fieldId ~= nil then
                    local field = g_fieldManager:getFieldById(fieldId)
                    if field ~= nil and field.fieldState ~= nil then moisture = field.fieldState.moisture end
                end
            end

            local harvestScale = g_currentMission:getHarvestScaleMultiplier(fruitTypeIndex, sprayLevel, plowLevel, limeLevel, weedsLevel, stubbleLevel, rollerLevel, beeYieldBonusPercentage, moisture or (math.random(12, 20) / 100))
            local areaLitres = g_fruitTypeManager:getFruitTypeAreaLiters(fruitTypeIndex, changedArea, true) * harvestScale * fillType.conversionFactor
            workArea.lastPickupLiters = areaLitres
            workArea.pickedUpLiters = areaLitres
            local dropArea = self:getDropArea(workArea)

            if dropArea == nil then
                if spec.fillUnitIndex ~= nil and self.isServer then
                    self:addFillUnitFillLevel(self:getOwnerFarmId(), spec.fillUnitIndex, areaLitres, fillType.fillTypeIndex, ToolType.UNDEFINED)
                end
            else
                dropArea.litersToDrop = dropArea.litersToDrop + areaLitres
                dropArea.fillType = fillType.fillTypeIndex
                dropArea.workAreaIndex = workArea.index

                if dropArea.fillType == FillType.GRASS_WINDROW then
                    local lsx, lsy, lsz, lex, ley, lez, radius = DensityMapHeightUtil.getLineByArea(workArea.start, workArea.width, workArea.height, true)
                    local pickup, lineOffset = DensityMapHeightUtil.tipToGroundAroundLine(self, -math.huge, FillType.DRYGRASS_WINDROW, lsx, lsy, lsz, lex, ley, lez, radius, nil, workArea.lineOffset or 0, false, nil, false)
                    workArea.lineOffset = lineOffset
                    dropArea.litersToDrop = dropArea.litersToDrop - pickup
                end

                dropArea.litersToDrop = math.min(dropArea.litersToDrop, 1000)
            end

            spec.workAreaParameters.lastInputFruitType = fruitTypeIndex
            spec.workAreaParameters.lastInputGrowthState = growthState
            spec.workAreaParameters.lastCutTime = g_time
            spec.workAreaParameters.lastChangedArea = spec.workAreaParameters.lastChangedArea + changedArea
            spec.workAreaParameters.lastStatsArea = spec.workAreaParameters.lastStatsArea + changedArea
            spec.workAreaParameters.lastTotalArea = spec.workAreaParameters.lastTotalArea + totalArea
            spec.workAreaParameters.lastUsedAreas = spec.workAreaParameters.lastUsedAreas + 1
            self:setTestAreaRequirements(fruitTypeIndex)

        end

    end

    spec.workAreaParameters.lastUsedAreasSum = spec.workAreaParameters.lastUsedAreasSum + 1

    return spec.workAreaParameters.lastChangedArea, spec.workAreaParameters.lastTotalArea

end

Mower.processMowerArea = Utils.overwrittenFunction(Mower.processMowerArea, RW_Mower.processMowerArea)