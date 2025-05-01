RW_FillTypeManager = {}
RW_FillTypeManager.isLoaded = false

local modDir = g_currentModDirectory
local modName = g_currentModName

function RW_FillTypeManager:loadFillTypes(superFunc, xmlFile, missionInfo, baseDirectory, isBaseType)

    --local xml = loadXMLFile("fillTypes", modDir .. "xml/fillTypes.xml")
    --g_fillTypeManager:loadFillTypes(xml, modDir , false, modName)

    local returnValue = superFunc(self, xmlFile, missionInfo, baseDirectory, isBaseType)

    if not returnValue or RW_FillTypeManager.isLoaded then return returnValue end

    local xmlFile = XMLFile.loadIfExists("rwFillTypes", modDir .. "xml/fillTypes.xml", FillTypeManager.xmlSchema)

    if xmlFile == nil then return end

    xmlFile:iterate("map.fillTypeCategories.fillTypeCategory", function (_, key)
    
        local categoryName = xmlFile:getValue(key .. "#name")
        local fillTypes = xmlFile:getValue(key)

        local categoryNameUpper = categoryName:upper()
        local category = self.nameToCategoryIndex[categoryNameUpper]

	    if baseDir and category == nil then category = self:addFillTypeCategory(categoryName, baseDir) end

        if category ~= nil and fillTypes ~= nil then

            for _, name in pairs(fillTypes) do

                local fillType = self:getFillTypeByName(name)

				if fillType == nil then
					Logging.warning("Unknown FillType \'" .. tostring(name) .. "\' in fillTypeCategory \'" .. tostring(categoryName) .. "\'!")
				elseif not self:addFillTypeToCategory(fillType.index, category) then
					Logging.warning("Could not add fillType \'" .. tostring(name) .. "\' to fillTypeCategory \'" .. tostring(categoryName) .. "\'!")
                else
                    print(string.format("RealisticWeather: added fillType %s to fillTypeCategory %s", tostring(name), tostring(categoryName)))
				end

            end

        end
    
    end)

    xmlFile:delete()
    RW_FillTypeManager.isLoaded = true

    return true

end

FillTypeManager.loadFillTypes = Utils.overwrittenFunction(FillTypeManager.loadFillTypes, RW_FillTypeManager.loadFillTypes)