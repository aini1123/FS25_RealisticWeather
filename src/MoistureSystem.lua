MoistureSystem = {}

MoistureSystem.VERSION = "1.1.2.2"

table.insert(FinanceStats.statNames, "irrigationUpkeep")
FinanceStats.statNameToIndex["irrigationUpkeep"] = #FinanceStats.statNames

MoistureSystem.CELL_WIDTH = {
    [1] = 15,
    [2] = 12,
    [3] = 10,
    [4] = 7,
    [5] = 5,
    [6] = 4
}

MoistureSystem.CELL_HEIGHT = {
    [1] = 15,
    [2] = 12,
    [3] = 10,
    [4] = 7,
    [5] = 5,
    [6] = 4
}

MoistureSystem.MAP_WIDTH = 2048
MoistureSystem.MAP_HEIGHT = 2048
MoistureSystem.TICKS_PER_UPDATE = 50
MoistureSystem.IRRIGATION_FACTOR = 0.000001
MoistureSystem.SPRAY_FACTOR = 0.00002
MoistureSystem.IRRIGATION_BASE_COST = 0.00000025

local moistureSystem_mt = Class(MoistureSystem)

function MoistureSystem.new()

    local self = setmetatable({}, moistureSystem_mt)

    self.mission = g_currentMission
    self.rows = {}
    self.isServer = self.mission:getIsServer()
    self.lastMoistureDelta = 0
    self.ticksSinceLastUpdate = MoistureSystem.TICKS_PER_UPDATE + 1
    self.currentHourlyUpdateQuarter = 1
    self.numRows = 0
    self.numColumns = 0
    self.cellWidth, self.cellHeight = MoistureSystem.CELL_WIDTH[4], MoistureSystem.CELL_HEIGHT[4]
    self.mapWidth, self.mapHeight = MoistureSystem.MAP_WIDTH, MoistureSystem.MAP_HEIGHT
    self.isShowingIrrigationInput = false
    self.irrigationEventId = RW_PlayerInputComponent.IRRIGATION_EVENT_ID
    self.isSaving = false

    self.pendingIrrigationCosts = 0
    self.irrigatingFields = {}
    self.irrigationInputField = nil

    self.needsSync = false

    self.witheringEnabled = true
    self.witheringChance = 1
    self.performanceIndex = 2
    self.moistureGainModifier = 1
    self.moistureLossModifier = 1
    self.moistureOverlayBehaviour = 3
    self.moistureFrameBehaviour = 1

    self.currentUpdateIteration = 1
    self.updateIterations = {
        {
            ["moistureDelta"] = 0,
            ["timeSinceLastUpdate"] = 0
        },
        {
            ["moistureDelta"] = 0,
            ["timeSinceLastUpdate"] = 0
        }
    }

    MoneyType.IRRIGATION_UPKEEP = MoneyType.register("irrigationUpkeep", "rw_ui_irrigationUpkeep")
    MoneyType.LAST_ID = MoneyType.LAST_ID + 1

    g_messageCenter:subscribe(MessageType.HOUR_CHANGED, self.onHourChanged, self)
    g_messageCenter:subscribe(MessageType.DAY_CHANGED, self.onDayChanged, self)
    g_messageCenter:subscribe(MessageType.OWN_PLAYER_ENTERED, self.onEnterVehicle, self)
    g_messageCenter:subscribe(MessageType.OWN_PLAYER_LEFT, self.onLeaveVehicle, self)

    return self

end


function MoistureSystem:delete()
    self = nil
end


function MoistureSystem:saveToXMLFile(path)

    if path == nil then return end

    local xmlFile = XMLFile.create("moistureXML", path, "moisture")
    if xmlFile == nil then return end

    self.isSaving = true

    local key = "moisture"

    xmlFile:setFloat(key .. "#cellWidth", self.cellWidth or 5)
    xmlFile:setFloat(key .. "#cellHeight", self.cellHeight or 5)
    xmlFile:setFloat(key .. "#mapWidth", self.mapWidth or 2048)
    xmlFile:setFloat(key .. "#mapHeight", self.mapHeight or 2048)

    xmlFile:setTable(key .. ".irrigation.field", self.irrigatingFields, function (irrigationKey, field)

        xmlFile:setInt(irrigationKey .. "#id", field.id)
        xmlFile:setFloat(irrigationKey .. "#pending", field.pendingCost)
        xmlFile:setBool(irrigationKey .. "#active", field.isActive)

    end)

    xmlFile:setTable(key .. ".rows.row", self.rows, function (rowKey, row)

        xmlFile:setFloat(rowKey .. "#x", row.x)

        xmlFile:setTable(rowKey .. ".columns.column", row.columns, function (columnKey, column)

            xmlFile:setFloat(columnKey .. "#z", column.z)
            xmlFile:setFloat(columnKey .. "#m", column.moisture)
            xmlFile:setFloat(columnKey .. "#r", column.retention)
            xmlFile:setFloat(columnKey .. "#t", column.trend)
            if column.witherChance ~= nil and column.witherChance ~= 0 then xmlFile:setFloat(columnKey .. "#w", column.witherChance) end

        end)

    end)

    xmlFile:save(false, true)

    self.isSaving = false

end


function MoistureSystem:loadFromXMLFile(mapXmlFile)

    local savegameIndex = g_careerScreen.savegameList.selectedIndex
    local savegame = g_savegameController:getSavegame(savegameIndex)

    if savegame == nil or savegame.savegameDirectory == nil then
        self:generateNewMapMoisture(mapXmlFile)
        table.sort(self.rows)
        return
    end

    local path = savegame.savegameDirectory .. "/moisture.xml"

    local xmlFile = XMLFile.loadIfExists("moistureXML", path)

    if xmlFile == nil then

        self:generateNewMapMoisture(mapXmlFile)

    else

        local numRows = 0
        local numColumns = 0
        local key = "moisture"

        self.cellWidth, self.cellHeight = xmlFile:getFloat(key .. "#cellWidth", 5), xmlFile:getFloat(key .. "#cellHeight", 5)
        self.mapWidth, self.mapHeight = xmlFile:getFloat(key .. "#mapWidth", 2048), xmlFile:getFloat(key .. "#mapHeight", 2048)

        xmlFile:iterate(key .. ".irrigation.field", function (_, irrigationKey)

            local id = xmlFile:getInt(irrigationKey .. "#id", 1)

            local field = {
                ["id"] = id,
                ["pendingCost"] = xmlFile:getFloat(irrigationKey .. "#pending", 0),
                ["isActive"] = xmlFile:getBool(irrigationKey .. "#active", true)
            }

            self.irrigatingFields[id] = field

        end)

        xmlFile:iterate(key .. ".rows.row", function (_, rowKey)

            local x = xmlFile:getFloat(rowKey .. "#x", 0)

            local row = { ["x"] = x, ["columns"] = {} }

            xmlFile:iterate(rowKey .. ".columns.column", function (_, columnKey)

                local z = xmlFile:getFloat(columnKey .. "#z", 0)
                local moisture = xmlFile:getFloat(columnKey .. "#m", 0)
                local retention = xmlFile:getFloat(columnKey .. "#r", 1)
                local trend = xmlFile:getFloat(columnKey .. "#t", moisture)
                local witherChance = xmlFile:getFloat(columnKey .. "#w", 0)

                if numRows == 0 then numColumns = numColumns + 1 end

                row.columns[z] = { ["z"] = z, ["moisture"] = math.clamp(moisture, 0, 1), ["witherChance"] = witherChance, ["retention"] = retention, ["trend"] = trend }

            end)

            self.rows[x] = row
            numRows = numRows + 1

        end)

        self.numRows = numRows
        self.numColumns = numColumns

        xmlFile:delete()

    end

    table.sort(self.rows)

end


function MoistureSystem:sendInitialState(connection)

    --connection:sendEvent(MoistureStateEvent.new(self.cellWidth, self.cellHeight, self.moistureDelta, self.lastMoistureDelta, self.currentHourlyUpdateQuarter, self.numRows, self.numColumns, self.rows))

end


function MoistureSystem:setInitialState(cellWidth, cellHeight, mapWidth, mapHeight, currentHourlyUpdateQuarter, numRows, numColumns, rows, irrigatingFields)

    self.cellWidth, self.cellHeight, self.mapWidth, self.mapHeight, self.currentHourlyUpdateQuarter, self.numRows, self.numColumns, self.rows, self.irrigatingFields = cellWidth, cellHeight, mapWidth, mapHeight, currentHourlyUpdateQuarter, numRows, numColumns, rows, irrigatingFields

end


function MoistureSystem:generateNewMapMoisture(xmlFile, force)

    print(string.format("--- RealisticWeather (%s) ---", MoistureSystem.VERSION), "--- Generating map moisture cell system")

    if not force then

        if xmlFile == nil then return end

        local performanceIndex = Utils.getPerformanceClassId()

        if g_server ~= nil and g_server.netIsRunning and performanceIndex <= 3 then
            performanceIndex = 4
            print("--- Generating on server mode")
        end

        self.cellWidth, self.cellHeight = MoistureSystem.CELL_WIDTH[performanceIndex], MoistureSystem.CELL_HEIGHT[performanceIndex]

        local width, height = getXMLInt(xmlFile, "map#width"), getXMLInt(xmlFile, "map#height")

        self.mapWidth, self.mapHeight = width, height
        self.cellWidth, self.cellHeight = self.cellWidth * (self.mapWidth / 2048), self.cellHeight * (self.mapHeight / 2048)
    
    else

        print("--- Force deleting and rebuilding moisture map")

        self.rows = {}
        self.isSaving = true
        
        for _, updateIteration in pairs(self.updateIterations) do
            updateIteration.moistureDelta = 0
            updateIteration.timeSinceLastUpdate = 0
        end

        self.currentUpdateIteration = 1

        for _, irrigatingField in pairs(self.irrigatingFields) do irrigatingField.isActive = false end

    end

    print(string.format("--- Map dimensions: %sx%s", self.mapWidth, self.mapHeight), string.format("--- Cell dimensions: %sx%s", self.cellWidth, self.cellHeight))

    local firstRow = true
    local numRows = 0
    local numColumns = 0
    local baseMoisture = math.random(100, 150) / 1000
    local i = 0


    for x = -self.mapWidth / 2, self.mapWidth / 2, self.cellWidth do

        local row = { ["x"] = x, ["columns"] = {} }

        local firstColumn = true

        local currentTime = tonumber(getDate("%Y%m%d%H%M%S") or "10000000")
        i = i + math.random() * (x + 1.5 * math.abs(x))

        math.randomseed(i + currentTime)

        for z = -self.mapHeight / 2, self.mapHeight / 2, self.cellHeight do

            local moisture

            if firstRow then numColumns = numColumns + 1 end

            local isIncrease = math.random() >= 0.5

            if firstRow and firstColumn then
                firstColumn = false
                moisture = (isIncrease and math.random(baseMoisture * 1000, baseMoisture * 1012) or math.random(baseMoisture * 988, baseMoisture * 1000)) / 1000
            else

                if firstColumn then

                    firstColumn = false

                    local downMoisture = self.rows[x - self.cellWidth].columns[z].moisture
                    moisture = (isIncrease and math.random(downMoisture * 1000, downMoisture * 1012) or math.random(downMoisture * 988, downMoisture * 1000)) / 1000

                elseif firstRow then

                    local leftMoisture = row.columns[z - self.cellHeight].moisture
                    moisture = (isIncrease and math.random(leftMoisture * 1000, leftMoisture * 1012) or math.random(leftMoisture * 988, leftMoisture * 1000)) / 1000

                else

                    local leftMoisture = row.columns[z - self.cellHeight].moisture * 1000
                    local downMoisture = self.rows[x - self.cellWidth].columns[z].moisture * 1000

                    if leftMoisture > downMoisture then
                        moisture = (isIncrease and math.random(downMoisture * 1, leftMoisture * 1.012) or math.random(downMoisture * 0.988, leftMoisture * 1)) / 1000
                    else
                        moisture = (isIncrease and math.random(leftMoisture * 1, downMoisture * 1.012) or math.random(leftMoisture * 0.988, downMoisture * 1)) / 1000
                    end

                end

            end

            moisture = math.clamp(moisture, 0, 1)
            moisture = math.clamp(moisture, baseMoisture * 0.25, baseMoisture * 1.75)

            row.columns[z] = { ["z"] = z, ["moisture"] = moisture, ["witherChance"] = 0, ["retention"] = math.clamp(moisture / baseMoisture, 0.25, 1.75), ["trend"] = moisture }

        end

        self.rows[x] = row
        numRows = numRows + 1
        firstRow = false

    end

    self.numRows = numRows
    self.numColumns = numColumns
    self.isSaving = false

    print(string.format("--- Generated %s rows with %s columns each", numRows, numColumns))

end


function MoistureSystem:getValuesAtCoords(x, z, values)

    if values == nil or #values == 0 or self.isSaving then return nil end

    local rX, rZ = math.round(x), math.round(z)
    local row = self.rows[rX]

    if row == nil then

        for i = -self.cellWidth + 1, self.cellWidth - 1 do
            if self.rows[rX + i] ~= nil then
                row = self.rows[rX + i]
                break
            end
        end

    end

    if row == nil or row.columns == nil then return nil end

    local column = row.columns[rZ]

    if column == nil then

        for i = -self.cellHeight + 1, self.cellHeight - 1 do
            if row.columns[rZ + i] ~= nil then
                column = row.columns[rZ + i]
                break
            end
        end

    end

    if column ~= nil then

        local returnValues = {}

        for _, value in pairs(values) do

            returnValues[value] = value == "retention" and column[value] or math.clamp(column[value] or 0, 0, 1)
            if value == "moisture" then
                    
                local delta = self:getUpdaterAtX(row.x).moistureDelta

                -- updateIterations 4
                -- mapWidth 2048
                -- boundaries = 0, 512, 1024, 1536
                -- boundaries = -1024 - -512, -512 - 0, 0 - 512, 512 - 1024

                local safeZoneFactor = 1

                if column.moisture < 0.06 and delta < 0 then
                    safeZoneFactor = (2 - column.retention) * column.moisture * 20
                end

                if column.moisture > 0.275 and delta > 0 then
                    safeZoneFactor = (column.retention / column.moisture) * 0.05
                end

                if delta >= 0 then
                    returnValues[value] = returnValues[value] + delta * column.retention * safeZoneFactor
                else
                    returnValues[value] = returnValues[value] + delta * (2 - column.retention) * safeZoneFactor
                end
            end

            if not self.witheringEnabled and value == "witherChance" then returnValues[value] = 0 end
        end

        return returnValues

    end

    return nil

end


function MoistureSystem:setValuesAtCoords(x, z, values)

    if values == nil or self.isSaving then return end

    local rX, rZ = math.round(x), math.round(z)
    local row

    for i = -self.cellWidth + 1, self.cellWidth - 1 do
        if self.rows[rX + i] ~= nil then
            row = self.rows[rX + i]
            break
        end
    end

    if row == nil or row.columns == nil then return end

    for i = -self.cellHeight + 1, self.cellHeight - 1 do
        if row.columns[rZ + i] ~= nil then
            local column = row.columns[rZ + i]

            for target, value in pairs(values) do
                if column[target] == nil then
                    column[target] = value
                else
                    column[target] = math.clamp(column[target] + value, 0, 1)
                end
            end

            return
        end
    end

    return

end


function MoistureSystem:update(delta, timescale)

    for _, updateIteration in pairs(self.updateIterations) do
        updateIteration.moistureDelta = updateIteration.moistureDelta + delta
        updateIteration.timeSinceLastUpdate = updateIteration.timeSinceLastUpdate + timescale / (MoistureSystem.TICKS_PER_UPDATE)
    end

    local puddleSystem = g_currentMission.puddleSystem

    if self.ticksSinceLastUpdate >= MoistureSystem.TICKS_PER_UPDATE and not self.isSaving then

        local canCreatePuddle = puddleSystem:getCanCreatePuddle()
        local isIrrigatingFields = false
        local fieldGroundSystem = g_currentMission.fieldGroundSystem

        for _, field in pairs(self.irrigatingFields) do
            if field.isActive then
                isIrrigatingFields = true
                break
            end
        end

        local maxRows = self.numRows / #self.updateIterations
        local i = 0

        if self.currentUpdateIteration > #self.updateIterations then self.currentUpdateIteration = 1 end
        
        local updaterWidth = self.mapWidth / #self.updateIterations
        local x = -self.mapWidth / 2 + (self.currentUpdateIteration - 1) * updaterWidth

        local moistureDelta = self.updateIterations[self.currentUpdateIteration].moistureDelta
        local timeSinceLastUpdate = self.updateIterations[self.currentUpdateIteration].timeSinceLastUpdate

        x = math.round(x)

        for correctionOffset = -self.cellWidth, self.cellWidth do
            if self.rows[x + correctionOffset] ~= nil then
                x = x + correctionOffset
                break
            end
        end

        if self.rows[x] ~= nil then

            while i <= maxRows do

                local row = self.rows[x]

                if row == nil then break end

                if row.columns == nil then
                    i = i + 1
                    x = x + self.cellWidth
                    continue
                end

                for z, column in pairs(row.columns) do

                    local irrigationFactor = 0
                    local fieldId

                    if isIrrigatingFields then

                        local fieldId = g_farmlandManager:getFarmlandIdAtWorldPosition(x, z)

                        if fieldId ~= nil and self.irrigatingFields[fieldId] ~= nil and self.irrigatingFields[fieldId].isActive then

                            irrigationFactor = MoistureSystem.IRRIGATION_FACTOR * timeSinceLastUpdate * self.moistureGainModifier
                            self.irrigatingFields[fieldId].pendingCost = self.irrigatingFields[fieldId].pendingCost + self.cellWidth * self.cellHeight * timeSinceLastUpdate * MoistureSystem.IRRIGATION_BASE_COST

                        end

                    end


                    -- "safeZoneFactor" to reduce the chances of moisture going to extreme highs/lows based on retention

                    local safeZoneFactor = 1

                    if column.moisture < 0.06 and moistureDelta < 0 then
                        safeZoneFactor = (2 - column.retention) * column.moisture * 20
                    end

                    if column.moisture > 0.275 and moistureDelta > 0 then
                        safeZoneFactor = (column.retention / column.moisture) * 0.05
                    end

                    if moistureDelta >= 0 then
                        column.moisture = column.moisture + irrigationFactor * column.retention + moistureDelta * column.retention * safeZoneFactor
                    else
                        column.moisture = column.moisture + irrigationFactor * column.retention + moistureDelta * (2 - column.retention) * safeZoneFactor
                    end


                    if column.moisture >= 0.3 and canCreatePuddle then
                        
                        local groundTypeValue = fieldGroundSystem:getValueAtWorldPos(FieldDensityMap.GROUND_TYPE, x, 0, z)
                        local groundType = FieldGroundType.getTypeByValue(groundTypeValue)

                        if groundType ~= FieldGroundType.NONE then

                            local closestPuddle = puddleSystem:getClosestPuddleToPoint(x, z)

                            if closestPuddle.puddle == nil or closestPuddle.distance > 100 then

                                canCreatePuddle = false

                                local terrainHeight = getTerrainHeightAtWorldPos(g_terrainNode, x, 0, z)

                                local variation = puddleSystem:getRandomVariation()

                                local puddle = Puddle.new(variation.id, terrainHeight)

                                puddleSystem:addPuddle(puddle)

                                puddle:setMoisture(column.moisture)
                                puddle:setPosition(x, terrainHeight + math.clamp((column.moisture - 0.3) * 0.25, 0, 0.2), z)
                                puddle:setScale(column.moisture - 0.3, column.moisture - 0.3)
                                puddle:setRotation(0, math.random(-180, 180) * 0.01, 0)
                                puddle:initialize()

                                NewPuddleEvent.sendEvent(puddle)

                            end

                        end

                    end


                end

                i = i + 1
                x = x + self.cellWidth

            end

        end

        self.lastMoistureDelta = self.updateIterations[self.currentUpdateIteration].moistureDelta * 1

        self.updateIterations[self.currentUpdateIteration].moistureDelta = 0
        self.updateIterations[self.currentUpdateIteration].timeSinceLastUpdate = 0

        self.moistureDelta = 0
        self.ticksSinceLastUpdate = 0
        self.timeSinceLastUpdate = 0
        self.currentUpdateIteration = self.currentUpdateIteration + 1

        if self.currentUpdateIteration > #self.updateIterations then self.currentUpdateIteration = 1 end

        puddleSystem:update(timescale, self)

    else
        puddleSystem.timeSinceLastUpdate = puddleSystem.timeSinceLastUpdate + timescale
    end

    self.ticksSinceLastUpdate = self.ticksSinceLastUpdate + 1

end


function MoistureSystem:onDayChanged()

    for _, row in pairs(self.rows) do
        for _, column in pairs(row.columns) do column.trend = column.moisture end
    end

    if self.isServer then

        for id, field in pairs(self.irrigatingFields) do

            if field.pendingCost <= 0 then continue end

            local ownerFarmId = g_farmlandManager:getFarmlandOwner(id)

            if ownerFarmId == nil or ownerFarmId == FarmlandManager.NO_OWNER_FARM_ID or ownerFarmId == FarmManager.SPECTATOR_FARM_ID or ownerFarmId == FarmManager.INVALID_FARM_ID then
                field.pendingCost = 0
                continue
            end

            local ownerFarm = g_farmManager:getFarmById(ownerFarmId)

            if ownerFarm == nil then
                field.pendingCost = 0
                continue
            end

            g_currentMission:addMoneyChange(0 - field.pendingCost, ownerFarmId, MoneyType.IRRIGATION_UPKEEP, true)
            ownerFarm:changeBalance(0 - field.pendingCost, MoneyType.IRRIGATION_UPKEEP)

            field.pendingCost = 0

        end

    else

        for id, field in pairs(self.irrigatingFields) do field.pendingCost = 0 end

    end

end


function MoistureSystem:onHourChanged()

    if self.isSaving then return end

    if not self.witheringEnabled then
        if self.isServer and self.needsSync and g_server ~= nil and g_server.netIsRunning then

            self.needsSync = false
            g_server:broadcastEvent(MoistureSyncEvent.new(self.numRows, self.numColumns, self.rows), false)

        end
        return
    end

    local i = 0
    local maxRows = self.numRows / 4

    local x = -self.mapWidth / 2

    if self.currentHourlyUpdateQuarter > 1 then
        x = x + self.cellWidth * self.numRows * ((self.currentHourlyUpdateQuarter - 1) / 4)
    end

    x = math.round(x)

    for correctionOffset = -self.cellWidth, self.cellWidth do
        if self.rows[x + correctionOffset] ~= nil then
            x = x + correctionOffset
            break
        end
    end

    -- a maximum number of withering cells per hour is required otherwise the game has massive lag spikes, especially during/after droughts
    -- REDUCE "maxWithers" IF YOU ARE EXPERIENCING HOURLY LAG

    local maxWithers = math.round(self.numRows * self.numColumns * 0.25 * 0.03)
    local timeSinceLastRain = MathUtil.msToMinutes(g_currentMission.environment.weather.timeSinceLastRain)

    if self.rows[x] ~= nil then

        while i <= maxRows do

            local row = self.rows[x]

            if row == nil then break end

            if row.columns == nil then
                i = i + 1
                x = x + self.cellWidth
                continue
            end

            for z, column in pairs(row.columns) do

                local fruitTypeIndex, densityState = FSDensityMapUtil.getFruitTypeIndexAtWorldPos(x, z)

                if fruitTypeIndex == nil or column.moisture >= 0.08 or densityState == nil then
                    column.witherChance = 0
                    continue
                end

                local fruitType = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
                local fruitTypeName = fruitType.name

                if RW_FSBaseMission.FRUIT_TYPES_MOISTURE[fruitTypeName] == nil or fruitTypeName == "GRASS" or fruitType:getIsCut(densityState) or fruitType:getIsWithered(densityState) then
                    column.witherChance = 0
                    continue
                end

                local lowMoisture = RW_FSBaseMission.FRUIT_TYPES_MOISTURE[fruitTypeName].LOW

                if column.moisture >= lowMoisture * 0.33 then
                    column.witherChance = 0
                    continue
                end

                local witherChance = column.witherChance or 0

                witherChance = witherChance + ((lowMoisture * 0.25 - column.moisture) / (lowMoisture * 4)) * 0.25 * self.witheringChance

                witherChance = math.clamp(witherChance, 0, 1)

                if self.isServer and witherChance > 0 and maxWithers > 0 and timeSinceLastRain > 60 then

                    if math.random() < witherChance then

                        local width = self.cellWidth * math.random()
                        local height = self.cellHeight * math.random()
                        local offsetX = x + self.cellWidth * math.random()
                        local offsetZ = z + self.cellHeight * math.random()

                        RWUtils.witherArea(offsetX, offsetZ, math.clamp(offsetX + width, offsetX, x + self.cellWidth), offsetZ, offsetX, math.clamp(offsetZ + height, offsetZ, z + self.cellHeight))
                        --FSDensityMapUtil.updateWheelDestructionArea(offsetX, offsetZ, math.clamp(offsetX + width, offsetX, x + self.cellWidth), offsetZ, offsetX, math.clamp(offsetZ + height, offsetZ, z + self.cellHeight))
                        maxWithers = maxWithers - 1

                    end

                end

                column.witherChance = witherChance

            end

            i = i + 1
            x = x + self.cellWidth

        end

    end

    self.currentHourlyUpdateQuarter = self.currentHourlyUpdateQuarter >= 4 and 1 or (self.currentHourlyUpdateQuarter + 1)



    if self.isServer and self.needsSync and g_server ~= nil and g_server.netIsRunning then

        self.needsSync = false
        g_server:broadcastEvent(MoistureSyncEvent.new(self.numRows, self.numColumns, self.rows), false)

    end


end


function MoistureSystem.irrigationInputCallback()

    local moistureSystem = g_currentMission.moistureSystem
    if moistureSystem == nil or g_inputBinding:getContextName() ~= PlayerInputComponent.INPUT_CONTEXT_NAME then return end

    local id = moistureSystem:getIrrigationInputField()

    moistureSystem:setFieldIrrigationState(id)

end


function MoistureSystem:setFieldIrrigationState(id)

    if id == nil then return end

    if self.irrigatingFields[id] ~= nil then

        local field = self.irrigatingFields[id]

        if field.isActive and field.pendingCost <= 0 then

            if g_client ~= nil then FieldIrrigationChangeEvent.sendEvent(id, true) end

            table.removeElement(self.irrigatingFields, id)
            return

        end

        if g_client ~= nil then FieldIrrigationChangeEvent.sendEvent(id, false, not field.isActive) end

        field.isActive = not field.isActive

        return

    end

    if g_client ~= nil then FieldIrrigationChangeEvent.sendEvent(id, false, true, true) end

    self.irrigatingFields[id] = {
        ["id"] = id,
        ["pendingCost"] = 0,
        ["isActive"] = true
    }

end


function MoistureSystem:setIrrigationInputField(id)

    self.irrigationInputField = id

end


function MoistureSystem:getIrrigationInputField()

    return self.irrigationInputField

end


function MoistureSystem:getIsFieldBeingIrrigated(id)

    if self.irrigatingFields[id] ~= nil then return self.irrigatingFields[id].isActive, self.irrigatingFields[id].pendingCost end

    return false, 0

end


function MoistureSystem:onEnterVehicle()
    self.isShowingIrrigationInput = false
    g_inputBinding:setActionEventActive(self.irrigationEventId, false)
end


function MoistureSystem:onLeaveVehicle()
    g_inputBinding:setActionEventActive(self.irrigationEventId, true)
end


function MoistureSystem:getCellsInsidePolygon(polygon)

    local cells = {}
	local cx, cz = 0, 0

	for i = 1, #polygon, 2 do

		local x, z = polygon[i], polygon[i + 1]

		if x == nil or z == nil then break end

		cx = cx + x
		cz = cz + z

	end

	cx = cx / (#polygon / 2)
	cz = cz / (#polygon / 2)

	for i = 1, #polygon, 2 do

		local x, z = polygon[i], polygon[i + 1]

		if x == nil or z == nil then break end

		local nextX = polygon[i + 2] or polygon[1]
		local nextZ = polygon[i + 3] or polygon[2]
		
		local minX, maxX = math.round(math.min(x, nextX, cx)), math.round(math.max(x, nextX, cx))
		local minZ, maxZ = math.round(math.min(z, nextZ, cz)), math.round(math.max(z, nextZ, cz))
	

		for px = minX, maxX, self.cellWidth do

            local row = self.rows[px]

            local rowOffset = 1
            while row == nil and rowOffset < self.cellWidth do
                
                row = self.rows[px - rowOffset]
                rowOffset = rowOffset + 1

            end

            if row == nil then break end
		
			for pz = minZ, maxZ, self.cellHeight do

                local column = row.columns[pz]

                local columnOffset = 1
                while column == nil and columnOffset < self.cellHeight do
                
                    column = row.columns[pz - columnOffset]
                    columnOffset = columnOffset + 1

                end

                if column == nil then break end

                local cell = self:getValuesAtCoords(row.x, column.z, { "moisture", "retention", "trend", "witherChance" })

                --local cell = {
                    --["x"] = row.x,
                    --["z"] = column.z,
                    --["moisture"] = column.moisture,
                    --["retention"] = column.retention,
                    --["trend"] = column.trend,
                    --["witherChance"] = self.witheringEnabled and column.witherChance or 0
                --}

                cell.x = row.x
                cell.z = column.z

                table.insert(cells, cell)

			end

		end

	end

	return cells

end


function MoistureSystem.onSettingChanged(name, state)

    local moistureSystem = g_currentMission.moistureSystem

    if moistureSystem == nil then return end

    moistureSystem[name] = state

    if name == "performanceIndex" then

        moistureSystem.currentUpdateIteration = 1
        moistureSystem.updateIterations = {}

        for i = 1, state * state do
            table.insert(moistureSystem.updateIterations, {
                ["moistureDelta"] = 0,
                ["timeSinceLastUpdate"] = 0
            })
        end

    end

end


function MoistureSystem.onClickRebuildMoistureMap()
    
    MoistureArgumentsDialog.show()

end


function MoistureSystem:getUpdaterAtX(x)

    local updater = math.floor((x + self.mapWidth / 2) / (self.mapWidth / #self.updateIterations) + 1)

    return self.updateIterations[updater or 1] or self.updateIterations[1]

end