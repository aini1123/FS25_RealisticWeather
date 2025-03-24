RW_DensityMapHeightManager = {}


function RW_DensityMapHeightManager:loadMapData(superFunc, xmlFile, missionInfo, baseDirectory)

    local returnValue = superFunc(self, xmlFile, missionInfo, baseDirectory)

    g_currentMission.moistureSystem = MoistureSystem.new()

    if g_currentMission:getIsServer() then g_currentMission.moistureSystem:loadFromXMLFile(xmlFile) end

    return returnValue

end

DensityMapHeightManager.loadMapData = Utils.overwrittenFunction(DensityMapHeightManager.loadMapData, RW_DensityMapHeightManager.loadMapData)