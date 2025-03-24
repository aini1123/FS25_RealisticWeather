RW_Weather = {}
RW_Weather.FACTOR =
{
    SNOW_FACTOR = 0.0005,
    SNOW_HEIGHT = 1.0,
    MAX_ANIMALS_SINK = 100
}

RW_Weather.isRealisticLivestockLoaded = false

SnowSystem.MAX_HEIGHT = RW_Weather.FACTOR.SNOW_HEIGHT
local animalStepCount = 0
local animalsToSink = 10
local animalIdToPos = {}
local profile = Utils.getPerformanceClassId()

function RW_Weather:update(_, dT)

    local timescale = dT * g_currentMission:getEffectiveTimeScale()

    if #self.forecastItems >= 2 then
        local forecast2 = self.forecastItems[2]
        local forecast1 = self.forecastItems[1]
        local weatherObject1 = self:getWeatherObjectByIndex(forecast1.season, forecast1.objectIndex)

        if self.owner.currentMonotonicDay > forecast2.startDay or self.owner.currentMonotonicDay == forecast2.startDay and self.owner.dayTime > forecast2.startDayTime then
            local changeDuration = self.cheatedTime and 0 or Weather.CHANGE_DURATION
            weatherObject1:deactivate(changeDuration)
            local weatherObject2 = self:getWeatherObjectByIndex(forecast2.season, forecast2.objectIndex)
            weatherObject2:activate(forecast2, changeDuration)

            if weatherObject2.setWindValues ~= nil then
                local a, b, c, d = self.windUpdater:getCurrentValues()
                weatherObject2:setWindValues(a, b, c, d)
            end

            self:onWeatherChanged(weatherObject2)
            table.remove(self.forecastItems, 1)

            if g_server ~= nil then self:fillWeatherForecast() end
        elseif self.cheatedTime then
            self.cheatedTime = nil
            local rainScale = self:getRainFallScale()
            local hailScale = self:getHailFallScale()
            local snowScale = self:getSnowFallScale()
            if rainScale == 0 and hailScale == 0 and snowScale == 0 then self.groundWetness = 0 end
        end

        local isDry = not (self:getIsRaining() or self:getIsHailing())

        if isDry then isDry = not self:getIsSnowing() end
        if isDry then
            self.timeSinceLastRain = self.timeSinceLastRain + timescale
        else
            self.timeSinceLastRain = 0
        end
    elseif g_server ~= nil then
        self:fillWeatherForecast()
    end

    for _, weatherObject in pairs(self.weatherObjects) do
        for _, weather in ipairs(weatherObject) do
            weather:update(timescale)
        end
    end

    local _, currentWeather = self.forecast:dataForTime(self.owner.currentMonotonicDay, self.owner.dayTime)
    local minTemp, maxTemp = self.temperatureUpdater:getCurrentValues()

    if currentWeather ~= nil and currentWeather.isBlizzard and (maxTemp > 0 or minTemp > -8) then
        minTemp = math.random(-15, -8)
        maxTemp = math.random(minTemp + 3, minTemp + 8)
        self.temperatureUpdater:setTargetValues(minTemp, maxTemp, true)
    end

    if currentWeather ~= nil and currentWeather.isDraught and (maxTemp < 35 or minTemp < 30) then
        minTemp = math.random(30, 35)
        maxTemp = math.random(minTemp + 5, minTemp + 15)
        self.temperatureUpdater:setTargetValues(minTemp, maxTemp, true)
    end


    self.cloudUpdater:update(timescale)
    self.temperatureUpdater:update(timescale)
    self.windUpdater:update(timescale)
    self.fogUpdater:update(timescale)
    self.rainUpdater:update(timescale)

    if self.skyBoxUpdater ~= nil then self.skyBoxUpdater:update(timescale, self.owner.dayTime, self:getRainFallScale(), self:getTimeUntilRain()) end

    local effectiveTimescale = g_currentMission:getEffectiveTimeScale()
    local temperature = self.temperatureUpdater:getTemperatureAtTime(self.owner.dayTime)

    if g_currentMission.missionInfo.isSnowEnabled then

        local blizzardFactor = currentWeather ~= nil and currentWeather.isBlizzard and 20 or 1

        if self:getIsSnowing() and temperature < 10 then
            local scale = 1 - temperature * 0.1
            self.snowHeight = math.clamp(self.snowHeight + RW_Weather.FACTOR.SNOW_FACTOR * (timescale / 100000) * self:getSnowFallScale() * scale * blizzardFactor, 0, RW_Weather.FACTOR.SNOW_HEIGHT)
        elseif temperature >= 10 then
            self.snowHeight = 0
            g_currentMission.snowSystem:removeAll()
        elseif temperature > 0 and self.snowHeight > 0 then
            local scale = self:getIsRaining() and math.max(5 / self:getRainFallScale(), 1.25) or 1
            self.snowHeight = math.clamp(self.snowHeight - temperature * 0.001 * (timescale / 100000) * scale, 0, RW_Weather.FACTOR.SNOW_HEIGHT)
            if self.snowHeight == 0 then g_currentMission.snowSystem:removeAll() end
        end

    else
        self.snowHeight = math.max(self.snowHeight - 0.005 * (dT / 1000) * (effectiveTimescale / 100), 0)
    end

    local wetness

    if self.timeSinceLastRain == 0 then
        local scale = math.max(self:getRainFallScale(), self:getSnowFallScale(), self:getHailFallScale())
        wetness = timescale / self.groundWetnessWetDuration * scale
    else
        wetness = -(timescale / self.groundWetnessDryDuration)
    end

    self.groundWetness = math.clamp(self.groundWetness + wetness, 0, 1)
    g_currentMission.snowSystem:setSnowHeight(self.snowHeight)

    local groundWetness = self:getGroundWetness()
    groundWetness = math.max(0, groundWetness - 0.15) / 0.85

    setWetness(groundWetness)
    setTerrainDisplacementWetness(g_terrainNode, groundWetness)


    local hail = self:getHailFallScale()

    if hail > 0 then
        local vehicles = g_currentMission.vehicleSystem.vehicles

        for _, vehicle in pairs(vehicles) do

            local wearable = vehicle.spec_wearable

            if wearable == nil then continue end
            local x, _, z = getWorldTranslation(vehicle.rootNode)

            if x == nil or z == nil then continue end

            local isIndoor = g_currentMission.indoorMask:getIsIndoorAtWorldPosition(x, z)
            if isIndoor then continue end

            local damageAmount = hail * 0.0006 * (timescale / 100000)
            local wearAmount = hail * 0.0018 * (timescale / 100000)
            wearable:addWearAmount(wearAmount, true)
            wearable:addDamageAmount(damageAmount, true)

        end
    end



    local fields = g_fieldManager:getFields()
    local farmId = g_localPlayer.farmId
    local draughtFactor = currentWeather ~= nil and currentWeather.isDraught and 1.5 or 1
    local temp = self.temperatureUpdater:getTemperatureAtTime(self.owner.dayTime)
    local hour = math.floor(self.owner:getMinuteOfDay() / 60)
    local daylightStart, dayLightEnd, _, _ = self.owner.daylight:getDaylightTimes()

    for _, field in pairs(fields) do

        local state = field.fieldState
        local moisture = state.moisture
        local oldMoisture = state.moisture

        if moisture == nil then
            local newMoisture = math.random(12, 30) / 100
            moisture = newMoisture
            oldMoisture = newMoisture
        end

        if temp < 0 then wetness = wetness * 0.25 end
        if wetness > 0 then moisture = moisture + math.clamp(wetness * 0.0007, 0, 0.00075) end

        local sunFactor = (hour >= daylightStart and hour < dayLightEnd and 1) or 0.25

        if temp >= 45 then
            moisture = moisture - (temp * 0.000018 * (timescale / 100000) * sunFactor * draughtFactor)
        elseif temp >= 35 then
            moisture = moisture - (temp * 0.000012 * (timescale / 100000) * sunFactor * draughtFactor)
        elseif temp >= 25 then
            moisture = moisture - (temp * 0.0000075 * (timescale / 100000) * sunFactor * draughtFactor)
        elseif temp >= 15 then
            moisture = moisture - (temp * 0.0000014 * (timescale / 100000) * sunFactor * draughtFactor)
        elseif temp > 0 then
            moisture = moisture - (temp * 0.0000008 * (timescale / 100000) * sunFactor * draughtFactor)
        end

        local fruitType =  g_fruitTypeManager:getFruitTypeByIndex(state.fruitTypeIndex)

        if fruitType ~= nil then

            local isWithered = fruitType:getIsWithered(state.growthState)
            local isCut = fruitType:getIsCut(state.growthState)
            local fruitName = fruitType.name

            if state.lastMessage == nil then state.lastMessage = -3 end

            local fieldOwner = field:getOwner()

            -- ######################################################################################

            -- NOTES

            -- Withering is disabled temporarily as the field system does not work quite as expected

            -- ######################################################################################

            if false and fruitType.witheredState ~= nil and fieldOwner == farmId and moisture <= 0.03 and moisture > 0 and moisture < oldMoisture and not isCut and not isWithered and state.growthState >= fruitType.numGrowthStates / 2 and state.lastMessage < self.owner.currentDay - 3 then
                state.lastMessage = self.owner.currentDay
                g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL, string.format(g_i18n:getText("rw_ui_aboutToWither"), field.farmland:getId()))
            elseif false and fruitType.witheredState ~= nil and moisture <= 0 and not isCut and not isWithered and state.growthState >= fruitType.numGrowthStates / 2 then
                if fruitName == "GRASS" then
                    field.fieldState.growthState = fruitType.minPreparingGrowthState
                else
                    field.fieldState.growthState = fruitType.witheredState
                end

                local updateTask = field.fieldState:createFieldUpdateTask()
                updateTask:setField(field)
                updateTask:start(true)
                updateTask:update(1)

                if updateTask.getField ~= nil then
                    local updateField = updateTask:getField()
                    if updateField ~= nil then updateField:updateState() end
                end

                if fieldOwner == farmId then g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL, string.format(g_i18n:getText("rw_ui_hasWithered"), field.farmland:getId())) end
            end

        end

        field.fieldState.moisture = math.clamp(moisture, 0, 1)

    end




    ---------------------------------------------------------

    -- ################################################################

    -- NOTES

    -- Resource-heavy operation: disabled for low systems

    -- It is unfortunately impossible to create a "footsteps" effect
    -- without completely redesigning the entire visual animals system
    -- ie: all the i3ds would have to have more parts added to them
    -- and the animals would have to be loaded script-side rather than
    -- engine-side (addHusbandryAnimal), which would also mean having
    -- to manually start their animation loops (and possibly also set
    -- their position manually)

    -- ################################################################

    if profile >= 4 and g_currentMission.missionInfo.isSnowEnabled and self.snowHeight > SnowSystem.MIN_LAYER_HEIGHT and animalStepCount >= math.min(math.max(100, animalsToSink * 4), 500) then

        animalsToSink = 0

        local husbandries = g_currentMission.husbandrySystem.clusterHusbandries
        if husbandries ~= nil then
            local snowSystem = g_currentMission.snowSystem
            local indoorMask = g_currentMission.indoorMask
            local animalsSunk = 0

            for _, husbandry in pairs(husbandries) do

                if RW_Weather.isRealisticLivestockLoaded then
                    local husbandryIds = husbandry.husbandryIds or {}

                    for i, animalIds in pairs(husbandry.animalIdToCluster) do
                        animalsToSink = animalsToSink + #animalIds
                        if animalIdToPos[husbandryIds[i]] == nil then animalIdToPos[husbandryIds[i]] = {} end

                        for animalId, _ in pairs(animalIds) do
                            local x, _, z = getAnimalPosition(husbandryIds[i], animalId)
                            if indoorMask:getIsIndoorAtWorldPosition(x, z) then continue end
                            local heightUnderAnimal = snowSystem:getSnowHeightAtArea(x, z, x + 1, z + 1, x - 1, z - 1)

                            local oldX, oldZ

                            if animalIdToPos[husbandryIds[i]][animalId] ~= nil then
                                oldX = animalIdToPos[husbandryIds[i]][animalId].x
                                oldZ = animalIdToPos[husbandryIds[i]][animalId].z
                            else
                                animalIdToPos[husbandryIds[i]][animalId] = {}
                            end

                            if heightUnderAnimal > 0.05 and (oldX ~= x or oldZ ~= z) then snowSystem:setSnowHeightAtArea(x, z, x + 1, z + 1, x - 1, z - 1, heightUnderAnimal * 0.75) end

                            animalsSunk = animalsSunk + 1
                            animalIdToPos[husbandryIds[i]][animalId].x = x
                            animalIdToPos[husbandryIds[i]][animalId].z = z

                            if animalsSunk >= RW_Weather.FACTOR.MAX_ANIMALS_SINK then break end
                        end


                        if animalsSunk >= RW_Weather.FACTOR.MAX_ANIMALS_SINK then break end
                    end
                else
                    animalsToSink = animalsToSink + #husbandry.animalIdToCluster

                    if animalIdToPos[husbandry.husbandryId] == nil then animalIdToPos[husbandry.husbandryId] = {} end

                    for animalId, _ in pairs(husbandry.animalIdToCluster) do
                        local x, _, z = getAnimalPosition(husbandry.husbandryId, animalId)
                        if indoorMask:getIsIndoorAtWorldPosition(x, z) then continue end
                        local heightUnderAnimal = snowSystem:getSnowHeightAtArea(x, z, x + 1, z + 1, x - 1, z - 1)

                        local oldX, oldZ

                        if animalIdToPos[husbandry.husbandryId][animalId] ~= nil then
                            oldX = animalIdToPos[husbandry.husbandryId][animalId].x
                            oldZ = animalIdToPos[husbandry.husbandryId][animalId].z
                        else
                            animalIdToPos[husbandry.husbandryId][animalId] = {}
                        end

                        if heightUnderAnimal > 0.05 and (oldX ~= x or oldZ ~= z) then snowSystem:setSnowHeightAtArea(x, z, x + 1, z + 1, x - 1, z - 1, heightUnderAnimal * 0.75) end

                        animalsSunk = animalsSunk + 1
                        animalIdToPos[husbandry.husbandryId][animalId].x = x
                        animalIdToPos[husbandry.husbandryId][animalId].z = z

                        if animalsSunk >= RW_Weather.FACTOR.MAX_ANIMALS_SINK then break end
                    end

                end

                if animalsSunk >= RW_Weather.FACTOR.MAX_ANIMALS_SINK then break end

            end
        end

        animalStepCount = 0

    end

    animalStepCount = animalStepCount + 1

end

Weather.update = Utils.overwrittenFunction(Weather.update, RW_Weather.update)


function RW_Weather:fillWeatherForecast(_, isInitialSync)
    self:updateAvailableWeatherObjects()

    local lastItem = self.forecastItems[#self.forecastItems]
    local maxNumOfforecastItemsItems = 2 ^ Weather.SEND_BITS_NUM_OBJECTS - 1
    local newObjects = {}

    while (lastItem == nil or lastItem.startDay < self.owner.currentMonotonicDay + 9) and #self.forecastItems < maxNumOfforecastItemsItems do

        local startDay = self.owner.currentMonotonicDay
        local startDayTime = self.owner.dayTime

        if lastItem ~= nil then
            startDay = lastItem.startDay
            startDayTime = lastItem.startDayTime + lastItem.duration
        end

        local endDay, endDayTime = self.owner:getDayAndDayTime(startDayTime, startDay)
        local newObject = self:createRandomWeatherInstance(self.owner:getVisualSeasonAtDay(endDay), endDay, endDayTime, false)

        local object = self:getWeatherObjectByIndex(newObject.season, newObject.objectIndex)

        if g_currentMission.missionInfo.isSnowEnabled and object.weatherType == WeatherType.SNOW and math.random() >= 0.92 then

            newObject.isBlizzard = true
            local minTemp = math.random(-15, -8)
            local maxTemp = math.random(minTemp + 3, minTemp + 8)
            object.temperatureUpdater:setTargetValues(minTemp, maxTemp, false)

        end

        if object.weatherType == WeatherType.SUN and object.season == 2 and math.random() >= 0.92 then

            newObject.isDraught = true
            local minTemp = math.random(30, 35)
            local maxTemp = math.random(minTemp + 5, minTemp + 15)
            object.temperatureUpdater:setTargetValues(minTemp, maxTemp, false)

            local wind = math.random(0, 200) / 100
            object.windUpdater.targetVelocity = wind

            object.rainUpdater.rainfallScale = 0

        end

        self:addWeatherForecast(newObject)
        table.insert(newObjects, newObject)
        lastItem = self.forecastItems[#self.forecastItems]

    end

    if #newObjects > 0 then g_server:broadcastEvent(WeatherAddObjectEvent.new(newObjects, isInitialSync or false), false) end
end

Weather.fillWeatherForecast = Utils.overwrittenFunction(Weather.fillWeatherForecast, RW_Weather.fillWeatherForecast)


function RW_Weather:randomizeFog(_, time)
    local season = self.owner.currentSeason
    local seasonToFog = self.seasonToFog[season]

    local fog

    if seasonToFog == nil then
        fog = nil
    else
        fog = seasonToFog:createFromTemplate()

        if season ~= 2 and math.random() >= 0.925 then

            fog.groundFogCoverageEdge0 = math.random(5, 10) / 100
            fog.groundFogCoverageEdge1 = math.random(90, 95) / 100
            fog.groundFogExtraHeight = math.random(25, 35)
            fog.groundFogGroundLevelDensity = math.random(85, 200) / 100
            fog.heightFogMaxHeight = math.random(650, 800)
            fog.heightFogGroundLevelDensity = math.random(75, 190) / 100
            fog.groundFogEndDayTimeMinutes = math.min(math.random(fog.groundFogStartDayTimeMinutes + 120, fog.groundFogStartDayTimeMinutes + 860), 1439)

            fog.groundFogWeatherTypes[WeatherType.SNOW] = true
            fog.groundFogWeatherTypes[WeatherType.RAIN] = true

        end
    end

    self.fogUpdater:setTargetFog(fog, time)
end

Weather.randomizeFog = Utils.overwrittenFunction(Weather.randomizeFog, RW_Weather.randomizeFog)