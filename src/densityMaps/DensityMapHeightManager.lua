RW_DensityMapHeightManager = {}


function RW_DensityMapHeightManager:loadMapData(superFunc, xmlFile, missionInfo, baseDirectory)

    local returnValue = superFunc(self, xmlFile, missionInfo, baseDirectory)

    g_currentMission.moistureSystem = MoistureSystem.new()
    g_currentMission.grassMoistureSystem = GrassMoistureSystem.new()
    g_currentMission.puddleSystem = PuddleSystem.new()
    g_currentMission.fireSystem = FireSystem.new()

    if g_currentMission:getIsServer() then
        g_currentMission.moistureSystem:loadFromXMLFile(xmlFile)
        g_currentMission.grassMoistureSystem:loadFromXMLFile()
        g_currentMission.fireSystem:loadFromXMLFile()
        PlayerInputComponent.update = Utils.appendedFunction(PlayerInputComponent.update, RW_PlayerInputComponent.update)
        PlayerHUDUpdater.update = Utils.appendedFunction(PlayerHUDUpdater.update, RW_PlayerHUDUpdater.update)
    end

    g_currentMission.puddleSystem:loadVariations()

    return returnValue

end

DensityMapHeightManager.loadMapData = Utils.overwrittenFunction(DensityMapHeightManager.loadMapData, RW_DensityMapHeightManager.loadMapData)