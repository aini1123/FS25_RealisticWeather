RW_HarvestMission = {}

local function getHarvestScaleAtPoint(x, z)

	local state = FieldState.new()
	local scale = 0
	state:update(x, z)

	if state.fruitTypeIndex ~= FruitType.UNKNOWN then
		local fruit = g_fruitTypeManager:getFruitTypeByIndex(state.fruitTypeIndex)

		if not fruit:getIsWithered(state.growthState) then scale = state:getHarvestScaleMultiplier() end
	end

	state = nil
	return scale

end

function RW_HarvestMission:getMaxCutLiters(superFunc)

	local field = self.field
	local polygon = field.densityMapPolygon
	local vertices = polygon:getVerticesList()
	local scale, points = 0, 0
	local cx, cz = 0, 0

	for i = 1, #vertices, 2 do

		local x, z = vertices[i], vertices[i + 1]

		if x == nil or z == nil then break end

		cx = cx + x
		cz = cz + z

	end

	cx = cx / (#vertices / 2)
	cz = cz / (#vertices / 2)

	for i = 1, #vertices, 2 do

		local x, z = vertices[i], vertices[i + 1]

		if x == nil or z == nil then break end

		local nextX = vertices[i + 2] or vertices[1]
		local nextZ = vertices[i + 3] or vertices[2]
		
		local minX, maxX = math.min(x, nextX, cx), math.max(x, nextX, cx)
		local minZ, maxZ = math.min(z, nextZ, cz), math.max(z, nextZ, cz)
		local norZ

		if cz ~= minZ and cz ~= maxZ then 
			norZ = cz
		elseif nextZ ~= minZ and nextZ ~= maxZ then 
			norZ = nextZ
		else
			norZ = z
	    end
	

		for px = minX, maxX do
		
			for pz = minZ, norZ do
				
				points = points + 1
				scale = scale + getHarvestScaleAtPoint(px, pz)

			end

			for pz = norZ, maxZ do
			
				points = points + 1
				scale = scale + getHarvestScaleAtPoint(px, pz)

			end

		end

	end

	local originalLitres = superFunc(self)

	if originalLitres == 0 then return 0 end

	local scaledLitres = (originalLitres / points) * scale

	return math.min(originalLitres, scaledLitres)

end

HarvestMission.getMaxCutLiters = Utils.overwrittenFunction(HarvestMission.getMaxCutLiters, RW_HarvestMission.getMaxCutLiters)