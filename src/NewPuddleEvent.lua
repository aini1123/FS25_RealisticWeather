NewPuddleEvent = {}

local NewPuddleEvent_mt = Class(NewPuddleEvent, Event)
InitEventClass(NewPuddleEvent, "NewPuddleEvent")


function NewPuddleEvent.emptyNew()
    local self = Event.new(NewPuddleEvent_mt)
    return self
end


function NewPuddleEvent.new(puddle)

    local self = NewPuddleEvent.emptyNew()

    self.puddle = puddle

    return self

end


function NewPuddleEvent:readStream(streamId, connection)
    
    local puddle = Puddle.new()
    local success = puddle:readStream(streamId)

    if success then
        self.puddle = puddle
        self:run(connection)
    end

end


function NewPuddleEvent:writeStream(streamId, connection)
        
    self.puddle:writeStream(streamId)

end


function NewPuddleEvent:run(connection)

    if g_server ~= nil then return end

    g_currentMission.puddleSystem:addPuddle(self.puddle)
    self.puddle:initialize()

end


function NewPuddleEvent.sendEvent(puddle)
	if g_server ~= nil then g_server:broadcastEvent(NewPuddleEvent.new(puddle)) end
end