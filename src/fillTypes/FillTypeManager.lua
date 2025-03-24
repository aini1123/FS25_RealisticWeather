RW_FillTypeManager = {}

local modDir = g_currentModDirectory
local modName = g_currentModName

function RW_FillTypeManager.loadFillTypes(xmlFile, missionInfo, baseDir)

    local xml = loadXMLFile("fillTypes", modDir .. "xml/fillTypes.xml")
    g_fillTypeManager:loadFillTypes(xml, modDir , false, modName)

end

FillTypeManager.loadMapData = Utils.appendedFunction(FillTypeManager.loadMapData, RW_FillTypeManager.loadFillTypes)