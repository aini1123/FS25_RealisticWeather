RW_Sprayer = {}

function RW_Sprayer:processSprayerArea(superFunc, workArea, dT)

    local changedArea, totalArea = superFunc(self, workArea, dT)

    if self.isServer then

        local moistureSystem = g_currentMission.moistureSystem

        if moistureSystem == nil then return changedArea, totalArea end

        local fillType = self.spec_sprayer.workAreaParameters.sprayFillType
        local target = { ["moisture"] = MoistureSystem.SPRAY_FACTOR * (fillType == FillType.WATER and 4 or 1) }

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

        for x = x1, x2, moistureSystem.cellWidth * 0.5 do
            for z = z1, z2, moistureSystem.cellHeight * 0.5 do
                --print(x, z, "----")
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