GrassMoistureSystem = {}

GrassMoistureSystem.HAY_MOISTURE = 0.125
GrassMoistureSystem.TICKS_PER_UPDATE = 250

local grassMoistureSystem_mt = Class(GrassMoistureSystem)


function GrassMoistureSystem.loadMap()
    g_currentMission.grassMoistureSystem = GrassMoistureSystem.new()

    if g_currentMission:getIsServer() then
        g_currentMission.grassMoistureSystem:loadFromXMLFile()
        PlayerInputComponent.update = Utils.appendedFunction(PlayerInputComponent.update, RW_PlayerInputComponent.update)
        PlayerHUDUpdater.update = Utils.appendedFunction(PlayerHUDUpdater.update, RW_PlayerHUDUpdater.update)
    end
end


addModEventListener(GrassMoistureSystem)


function GrassMoistureSystem.new()

    local self = setmetatable({}, grassMoistureSystem_mt)

    self.mission = g_currentMission
    self.areaToGrass = {}
    self.moistureDelta = 0
    self.ticksSinceLastUpdate = GrassMoistureSystem.TICKS_PER_UPDATE + 1
    self.isServer = self.mission:getIsServer()

    return self

end


function GrassMoistureSystem:delete()
    self = nil
end


function GrassMoistureSystem:update(delta)

    local linesToRemove = {}

    delta = delta * (delta > 0 and 0.5 or 1.5)
    self.moistureDelta = self.moistureDelta + delta

    if self.ticksSinceLastUpdate >= GrassMoistureSystem.TICKS_PER_UPDATE then

        self.ticksSinceLastUpdate = 0
        local grassFillType = g_fillTypeManager:getFillTypeIndexByName("GRASS_WINDROW")
        local hayFillType = g_fillTypeManager:getFillTypeIndexByName("DRYGRASS_WINDROW")

        for i, line in pairs(self.areaToGrass) do

            line.moisture = line.moisture + self.moistureDelta

            if line.moisture <= GrassMoistureSystem.HAY_MOISTURE then

                if self.isServer and grassFillType ~= nil and hayFillType ~= nil then DensityMapHeightUtil.changeFillTypeAtArea(line.sx, line.sz, line.wx, line.wz, line.hx, line.hz, grassFillType, hayFillType) end
                table.insert(linesToRemove, i)

            end

        end

        self.moistureDelta = 0

        for i = #linesToRemove, 1, -1 do table.remove(self.areaToGrass, linesToRemove[i]) end

    end

    self.ticksSinceLastUpdate = self.ticksSinceLastUpdate + 1

end


function GrassMoistureSystem:loadFromXMLFile()

    local savegameIndex = g_careerScreen.savegameList.selectedIndex
    local savegame = g_savegameController:getSavegame(savegameIndex)

    if savegame == nil or savegame.savegameDirectory == nil then return end

    local path = savegame.savegameDirectory .. "/grassMoisture.xml"

    local xmlFile = XMLFile.loadIfExists("grassMoistureXML", path)
    if xmlFile == nil then return end

    local key = "grassMoisture"

    xmlFile:iterate(key .. ".areas.area", function (_, areaKey)

        local newArea = {
            moisture = xmlFile:getFloat(areaKey .. "#moisture", 0),
            sx = xmlFile:getFloat(areaKey .. "#sx", 0),
            sz = xmlFile:getFloat(areaKey .. "#sz", 0),
            wx = xmlFile:getFloat(areaKey .. "#wx", 0),
            wz = xmlFile:getFloat(areaKey .. "#wz", 0),
            hx = xmlFile:getFloat(areaKey .. "#hx", 0),
            hz = xmlFile:getFloat(areaKey .. "#hz", 0)
        }

        table.insert(self.areaToGrass, newArea)

    end)

end


function GrassMoistureSystem:saveToXMLFile(path)

    if path == nil then return end

    local xmlFile = XMLFile.create("grassMoistureXML", path, "grassMoisture")
    if xmlFile == nil then return end

    local key = "grassMoisture"

    xmlFile:setTable(key .. ".areas.area", self.areaToGrass, function (areaKey, area)

        xmlFile:setFloat(areaKey .. "#moisture", area.moisture)

        xmlFile:setFloat(areaKey .. "#sx", area.sx)
        xmlFile:setFloat(areaKey .. "#sz", area.sz)
        xmlFile:setFloat(areaKey .. "#wx", area.wx)
        xmlFile:setFloat(areaKey .. "#wz", area.wz)
        xmlFile:setFloat(areaKey .. "#hx", area.hx)
        xmlFile:setFloat(areaKey .. "#hz", area.hz)

    end)

    xmlFile:save(false, true)

end



function GrassMoistureSystem:getMoistureAtArea(x, z)

    for _, line in pairs(self.areaToGrass) do

        if ((line.sx >= line.wx and line.sx >= x and line.wx <= x) or (line.sx <= line.wx and line.sx <= x and line.wx >= x)) and ((line.sz >= line.wz and line.sz >= z and line.wz <= z) or (line.sz <= line.wz and line.sz <= z and line.wz >= z)) then
            return true, line.moisture + self.moistureDelta
        end

    end

    return false, nil

end


function GrassMoistureSystem:addArea(sx, sz, wx, wz, hx, hz)

    local moistureSystem = g_currentMission.moistureSystem

    if moistureSystem == nil then return end

    local target = { "moisture" }

    local startMoistureValues = moistureSystem:getValuesAtCoords(sx, sz, target)
    local widthMoistureValues = moistureSystem:getValuesAtCoords(wx, wz, target)
    local heightMoistureValues = moistureSystem:getValuesAtCoords(hx, hz, target)

    local startMoisture, widthMoisture, heightMoisture = 0, 0, 0

    if startMoistureValues ~= nil and startMoistureValues.moisture ~= nil then startMoisture = startMoistureValues.moisture end
    if widthMoistureValues ~= nil and widthMoistureValues.moisture ~= nil then widthMoisture = widthMoistureValues.moisture end
    if heightMoistureValues ~= nil and heightMoistureValues.moisture ~= nil then heightMoisture = heightMoistureValues.moisture end

    local averageMoisture = (startMoisture + widthMoisture + heightMoisture) / 3

    local newAreaToGrass = {
        moisture = averageMoisture * 0.85,
        sx = sx,
        sz = sz,
        wx = wx,
        wz = wz,
        hx = hx,
        hz = hz
    }

    table.insert(self.areaToGrass, newAreaToGrass)

end