MoistureStateEvent = {}

local moistureStateEvent_mt = Class(MoistureStateEvent, Event)
InitStaticEventClass(MoistureStateEvent, "MoistureStateEvent")


function MoistureStateEvent.emptyNew()
    return Event.new(moistureStateEvent_mt)
end


function MoistureStateEvent.new(cellWidth, cellHeight, moistureDelta, lastMoistureDelta, currentHourlyUpdateQuarter, numRows, numColumns, rows)
    local self = MoistureStateEvent.emptyNew()

    self.cellWidth, self.cellHeight, self.moistureDelta, self.lastMoistureDelta, self.currentHourlyUpdateQuarter, self.numRows, self.numColumns, self.rows = cellWidth, cellHeight, moistureDelta, lastMoistureDelta, currentHourlyUpdateQuarter, numRows, numColumns, rows

    return self
end


function MoistureStateEvent:readStream(streamId, connection)

    self.cellWidth = streamReadFloat32(streamId)
    self.cellHeight = streamReadFloat32(streamId)
    self.moistureDelta = streamReadFloat32(streamId)
    self.lastMoistureDelta = streamReadFloat32(streamId)
    self.currentHourlyUpdateQuarter = streamReadInt8(streamId)
    self.numRows = streamReadInt8(streamId)
    self.numColumns = streamReadInt8(streamId)

    local rows = {}

    if self.numRows > 0 and self.numColumns > 0 then

        for i = 1, self.numRows do

            local x = streamReadFloat32(streamId)

            local row = { [x] = x, ["columns"] = {} }

            for j = 1, self.numColumns do

                local z = streamReadFloat32(streamId)
                local moisture = streamReadFloat32(streamId)
                local witherChance = streamReadFloat32(streamId)

                row.columns[z] = { ["z"] = z, ["moisture"] = moisture, ["witherChance"] = witherChance }

            end

            rows[x] = row

        end

    end

    self.rows = rows

    self:run(connection)

end


function MoistureStateEvent:writeStream(connection, _)

    streamWriteFloat32(connection, self.cellWidth)
    streamWriteFloat32(connection, self.cellHeight)
    streamWriteFloat32(connection, self.moistureDelta or 0)
    streamWriteFloat32(connection, self.lastMoistureDelta or 0)
    streamWriteInt8(connection, self.currentHourlyUpdateQuarter or 1)
    streamWriteInt8(connection, self.numRows or 0)
    streamWriteInt8(connection, self.numColumns or 0)

    for x, row in pairs(self.rows) do

        if row.columns ~= nil then

            streamWriteFloat32(connection, x)

            for z, column in pairs(row.columns) do

                streamWriteFloat32(connection, column.z)
                streamWriteFloat32(connection, column.moisture)
                streamWriteFloat32(connection, column.witherChance or 0)

            end

        end

    end

end


function MoistureStateEvent:run(_)
    g_currentMission.moistureSystem:setInitialState(self.cellWidth, self.cellHeight, self.moistureDelta, self.lastMoistureDelta, self.currentHourlyUpdateQuarter, self.numRows, self.numColumns, self.rows)
end