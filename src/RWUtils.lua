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
			["fieldFilter"] = DensityMapFilter.new(groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels)
		}

		cache.fieldFilter:setValueCompareParams(DensityValueCompareType.GREATER, 0)
		RWUtils.functionCache.witherArea = cache

	end

	local modifier = cache.modifier
	local multiModifier = cache.multiModifier
	local filter1 = cache.filter1
	local fieldFilter = cache.fieldFilter

	g_currentMission.growthSystem:setIgnoreDensityChanges(true)

	if multiModifier == nil then

		multiModifier = DensityMapMultiModifier.new()
		cache.multiModifier = multiModifier

		for _, fruitType in pairs(g_fruitTypeManager:getFruitTypes()) do

			if fruitType.terrainDataPlaneId ~= nil and fruitType.witheredState ~= nil then

				modifier:resetDensityMapAndChannels(fruitType.terrainDataPlaneId, fruitType.startStateChannel, fruitType.numStateChannels)
				filter1:resetDensityMapAndChannels(fruitType.terrainDataPlaneId, fruitType.startStateChannel, fruitType.numStateChannels)
				filter1:setValueCompareParams(DensityValueCompareType.BETWEEN, fruitType.minPreparingGrowthState, fruitType.maxHarvestingGrowthState)
				multiModifier:addExecuteSet(fruitType.witheredState, modifier, filter1, fieldFilter)

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