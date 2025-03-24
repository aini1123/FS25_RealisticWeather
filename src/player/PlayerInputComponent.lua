RW_PlayerInputComponent = {}
RW_PlayerInputComponent.IRRIGATION_EVENT_ID = nil


function RW_PlayerInputComponent:update()

    if not self.player.isOwner or g_inputBinding:getContextName() ~= PlayerInputComponent.INPUT_CONTEXT_NAME then return end

    local x, y, z, dirX, dirY, dirZ = self.player:getLookRay()

    if x == nil or y == nil or z == nil or dirX == nil or dirY == nil or dirZ == nil then return end

    self.player.hudUpdater:setCurrentRaycastFillTypeCoords(x, y, z, dirX, dirY, dirZ)

end


function RW_PlayerInputComponent:registerGlobalPlayerActionEvents()

    local valid, eventId = g_inputBinding:registerActionEvent(InputAction.Irrigation, MoistureSystem, MoistureSystem.irrigationInputCallback, false, true, false, true, nil, false)

    g_inputBinding:setActionEventActive(eventId, false)

    RW_PlayerInputComponent.IRRIGATION_EVENT_ID = eventId

    if g_currentMission.moistureSystem ~= nil and valid then g_currentMission.moistureSystem.irrigationEventId = eventId end

end


PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.appendedFunction(PlayerInputComponent.registerGlobalPlayerActionEvents, RW_PlayerInputComponent.registerGlobalPlayerActionEvents)