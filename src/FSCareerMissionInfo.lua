RW_FSCareerMissionInfo = {}

function RW_FSCareerMissionInfo:saveToXMLFile()
    if self.xmlFile ~= nil and g_currentMission ~= nil and g_currentMission.grassMoistureSystem ~= nil then
        g_currentMission.grassMoistureSystem:saveToXMLFile(self.savegameDirectory .. "/grassMoisture.xml")
        g_currentMission.moistureSystem:saveToXMLFile(self.savegameDirectory .. "/moisture.xml")
        RWSettings.saveToXMLFile()
    end
end

FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, RW_FSCareerMissionInfo.saveToXMLFile)