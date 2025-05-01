MoistureSyncEvent = {}
local moistureSyncEvent_mt = Class(MoistureSyncEvent, Event)
InitEventClass(MoistureSyncEvent, "MoistureSyncEvent")


function MoistureSyncEvent.emptyNew()
    local self = Event.new(moistureSyncEvent_mt)
    return self
end


function MoistureSyncEvent.new(rows, isReset)

    local self = MoistureSyncEvent.emptyNew()

    self.rows = rows
    self.isReset = isReset or false

    return self

end


function MoistureSyncEvent:readStream(streamId, connection)

    self.isReset = streamReadBool(streamId)
    local rows = {}

    if self.isReset then

        local numRows = streamReadUInt16(streamId)
        local numColumns = streamReadUInt16(streamId)
        local cellWidth = streamReadUInt8(streamId)
        local cellHeight = streamReadUInt8(streamId)

        for i = 1, numRows do

            local x = streamReadFloat32(streamId)
            local row = { ["x"] = x, ["columns"] = {} }

            for j = 1, numColumns do

                local z = streamReadFloat32(streamId)
                local moisture = streamReadFloat32(streamId)
                local retention = streamReadFloat32(streamId)
                local trend = streamReadFloat32(streamId)
                local witherChance = streamReadFloat32(streamId)

                row.columns[z] = {
                    ["z"] = z,
                    ["moisture"] = moisture,
                    ["retention"] = retention,
                    ["trend"] = trend,
                    ["witherChance"] = witherChance
                }

            end

            rows[x] = row

        end

        self.numRows = numRows
        self.numColumns = numColumns
        self.cellWidth = cellWidth
        self.cellHeight = cellHeight

    else

        local numRows = streamReadUInt16(streamId)

        for i = 1, numRows do

            local numColumns = streamReadUInt16(streamId)
            local x = streamReadFloat32(streamId)

            for j = 1, numColumns do

                local z = streamReadFloat32(streamId)

                local numTargets = streamReadUInt8(streamId)
                local targets = {}

                for j = 1, numTargets do

                    local target = streamReadString(streamId)
                    local value = streamReadFloat32(streamId)

                    targets[target] = value

                end

                table.insert(rows, {
                    ["x"] = x,
                    ["z"] = z,
                    ["targets"] = targets
                })

            end

        end

    end

    self.rows = rows
    self:run(connection)

end


function MoistureSyncEvent:writeStream(streamId, connection)

    streamWriteBool(streamId, self.isReset)

    if self.isReset then

        local moistureSystem = g_currentMission.moistureSystem

        streamWriteUInt16(streamId, moistureSystem.numRows)
        streamWriteUInt16(streamId, moistureSystem.numColumns)
        streamWriteUInt8(streamId, moistureSystem.cellWidth)
        streamWriteUInt8(streamId, moistureSystem.cellHeight)

        for x, row in pairs(self.rows) do

            streamWriteFloat32(streamId, x)

            for z, column in pairs(row.columns) do

                streamWriteFloat32(streamId, z)
                streamWriteFloat32(streamId, column.moisture)
                streamWriteFloat32(streamId, column.retention)
                streamWriteFloat32(streamId, column.trend)
                streamWriteFloat32(streamId, column.witherChance or 0)

            end

        end

    else

        local numRows = self.rows.numRows

        streamWriteUInt16(streamId, numRows)


        for x, row in pairs(self.rows) do

            if x == "numRows" then continue end

            local numColumns = row.numColumns

            streamWriteUInt16(streamId, numColumns)
            streamWriteFloat32(streamId, x)

            for z, targets in pairs(row) do

                if z == "numColumns" then continue end

                streamWriteFloat32(streamId, z)

                local numTargets = 0

                for target, value in pairs(targets) do numTargets = numTargets + 1 end

                streamWriteUInt8(streamId, numTargets)

                for target, value in pairs(targets) do

                    streamWriteString(streamId, target)
                    streamWriteFloat32(streamId, value)

                end

            end

        end

    end

end


function MoistureSyncEvent:run(connection)

    local moistureSystem = g_currentMission.moistureSystem

    if moistureSystem == nil then return end

    if self.isReset then
        moistureSystem:applyResetFromSync(self.rows, self.numRows, self.numColumns, self.cellWidth, self.cellHeight)
    else
        moistureSystem:applyUpdaterSync(self.rows)
    end

end