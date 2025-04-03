RealisticWeatherFrame = {}

local realisticWeatherFrame_mt = Class(RealisticWeatherFrame, TabbedMenuFrameElement)


function RealisticWeatherFrame.new()

	local self = RealisticWeatherFrame:superClass().new(nil, realisticWeatherFrame_mt)
	
	self.name = "RealisticWeatherFrame"
	self.ownedFields = {}
	self.fieldTexts = {}
	self.selectedField = 1
	self.fieldData = {}
	self.mapWidth, self.mapHeight = 2048, 2048
	self.buttonStates = {}
	self.hasContent = false
	self.cachedBehaviour = 0

	return self

end


function RealisticWeatherFrame:delete()
	RealisticWeatherFrame:superClass().delete(self)
end


function RealisticWeatherFrame:initialize()

	self.backButtonInfo = {
		["inputAction"] = InputAction.MENU_BACK
	}

	self.nextPageButtonInfo = {
		["inputAction"] = InputAction.MENU_PAGE_NEXT,
		["text"] = g_i18n:getText("ui_ingameMenuNext"),
		["callback"] = self.onPageNext
	}

	self.prevPageButtonInfo = {
		["inputAction"] = InputAction.MENU_PAGE_PREV,
		["text"] = g_i18n:getText("ui_ingameMenuPrev"),
		["callback"] = self.onPagePrevious
	}

	self.irrigationButtonInfo = {
		["inputAction"] = InputAction.MENU_ACTIVATE,
		["text"] = g_i18n:getText("rw_ui_irrigation_start"),
		["callback"] = function()
			self:onClickIrrigation()
		end,
		["profile"] = "buttonSelect"
	}

	self.refreshButtonInfo = {
		["inputAction"] = InputAction.MENU_EXTRA_1,
		["text"] = g_i18n:getText("button_refresh"),
		["callback"] = function()
			self:onClickRefresh()
		end,
		["profile"] = "buttonMenuSwitch"
	}
	
end


function RealisticWeatherFrame:onGuiSetupFinished()
	RealisticWeatherFrame:superClass().onGuiSetupFinished(self)
end


function RealisticWeatherFrame:onFrameOpen()
	RealisticWeatherFrame:superClass().onFrameOpen(self)   
    if not self.hasContent or (g_currentMission.moistureSystem ~= nil and g_currentMission.moistureSystem.moistureFrameBehaviour ~= self.cachedBehaviour) then
		self:updateContent()
	else
		self:resetButtonStates()
		self:updateMenuButtons()
		self.moistureList:reloadData()
	end
end


function RealisticWeatherFrame:onFrameClose()
	RealisticWeatherFrame:superClass().onFrameClose(self)   
end


function RealisticWeatherFrame:updateContent()

	self.hasContent = true

	local ownedFields = {}
	local allFields = {}
	local fieldTexts = {}
	
	local moistureSystem = g_currentMission.moistureSystem

	if moistureSystem == nil then return end

	self.mapWidth, self.mapHeight, self.showAll = moistureSystem.mapWidth, moistureSystem.mapHeight, moistureSystem.moistureFrameBehaviour == 1

	self.cachedBehaviour = moistureSystem.moistureFrameBehaviour

	if g_localPlayer ~= nil and g_localPlayer.farmId ~= nil and g_localPlayer.farmId ~= FarmlandManager.NO_OWNER_FARM_ID then
		
		local farm = g_localPlayer.farmId
		local fields = g_fieldManager:getFields()

		for _, field in pairs(fields) do

			local owner = field:getOwner()

			if owner == farm then
				local id = field:getId()
				table.insert(ownedFields, id)
				if self.showAll then table.insert(fieldTexts, "Field " .. id) end
			end

			if not self.showAll then
				local id = field:getId()
				table.insert(allFields, id)
			end

		end

	end

	if not self.showAll then fieldTexts = { g_i18n:getText("rw_ui_ownedFields"), g_i18n:getText("rw_ui_allFields") } end

	self.fieldList:setTexts(fieldTexts)
	self.ownedFields = ownedFields
	self.allFields = allFields
	self.selectedField = 1
	self.fieldList:setState(self.selectedField)

	self.currentBalanceText:setText(g_i18n:formatMoney(g_currentMission:getMoney(), 2, true, true))
	
	self:updateFieldInfo()

end


function RealisticWeatherFrame:updateMenuButtons()

	local moistureSystem = g_currentMission.moistureSystem

	if moistureSystem == nil then return end

	self.menuButtonInfo = { self.backButtonInfo, self.nextPageButtonInfo, self.prevPageButtonInfo, self.refreshButtonInfo }

	if (#self.ownedFields > 0 and self.ownedFields[self.selectedField] ~= nil) or (not self.showAll and #self.allFields > 0) then

		local isBeingIrrigated, _ = moistureSystem:getIsFieldBeingIrrigated(self.ownedFields[self.selectedField])
		self.irrigationButtonInfo.text = g_i18n:getText(isBeingIrrigated and "rw_ui_irrigation_stop" or "rw_ui_irrigation_start")
		table.insert(self.menuButtonInfo, self.irrigationButtonInfo)

	end
	
	self:setMenuButtonInfoDirty()

end


function RealisticWeatherFrame:onClickFieldList(index)

	self.selectedField = index

	self:resetButtonStates()
	self:updateMenuButtons()
	self.moistureList:reloadData()

end


function RealisticWeatherFrame:resetButtonStates()

	self.buttonStates = {
		[self.fieldButton] = { ["sorter"] = false, ["target"] = "field", ["pos"] = "-5px" },
		[self.moistureButton] = { ["sorter"] = false, ["target"] = "moisture", ["pos"] = "12px" },
		[self.trendButton] = { ["sorter"] = false, ["target"] = "trend", ["pos"] = "35px" },
		[self.retentionButton] = { ["sorter"] = false, ["target"] = "retention", ["pos"] = "12px" },
		[self.witherChanceButton] = { ["sorter"] = false, ["target"] = "witherChance", ["pos"] = "22px" },
		[self.xButton] = { ["sorter"] = false, ["target"] = "x", ["pos"] = "36px" },
		[self.zButton] = { ["sorter"] = false, ["target"] = "z", ["pos"] = "36px" }
	}

	self.sortingIcon_true:setVisible(false)
	self.sortingIcon_false:setVisible(false)

end


function RealisticWeatherFrame:updateFieldInfo()

	self:resetButtonStates()
	self:updateMenuButtons()

	local fieldData = {}
	local ownedFieldData = {}
	local allFieldData = {}
	local moistureSystem = g_currentMission.moistureSystem

	for _, fieldId in pairs(self.ownedFields) do

		local field = g_fieldManager:getFieldById(fieldId)
		local data = {}

		if field ~= nil and moistureSystem ~= nil then

			local polygon = field.densityMapPolygon
			data = moistureSystem:getCellsInsidePolygon(polygon:getVerticesList())

		end

		if self.showAll then

			table.insert(fieldData, data)

		else

			local averageData = {
				["moisture"] = 0,
				["trend"] = 0,
				["retention"] = 0,
				["witherChance"] = 0,
				["x"] = 0,
				["z"] = 0
			}

			for _, cell in pairs(data) do

				for key, value in pairs(averageData) do averageData[key] = value + cell[key] end

			end

			if #data ~= 0 then 
				for key, value in pairs(averageData) do averageData[key] = value / #data end
			end

			averageData.field = fieldId

			table.insert(ownedFieldData, averageData)

		end

	end

	if not self.showAll then

		for _, fieldId in pairs(self.allFields) do

			local data = {}

			for _, ownedField in pairs(ownedFieldData) do
				if ownedField.field == fieldId then
					data = ownedField
					break
				end
			end

			local field = g_fieldManager:getFieldById(fieldId)

			if field ~= nil and moistureSystem ~= nil then

				local polygon = field.densityMapPolygon
				data = moistureSystem:getCellsInsidePolygon(polygon:getVerticesList())

			end

			local averageData = {
				["moisture"] = 0,
				["trend"] = 0,
				["retention"] = 0,
				["witherChance"] = 0,
				["x"] = 0,
				["z"] = 0
			}

			for _, cell in pairs(data) do

				for key, value in pairs(averageData) do averageData[key] = value + cell[key] end

			end

			if #data ~= 0 then 
				for key, value in pairs(averageData) do averageData[key] = value / #data end
			end

			averageData.field = fieldId

			table.insert(allFieldData, averageData)

		end

	end

	self.fieldData = fieldData
	self.ownedFieldData = ownedFieldData
	self.allFieldData = allFieldData

	self.fieldButton:setVisible(not self.showAll)

	self.moistureList:reloadData()

end


function RealisticWeatherFrame:getNumberOfSections()
	if (self.showAll and (self.fieldData == nil or self.fieldData[self.selectedField] == nil)) or (not self.showAll and self.selectedIndex == 1 and self.ownedFieldData == nil or self.allFieldData == nil) then return 0 end
	return 1
end


function RealisticWeatherFrame:getNumberOfItemsInSection(list, section)
        if (self.showAll and (self.fieldData == nil or self.fieldData[self.selectedField] == nil)) or (not self.showAll and self.selectedIndex == 1 and self.ownedFieldData == nil or self.allFieldData == nil) then return 0 end
	return self.showAll and #self.fieldData[self.selectedField] or (self.selectedField == 1 and #self.ownedFieldData or #self.allFieldData)
end


function RealisticWeatherFrame:getTitleForSectionHeader(list, section)
    return ""
end


function RealisticWeatherFrame:populateCellForItemInSection(list, section, index, cell)

	local data = self.showAll and self.fieldData[self.selectedField] or (self.selectedField == 1 and self.ownedFieldData or self.allFieldData)
	local item = data[index]

	local trend = (item.moisture - item.trend) * 100
	local colour = { 0, 0, 0, 0}

	if trend > 0 then

		colour = { math.max(1 - trend * 0.75, 0), 1, 0, 1}

	elseif trend < 0 then

		colour = { 1, math.max(1 - math.abs(trend) * 0.75, 0), 0, 1}
		cell:getAttribute("trendArrow"):applyProfile("rw_trendArrowDown")

	end

	if not self.showAll then cell:getAttribute("field"):setText(item.field) end

	cell:getAttribute("trendArrow"):setImageColor(nil, unpack(colour))

	cell:getAttribute("moisture"):setText(string.format("%.3f%%", item.moisture * 100))
	cell:getAttribute("trend"):setText(string.format("%.3f%%", trend))
	cell:getAttribute("retention"):setText(string.format("%.2f%%", item.retention * 100))
	cell:getAttribute("witherChance"):setText(string.format("%.2f%%", item.witherChance * 100))
	cell:getAttribute("x"):setText(math.round(item.x + self.mapWidth / 2))
	cell:getAttribute("z"):setText(math.round(item.z + self.mapHeight / 2))

end


function RealisticWeatherFrame:onClickSortButton(button)
	
	local buttonState = self.buttonStates[button]

	self["sortingIcon_" .. tostring(buttonState.sorter)]:setVisible(false)
	self["sortingIcon_" .. tostring(not buttonState.sorter)]:setVisible(true)
	self["sortingIcon_" .. tostring(not buttonState.sorter)]:setPosition(button.position[1] + GuiUtils.getNormalizedXValue(buttonState.pos), 0)

	buttonState.sorter = not buttonState.sorter
	
	local sorter = buttonState.sorter
	local target = buttonState.target

	table.sort(self.showAll and self.fieldData[self.selectedField] or (self.selectedField == 1 and self.ownedFieldData or self.allFieldData), function(a, b)
		if sorter then return a[target] > b[target] end

		return a[target] < b[target] 
	end)

	self.moistureList:reloadData()

end


function RealisticWeatherFrame:onClickIrrigation()

	local moistureSystem = g_currentMission.moistureSystem

	if moistureSystem == nil or #self.ownedFields == 0 or self.ownedFields[self.selectedField] == nil then return end

	moistureSystem:setFieldIrrigationState(self.ownedFields[self.selectedField])
	self:updateMenuButtons()

end


function RealisticWeatherFrame:onClickRefresh()
	self:updateContent()
end
