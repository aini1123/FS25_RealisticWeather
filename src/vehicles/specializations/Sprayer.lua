RW_Sprayer = {}

function RW_Sprayer:processSprayerArea(superFunc, workArea, dT)

    local changedArea, totalArea = superFunc(self, workArea, dT)

    if self.isServer then

        local moistureSystem = g_currentMission.moistureSystem

        if moistureSystem == nil then return changedArea, totalArea end

        local fillType = self.spec_sprayer.workAreaParameters.sprayFillType

        local factor = MoistureSystem.SPRAY_FACTOR[self.spec_sprayer.isSlurryTanker and "slurry" or "fertilizer"]

        local target = { ["moisture"] = factor * (fillType == FillType.WATER and 4 or 1) * moistureSystem.moistureGainModifier }

        local sx, _, sz = getWorldTranslation(workArea.start)
        local wx, _, wz = getWorldTranslation(workArea.width)
        local hx, _, hz = getWorldTranslation(workArea.height)
        
        local width = wx - sx
        local height = wz - sz

        local realWidth = MathUtil.vector2Length(wx - sx, wz - sz) * 2
        local realHeightX = (hx - sx) * 0.5
        local realHeightZ = (hz - sz) * 0.5

        local fieldGroundSystem = g_currentMission.fieldGroundSystem
 
        local stepX = width / realWidth
        local stepZ = height / realWidth

        for i = 0, realWidth do

            local x = sx + realHeightX + stepX * i
            local z = sz + realHeightZ + stepZ * i

            local groundTypeValue = fieldGroundSystem:getValueAtWorldPos(FieldDensityMap.GROUND_TYPE, x, 0, z)
	        local groundType = FieldGroundType.getTypeByValue(groundTypeValue)
                
            if groundType == FieldGroundType.NONE then continue end

            moistureSystem:setValuesAtCoords(x, z, target, true)

        end

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