RealisticWeatherFrame = {}

local realisticWeatherFrame_mt = Class(RealisticWeatherFrame, TabbedMenuFrameElement)


function RealisticWeatherFrame.new()

	local self = RealisticWeatherFrame:superClass().new(nil, realisticWeatherFrame_mt)
	
	self.name = "RealisticWeatherFrame"
	self.ownedFields = {}
	self.fieldTexts = {}
	self.selectedField = 1
	self.fieldData = {}
	self.allFields = {}
	self.mapWidth, self.mapHeight = 2048, 2048
	self.buttonStates = {}
	self.hasContent = false
	self.cachedBehaviour = 0
	self.selectedFieldId = nil

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

	self.teleportButtonInfo = {
		["inputAction"] = InputAction.MENU_ACCEPT,
		["text"] = g_i18n:getText("rw_ui_teleport"),
		["callback"] = function()
			self:onClickTeleport()
		end,
		["profile"] = "buttonOK"
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

	self.menuButtonInfo = { self.backButtonInfo, self.nextPageButtonInfo, self.prevPageButtonInfo, self.refreshButtonInfo, self.teleportButtonInfo }

	if (self.showAll and self.ownedFields ~= nil and self.ownedFields[self.selectedField] ~= nil) or (not self.showAll and self.selectedFieldId ~= nil) then

		local isBeingIrrigated, _ = moistureSystem:getIsFieldBeingIrrigated(self.showAll and self.ownedFields[self.selectedField] or self.selectedFieldId)
		self.irrigationButtonInfo.text = g_i18n:getText(isBeingIrrigated and "rw_ui_irrigation_stop" or "rw_ui_irrigation_start")
		self.irrigationButtonInfo.disabled = false

	else

		self.irrigationButtonInfo.disabled = true

	end

	table.insert(self.menuButtonInfo, self.irrigationButtonInfo)
	
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
		[self.zButton] = { ["sorter"] = false, ["target"] = "z", ["pos"] = "36px" },
		[self.irrigationActiveButton] = { ["sorter"] = false, ["target"] = "irrigationActive", ["pos"] = "10px" },
		[self.irrigationCostButton] = { ["sorter"] = false, ["target"] = "irrigationCost", ["pos"] = "20px" }
	}

	self.sortingIcon_true:setVisible(false)
	self.sortingIcon_false:setVisible(false)

end


function RealisticWeatherFrame:updateFieldInfo()

	self:resetButtonStates()

	local fieldData = {}
	local ownedFieldData = {}
	local allFieldData = {}
	local moistureSystem = g_currentMission.moistureSystem

	for _, fieldId in pairs(self.ownedFields) do

		local field = g_fieldManager:getFieldById(fieldId)
		local data = {}

		if field ~= nil and moistureSystem ~= nil then

			local polygon = field.densityMapPolygon
			data = moistureSystem:getCellsInsidePolygon(polygon:getVerticesList()) or {}

		end

		if self.showAll then

			-- extremely large lists are obviously not healthy for the game interface and can cause crashes or massive lag just by being displayed
			-- i could just limit it at 1500, ie, show 1500 even if there are 3000, but then that may be confusing for players

			if #data >= 1500 then data = {} end

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
				data = moistureSystem:getCellsInsidePolygon(polygon:getVerticesList()) or {}

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
	self.irrigationActiveButton:setVisible(not self.showAll)
	self.irrigationCostButton:setVisible(not self.showAll)

	self.moistureList:reloadData()
	self:updateMenuButtons()

end


function RealisticWeatherFrame:getNumberOfSections()
	if (self.showAll and self.fieldData[self.selectedField] == nil) or (not self.showAll and ((self.selectedField == 1 and self.ownedFieldData == nil) or (self.selectedField == 2 and self.allFieldData == nil))) then return 0 end

	return 1
end


function RealisticWeatherFrame:getNumberOfItemsInSection(list, section)
		if (self.showAll and self.fieldData[self.selectedField] == nil) or (not self.showAll and ((self.selectedField == 1 and self.ownedFieldData == nil) or (self.selectedField == 2 and self.allFieldData == nil))) then return 0 end

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

		colour = { 1, math.max(1 - math.abs(trend) * 0.75, 0), 0, 1 }
		cell:getAttribute("trendArrow"):applyProfile("rw_trendArrowDown")

	end

	cell:getAttribute("field"):setText(self.showAll and "" or item.field)

	cell:getAttribute("trendArrow"):setImageColor(nil, unpack(colour))

	cell:getAttribute("moisture"):setText(string.format("%.3f%%", item.moisture * 100))
	cell:getAttribute("trend"):setText(string.format("%.3f%%", trend))
	cell:getAttribute("retention"):setText(string.format("%.2f%%", item.retention * 100))
	cell:getAttribute("witherChance"):setText(string.format("%.2f%%", item.witherChance * 100))
	cell:getAttribute("x"):setText(math.round(item.x + self.mapWidth / 2))
	cell:getAttribute("z"):setText(math.round(item.z + self.mapHeight / 2))
	
	if not self.showAll then
		cell.setSelected = Utils.appendedFunction(cell.setSelected, function(cell, selected)
			if selected then self:onClickListItem(cell) end
		end)

		local irrigationActiveCell = cell:getAttribute("irrigationActive")
		local irrigationCostCell = cell:getAttribute("irrigationCost")
		
		irrigationActiveCell:setVisible(true)
		irrigationCostCell:setVisible(true)

		local moistureSystem = g_currentMission.moistureSystem
		local active, cost = item.irrigationActive, item.irrigationCost
		
		if active == nil or cost == nil then
			active, cost = moistureSystem:getIsFieldBeingIrrigated(item.field)
			active = active and 2 or 1
		end

		irrigationActiveCell:setText(g_i18n:getText(active == 2 and "rw_ui_active" or "rw_ui_inactive"))
		irrigationCostCell:setText(g_i18n:formatMoney(cost, 2, true, true))

		item.irrigationActive = nil
		item.irrigationCost = nil
	else
		cell:getAttribute("irrigationActive"):setText("")
		cell:getAttribute("irrigationCost"):setText("")
	end

end


function RealisticWeatherFrame:onClickSortButton(button)
	
	local buttonState = self.buttonStates[button]

	self["sortingIcon_" .. tostring(buttonState.sorter)]:setVisible(false)
	self["sortingIcon_" .. tostring(not buttonState.sorter)]:setVisible(true)
	self["sortingIcon_" .. tostring(not buttonState.sorter)]:setPosition(button.position[1] + GuiUtils.getNormalizedXValue(buttonState.pos), 0)

	buttonState.sorter = not buttonState.sorter
	
	local sorter = buttonState.sorter
	local target = buttonState.target

	if not self.showAll and (target == "irrigationActive" or target == "irrigationCost") then
		
		local data = self.selectedField == 1 and self.ownedFieldData or self.allFieldData
		local moistureSystem = g_currentMission.moistureSystem
		
		for _, item in pairs(data) do
			local active, cost = moistureSystem:getIsFieldBeingIrrigated(item.field)
			item.irrigationActive = active and 2 or 1
			item.irrigationCost = cost
		end

	end

	table.sort(self.showAll and self.fieldData[self.selectedField] or (self.selectedField == 1 and self.ownedFieldData or self.allFieldData), function(a, b)
		if sorter then return a[target] > b[target] end

		return a[target] < b[target]
	end)

	self.moistureList:reloadData()

end


function RealisticWeatherFrame:onClickIrrigation()

	local moistureSystem = g_currentMission.moistureSystem

	if moistureSystem == nil or (self.showAll and (#self.ownedFields == 0 or self.ownedFields[self.selectedField] == nil)) or (not self.showAll and self.selectedFieldId == nil) then return end

	moistureSystem:setFieldIrrigationState(self.showAll and self.ownedFields[self.selectedField] or self.selectedFieldId)
	self:updateMenuButtons()

	if not self.showAll then self.moistureList:reloadData() end

end


function RealisticWeatherFrame:onClickRefresh()
	self:updateContent()
end


function RealisticWeatherFrame:onClickTeleport()

	if g_localPlayer == nil then return end

	local item

	if self.showAll and self.fieldData ~= nil and self.fieldData[self.selectedField] ~= nil and self.moistureList.selectedIndex ~= 0 then
		item = self.fieldData[self.selectedField][self.moistureList.selectedIndex]
	elseif not self.showAll and self.moistureList.selectedIndex ~= 0 then
		if self.selectedField == 1 then
			item = self.ownedFieldData[self.moistureList.selectedIndex]
		else
			item = self.allFieldData[self.moistureList.selectedIndex]
		end
	end

	if item == nil then return end

	g_localPlayer:teleportTo(item.x, getTerrainHeightAtWorldPos(g_terrainNode, item.x, 0, item.z), item.z, false, true)

end


function RealisticWeatherFrame:onClickListItem(item)

	if self.showAll then return end

	self.selectedFieldId = nil

	local data = self.selectedField == 1 and self.ownedFieldData or self.allFieldData

	local index = item.indexInSection

	if data == nil or data[index] == nil or g_localPlayer == nil then
		self:updateMenuButtons()
		return
	end

	local fieldId = data[index].field
	local field = g_fieldManager:getFieldById(fieldId)
	local playerFarm = g_localPlayer.farmId

	if field ~= nil and playerFarm ~= FarmManager.SPECTATOR_FARM_ID then
		local owner = field:getOwner()
		if owner == playerFarm then self.selectedFieldId = fieldId end
	end

	self:updateMenuButtons()

end