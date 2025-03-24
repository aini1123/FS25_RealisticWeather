MoistureSyncEvent = {}
local moistureSyncEvent_mt = Class(MoistureSyncEvent, Event)
InitEventClass(MoistureSyncEvent, "MoistureSyncEvent")


function MoistureSyncEvent.emptyNew()
    local self = Event.new(moistureSyncEvent_mt)
    return self
end


function MoistureSyncEvent.new(numRows, numColumns, rows)

    local self = MoistureSyncEvent.emptyNew()

    self.numRows = numRows
    self.numColumns = numColumns
    self.rows = rows

    return self

end


function MoistureSyncEvent:readStream(streamId, connection)

    self.numRows = streamReadUInt16(streamId)
    self.numColumns = streamReadUInt16(streamId)

    local rows = {}

    if self.numRows > 0 and self.numColumns > 0 then

        for i = 1, self.numRows do

            local x = streamReadFloat32(streamId)

            local row = { [x] = x, ["columns"] = {} }

            for j = 1, self.numColumns do

                local z = streamReadFloat32(streamId)
                local moisture = streamReadFloat32(streamId)
                local retention = streamReadFloat32(streamId)
                local witherChance = streamReadFloat32(streamId)

                row.columns[z] = { ["z"] = z, ["moisture"] = moisture, ["witherChance"] = witherChance, ["retention"] = retention }

            end

            rows[x] = row

        end

    end

    self.rows = rows

end


function MoistureSyncEvent:writeStream(streamId, connection)

    streamWriteUInt16(streamId, self.numRows or 0)
    streamWriteUInt16(streamId, self.numColumns or 0)

    if self.rows ~= nil then

        for x, row in pairs(self.rows) do

            if row.columns ~= nil then

                streamWriteFloat32(streamId, x)

                for z, column in pairs(row.columns) do

                    streamWriteFloat32(streamId, column.z)
                    streamWriteFloat32(streamId, column.moisture)
                    streamWriteFloat32(streamId, column.retention)
                    streamWriteFloat32(streamId, column.witherChance or 0)

                end

            end

        end

    end

end


function MoistureSyncEvent:run(connection)

    local moistureSystem = g_currentMission.moistureSystem

    if moistureSystem == nil then return end

    moistureSystem.numRows = self.numRows
    moistureSystem.numColumns = self.numColumns
    moistureSystem.rows = self.rows

end