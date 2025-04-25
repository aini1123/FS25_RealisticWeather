RWUtils = {}
RWUtils.functionCache = {}


function RWUtils.witherArea(sx, sz, wx, wz, hx, hz)

	local cache = RWUtils.functionCache.witherArea

	if cache == nil then

		local fieldGroundSystem = g_currentMission.fieldGroundSystem

		local groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.GROUND_TYPE)
		local sprayTypeMapId, sprayTypeFirstChannel, sprayTypeNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.SPRAY_TYPE)

		cache = {
			["modifier"] = DensityMapModifier.new(sprayTypeMapId, sprayTypeFirstChannel, sprayTypeNumChannels, g_terrainNode),
			["multiModifier"] = nil,
			["filter1"] = DensityMapFilter.new(groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels),
			["filter2"] = DensityMapFilter.new(groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels),
			["fieldFilter"] = DensityMapFilter.new(groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels)
		}

		cache.fieldFilter:setValueCompareParams(DensityValueCompareType.GREATER, 0)
		RWUtils.functionCache.witherArea = cache

	end

	local modifier = cache.modifier
	local multiModifier = cache.multiModifier
	local filter1 = cache.filter1
	local filter2 = cache.filter2
	local fieldFilter = cache.fieldFilter

	g_currentMission.growthSystem:setIgnoreDensityChanges(true)

	if multiModifier == nil then

		multiModifier = DensityMapMultiModifier.new()
		cache.multiModifier = multiModifier

		for _, fruitType in pairs(g_fruitTypeManager:getFruitTypes()) do

			if fruitType.terrainDataPlaneId ~= nil and fruitType.witheredState ~= nil and fruitType.cutState ~= nil then

				modifier:resetDensityMapAndChannels(fruitType.terrainDataPlaneId, fruitType.startStateChannel, fruitType.numStateChannels)
				filter1:resetDensityMapAndChannels(fruitType.terrainDataPlaneId, fruitType.startStateChannel, fruitType.numStateChannels)
				filter2:resetDensityMapAndChannels(fruitType.terrainDataPlaneId, fruitType.startStateChannel, fruitType.numStateChannels)

				local minWitherableState = fruitType.minHarvestingGrowthState - 1

				if fruitType.minPreparingGrowthState >= 0 then minWitherableState = math.min(minWitherableState, fruitType.minPreparingGrowthState - 1) end

				minWitherableState = math.max(math.ceil(minWitherableState - fruitType.numGrowthStates * 0.5), 2)

				filter1:setValueCompareParams(DensityValueCompareType.BETWEEN, minWitherableState, fruitType.maxHarvestingGrowthState)
				filter2:setValueCompareParams(DensityValueCompareType.BETWEEN, 1, minWitherableState - 1)
				
				multiModifier:addExecuteSet(fruitType.witheredState, modifier, filter1, fieldFilter)
				multiModifier:addExecuteSet(fruitType.cutState, modifier, filter2, fieldFilter)

			end

		end

		for i = 1, #g_currentMission.dynamicFoliageLayers do

			local dynamicFoliageLayer = g_currentMission.dynamicFoliageLayers[i]
			modifier:resetDensityMapAndChannels(dynamicFoliageLayer, 0, (getTerrainDetailNumChannels(dynamicFoliageLayer)))
			multiModifier:addExecuteSet(0, modifier)

		end

	end

	multiModifier:updateParallelogramWorldCoords(sx, sz, wx, wz, hx, hz, DensityCoordType.POINT_POINT_POINT)
	multiModifier:execute()

	FSDensityMapUtil.removeWeedArea(sx, sz, wx, wz, hx, hz)
	g_currentMission.growthSystem:setIgnoreDensityChanges(false)

end


function RWUtils.burnArea(sx, sz, wx, wz, hx, hz)

	local cache = RWUtils.functionCache.burnArea

	if cache == nil then

		local fieldGroundSystem = g_currentMission.fieldGroundSystem

		local groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.GROUND_TYPE)
		local sprayTypeMapId, sprayTypeFirstChannel, sprayTypeNumChannels = fieldGroundSystem:getDensityMapData(FieldDensityMap.SPRAY_TYPE)

		cache = {
			["modifier"] = DensityMapModifier.new(sprayTypeMapId, sprayTypeFirstChannel, sprayTypeNumChannels, g_terrainNode),
			["groundModifier"] = DensityMapModifier.new(groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels, g_terrainNode),
			["multiModifier"] = nil,
			["filter1"] = DensityMapFilter.new(groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels),
			["fieldFilter"] = DensityMapFilter.new(groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels),
			["notCultivatedFilter"] = DensityMapFilter.new(groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels),
			["stubbleType"] = FieldGroundType.getValueByType(FieldGroundType.STUBBLE_TILLAGE)
		}

		cache.fieldFilter:setValueCompareParams(DensityValueCompareType.GREATER, 0)
		cache.notCultivatedFilter:setValueCompareParams(DensityValueCompareType.NOTEQUAL, FieldGroundType.getValueByType(FieldGroundType.CULTIVATED))
		RWUtils.functionCache.burnArea = cache

	end

	local modifier = cache.modifier
	local multiModifier = cache.multiModifier
	local filter1 = cache.filter1
	local fieldFilter = cache.fieldFilter
	local notCultivatedFilter = cache.notCultivatedFilter

	local area, totalArea = RWUtils.getCropDensityAtArea(sx, sz, wx, wz, hx, hz)

	g_currentMission.growthSystem:setIgnoreDensityChanges(true)

	if multiModifier == nil then

		multiModifier = DensityMapMultiModifier.new()
		cache.multiModifier = multiModifier

		for _, fruitType in pairs(g_fruitTypeManager:getFruitTypes()) do

			if fruitType.terrainDataPlaneId ~= nil then

				modifier:resetDensityMapAndChannels(fruitType.terrainDataPlaneId, fruitType.startStateChannel, fruitType.numStateChannels)
				filter1:resetDensityMapAndChannels(fruitType.terrainDataPlaneId, fruitType.startStateChannel, fruitType.numStateChannels)

				if fruitType.witheredState ~= nil and fruitType.witheredState > fruitType.cutState then
					filter1:setValueCompareParams(DensityValueCompareType.BETWEEN, 1, fruitType.witheredState)
				else
					filter1:setValueCompareParams(DensityValueCompareType.BETWEEN, 1, fruitType.cutState)
				end

				multiModifier:addExecuteSet(fruitType.disasterDestructionState, modifier, filter1, fieldFilter, notCultivatedFilter)

			end

		end

		for i = 1, #g_currentMission.dynamicFoliageLayers do

			local dynamicFoliageLayer = g_currentMission.dynamicFoliageLayers[i]
			modifier:resetDensityMapAndChannels(dynamicFoliageLayer, 0, (getTerrainDetailNumChannels(dynamicFoliageLayer)))
			multiModifier:addExecuteSet(0, modifier)

		end

		multiModifier:addExecuteSet(cache.stubbleType, cache.groundModifier, fieldFilter)

	end

	multiModifier:updateParallelogramWorldCoords(sx, sz, wx, wz, hx, hz, DensityCoordType.POINT_POINT_POINT)
	multiModifier:execute()

	FSDensityMapUtil.removeWeedArea(sx, sz, wx, wz, hx, hz)
	g_currentMission.growthSystem:setIgnoreDensityChanges(false)

	return area, totalArea

end


function RWUtils.getCropDensityAtArea(sx, sz, wx, wz, hx, hz)

	local cache = RWUtils.functionCache.getCropDensityAtArea

	if cache == nil then

		local fruitTypes = g_fruitTypeManager:getFruitTypes()
		local multiModifier = DensityMapMultiModifier.new()

		cache = {}

		for _, fruitType in pairs(fruitTypes) do

			if fruitType.terrainDataPlaneId == nil then continue end

			local modifier = DensityMapModifier.new(fruitType.terrainDataPlaneId, fruitType.startStateChannel, fruitType.numStateChannels, g_terrainNode)
			
			for state = 1, fruitType.numFoliageStates do

				local filter = DensityMapFilter.new(modifier)
				filter:setValueCompareParams(DensityValueCompareType.EQUAL, state)
				multiModifier:addExecuteGet(fruitType.name .. "|" .. state, modifier, filter)

			end

		end

		cache.multiModifier	= multiModifier

		RWUtils.functionCache.getCropDensityAtArea = cache

	end

	local multiModifier = cache.multiModifier

	multiModifier:resetStats()
	multiModifier:updateParallelogramWorldCoords(sx, sz, wx, wz, hx, hz, DensityCoordType.POINT_POINT_POINT)
	local _, area, _, totalArea = multiModifier:execute(nil)

	return area, totalArea

end