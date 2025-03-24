RW_WeatherInstance = {}

function RW_WeatherInstance:saveToXMLFile(xmlFile, key, _)
    if self.isBlizzard then xmlFile:setBool(key .. "#isBlizzard", true) end
    if self.isDraught then xmlFile:setBool(key .. "#isDraught", true) end
    if self.snowForecast ~= nil then xmlFile:setFloat(key .. "#snowForecast", self.snowForecast) end
end

WeatherInstance.saveToXMLFile = Utils.appendedFunction(WeatherInstance.saveToXMLFile, RW_WeatherInstance.saveToXMLFile)


function RW_WeatherInstance:loadFromXMLFile(superFunc, xmlFile, key)
    local r = superFunc(self, xmlFile, key)

    self.isBlizzard = xmlFile:getBool(key .. "#isBlizzard", false)
    self.isDraught = xmlFile:getBool(key .. "#isDraught", false)

    local snowForecast = xmlFile:getFloat(key .. "#snowForecast", -1.0)
    if snowForecast >= 0 then self.snowForecast = snowForecast end

    return r
end

WeatherInstance.loadFromXMLFile = Utils.overwrittenFunction(WeatherInstance.loadFromXMLFile, RW_WeatherInstance.loadFromXMLFile)


function RW_WeatherInstance:readStream(streamId, _)

    self.isBlizzard = streamReadBool(streamId)
    self.isDraught = streamReadBool(streamId)
    local snowForecast = streamReadFloat32(streamId)
    if snowForecast >= 0 then self.snowForecast = snowForecast end

end

WeatherInstance.readStream = Utils.appendedFunction(WeatherInstance.readStream, RW_WeatherInstance.readStream)


function RW_WeatherInstance:writeStream(streamId, _)

    streamWriteBool(streamId, self.isBlizzard or false)
    streamWriteBool(streamId, self.isDraught or false)
    streamWriteFloat32(streamId, self.snowForecast or -1.0)

end

WeatherInstance.writeStream = Utils.appendedFunction(WeatherInstance.writeStream, RW_WeatherInstance.writeStream)