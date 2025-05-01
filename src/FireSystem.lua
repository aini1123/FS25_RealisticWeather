FireSystem = {}

FireSystem.SEASON_TO_PROBABILITY = {
    [Season.SPRING] = 0.35,
    [Season.SUMMER] = 1,
    [Season.AUTUMN] = 0.05,
    [Season.WINTER] = 0
}

local fireSystem_mt = Class(FireSystem)
local modDirectory = g_currentModDirectory


function FireSystem.new()

	local self = setmetatable({}, fireSystem_mt)

	self.fieldId = nil
	self.fires = {}
	self.isServer = g_currentMission:getIsServer()
	self.fireEnabled = true
    self.isSaving = false
    self.timeSinceLastUpdate = 0
    self.updateIteration = 1
    self.isRaining = false

    if self.isServer then
        
        g_messageCenter:subscribe(MessageType.HOUR_CHANGED, self.onHourChanged, self)
        g_messageCenter:subscribe(MessageType.DAY_CHANGED, self.onDayChanged, self)

        self.isViableForFire = false

    end

	return self

end


function FireSystem:loadFromXMLFile()

	local savegameIndex = g_careerScreen.savegameList.selectedIndex
    local savegame = g_savegameController:getSavegame(savegameIndex)

    if savegame == nil or savegame.savegameDirectory == nil then return end

    local xmlFile = XMLFile.loadIfExists("firesXML", savegame.savegameDirectory .. "/fires.xml")

    if xmlFile == nil then return end

    self.fieldId = xmlFile:getInt("fires#fieldId")
    self.isViableForFire = xmlFile:getBool("fires#isViableForFire", false)

    xmlFile:iterate("fires.fire", function(_, key)

        local fire = Fire.new()
        local success = fire:loadFromXMLFile(xmlFile, key)

        if success then table.insert(self.fires, fire) end

    end)

    xmlFile:delete()

end


function FireSystem:saveToXMLFile(path)

	if path == nil then return end

    local xmlFile = XMLFile.create("firesXML", path, "fires")
    if xmlFile == nil then return end

    self.isSaving = true

    if self.fieldId ~= nil then xmlFile:setInt("fires#fieldId", self.fieldId) end
    xmlFile:setBool("fires#isViableForFire", self.isViableForFire)

    for i = 1, #self.fires do

        local fire = self.fires[i]
        fire:saveToXMLFile(xmlFile, string.format("fires.fire(%d)", i - 1))

    end

    xmlFile:save(false, true)

    xmlFile:delete()

    self.isSaving = false

end


function FireSystem:initialize()

	for _, fire in pairs(self.fires) do fire:initialize() end

end


function FireSystem:update(timescale, updateCache)

    if self.isSaving then return end

    if self.fieldId == nil or #self.fires == 0 or not self.fireEnabled then
        
        if self.fieldId ~= nil then self:endFire() end

        return

    end

    local timeSinceLastUpdate = self.timeSinceLastUpdate + timescale

    for _, fire in pairs(self.fires) do fire.timeSinceLastUpdate = fire.timeSinceLastUpdate + timeSinceLastUpdate end

    local needsDeletion = self.fires[self.updateIteration]:update(self, self.isRaining)

    if needsDeletion then

        table.remove(self.fires, self.updateIteration)
        self.updateIteration = self.updateIteration - 1

    end

    if updateCache then

        self.isRaining = g_currentMission.environment.weather.timeSinceLastRain == 0
        
        local px, pz
        
        if g_localPlayer ~= nil then px, _, pz = g_localPlayer:getPosition() end

        for _, fire in pairs(self.fires) do fire:updateDistanceToPlayer(px, pz) end

    end


    self.timeSinceLastUpdate = 0
    self.updateIteration = self.updateIteration + 1

    if self.updateIteration > #self.fires then self.updateIteration = 1 end

end


function FireSystem:startFire(x, z, fieldId)

    if self.fieldId ~= nil or not self.isServer or not self.fireEnabled then return end

    self.fieldId = fieldId
    self.updateIteration = 1
    self.timeSinceLastUpdate = 0

    local fire = Fire.new()

    fire.position = { x, 0, z }
    local y = getTerrainHeightAtWorldPos(g_terrainNode, x, 0, z) - 0.1
    fire.position[2] = y
    fire.direction = math.random(-1800, 1800) / 10
    fire.width = math.random(800, 1200) / 1000
    fire.height = math.random(900, 1500) / 1000
    
    fire:calculateDirectionFactors()
    fire:initialize()

    table.insert(self.fires, fire)

    g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL, string.format("Fire started on field %d", fieldId))

    g_server:broadcastEvent(FireEvent.new(1, 0, fieldId, self.fires))

end


function FireSystem:endFire()

    if self.isServer then g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL, "Fire ended on field " .. self.fieldId) end

    self.fieldId = nil

    for i = #self.fires, 1, -1 do

        local fire = self.fires[i]
        fire:delete()
        table.remove(self.fires, i)

    end

end


function FireSystem:getNextFireDirection()

    local direction = 0

    for i = #self.fires, 1, -1 do

        direction = self.fires[i].direction

    end

    direction = direction + 180 / #self.fires

    if direction > 180 then direction = -360 + direction end

    return direction

end


function FireSystem.onSettingChanged(name, state)

    local fireSystem = g_currentMission.fireSystem

    if fireSystem == nil then return end

    fireSystem[name] = state

    if name == "fireEnabled" and not state and fireSystem.fieldId ~= nil then fireSystem:endFire() end

end


function FireSystem:onHourChanged()

    if not self.isViableForFire or self.fieldId ~= nil then return end

    environment = g_currentMission.environment

    local _, currentWeather = environment.weather.forecast:dataForTime(environment.currentMonotonicDay, environment.dayTime)
    
    local season, hour = environment.currentSeason, math.floor(environment:getMinuteOfDay() / 60)
    local temperature = environment.weather.temperatureUpdater:getTemperatureAtTime(environment.dayTime)

    local probability = FireSystem.SEASON_TO_PROBABILITY[season] * (currentWeather.isDraught and 0.45 or 0.05)

    if hour < 6 or hour > 18 then probability = probability * 0.08 end

    probability = probability * (temperature / 35)

    if temperature < 25 or environment.weather.timeSinceLastRain == 0 then probability = 0 end

    if math.random() >= probability then return end

    local moistureSystem = g_currentMission.moistureSystem

    for i = 1, 25 do

        local cell = moistureSystem:getRandomCell()

        if cell == nil or cell.moisture > 0.075 then continue end

        local groundTypeValue = g_currentMission.fieldGroundSystem:getValueAtWorldPos(FieldDensityMap.GROUND_TYPE, cell.x, 0, cell.z)
        local groundType = FieldGroundType.getTypeByValue(groundTypeValue)

	    if groundType == FieldGroundType.CULTIVATED or groundType == FieldGroundType.NONE then continue end

        local fieldId = g_farmlandManager:getFarmlandIdAtWorldPosition(cell.x, cell.z)

        if fieldId == nil or fieldId == 0 then continue end

        self:startFire(cell.x, cell.z, fieldId)
        break

    end

end


function FireSystem:onDayChanged()

    local environment = g_currentMission.environment

    local season = environment.currentSeason

    local probability = FireSystem.SEASON_TO_PROBABILITY[season]

    self.isViableForFire = math.random() < probability

end