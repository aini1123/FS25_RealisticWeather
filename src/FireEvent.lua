FireEvent = {}

local FireEvent_mt = Class(FireEvent, Event)
InitEventClass(FireEvent, "FireEvent")


function FireEvent.emptyNew()
    local self = Event.new(FireEvent_mt)
    return self
end


function FireEvent.new(updateIteration, timeSinceLastUpdate, fieldId, fires)

    local self = FireEvent.emptyNew()

    self.updateIteration, self.timeSinceLastUpdate, self.fieldId, self.fires = updateIteration, timeSinceLastUpdate, fieldId, fires

    return self

end


function FireEvent:readStream(streamId, connection)

    local numFires = streamReadUInt8(streamId)
    
    self.updateIteration = streamReadUInt8(streamId)
    self.fieldId = streamReadUInt16(streamId)

    if self.fieldId == 0 then self.fieldId = nil end

    self.timeSinceLastUpdate = streamReadFloat32(streamId)
    
    self.fires = {}

    for i = 1, numFires do

        local fire = Fire.new()
        local success = fire:readStream(streamId)

        if success then table.insert(self.fires, fire) end

    end

    self:run(connection)

end


function FireEvent:writeStream(streamId, connection)
        
    streamWriteUInt8(streamId, #self.fires)

    streamWriteUInt8(streamId, self.updateIteration)
    streamWriteUInt16(streamId, self.fieldId or 0)
    streamWriteFloat32(streamId, self.timeSinceLastUpdate)

    for i = 1, #self.fires do
        self.fires[i]:writeStream(streamId)
    end

end


function FireEvent:run(connection)

    local fireSystem = g_currentMission.fireSystem

    fireSystem.updateIteration = self.updateIteration
    fireSystem.timeSinceLastUpdate = self.timeSinceLastUpdate
    fireSystem.fires = self.fires
    fireSystem.fieldId = self.fieldId

    fireSystem:initialize()

end