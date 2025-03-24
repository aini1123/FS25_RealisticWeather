RW_Tedder = {}

function RW_Tedder:processDropArea(superFunc, dropArea, fillType, amount)

    if g_fillTypeManager:getFillTypeNameByIndex(fillType) ~= "GRASS_WINDROW" then return superFunc(self, dropArea, fillType, amount) end

    local startX, startY, startZ, endX, endY, endZ, radius = DensityMapHeightUtil.getLineByArea(dropArea.start, dropArea.width, dropArea.height, true)
    local dropped, lineOffset = DensityMapHeightUtil.tipToGroundAroundLine(self, amount, fillType, startX, startY, startZ, endX, endY, endZ, radius, nil, dropArea.lineOffset, false, nil, false)
    dropArea.lineOffset = lineOffset


    local sx, _, sz = getWorldTranslation(dropArea.start)
    local wx, _, wz = getWorldTranslation(dropArea.width)
    local hx, _, hz = getWorldTranslation(dropArea.height)

    --g_currentMission.grassMoistureSystem:addArea(startX, startY, startZ, endX, endY, endZ)
    g_currentMission.grassMoistureSystem:addArea(sx, sz, wx, wz, hx, hz)

    return dropped

end

Tedder.processDropArea = Utils.overwrittenFunction(Tedder.processDropArea, RW_Tedder.processDropArea)


function RW_Tedder:processTedderArea(_, workArea, dt)
    local spec = self.spec_tedder
    local workAreaSpec = self.spec_workArea

    local sx, sy, sz = getWorldTranslation(workArea.start)
    local wx, wy, wz = getWorldTranslation(workArea.width)
    local hx, hy, hz = getWorldTranslation(workArea.height)

    -- pick up
    local lsx, lsy, lsz, lex, ley, lez, lineRadius = DensityMapHeightUtil.getLineByAreaDimensions(sx, sy, sz, wx, wy, wz, hx, hy, hz, true)

    for targetFillType, inputFillTypes in pairs(spec.fillTypeConvertersReverse) do
        local pickedUpLiters = 0
        for _, inputFillType in ipairs(inputFillTypes) do
            pickedUpLiters = pickedUpLiters + DensityMapHeightUtil.tipToGroundAroundLine(self, -math.huge, inputFillType, lsx, lsy, lsz, lex, ley, lez, lineRadius, nil, nil, false, nil)
        end

        if pickedUpLiters == 0 and workArea.lastDropFillType ~= FillType.UNKNOWN then
            targetFillType = workArea.lastDropFillType
        end

        workArea.lastPickupLiters = -pickedUpLiters
        workArea.litersToDrop = workArea.litersToDrop + workArea.lastPickupLiters

        -- drop
        local dropArea = workAreaSpec.workAreas[workArea.dropWindrowWorkAreaIndex]
        if dropArea ~= nil and workArea.litersToDrop > 0 then

            local dropped

            if g_fillTypeManager:getFillTypeNameByIndex(targetFillType) == "DRYGRASS_WINDROW" then

                local grassFillTypeIndex = g_fillTypeManager:getFillTypeIndexByName("GRASS_WINDROW")
                dropped = self:processDropArea(dropArea, grassFillTypeIndex, workArea.litersToDrop)

            else
                dropped = self:processDropArea(dropArea, targetFillType, workArea.litersToDrop)
            end

            workArea.lastDropFillType = targetFillType
            workArea.lastDroppedLiters = dropped
            spec.lastDroppedLiters = spec.lastDroppedLiters + dropped
            workArea.litersToDrop = workArea.litersToDrop - dropped

            if self.isServer then
                --particles
                local lastSpeed = self:getLastSpeed(true)
                if dropped > 0 and lastSpeed > 0.5 then
                    local changedFillType = false
                    if spec.tedderWorkAreaFillTypes[workArea.tedderWorkAreaIndex] ~= targetFillType then
                        spec.tedderWorkAreaFillTypes[workArea.tedderWorkAreaIndex] = targetFillType
                        self:raiseDirtyFlags(spec.fillTypesDirtyFlag)
                        changedFillType = true
                    end

                    local effects = spec.workAreaToEffects[workArea.index]
                    if effects ~= nil then
                        for _, effect in ipairs(effects) do
                            effect.activeTime = g_currentMission.time + effect.activeTimeDuration

                            -- sync mp
                            if not effect.isActiveSent then
                                effect.isActiveSent = true
                                self:raiseDirtyFlags(spec.effectDirtyFlag)
                            end

                            if changedFillType then
                                g_effectManager:setEffectTypeInfo(effect.effects, targetFillType)
                            end

                            -- enable effect
                            if not effect.isActive then
                                g_effectManager:setEffectTypeInfo(effect.effects, targetFillType)
                                g_effectManager:startEffects(effect.effects)
                            end

                            g_effectManager:setDensity(effect.effects, math.max(lastSpeed / self:getSpeedLimit(), 0.6))

                            effect.isActive = true
                        end
                    end
                end
            end
        end
    end

    if self:getLastSpeed() > 0.5 then
        spec.stoneLastState = FSDensityMapUtil.getStoneArea(sx, sz, wx, wz, hx, hz)
    else
        spec.stoneLastState = 0
    end

    --calculating area by area width multiplied by last moved distance (not 100% accuracy in corners)
    local areaWidth = MathUtil.vector3Length(lsx-lex, lsy-ley, lsz-lez)
    local area = areaWidth * self.lastMovedDistance

    return area, area
end

Tedder.processTedderArea = Utils.overwrittenFunction(Tedder.processTedderArea, RW_Tedder.processTedderArea)