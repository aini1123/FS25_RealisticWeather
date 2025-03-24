FieldIrrigationChangeEvent = {}
local fieldIrrigationChangeEvent_mt = Class(FieldIrrigationChangeEvent, Event)
InitEventClass(FieldIrrigationChangeEvent, "FieldIrrigationChangeEvent")


function FieldIrrigationChangeEvent.emptyNew()
    local self = Event.new(fieldIrrigationChangeEvent_mt)
    return self
end


function FieldIrrigationChangeEvent.new(id, remove, active, create)

    local self = FieldIrrigationChangeEvent.emptyNew()

    self.id = id
    self.remove = remove
    self.active = active
    self.create = create

    return self

end


function FieldIrrigationChangeEvent:readStream(streamId, connection)
    self.id = streamReadUInt16(streamId)
    self.remove = streamReadBool(streamId)
    self.active = streamReadBool(streamId)
    self.create = streamReadBool(streamId)

    self:run(connection)
end


function FieldIrrigationChangeEvent:writeStream(streamId, connection)
    streamWriteUInt16(streamId, self.id)
    streamWriteBool(streamId, self.remove or false)
    streamWriteBool(streamId, self.active or false)
    streamWriteBool(streamId, self.create or false)
end


function FieldIrrigationChangeEvent:run(connection)

    local moistureSystem = g_currentMission.moistureSystem

    if moistureSystem == nil then return end

    if self.remove then
        if moistureSystem.irrigatingFields[self.id] ~= nil then table.removeElement(moistureSystem.irrigatingFields, self.id) end
    elseif not self.create and moistureSystem.irrigatingFields[self.id] ~= nil then
        moistureSystem.irrigatingFields[self.id].isActive = self.active
    elseif self.create and moistureSystem.irrigatingFields[self.id] == nil then
        moistureSystem.irrigatingFields[self.id] = {
            ["id"] = self.id,
            ["pendingCost"] = 0,
            ["isActive"] = true
        }
    end

end


function FieldIrrigationChangeEvent.sendEvent(id, remove, active, create)

    if g_server == nil and g_client ~= nil then g_client:getServerConnection():sendEvent(FieldIrrigationChangeEvent.new(id, remove, active, create)) end

end