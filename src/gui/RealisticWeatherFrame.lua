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

end


function RealisticWeatherFrame:onGuiSetupFinished()
	RealisticWeatherFrame:superClass().onGuiSetupFinished(self)
end


function RealisticWeatherFrame:onFrameOpen()
	RealisticWeatherFrame:superClass().onFrameOpen(self)   
    self:updateContent()
end


function RealisticWeatherFrame:onFrameClose()
	RealisticWeatherFrame:superClass().onFrameClose(self)   
end


function RealisticWeatherFrame:updateContent()

	local ownedFields = {}
	local fieldTexts = {}
	
	local moistureSystem = g_currentMission.moistureSystem

	if moistureSystem ~= nil then self.mapWidth, self.mapHeight = moistureSystem.mapWidth, moistureSystem.mapHeight end

	if g_localPlayer ~= nil and g_localPlayer.farmId ~= nil and g_localPlayer.farmId ~= FarmlandManager.NO_OWNER_FARM_ID then
		
		local farm = g_localPlayer.farmId
		local fields = g_fieldManager:getFields()

		for _, field in pairs(fields) do

			local owner = field:getOwner()

			if owner == farm then
				local id = field:getId()
				table.insert(ownedFields, id)
				table.insert(fieldTexts, "Field " .. id)
			end

		end

	end

	self.fieldList:setTexts(fieldTexts)
	self.ownedFields = ownedFields
	self.selectedField = 1
	self.fieldList:setState(self.selectedField)

	self.currentBalanceText:setText(g_i18n:formatMoney(g_currentMission:getMoney(), 2, true, true))
	
	self:updateFieldInfo()

end


function RealisticWeatherFrame:updateMenuButtons()

	local moistureSystem = g_currentMission.moistureSystem

	if moistureSystem == nil then return end

	self.menuButtonInfo = { self.backButtonInfo, self.nextPageButtonInfo, self.prevPageButtonInfo }

	if #self.ownedFields > 0 and self.ownedFields[self.selectedField] ~= nil then

		local isBeingIrrigated, _ = moistureSystem:getIsFieldBeingIrrigated(self.ownedFields[self.selectedField])
		self.irrigationButtonInfo.text = g_i18n:getText(isBeingIrrigated and "rw_ui_irrigation_stop" or "rw_ui_irrigation_start")
		table.insert(self.menuButtonInfo, self.irrigationButtonInfo)

	end
	
	self:setMenuButtonInfoDirty()

end


function RealisticWeatherFrame:onClickFieldList(index)

	self.selectedField = index

	self:updateFieldInfo()

end


function RealisticWeatherFrame:resetButtonStates()

	self.buttonStates = {
		[self.moistureButton] = { ["sorter"] = false, ["target"] = "moisture" },
		[self.trendButton] = { ["sorter"] = false, ["target"] = "trend" },
		[self.retentionButton] = { ["sorter"] = false, ["target"] = "retention" },
		[self.witherChanceButton] = { ["sorter"] = false, ["target"] = "witherChance" },
		[self.xButton] = { ["sorter"] = false, ["target"] = "x" },
		[self.zButton] = { ["sorter"] = false, ["target"] = "z" }
	}

	self.sortingIcon_true:setVisible(false)
	self.sortingIcon_false:setVisible(false)

end


function RealisticWeatherFrame:updateFieldInfo()

	self:resetButtonStates()
	self:updateMenuButtons()

	local fieldId = self.ownedFields[self.selectedField]
	local field = g_fieldManager:getFieldById(fieldId)
	local fieldData = {}
	local moistureSystem = g_currentMission.moistureSystem

	if field ~= nil and moistureSystem ~= nil then

		local polygon = field.densityMapPolygon
		fieldData = moistureSystem:getCellsInsidePolygon(polygon:getVerticesList())

	end

	self.fieldData = fieldData
	self.moistureList:reloadData()

end


function RealisticWeatherFrame:getNumberOfSections()
	return 1
end


function RealisticWeatherFrame:getNumberOfItemsInSection(list, section)
        return #self.fieldData
end


function RealisticWeatherFrame:getTitleForSectionHeader(list, section)
    return ""
end


function RealisticWeatherFrame:populateCellForItemInSection(list, section, index, cell)

	local item = self.fieldData[index]

	local trend = (item.moisture - item.trend) * 100
	local colour = { 0, 0, 0, 0}

	if trend > 0 then

		colour = { math.max(1 - trend * 0.75, 0), 1, 0, 1}

	elseif trend < 0 then

		colour = { 1, math.max(1 - math.abs(trend) * 0.75, 0), 0, 1}
		cell:getAttribute("trendArrow"):applyProfile("rw_trendArrowDown")

	end

	cell:getAttribute("trendArrow"):setImageColor(nil, unpack(colour))

	cell:getAttribute("moisture"):setText(string.format("%.3f%%", item.moisture * 100))
	cell:getAttribute("trend"):setText(string.format("%.3f%%", trend))
	cell:getAttribute("retention"):setText(string.format("%.2f%%", item.retention * 100))
	cell:getAttribute("witherChance"):setText(string.format("%.2f%%", item.witherChance * 100))
	cell:getAttribute("x"):setText(item.x + self.mapWidth / 2)
	cell:getAttribute("z"):setText(item.z + self.mapHeight / 2)

end


function RealisticWeatherFrame:onClickSortButton(button)
	
	local buttonState = self.buttonStates[button]

	self["sortingIcon_" .. tostring(buttonState.sorter)]:setVisible(false)
	self["sortingIcon_" .. tostring(not buttonState.sorter)]:setVisible(true)
	self["sortingIcon_" .. tostring(not buttonState.sorter)]:setPosition(button.position[1] + GuiUtils.getNormalizedXValue("10px"), 0)

	buttonState.sorter = not buttonState.sorter
	
	local sorter = buttonState.sorter
	local target = buttonState.target

	table.sort(self.fieldData, function(a, b)
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