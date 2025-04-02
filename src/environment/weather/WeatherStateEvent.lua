RW_WeatherStateEvent = {}


function RW_WeatherStateEvent.new(snowHeight, timeSinceLastRain, cellWidth, cellHeight, mapWidth, mapHeight, currentHourlyUpdateQuarter, numRows, numColumns, rows, irrigatingFields)
    local self = WeatherStateEvent.emptyNew()
    self.snowHeight = snowHeight
    self.timeSinceLastRain = timeSinceLastRain
    --self.moisture = moisture

    self.cellWidth, self.cellHeight, self.mapWidth, self.mapHeight, self.currentHourlyUpdateQuarter, self.numRows, self.numColumns, self.rows, self.irrigatingFields = cellWidth, cellHeight, mapWidth, mapHeight, currentHourlyUpdateQuarter, numRows, numColumns, rows, irrigatingFields
    return self
end

WeatherStateEvent.new = RW_WeatherStateEvent.new


function RW_WeatherStateEvent:readStream(_, streamId, connection)
    self.snowHeight = streamReadFloat32(streamId)
    self.timeSinceLastRain = streamReadFloat32(streamId)
    --self.moisture = streamReadFloat32(streamId)

    self.cellWidth = streamReadFloat32(streamId)
    self.cellHeight = streamReadFloat32(streamId)
    self.mapWidth = streamReadFloat32(streamId)
    self.mapHeight = streamReadFloat32(streamId)
    --self.moistureDeltaLower = streamReadFloat32(streamId)
    --self.moistureDeltaUpper = streamReadFloat32(streamId)
    --self.lastMoistureDelta = streamReadFloat32(streamId)
    self.currentHourlyUpdateQuarter = streamReadUInt8(streamId)
    self.numRows = streamReadUInt16(streamId)
    self.numColumns = streamReadUInt16(streamId)

    local rows = {}

    if self.numRows > 0 and self.numColumns > 0 then

        for i = 1, self.numRows do

            local x = streamReadFloat32(streamId)

            local row = { ["x"] = x, ["columns"] = {} }

            for j = 1, self.numColumns do

                local z = streamReadFloat32(streamId)
                local moisture = streamReadFloat32(streamId)
                local retention = streamReadFloat32(streamId)
                local trend = streamReadFloat32(streamId)
                local witherChance = streamReadFloat32(streamId)

                row.columns[z] = { ["z"] = z, ["moisture"] = moisture, ["witherChance"] = witherChance, ["retention"] = retention, ["trend"] = trend }

            end

            rows[x] = row

        end

    end

    self.rows = rows

    local numIrrigatingFields = streamReadUInt16(streamId)

    local irrigatingFields = {}

    if numIrrigatingFields > 0 then

        for i = 1, numIrrigatingFields do

            local id = streamReadUInt16(streamId)
            local pendingCost = streamReadFloat32(streamId)
            local isActive = streamReadBool(streamId)

            irrigatingFields[id] = {
                ["id"] = id,
                ["pendingCost"] = pendingCost,
                ["isActive"] = isActive
            }

        end

    end

    self.irrigatingFields = irrigatingFields

    self:run(connection)
end

WeatherStateEvent.readStream = Utils.overwrittenFunction(WeatherStateEvent.readStream, RW_WeatherStateEvent.readStream)


function RW_WeatherStateEvent:writeStream(_, connection, _)
    streamWriteFloat32(connection, self.snowHeight)
    streamWriteFloat32(connection, self.timeSinceLastRain)
    --streamWriteFloat32(connection, self.moisture)

    streamWriteFloat32(connection, self.cellWidth or 5)
    streamWriteFloat32(connection, self.cellHeight or 5)
    streamWriteFloat32(connection, self.mapWidth or 2048)
    streamWriteFloat32(connection, self.mapHeight or 2048)
    --streamWriteFloat32(connection, self.moistureDeltaLower or 0)
    --streamWriteFloat32(connection, self.moistureDeltaUpper or 0)
    --streamWriteFloat32(connection, self.lastMoistureDelta or 0)
    streamWriteUInt8(connection, self.currentHourlyUpdateQuarter or 1)
    streamWriteUInt16(connection, self.numRows or 0)
    streamWriteUInt16(connection, self.numColumns or 0)

    if self.rows ~= nil then

        for x, row in pairs(self.rows) do

            if row.columns ~= nil then

                streamWriteFloat32(connection, x)

                for z, column in pairs(row.columns) do

                    streamWriteFloat32(connection, column.z)
                    streamWriteFloat32(connection, column.moisture)
                    streamWriteFloat32(connection, column.retention)
                    streamWriteFloat32(connection, column.trend)
                    streamWriteFloat32(connection, column.witherChance or 0)

                end

            end

        end

    end


    if self.irrigatingFields ~= nil then

        local numIrrigatingFields = 0

        for _, field in pairs(self.irrigatingFields) do numIrrigatingFields = numIrrigatingFields + 1 end

        streamWriteUInt16(connection, numIrrigatingFields)

        for id, field in pairs(self.irrigatingFields) do
            streamWriteUInt16(connection, id)
            streamWriteFloat32(connection, field.pendingCost or 0)
            streamWriteBool(connection, field.isActive or false)
        end

    else
        streamWriteUInt16(connection, 0)
    end

end

WeatherStateEvent.writeStream = Utils.overwrittenFunction(WeatherStateEvent.writeStream, RW_WeatherStateEvent.writeStream)


function RW_WeatherStateEvent:run(_, _)
    g_currentMission.environment.weather:setInitialState(self.snowHeight, self.timeSinceLastRain)
    g_currentMission.moistureSystem:setInitialState(self.cellWidth, self.cellHeight, self.mapWidth, self.mapHeight, self.currentHourlyUpdateQuarter, self.numRows, self.numColumns, self.rows, self.irrigatingFields)
end

WeatherStateEvent.run = Utils.overwrittenFunction(WeatherStateEvent.run, RW_WeatherStateEvent.run)