PuddleSystem = {}

local puddleSystem_mt = Class(PuddleSystem)
local modDirectory = g_currentModDirectory

PuddleSystem.maxPuddles = Utils.getPerformanceClassId() * 4


function PuddleSystem.new()

    local self = setmetatable({}, puddleSystem_mt)

    self.puddles = {}
    self.variations = {}
    self.updateIteration = 1
    self.timeSinceLastUpdate = 0
    self.isServer = g_currentMission:getIsServer()
    self.puddlesEnabled = true

    return self

end


function PuddleSystem.onCreateWater(node)

	if getHasClassId(node, ClassIds.SHAPE) then

		if not Utils.getNoNil(getUserAttribute(node, "useShapeObjectMask"), false) then
			local mask = bitAND(getObjectMask(node), bitNOT(ObjectMask.SHAPE_VIS_MIRROR))
			setObjectMask(node, mask)
		end

		if getShapeCastShadowmap(node) then
			Logging.i3dWarning(node, "PuddleSystem:onCreateWater(): Water plane has shadow casting active")
		end

		if not getShapeReceiveShadowmap(node) then
			Logging.i3dWarning(node, "PuddleSystem:onCreateWater(): Water plane is missing shadow receive")
		end

		local performanceClass = Utils.getPerformanceClassId()

		if performanceClass <= GS_PROFILE_MEDIUM or GS_IS_CONSOLE_VERSION then
			setReflectionMapScaling(node, 0, true)
		elseif performanceClass <= GS_PROFILE_HIGH then
			setReflectionMapObjectMasks(node, ObjectMask.SHAPE_VIS_WATER_REFL, ObjectMask.LIGHT_VIS_WATER_REFL, true)
		else
			setReflectionMapObjectMasks(node, ObjectMask.SHAPE_VIS_WATER_REFL_VERYHIGH, ObjectMask.LIGHT_VIS_WATER_REFL_VERYHIGH, true)
		end

		if getRigidBodyType(node) ~= RigidBodyType.NONE then
			if not CollisionFlag.getHasGroupFlagSet(node, CollisionFlag.WATER) then
				Logging.i3dWarning(node, "PuddleSystem:onCreateWater(): Water plane is missing %s", CollisionFlag.getBitAndName(CollisionFlag.WATER))
			end
			if g_currentMission.shallowWaterSimulation ~= nil then
				g_currentMission.shallowWaterSimulation:addWaterPlane(node)
				g_currentMission.shallowWaterSimulation:addAreaGeometry(node)
			end
		end

	else
		Logging.i3dError(node, "PuddleSystem:onCreateWater(): Given node is not a shape, ignoring")
	end

end


function PuddleSystem:loadVariations()

    local xmlFile = XMLFile.loadIfExists("PuddleSystem", modDirectory .. "xml/puddles.xml")

    if xmlFile == nil then return end

    local rootNode = getRootNode()

    xmlFile:iterate("variations.variation", function (_, key)

        local path = xmlFile:getString(key .. "#file")
        local id = xmlFile:getInt(key .. "#id")
        local node = g_i3DManager:loadI3DFile(modDirectory .. path, false, false)

        if node ~= 0 then
            
            link(rootNode, node)
            
            setVisibility(node, false)
            setWorldTranslation(node, 0, 0, 0)
            local numShapes = getNumOfChildren(node)
            local groups = {}

            for i = 0, numShapes - 1 do

                local shapeNode = getChildAt(node, i)
                local shapeChildren = getNumOfChildren(shapeNode)

                for j = 0, shapeChildren - 1 do

                    local group = getChildAt(shapeNode, j)
                    local groupName = getName(group)
                    local groupChildren = getNumOfChildren(group)

                    groups[groupName] = groupChildren

                end

            end

            table.insert(self.variations, { ["node"] = node, ["path"] = path, ["id"] = id, ["groups"] = groups, ["shapes"] = numShapes })

        end

    end)

    xmlFile:delete()

    if self.isServer then self:loadFromXMLFile() end

end


function PuddleSystem:loadFromXMLFile()

    local savegameIndex = g_careerScreen.savegameList.selectedIndex
    local savegame = g_savegameController:getSavegame(savegameIndex)

    if savegame == nil or savegame.savegameDirectory == nil then return end

    local xmlFile = XMLFile.loadIfExists("puddlesXML", savegame.savegameDirectory .. "/puddles.xml")

    if xmlFile == nil then return end

    xmlFile:iterate("puddles.puddle", function(_, key)

        local puddle = Puddle.new()
        local success = puddle:loadFromXMLFile(xmlFile, key)

        if success then table.insert(self.puddles, puddle) end

    end)

    xmlFile:delete()

end


function PuddleSystem:saveToXMLFile(path)

    if path == nil then return end

    local xmlFile = XMLFile.create("puddlesXML", path, "puddles")
    if xmlFile == nil then return end

    for i = 1, #self.puddles do

        local puddle = self.puddles[i]
        puddle:saveToXMLFile(xmlFile, string.format("puddles.puddle(%d)", i - 1))

    end

    xmlFile:save(false, true)

end


function PuddleSystem:initialize()

    for _, puddle in pairs(self.puddles) do puddle:initialize() end

end


function PuddleSystem:getVariationById(id)

    for _, variation in pairs(self.variations) do

        if variation.id == id then return variation end

    end

    return nil

end


function PuddleSystem:getRandomVariation()
    return self.variations[math.random(1, #self.variations)]
end


function PuddleSystem:addPuddle(puddle)

    table.insert(self.puddles, puddle)

end


function PuddleSystem:removePuddle(puddle)

    for i, p in pairs(self.puddles) do
        if p == puddle then
            table.remove(self.puddles, i)
            puddle = nil
            break
        end
    end

end


function PuddleSystem:getClosestPuddleToPoint(x, z)

    local closestPoint = { ["distance"] = 10000, ["puddle"] = nil }

    for _, puddle in pairs(self.puddles) do

        local distance = MathUtil.vector2Length(x - puddle.position[1], z - puddle.position[3])
        
        if closestPoint.puddle == nil or closestPoint.distance > distance then closestPoint = { ["distance"] = distance, ["puddle"] = puddle } end 

    end

    return closestPoint

end


function PuddleSystem:update(timescale, moistureSystem)

    if moistureSystem == nil or moistureSystem.isSaving or not self.puddlesEnabled then return end

    for _, puddle in pairs(self.puddles) do

        puddle.timeSinceLastUpdate = puddle.timeSinceLastUpdate + timescale + self.timeSinceLastUpdate

    end

    self.timeSinceLastUpdate = 0

    local puddle = self.puddles[self.updateIteration] or self.puddles[1]

    if puddle == nil then return end

    self.updateIteration = self.updateIteration + 1
    if self.updateIteration > #self.puddles then self.updateIteration = 1 end

    if puddle.node ~= nil and puddle.node ~= 0 then
        puddle:update(moistureSystem)
    elseif puddle ~= nil then
        if puddle.node ~= 0 and puddle.node ~= nil then puddle:delete() end
        self:removePuddle(puddle)
        self.updateIteration = self.updateIteration - 1
    end

    --for i = #self.puddles, 1, -1 do
        
        --local puddle = self.puddles[i]

        --if puddle.node ~= nil then
            --puddle:update(timescale, moistureSystem)

            --if puddle.node ~= 0 then
                --puddle:applyScale()
                --puddle:applyPosition()
            --end
        --else
            --puddle:delete()
            --self:removePuddle(puddle)
        --end

    --end

    --self:updateCachedCoords()

end


function PuddleSystem:getCanCreatePuddle()
    return self.isServer and #self.puddles < PuddleSystem.maxPuddles and self.puddlesEnabled
end


function PuddleSystem:getPuddleAtCoords(x, z)

    for _, puddle in pairs(self.puddles) do

        if puddle:getIsPointInsidePuddle(x, z) then return puddle end

    end

    return nil

end


function PuddleSystem:updateCachedCoords()

    for _, puddle in pairs(self.puddles) do
        if puddle.node ~= 0 then puddle:updateCachedCoords() end
    end

end


function PuddleSystem.onSettingChanged(name, state)

    local puddleSystem = g_currentMission.puddleSystem

    if puddleSystem == nil then return end

    puddleSystem[name] = state

    if name == "puddlesEnabled" and not state and puddleSystem.puddles ~= nil then

        for i = #puddleSystem.puddles, 1, -1 do

            local puddle = puddleSystem.puddles[i]
            puddle:delete()
            table.remove(puddleSystem.puddles, i)

        end

    end

end