PuddleSystemStateEvent = {}

local PuddleSystemStateEvent_mt = Class(PuddleSystemStateEvent, Event)
InitEventClass(PuddleSystemStateEvent, "PuddleSystemStateEvent")


function PuddleSystemStateEvent.emptyNew()
    local self = Event.new(PuddleSystemStateEvent_mt)
    return self
end


function PuddleSystemStateEvent.new(updateIteration, timeSinceLastUpdate, puddles)

    local self = PuddleSystemStateEvent.emptyNew()

    self.updateIteration, self.timeSinceLastUpdate, self.puddles = updateIteration, timeSinceLastUpdate, puddles

    return self

end


function PuddleSystemStateEvent:readStream(streamId, connection)
    
    local puddleSystem = g_currentMission.puddleSystem
    local numPuddles = streamReadUInt8(streamId)
    self.updateIteration = streamReadUInt8(streamId)
    self.timeSinceLastUpdate = streamReadFloat32(streamId)
    
    self.puddles = {}

    for i = 1, numPuddles do

        local puddle = Puddle.new()
        local success = puddle:readStream(streamId)

        if success then table.insert(self.puddles, puddle) end

    end

    self:run(connection)

end


function PuddleSystemStateEvent:writeStream(streamId, connection)
        
    streamWriteUInt8(streamId, #self.puddles)
    streamWriteUInt8(streamId, self.updateIteration)
    streamWriteFloat32(streamId, self.timeSinceLastUpdate)

    for i = 1, #self.puddles do
        self.puddles[i]:writeStream(streamId)
    end

end


function PuddleSystemStateEvent:run(connection)

    local puddleSystem = g_currentMission.puddleSystem

    puddleSystem.puddles = self.puddles
    puddleSystem:initialize()

end