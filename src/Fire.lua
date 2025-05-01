Fire = {}


local modDirectory = g_currentModDirectory
local fire_mt = Class(Fire)
local rotationOffset = math.pi / 2


function Fire.new()

	local self = setmetatable({}, fire_mt)

	self.node = nil
	self.sharedLoadRequest = nil
	self.isInRange = false
	self.position = { 0, 0, 0 }
	self.oldPosition = nil
	self.width = 1
	self.height = 1
	self.burnTime = 0
	self.fuel = 1500
	self.direction = 0
	self.timeSinceLastUpdate = 0
	self.timeSinceLastChild = 0
	self.updatesSinceLastGroundCheck = 0
	self.isOnCultivatedGround = false
	self.lastBurnArea = 1

	return self

end


function Fire:delete()

	if self.sharedLoadRequest ~= nil then
		g_i3DManager:releaseSharedI3DFile(self.sharedLoadRequest)
		self.sharedLoadRequest = nil
	end

	delete(self.node)

end


function Fire:loadFromXMLFile(xmlFile, key)

    if xmlFile == nil then return false end

    self.position = xmlFile:getVector(key .. "#position", { 0, 0, 0 })
    self.direction = xmlFile:getFloat(key .. "#direction", 0)
    self.width = xmlFile:getFloat(key .. "#width", 1)
    self.height = xmlFile:getFloat(key .. "#height", 1)
    self.burnTime = xmlFile:getFloat(key .. "#burnTime", 0)
    self.fuel = xmlFile:getFloat(key .. "#fuel", 1500)
	self.lastChildDirection = xmlFile:getFloat(key .. "#lastChildDirection")
	self.lastBurnArea = xmlFile:getFloat(key .. "#lastBurnArea", 1)
	self.oldPosition = xmlFile:getVector(key .. "#oldPosition")
	self.timeSinceLastChild = xmlFile:getInt(key .. "#timeSinceLastChild", 0)
	self.isOnCultivatedGround = xmlFile:getBool(key .. "#isOnCultivatedGround", false)

	self:calculateDirectionFactors()

    return true

end


function Fire:saveToXMLFile(xmlFile, key)

    if xmlFile == nil then return end

    xmlFile:setVector(key .. "#position", self.position or {0, 0, 0 })
    xmlFile:setFloat(key .. "#direction", self.direction or 0)
    xmlFile:setFloat(key .. "#width", self.width or 1)
    xmlFile:setFloat(key .. "#height", self.height or 1)
	xmlFile:setFloat(key .. "#burnTime", self.burnTime or 0)
	xmlFile:setFloat(key .. "#fuel", self.fuel or 1500)
	
	if self.lastChildDirection ~= nil then xmlFile:setFloat(key .. "#lastChildDirection", self.lastChildDirection) end
	if self.lastBurnArea < 1 then xmlFile:setFloat(key .. "#lastBurnArea", self.lastBurnArea) end
	if self.oldPosition ~= nil then xmlFile:setVector(key .. "#oldPosition", self.oldPosition) end
	if self.timeSinceLastChild ~= 0 then xmlFile:setInt(key .. "#timeSinceLastChild", self.timeSinceLastChild) end
	if self.isOnCultivatedGround then xmlFile:setBool(key .. "#isOnCultivatedGround", self.isOnCultivatedGround) end

end


function Fire:writeStream(streamId)

    streamWriteFloat32(streamId, self.timeSinceLastUpdate)
    streamWriteUInt16(streamId, self.updatesSinceLastGroundCheck)

    streamWriteFloat32(streamId, self.width)
    streamWriteFloat32(streamId, self.height)

    streamWriteFloat32(streamId, self.position[1])
    streamWriteFloat32(streamId, self.position[2])
    streamWriteFloat32(streamId, self.position[3])

	if self.oldPosition == nil then

		streamWriteFloat32(streamId, self.position[1])
		streamWriteFloat32(streamId, self.position[2])
		streamWriteFloat32(streamId, self.position[3])

	else

		streamWriteFloat32(streamId, self.oldPosition[1])
		streamWriteFloat32(streamId, self.oldPosition[2])
		streamWriteFloat32(streamId, self.oldPosition[3])

	end

	streamWriteFloat32(streamId, self.fuel)
	streamWriteFloat32(streamId, self.burnTime)
	streamWriteFloat32(streamId, self.direction)
	
	streamWriteFloat32(streamId, self.lastChildDirection or self.direction)
	streamWriteFloat32(streamId, self.lastBurnArea)
	streamWriteUInt16(streamId, self.timeSinceLastChild)
	streamWriteBool(streamId, self.isOnCultivatedGround)

end


function Fire:readStream(streamId)

    self.timeSinceLastUpdate = streamReadFloat32(streamId)
    self.updatesSinceLastGroundCheck = streamReadUInt16(streamId)

    self.width = streamReadFloat32(streamId)
    self.height = streamReadFloat32(streamId)

    self.position[1] = streamReadFloat32(streamId)
    self.position[2] = streamReadFloat32(streamId)
    self.position[3] = streamReadFloat32(streamId)

    self.oldPosition[1] = streamReadFloat32(streamId)
    self.oldPosition[2] = streamReadFloat32(streamId)
    self.oldPosition[3] = streamReadFloat32(streamId)

    self.fuel = streamReadFloat32(streamId)
    self.burnTime = streamReadFloat32(streamId)
    self.direction = streamReadFloat32(streamId)

    self.lastChildDirection = streamReadFloat32(streamId)
    self.lastBurnArea = streamReadFloat32(streamId)
    self.timeSinceLastChild = streamReadUInt16(streamId)
    self.isOnCultivatedGround = streamReadBool(streamId)

    return true

end


function Fire:initialize()

	local node, sharedLoadRequest = g_i3DManager:loadSharedI3DFile(modDirectory .. "i3d/fire.i3d")

	self.node, self.sharedLoadRequest = node, sharedLoadRequest

	self.oldPosition = self.oldPosition or { self.position[1], self.position[3] }

	link(getRootNode(), node)
	setWorldTranslation(node, unpack(self.position))
	setVisibility(node, true)
	setScale(node, 1, self.height, self.width)

	local shapeNode = getChildAt(node, 0)

	setShaderParameter(shapeNode, "startPosition", math.random(), 0, 0, 0, false)

end


function Fire:calculateDirectionFactors()

	local xF, zF

	if self.direction <= -135 then
		
		xF = 0.5 * ((-180 - self.direction) / 45)
		zF = -1 - xF

	elseif self.direction <= -90 then
		
		xF = -0.5 + 0.5 * ((-135 - self.direction) / 45)
		zF = -1 - xF

	elseif self.direction <= -45 then
		
		xF = -0.5 + 0.5 * ((-90 - self.direction) / 45)
		zF = 1 + xF

	elseif self.direction <= 0 then
		
		zF = 0.5 + 0.5 * math.abs((-45 - self.direction) / 45)
		xF = -1 + zF

	elseif self.direction <= 45 then
		
		zF = 1 - 0.5 * math.abs((0 - self.direction) / 45)
		xF = 1 - zF

	elseif self.direction <= 90 then
		
		xF = 0.5 + 0.5 * math.abs((45 - self.direction) / 45)
		zF = 1 - xF

	elseif self.direction <= 135 then
		
		xF = 1 - 0.5 * math.abs((90 - self.direction) / 45)
		zF = -1 + xF

	else
		
		xF = 0.5 - 0.5 * math.abs((135 - self.direction) / 45)
		zF = -1 + xF
		
	end

	self.xF, self.zF = xF, zF

end


function Fire:createFromExistingFire(fire)

	self.width, self.height, self.fuel = math.clamp(fire.width * 0.97, 0.15, 1.4), math.clamp(fire.height * 0.97, 0.15, 1.6), fire.fuel * 0.5
	
	--self.direction = g_currentMission.fireSystem:getNextFireDirection()

	local lastChildDirection = fire.lastChildDirection or fire.direction
	
	--if fire.direction >= 0 then
		--self.direction = fire.direction + 45
	--else
		--self.direction = fire.direction - 45
	--end

	self.direction = lastChildDirection + 45

	if self.direction < -180 then
		self.direction = 360 + self.direction
	elseif self.direction > 180 then
		self.direction = -360 + self.direction
	end

	fire.lastChildDirection = self.direction

	self:calculateDirectionFactors()

	self.position = { fire.position[1] + 1.5 * self.xF, fire.position[2], fire.position[3] + 1.5 * self.zF }

	self:initialize()

end


function Fire:updateDistanceToPlayer(px, pz)

	if px == nil or pz == nil then
		self.isInRange = false
		return
	end

	local x, z = self.position[1], self.position[3]
	--local px, _, pz = g_localPlayer:getPosition()

	local distance = MathUtil.vector2Length(x - px, z - pz)
	
	self.isInRange = distance < 250

end


function Fire:update(fireSystem, isRaining)

	local timescale = math.min(self.timeSinceLastUpdate, 2500)

	if self.isInRange then

		local dx, _, dz = localDirectionToWorld(g_localPlayer.camera.cameraRootNode, 0, 0, -1)
		local dir = MathUtil.getYRotationFromDirection(dx, dz)

		dir = dir + (dir >= 0 and -rotationOffset or rotationOffset)

		setWorldRotation(self.node, 0, dir, 0)

	end

	local x, z = self.position[1], self.position[3]
	
	local step = 0.000018 * timescale

	local isOnCultivatedGround, shrinkFactor = self.isOnCultivatedGround, isRaining and 10 or 1

	if isOnCultivatedGround then
		step = step * 0.3
		shrinkFactor = shrinkFactor + 50
	end
		
	x, z = x + step * self.xF, z + step * self.zF

	self.position[1], self.position[3] = x, z

	setWorldTranslation(self.node, x, self.position[2], z)

	local burnTime = self.burnTime + math.min(0.0012 * timescale, 1.5)
	local fuel = math.clamp(self.fuel - self.width * self.height * timescale * 0.00065 * shrinkFactor, 0, 2500)

	local width, height = self.width, self.height

	width = math.max(width - 0.0002 * (self.fuel - fuel) * shrinkFactor, 0.15)
	height = math.max(height - 0.000175 * (self.fuel - fuel) * shrinkFactor, 0.15)

	if fuel <= 0 or width <= 0.15 or height <= 0.15 then

		self:delete()
		return true

	end

	local numFires = #fireSystem.fires

	if not isOnCultivatedGround and burnTime >= 3 - width * height then
	
		local ox, oz = self.oldPosition[1], self.oldPosition[2]
		
		local burnDistance = MathUtil.vector2Length(ox - x, oz - z)

		if burnDistance >= 0.5 then


			local burnWidth = x - ox
			local burnHeight = z - oz
			local dataPlaneId = g_fruitTypeManager:getDefaultDataPlaneId()
			local totalBurnArea = 0
			local burnArea = 0

			for i = 0, burnDistance, 0.25 do

				local burnX = ox + 0.25 + burnWidth * (i / burnDistance)
				local burnZ = oz + 0.25 + burnHeight * (i / burnDistance)
				
				local fruitTypeIndex = getDensityTypeIndexAtWorldPos(dataPlaneId, burnX, 0, burnZ)
				local fruitType = g_fruitTypeManager:getFruitTypeByDensityTypeIndex(fruitTypeIndex)

				local growthState = getDensityStatesAtWorldPos(dataPlaneId, burnX, 0, burnZ)

				if growthState > 0 and growthState <= fruitType.maxHarvestingGrowthState then burnArea = burnArea + 1 end

				totalBurnArea = totalBurnArea + 1

			end

			RWUtils.burnArea(ox + 0.2, oz + 0.2, ox - 0.2, oz - 0.2, x, z)


			self.lastBurnArea = (burnArea / totalBurnArea)

			burnDistance = burnDistance * (burnArea / totalBurnArea)

			burnTime = 0
			fuel = fuel + burnDistance * 80 * width * height
			self.oldPosition = { x, z }

			width = math.min(width + burnDistance * 0.0006, 1.4)
			height = math.min(width + burnDistance * 0.00075, 1.6)

			if self.timeSinceLastChild >= 350 and fuel > width * height * 100 and numFires < 20 then
			
				self.width, self.height = width, height
				self.timeSinceLastChild = 0

				local fire = Fire.new()
				fire:createFromExistingFire(self)
				table.insert(fireSystem.fires, fire)

				fuel = fuel * 0.5
		
			end

		end

	end


	self.width, self.height = width, height
	self.burnTime, self.fuel = burnTime, fuel

	setScale(self.node, 1, height, width)

	self.timeSinceLastUpdate = 0
	self.timeSinceLastChild = math.min(self.timeSinceLastChild + 1 * numFires, 1000)
	self.updatesSinceLastGroundCheck = self.updatesSinceLastGroundCheck + 1 * numFires

	if self.updatesSinceLastGroundCheck >= 100 then
		self.updatesSinceLastGroundCheck = 0
		self:updateGroundDetails()
	end

	return false

end


function Fire:updateGroundDetails()

	local groundTypeValue = g_currentMission.fieldGroundSystem:getValueAtWorldPos(FieldDensityMap.GROUND_TYPE, self.position[1], 0, self.position[3])
    local groundType = FieldGroundType.getTypeByValue(groundTypeValue)

	self.isOnCultivatedGround = groundType == FieldGroundType.CULTIVATED or groundType == FieldGroundType.NONE

	self.position[2] = getTerrainHeightAtWorldPos(g_terrainNode, self.position[1], 0, self.position[3]) - 0.1
	
	if self.isOnCultivatedGround or self.lastBurnArea < 0.33 then

		self.direction = self.direction + 25

		if self.direction > 180 then self.direction = -360 + self.direction end

		self:calculateDirectionFactors()

	end

end