MoistureSyncEvent = {}
local moistureSyncEvent_mt = Class(MoistureSyncEvent, Event)
InitEventClass(MoistureSyncEvent, "MoistureSyncEvent")


function MoistureSyncEvent.emptyNew()
    local self = Event.new(moistureSyncEvent_mt)
    return self
end


function MoistureSyncEvent.new(rows)

    local self = MoistureSyncEvent.emptyNew()

    self.rows = rows

    return self

end


function MoistureSyncEvent:readStream(streamId, connection)

    local numRows = streamReadUInt16(streamId)

    local rows = {}

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

    self.rows = rows
    self:run(connection)

end


function MoistureSyncEvent:writeStream(streamId, connection)

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


function MoistureSyncEvent:run(connection)

    local moistureSystem = g_currentMission.moistureSystem

    if moistureSystem == nil then return end

    moistureSystem:applyUpdaterSync(self.rows)

end