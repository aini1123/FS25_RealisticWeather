RW_Mower = {}

function RW_Mower:processMowerArea(superFunc, workArea, dt)

    local moistureSystem = g_currentMission.moistureSystem

    if moistureSystem == nil then return superFunc(self, workArea, dt) end

    local spec = self.spec_mower

    local xs,_,zs = getWorldTranslation(workArea.start)
    local xw,_,zw = getWorldTranslation(workArea.width)
    local xh,_,zh = getWorldTranslation(workArea.height)

    if self:getLastSpeed() > 1 then
        spec.isWorking = true
        spec.stoneLastState = FSDensityMapUtil.getStoneArea(xs, zs, xw, zw, xh, zh)
    else
        spec.stoneLastState = 0
    end

    local limitToField = self:getIsAIActive()
    for inputFruitType, converterData in pairs(spec.fruitTypeConverters) do
        local changedArea, totalArea, sprayFactor, plowFactor, limeFactor, weedFactor, stubbleFactor, rollerFactor, beeYieldBonusPerc, growthState, _ = FSDensityMapUtil.updateMowerArea(inputFruitType, xs, zs, xw, zw, xh, zh, limitToField)

        if changedArea > 0 then

            local target = { "moisture" }

            local startMoistureValues = moistureSystem:getValuesAtCoords(xs, zs, target)
            local widthMoistureValues = moistureSystem:getValuesAtCoords(xw, zw, target)
            local heightMoistureValues = moistureSystem:getValuesAtCoords(xh, zh, target)

            local startMoisture, widthMoisture, heightMoisture = 0, 0, 0

            if startMoistureValues ~= nil and startMoistureValues.moisture ~= nil then startMoisture = startMoistureValues.moisture end
            if widthMoistureValues ~= nil and widthMoistureValues.moisture ~= nil then widthMoisture = widthMoistureValues.moisture end
            if heightMoistureValues ~= nil and heightMoistureValues.moisture ~= nil then heightMoisture = heightMoistureValues.moisture end

            local averageMoisture = (startMoisture + widthMoisture + heightMoisture) / 3

            local multiplier = g_currentMission:getHarvestScaleMultiplier(inputFruitType, sprayFactor, plowFactor, limeFactor, weedFactor, stubbleFactor, rollerFactor, beeYieldBonusPerc, averageMoisture)

            local litersToDrop = g_fruitTypeManager:getFruitTypeAreaLiters(inputFruitType, changedArea, true)

            litersToDrop = litersToDrop * multiplier
            litersToDrop = litersToDrop * converterData.conversionFactor

            workArea.lastPickupLiters = litersToDrop
            workArea.pickedUpLiters = litersToDrop

            local dropArea = self:getDropArea(workArea)
            if dropArea ~= nil then
                dropArea.litersToDrop = dropArea.litersToDrop + litersToDrop
                dropArea.fillType = converterData.fillTypeIndex
                dropArea.workAreaIndex = workArea.index

                if dropArea.fillType == FillType.GRASS_WINDROW then
                    local lsx, lsy, lsz, lex, ley, lez, radius = DensityMapHeightUtil.getLineByArea(workArea.start, workArea.width, workArea.height, true)
                    local pickup
                    pickup, workArea.lineOffset = DensityMapHeightUtil.tipToGroundAroundLine(self, -math.huge, FillType.DRYGRASS_WINDROW, lsx, lsy, lsz, lex, ley, lez, radius, nil, workArea.lineOffset or 0, false, nil, false)
                    dropArea.litersToDrop = dropArea.litersToDrop - pickup
                end

                dropArea.litersToDrop = math.min(dropArea.litersToDrop, 1000)
            elseif spec.fillUnitIndex ~= nil then
                if self.isServer then
                    self:addFillUnitFillLevel(self:getOwnerFarmId(), spec.fillUnitIndex, litersToDrop, converterData.fillTypeIndex, ToolType.UNDEFINED)
                end
            end

            spec.workAreaParameters.lastInputFruitType = inputFruitType
            spec.workAreaParameters.lastInputGrowthState = growthState
            spec.workAreaParameters.lastCutTime = g_time

            spec.workAreaParameters.lastChangedArea = spec.workAreaParameters.lastChangedArea + changedArea
            spec.workAreaParameters.lastStatsArea = spec.workAreaParameters.lastStatsArea + changedArea
            spec.workAreaParameters.lastTotalArea   = spec.workAreaParameters.lastTotalArea + totalArea

            spec.workAreaParameters.lastUsedAreas = spec.workAreaParameters.lastUsedAreas + 1

            self:setTestAreaRequirements(inputFruitType)
        end
    end

    spec.workAreaParameters.lastUsedAreasSum = spec.workAreaParameters.lastUsedAreasSum + 1

    return spec.workAreaParameters.lastChangedArea, spec.workAreaParameters.lastTotalArea
end

Mower.processMowerArea = Utils.overwrittenFunction(Mower.processMowerArea, RW_Mower.processMowerArea)