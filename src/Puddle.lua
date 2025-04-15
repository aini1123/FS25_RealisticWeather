Puddle = {}

local puddle_mt = Class(Puddle)


function Puddle.new(variation, terrainHeight)

    local self = setmetatable({}, puddle_mt)

    self.variation = variation
    self.node = 0
    self.size = { 0, 0 }
    self.widthLeft = 1
    self.widthRight = 1
    self.position = { 0, 0, 0 }
    self.rotation = { 0, 0, 0 }
    self.moisture = 0
    self.terrainHeight = terrainHeight
    self.timeSinceLastUpdate = 0

    self.points = { ["inner"] = {}, ["outer"] = {} }
    self.shapes = { ["right"] = {}, ["left"] = {} }
    self.feelers = { ["up"] = {}, ["down"] = {}, ["left"] = {}, ["right"] = {} }

    return self

end


function Puddle:delete()

    if self.node ~= nil then
        for _, shape in pairs(self.shapes) do
            g_currentMission.shallowWaterSimulation:removeWaterPlane(shape)
	        g_currentMission.shallowWaterSimulation:removeAreaGeometry(shape)
        end
        delete(self.node)
    end
    self.node = 0

end


function Puddle:loadFromXMLFile(xmlFile, key)

    if xmlFile == nil then return false end

    self.variation = xmlFile:getInt(key .. "#variation", 1)
    self.size = xmlFile:getVector(key .. "#size", { 0, 0 })
    self.position = xmlFile:getVector(key .. "#position", { 0, 0, 0 })
    self.rotation = xmlFile:getVector(key .. "#rotation", { 0, 0, 0 })
    self.terrainHeight = xmlFile:getFloat(key .. "#terrainHeight", nil)
    self.widthLeft = math.clamp(xmlFile:getFloat(key .. "#wl", 1), 0.1, 1.75)
    self.widthRight = math.clamp(xmlFile:getFloat(key .. "#wr", 1), 0.1, 1.75)

    return true

end


function Puddle:saveToXMLFile(xmlFile, key)

    if xmlFile == nil then return end

    xmlFile:setInt(key .. "#variation", self.variation or 1)
    xmlFile:setFloat(key .. "#terrainHeight", self.terrainHeight or getTerrainHeightAtWorldPos(g_terrainNode, self.position[1], 0, self.position[3]))
    xmlFile:setVector(key .. "#size", self.size or { 0, 0 })
    xmlFile:setVector(key .. "#position", self.position or {0, 0, 0 })
    xmlFile:setVector(key .. "#rotation", self.rotation or {0, 0, 0 })
    xmlFile:setFloat(key .. "#wl", self.widthLeft or 1)
    xmlFile:setFloat(key .. "#wr", self.widthRight or 1)

end


function Puddle:initialize()

    local puddleSystem = g_currentMission.puddleSystem
    local variation = puddleSystem:getVariationById(self.variation)
    local node = clone(variation.node, false, false, true)

    if node == nil or node == 0 then
        puddleSystem:removePuddle(self)
        return
    end

    link(getRootNode(), node)
    
    setVisibility(node, true)
    setWorldTranslation(node, unpack(self.position))
    setScale(node, self.size[1], 1.75, self.size[2])
    setWorldRotation(node, unpack(self.rotation))

    self.node = node

    for i = 0, variation.shapes - 1 do

        local shape = getChildAt(node, i)

        PuddleSystem.onCreateWater(shape)

        local shapeName = getName(shape)

        local innerPoints = getChild(shape, shapeName .. "Inner")
        local path = shapeName .. "Inner"

        self.points.inner[shapeName] = {}
        self.points.outer[shapeName] = {}

        self.shapes[shapeName] = shape
        
        for j = 0, variation.groups[path] - 1 do

            local point = getChild(innerPoints, path .. (j + 1))
            local x, y, z = getWorldTranslation(point)
            local t = getTerrainHeightAtWorldPos(g_terrainNode, x, 0, z)
            self.points.inner[shapeName][j + 1] = { ["node"] = point, ["x"] = x, ["y"] = y, ["z"] = z, ["t"] = t }

        end

        local outerPoints = getChild(shape, shapeName .. "Outer")
        path = shapeName .. "Outer"
        
        for j = 0, variation.groups[path] - 1 do

            local point = getChild(outerPoints, path .. (j + 1))
            local x, y, z = getWorldTranslation(point)
            local t = getTerrainHeightAtWorldPos(g_terrainNode, x, 0, z)
            self.points.outer[shapeName][j + 1] = { ["node"] = point, ["x"] = x, ["y"] = y, ["z"] = z, ["t"] = t }

        end


        local feelerGroup = getChild(shape, shapeName .. "Feelers")

        for j = 0, variation.groups[shapeName .. "Feelers"] - 1 do

            local feelerNode = getChildAt(feelerGroup, j)
            local feelerName = getName(feelerNode)
            
            local p, _ = string.find(feelerName, "Feeler")
            local connectorId = getUserAttribute(feelerNode, "connector")
            local connectorNode = self.points.outer[shapeName][connectorId].node

            local baseId = getUserAttribute(feelerNode, "base")
            local baseNode = self.points.outer[shapeName][baseId].node
            
            self.feelers[string.sub(feelerName, 1, p - 1)] = { ["feeler"] = feelerNode, ["connector"] = connectorNode, ["base"] = baseNode }

        end


    end

    setScale(self.shapes.left, self.widthLeft, 1, 1)
    setScale(self.shapes.right, self.widthRight, 1, 1)

end


function Puddle:setPosition(x, y, z)
    
    self.position = table.pack(x, y, z)

end


function Puddle:applyPosition()

    setWorldTranslation(self.node, unpack(self.position))

end


function Puddle:setScale(width, height)
    
    self.size = table.pack(width, height)

end


function Puddle:applyScale()

    setScale(self.node, self.size[1], 1.75, self.size[2])
    setScale(self.shapes.left, self.widthLeft, 1, 1)
    setScale(self.shapes.right, self.widthRight, 1, 1)

end

function Puddle:setMoisture(moisture)

    self.moisture = moisture

end


function Puddle:setRotation(dx, dy, dz)

    self.rotation = table.pack(dx, dy, dz)

end


function Puddle:applyRotation()

    setWorldRotation(self.node, unpack(self.rotation))

end


function Puddle:update(moistureSystem)

    local timescale = self.timeSinceLastUpdate
    local moisture = moistureSystem:getValuesAtCoords(self.position[1], self.position[3], { "moisture" }).moisture

    for name, feeler in pairs(self.feelers) do

        local fx, _, fz = getWorldTranslation(feeler.feeler)
        local cx, _, cz = getWorldTranslation(feeler.connector)
        local bx, _, bz = getWorldTranslation(feeler.base)
        --local fm = moistureSystem:getValuesAtCoords(fx, fz, { "moisture" }).moisture
        --local cm = moistureSystem:getValuesAtCoords(cx, cz, { "moisture" }).moisture


        -- feeler = outside puddle
        -- connector = outer ring of puddle
        -- base = inner ring of puddle
        -- puddle goes from high moisture to low, or high to higher? or neither?
        -- if terrain height at feeler < terrain height at feeler connector then flow towards that feeler
        -- if terrain height at feeler connector > terrain height at feeler base then flow away from that feeler

        local ft = getTerrainHeightAtWorldPos(g_terrainNode, fx, 0, fz)
        local ct = getTerrainHeightAtWorldPos(g_terrainNode, cx, 0, cz)
        local bt = getTerrainHeightAtWorldPos(g_terrainNode, bx, 0, bz)

        local cfd = ct - ft
        local bcd = bt - ct

        if bcd ~= 0 then
            if name == "left" then self.widthLeft = math.clamp(self.widthLeft + bcd * timescale * 0.00005, 0.1, 1.75) end
            if name == "right" then self.widthRight = math.clamp(self.widthRight + bcd * timescale * 0.00005, 0.1, 1.75) end
        end
        
        if bcd >= 0 and cfd > 0 then
            if name == "left" then self.widthLeft = math.clamp(self.widthLeft + cfd * timescale * 0.00005, 0.1, 1.75) end
            if name == "right" then self.widthRight = math.clamp(self.widthRight + cfd * timescale * 0.00005, 0.1, 1.75) end
        end

        --print(string.format("feeler %s: %.5f (%.2f, %.2f), %.5f (%.2f, %.2f)", name, fm, fx + 1024, fz + 1024, cm, cx + 1024, cz + 1024))

    end

    self.terrainHeight = self.terrainHeight or getTerrainHeightAtWorldPos(g_terrainNode, self.position[1], 0, self.position[3])

    local delta = (moisture - self.moisture) * timescale * 0.003
    local width, height = unpack(self.size)
    local y = self.position[2] + delta * 0.04

    width = math.clamp(width + delta, 0, 2)
    height = math.clamp(height + delta, 0, 2)

    if width <= 0 or height <= 0 or (self.widthLeft <= 0 and self.widthRight <= 0) or not self:getIsAboveGround() then
        self:delete()
        g_currentMission.puddleSystem:removePuddle(self)
        return
    end

    self:setScale(width, height)

    self.moisture = moisture


    -- keep puddle grounded, only the inner ring can be above terrain height as it is sloped

    local yOffset = self:getHighestTerrainOffset(y - self.position[2])
    if yOffset > 0 then y = self.position[2] - yOffset end

    self.position[2] = y

    self:applyPosition()
    self:applyScale()
    self:applyRotation()

    self.timeSinceLastUpdate = 0

    self:updateCachedCoords()

end


function Puddle:getIsPointInsidePuddle(x, z)

    local inside = false
    local shapes = self.points.outer

    for _, polygon in pairs(shapes) do

        local p1 = polygon[1]
        local p2

        for i = 1, #polygon do

            p2 = polygon[(i % #polygon) + 1]

            if z > math.min(p1.z, p2.z) and z <= math.max(p1.z, p2.z) and x <= math.max(p1.x, p2.x) then

                local intersection = (z - p1.z) * (p2.x - p1.x) / (p2.z - p1.z) + p1.x

                if p1.x == p2.x or x <= intersection then inside = not inside end

            end

            p1 = p2

        end

        if inside then return true end

    end

    return inside

end


function Puddle:updateCachedCoords()

    for i, pointType in pairs(self.points) do
        for j, shape in pairs(pointType) do
            for k, point in pairs(shape) do
              
                local x, y, z = getWorldTranslation(point.node)
                point.x, point.y, point.z = x, y, z
                point.t = getTerrainHeightAtWorldPos(g_terrainNode, x, y, z)

            end
        end
    end

end


function Puddle:getHighestTerrainOffset(delta)

    local maxOffset = 0
    
    for _, shape in pairs(self.points.outer) do

        for _, point in pairs(shape) do

            local offset = point.y + delta - point.t
            if offset > maxOffset then maxOffset = offset end

        end

    end

    return maxOffset

end


function Puddle:getIsAboveGround()

    for _, pointType in pairs(self.points) do
        for _, shape in pairs(pointType) do
            for _, point in pairs(shape) do
                if point.y >= point.t then return true end
            end
        end
    end

    return false

end


function Puddle:writeStream(streamId)

    streamWriteUInt8(streamId, self.variation)
    streamWriteFloat32(streamId, self.size[1])
    streamWriteFloat32(streamId, self.size[2])
    streamWriteFloat32(streamId, self.position[1])
    streamWriteFloat32(streamId, self.position[2])
    streamWriteFloat32(streamId, self.position[3])
    streamWriteFloat32(streamId, self.rotation[1])
    streamWriteFloat32(streamId, self.rotation[2])
    streamWriteFloat32(streamId, self.rotation[3])
    streamWriteFloat32(streamId, self.moisture)
    streamWriteFloat32(streamId, self.terrainHeight)
    streamWriteFloat32(streamId, self.timeSinceLastUpdate)
    streamWriteFloat32(streamId, self.widthLeft)
    streamWriteFloat32(streamId, self.widthRight)

end


function Puddle:readStream(streamId)

    self.variation = streamReadUInt8(streamId)
    self.size[1] = streamReadFloat32(streamId)
    self.size[2] = streamReadFloat32(streamId)
    self.position[1] = streamReadFloat32(streamId)
    self.position[2] = streamReadFloat32(streamId)
    self.position[3] = streamReadFloat32(streamId)
    self.rotation[1] = streamReadFloat32(streamId)
    self.rotation[2] = streamReadFloat32(streamId)
    self.rotation[3] = streamReadFloat32(streamId)
    self.moisture = streamReadFloat32(streamId)
    self.terrainHeight = streamReadFloat32(streamId)
    self.timeSinceLastUpdate = streamReadFloat32(streamId)
    self.widthLeft = streamReadFloat32(streamId)
    self.widthRight = streamReadFloat32(streamId)

    return true

end