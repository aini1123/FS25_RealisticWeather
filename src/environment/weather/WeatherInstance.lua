RW_WeatherInstance = {}

function RW_WeatherInstance:saveToXMLFile(xmlFile, key, _)
    if self.isBlizzard then xmlFile:setBool(key .. "#isBlizzard", true) end
    if self.isDraught then xmlFile:setBool(key .. "#isDraught", true) end
    if self.snowForecast ~= nil then xmlFile:setFloat(key .. "#snowForecast", self.snowForecast) end
end

WeatherInstance.saveToXMLFile = Utils.appendedFunction(WeatherInstance.saveToXMLFile, RW_WeatherInstance.saveToXMLFile)


function RW_WeatherInstance:loadFromXMLFile(superFunc, xmlFile, key)
    local r = superFunc(self, xmlFile, key)

    local isBlizzard = xmlFile:getBool(key .. "#isBlizzard", false)
    if isBlizzard then self.isBlizzard = true end

    local isDraught = xmlFile:getBool(key .. "#isDraught", false)
    if isDraught then self.isDraught = true end

    local snowForecast = xmlFile:getFloat(key .. "#snowForecast", -1.0)
    if snowForecast >= 0 then self.snowForecast = snowForecast end

    return r
end

WeatherInstance.loadFromXMLFile = Utils.overwrittenFunction(WeatherInstance.loadFromXMLFile, RW_WeatherInstance.loadFromXMLFile)