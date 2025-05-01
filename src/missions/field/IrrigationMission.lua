IrrigationMission = {}

IrrigationMission.NAME = "irrigationMission"
IrrigationMission.rewardPerHa = 1500

local irrigationMission_mt = Class(IrrigationMission, AbstractFieldMission)
InitObjectClass(IrrigationMission, "IrrigationMission")


function IrrigationMission.new(isServer, isClient, customMt)

	local title = g_i18n:getText("rw_contract_field_irrigation_title")
	local description = g_i18n:getText("rw_contract_field_irrigation_description")

	local self = AbstractFieldMission.new(isServer, isClient, title, description, customMt or irrigationMission_mt)

	self.workAreaTypes = {
		[WorkAreaType.SPRAYER] = true
	}

	self.validFertilizerTypes = {
		[FillType.WATER] = true
	}

	self.fillTypeTitle = g_fillTypeManager:getFillTypeTitleByIndex(FillType.WATER)
	self.targetMoistureLevel = nil
	self.averageMoistureLevel = nil
	self.currentUpdateIteration = 1

	return self

end


function IrrigationMission:saveToXMLFile(xmlFile, key)

	IrrigationMission:superClass().saveToXMLFile(self, xmlFile, key)
	xmlFile:setFloat(key .. "#targetMoistureLevel", self.targetMoistureLevel)
	xmlFile:setFloat(key .. "#averageMoistureLevel", self.averageMoistureLevel)

end


function IrrigationMission:loadFromXMLFile(xmlFile, key)
	
	if not IrrigationMission:superClass().loadFromXMLFile(self, xmlFile, key) then return false end

	self.targetMoistureLevel = xmlFile:getFloat(key .. "#targetMoistureLevel")
	self.averageMoistureLevel = xmlFile:getFloat(key .. "#averageMoistureLevel")

	return true

end


function IrrigationMission:writeStream(streamId, connection)

	IrrigationMission:superClass().writeStream(self, streamId, connection)

	streamWriteFloat32(streamId, self.targetMoistureLevel)
	streamWriteFloat32(streamId, self.averageMoistureLevel)

end
	


function IrrigationMission:readStream(streamId, connection)

	IrrigationMission:superClass().readStream(self, streamId, connection)

	self.targetMoistureLevel = streamReadFloat32(streamId) or 0
	self.averageMoistureLevel = streamReadFloat32(streamId) or 0

end


function IrrigationMission.loadMapData(xmlFile, key, _)

	g_missionManager:getMissionTypeDataByName(IrrigationMission.NAME).rewardPerHa = xmlFile:getFloat(key .. "#rewardPerHa", 1500)
	return true

end


function IrrigationMission.canRun()

	local data = g_missionManager:getMissionTypeDataByName(IrrigationMission.NAME)
	
	if data.numInstances >= data.maxNumInstances then return false end
	
	return not g_currentMission.growthSystem:getIsGrowingInProgress()

end


function IrrigationMission.isAvailableForField(field, mission)

	if mission == nil then

		local fieldState = field:getFieldState()

		if not fieldState.isValid then return false end

		local fruitTypeIndex = fieldState.fruitTypeIndex

		if fruitTypeIndex == FruitType.UNKNOWN then return false end

		local growthState = fieldState.growthState

		if growthState ~= nil and growthState <= 0 then return false end

		local fruitType = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)

		if not fruitType:getIsGrowing(growthState) and not fruitType:getIsHarvestable(growthState) then return false end

	end

	return g_currentMission.environment == nil or g_currentMission.environment.currentSeason ~= Season.WINTER

end


function IrrigationMission.tryGenerateMission()

	if IrrigationMission.canRun() then

		local field = g_fieldManager:getFieldForMission()

		if field == nil or field.currentMission ~= nil or not IrrigationMission.isAvailableForField(field, nil) then return nil end

		local mission = IrrigationMission.new(true, g_client ~= nil)

		if mission:initialize(field) then
			mission:setDefaultEndDate()
			return mission
		end

		mission:delete()

	end

	return nil

end


function IrrigationMission:initialize(field)

	self.fieldPolygon = field.densityMapPolygon:getVerticesList()

	local cells = g_currentMission.moistureSystem:getCellsInsidePolygon(self.fieldPolygon, { "moisture" })

	local totalMoistureLevel = 0
	local totalTargetMoistureLevel = 0
	local minTargetMoistureLevel = 0

	for _, cell in pairs(cells) do

		totalMoistureLevel = totalMoistureLevel + cell.moisture

		local fruitTypeIndex = FSDensityMapUtil.getFruitTypeIndexAtWorldPos(cell.x, cell.z)

		local cropToMoisture = RW_FSBaseMission.FRUIT_TYPES_MOISTURE[fruitTypeIndex] or RW_FSBaseMission.FRUIT_TYPES_MOISTURE.DEFAULT
		local perfectMoisture = (cropToMoisture.LOW + cropToMoisture.HIGH) / 2

		totalTargetMoistureLevel = totalTargetMoistureLevel + perfectMoisture
		minTargetMoistureLevel = minTargetMoistureLevel + cropToMoisture.LOW

	end

	local averageMoistureLevel = totalMoistureLevel / #cells
	local targetMoistureLevel = totalTargetMoistureLevel / #cells
	local averageMinTargetMoistureLevel = minTargetMoistureLevel / #cells

	if averageMoistureLevel >= averageMinTargetMoistureLevel then return false end

	self.cells = cells
	self.averageMoistureLevel = averageMoistureLevel
	self.targetMoistureLevel = targetMoistureLevel

	return IrrigationMission:superClass().init(self, field)

end


function IrrigationMission:createModifier()

end


function IrrigationMission:getMissionTypeName()

	return IrrigationMission.NAME

end


function IrrigationMission:getRewardPerHa()

	return g_missionManager:getMissionTypeDataByName(IrrigationMission.NAME).rewardPerHa

end


function IrrigationMission:validate(event)
	
	if IrrigationMission:superClass().validate(self, event) then return (self:getIsFinished() or IrrigationMission.isAvailableForField(self.field, self)) and true or false end
	
	return false

end


function IrrigationMission:calculateReimbursement()

	IrrigationMission:superClass().calculateReimbursement(self)
	local reimbursement = 0

	for _, vehicle in pairs(self.vehicles) do

		if vehicle.spec_fillUnit ~= nil then

			for fillUnit, _ in pairs(vehicle:getFillUnits()) do

				local fillType = vehicle:getFillUnitFillType(fillUnit)
				if self.validFertilizerTypes[fillType] ~= nil then reimbursement = reimbursement + vehicle:getFillUnitFillLevel(fillUnit) * g_fillTypeManager:getFillTypeByIndex(fillType).pricePerLiter end

			end

		end

	end

	self.reimbursement = self.reimbursement + reimbursement * AbstractMission.REIMBURSEMENT_FACTOR

end


function IrrigationMission:getFieldFinishTask()
	
	return nil

end


function IrrigationMission:getCells()

	if self.cells ~= nil then return self.cells end
	
	if self.fieldPolygon == nil then self.fieldPolygon = self.field.densityMapPolygon:getVerticesList() end

	self.cells = g_currentMission.moistureSystem:getCellsInsidePolygon(self.fieldPolygon, { "moisture" })

	return self.cells

end


function IrrigationMission:getFieldCompletion()

	local cells = self:getCells()

	local completedCells = 0
	local averageMoistureLevel = 0
	local moistureSystem = g_currentMission.moistureSystem

	local currentUpdateIteration = self.currentUpdateIteration
	local cellToUpdate = self.cells[currentUpdateIteration]

	if cellToUpdate ~= nil then

		local values = moistureSystem:getValuesAtCoords(cellToUpdate.x, cellToUpdate.z, { "moisture" })

		if values.moisture ~= nil then self.cells[currentUpdateIteration].moisture = values.moisture end

	end

	self.currentUpdateIteration = currentUpdateIteration + 1

	if self.currentUpdateIteration > #cells then self.currentUpdateIteration = 1 end

	for _, cell in pairs(cells) do

		--local values = moistureSystem:getValuesAtCoords(cell.x, cell.z, { "moisture" })

		--if values == nil then continue end

		--cell.moisture = values.moisture

		averageMoistureLevel = averageMoistureLevel + cell.moisture

	end

	self.averageMoistureLevel = averageMoistureLevel / #cells
	self.fieldPercentageDone = self.averageMoistureLevel / self.targetMoistureLevel

	return self.fieldPercentageDone

end


function IrrigationMission:getDetails()

	local details = IrrigationMission:superClass().getDetails(self)

	local currentAverageMoistureInfo = {
		["title"] = g_i18n:getText("rw_contract_field_irrigation_currentAverage"),
		["value"] = string.format("%.3f%%", self.averageMoistureLevel * 100)
	}
	
	local targetAverageMoistureInfo = {
		["title"] = g_i18n:getText("rw_contract_field_irrigation_targetAverage"),
		["value"] = string.format("%.3f%%", self.targetMoistureLevel * 100)
	}

	table.insert(details, currentAverageMoistureInfo)
	table.insert(details, targetAverageMoistureInfo)

	return details

end


g_missionManager:registerMissionType(IrrigationMission, IrrigationMission.NAME, 3)