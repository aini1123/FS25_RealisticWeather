RW_Sprayer = {}

function RW_Sprayer:processSprayerArea(superFunc, workArea, dT)

    local changedArea, totalArea = superFunc(self, workArea, dT)

    if self.isServer then

        local moistureSystem = g_currentMission.moistureSystem

        if moistureSystem == nil then return changedArea, totalArea end

        local fillType = self.spec_sprayer.workAreaParameters.sprayFillType
        local target = { ["moisture"] = MoistureSystem.SPRAY_FACTOR * (fillType == FillType.WATER and 4 or 1) * moistureSystem.moistureGainModifier }

        local sx, _, sz = getWorldTranslation(workArea.start)
        local wx, _, wz = getWorldTranslation(workArea.width)
        local hx, _, hz = getWorldTranslation(workArea.height)

        local width = math.abs(wx - sx)
        local height = math.abs(hz - sz)

        --print(sz, wz, hz, "-------------------")
        local x1 = math.min(sx, wx, hx)
        local z1 = math.min(sz, wz, hz)
        local x2 = math.max(sx, wx, hx)
        local z2 = math.max(sz, wz, hz)

        --for i = 0, width, moistureSystem.cellWidth * 0.25 do

            --for j = 0, height, moistureSystem.cellHeight * 0.25 do
                --print(sx + i, sz + j, "------")
                --moistureSystem:setValuesAtCoords(sx + i, sz + j, target)
            --end

        --end

        local fieldGroundSystem = g_currentMission.fieldGroundSystem

        for x = x1, x2, moistureSystem.cellWidth * 0.5 do
            for z = z1, z2, moistureSystem.cellHeight * 0.5 do
                --print(x, z, "----")

                local groundTypeValue = fieldGroundSystem:getValueAtWorldPos(FieldDensityMap.GROUND_TYPE, x, 0, z)
	            local groundType = FieldGroundType.getTypeByValue(groundTypeValue)
                
                if groundType == FieldGroundType.NONE then continue end

                moistureSystem:setValuesAtCoords(x, z, target)
            end
        end

        --print("---------------------------------------------")

        moistureSystem.needsSync = true

    end

    return changedArea, totalArea

end

Sprayer.processSprayerArea = Utils.overwrittenFunction(Sprayer.processSprayerArea, RW_Sprayer.processSprayerArea)


function RW_Sprayer:getSprayerUsage(superFunc, fillType, dT)

    local usage = superFunc(self, fillType, dT)
    
    if fillType == FillType.WATER then usage = usage * 0.14 end

    return usage
end

Sprayer.getSprayerUsage = Utils.overwrittenFunction(Sprayer.getSprayerUsage, RW_Sprayer.getSprayerUsage)


function RW_Sprayer:updateSprayerEffects(force)

    local spec = self.spec_sprayer

    local effectsState = self:getAreEffectsVisible()
    if effectsState ~= spec.lastEffectsState or force then

        if effectsState then

            local fillType = self:getFillUnitLastValidFillType(self:getSprayerFillUnitIndex())
            if fillType == FillType.UNKNOWN then
                fillType = self:getFillUnitFirstSupportedFillType(self:getSprayerFillUnitIndex())
            end

            if fillType == FillType.WATER then

                g_effectManager:setEffectTypeInfo(spec.effects, FillType.LIQUIDFERTILIZER)
                g_effectManager:startEffects(spec.effects)

                g_soundManager:playSample(spec.samples.spray)

                local sprayType = self:getActiveSprayType()
                if sprayType ~= nil then
                    g_effectManager:setEffectTypeInfo(sprayType.effects, FillType.LIQUIDFERTILIZER)
                    g_effectManager:startEffects(sprayType.effects)

                    g_animationManager:startAnimations(sprayType.animationNodes)

                    g_soundManager:playSample(sprayType.samples.spray)
                end

                g_animationManager:startAnimations(spec.animationNodes)

                spec.lastEffectsState = effectsState

            end

        end

    end

end

Sprayer.updateSprayerEffects = Utils.prependedFunction(Sprayer.updateSprayerEffects, RW_Sprayer.updateSprayerEffects)