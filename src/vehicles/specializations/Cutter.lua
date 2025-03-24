RW_Cutter = {}


function RW_Cutter:processCutterArea(superFunc, workArea, dt)

    local moistureSystem = g_currentMission.moistureSystem

    if moistureSystem == nil then return superFunc(self, workArea, dt) end

    local spec = self.spec_cutter

    if spec.workAreaParameters.combineVehicle ~= nil then
        local fieldGroundSystem = g_currentMission.fieldGroundSystem

        local xs, _, zs = getWorldTranslation(workArea.start)
        local xw, _, zw = getWorldTranslation(workArea.width)
        local xh, _, zh = getWorldTranslation(workArea.height)

        local lastArea = 0
        local lastMultiplierArea = 0
        local lastTotalArea = 0

        for _, fruitTypeIndex in ipairs(spec.workAreaParameters.fruitTypeIndicesToUse) do
            local fruitTypeDesc = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
            local excludedSprayType = fieldGroundSystem:getChopperTypeValue(fruitTypeDesc.chopperType)
            local area, totalArea, sprayFactor, plowFactor, limeFactor, weedFactor, stubbleFactor, rollerFactor, beeYieldBonusPerc, growthState, _, terrainDetailPixelsSum = FSDensityMapUtil.cutFruitArea(fruitTypeIndex, xs,zs, xw,zw, xh,zh, true, spec.allowsForageGrowthState, excludedSprayType)

            if area > 0 then
                lastTotalArea = lastTotalArea + totalArea

                if self.isServer then
                    if growthState ~= spec.currentGrowthState then
                        spec.currentGrowthStateTimer = spec.currentGrowthStateTimer + dt
                        if spec.currentGrowthStateTimer > 500 or spec.currentGrowthStateTime + 1000 < g_time then
                            spec.currentGrowthState = growthState
                            spec.currentGrowthStateTimer = 0
                        end
                    else
                        spec.currentGrowthStateTimer = 0
                        spec.currentGrowthStateTime = g_time
                    end

                    if fruitTypeIndex ~= spec.currentInputFruitType then
                        spec.currentInputFruitType = fruitTypeIndex
                        spec.currentGrowthState = growthState

                        spec.currentOutputFillType = g_fruitTypeManager:getFillTypeIndexByFruitTypeIndex(spec.currentInputFruitType)
                        if spec.fruitTypeConverters[spec.currentInputFruitType] ~= nil then
                            spec.currentOutputFillType = spec.fruitTypeConverters[spec.currentInputFruitType].fillTypeIndex
                            spec.currentConversionFactor = spec.fruitTypeConverters[spec.currentInputFruitType].conversionFactor
                        end

                        local cutHeight = g_fruitTypeManager:getCutHeightByFruitTypeIndex(fruitTypeIndex, spec.allowsForageGrowthState)
                        self:setCutterCutHeight(cutHeight)
                    end

                    self:setTestAreaRequirements(fruitTypeIndex, nil, spec.allowsForageGrowthState)

                    if terrainDetailPixelsSum > 0 then
                        spec.currentInputFruitTypeAI = fruitTypeIndex
                    end
                    spec.currentInputFillType = g_fruitTypeManager:getFillTypeIndexByFruitTypeIndex(fruitTypeIndex)
                    spec.useWindrow = false
                end

                local target = { "moisture" }

                local startMoistureValues = moistureSystem:getValuesAtCoords(xs, zs, target)
                local widthMoistureValues = moistureSystem:getValuesAtCoords(xw, zw, target)
                local heightMoistureValues = moistureSystem:getValuesAtCoords(xh, zh, target)

                local startMoisture, widthMoisture, heightMoisture = 0, 0, 0

                if startMoistureValues ~= nil and startMoistureValues.moisture ~= nil then startMoisture = startMoistureValues.moisture end
                if widthMoistureValues ~= nil and widthMoistureValues.moisture ~= nil then widthMoisture = widthMoistureValues.moisture end
                if heightMoistureValues ~= nil and heightMoistureValues.moisture ~= nil then heightMoisture = heightMoistureValues.moisture end

                local averageMoisture = (startMoisture + widthMoisture + heightMoisture) / 3

                local multiplier = g_currentMission:getHarvestScaleMultiplier(fruitTypeIndex, sprayFactor, plowFactor, limeFactor, weedFactor, stubbleFactor, rollerFactor, beeYieldBonusPerc, averageMoisture)

                lastArea = area
                lastMultiplierArea = area * multiplier

                spec.workAreaParameters.lastFruitType = fruitTypeIndex
                break
            end
        end

        if lastArea > 0 then
            if workArea.chopperAreaIndex ~= nil and spec.workAreaParameters.lastFruitType ~= nil then
                local chopperWorkArea = self:getWorkAreaByIndex(workArea.chopperAreaIndex)
                if chopperWorkArea ~= nil then
                    xs, _, zs = getWorldTranslation(chopperWorkArea.start)
                    xw, _, zw = getWorldTranslation(chopperWorkArea.width)
                    xh, _, zh = getWorldTranslation(chopperWorkArea.height)

                    local fruitTypeDesc = g_fruitTypeManager:getFruitTypeByIndex(spec.workAreaParameters.lastFruitType)
                    if fruitTypeDesc.chopperType ~= nil then
                        local strawGroundType = FieldChopperType.getValueByType(fruitTypeDesc.chopperType)
                        if strawGroundType ~= nil then
                            FSDensityMapUtil.setGroundTypeLayerArea(xs, zs, xw, zw, xh, zh, strawGroundType)
                        end
                    elseif fruitTypeDesc.chopperUseHaulm then
                        local area = FSDensityMapUtil.updateFruitHaulmArea(spec.workAreaParameters.lastFruitType, xs, zs, xw, zw, xh, zh)

                        if area > 0 then
                            -- remove tireTracks since the haulm drops on top of it
                            FSDensityMapUtil.eraseTireTrack(xs, zs, xw, zw, xh, zh)
                        end
                    end
                else
                    Logging.xmlWarning(self.xmlFile, "Invalid chopperAreaIndex '%d' for workArea '%d'!", workArea.chopperAreaIndex, workArea.index)
                    workArea.chopperAreaIndex = nil
                end
            end

            spec.stoneLastState = FSDensityMapUtil.getStoneArea(xs, zs, xw, zw, xh, zh)
            spec.isWorking = true
        end

        spec.workAreaParameters.lastArea = spec.workAreaParameters.lastArea + lastArea
        spec.workAreaParameters.lastMultiplierArea = spec.workAreaParameters.lastMultiplierArea + lastMultiplierArea

        return spec.workAreaParameters.lastArea, lastTotalArea
    end

    return 0, 0
end

Cutter.processCutterArea = Utils.overwrittenFunction(Cutter.processCutterArea, RW_Cutter.processCutterArea)