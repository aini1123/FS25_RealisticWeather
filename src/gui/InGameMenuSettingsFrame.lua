RW_InGameMenuSettingsFrame = {}

function RW_InGameMenuSettingsFrame:updateButtons()
	
    local moistureSystem = g_currentMission.moistureSystem

	if moistureSystem == nil then return end

	self.regenerateMoistureMapButton = self.regenerateMoistureMapButton or {
		["inputAction"] = InputAction.MENU_EXTRA_1,
		["text"] = g_i18n:getText("rw_ui_rebuildMoistureMap"),
		["callback"] = function()
			moistureSystem:onClickRebuildMoistureMap()
		end,
		["showWhenPaused"] = true }

	table.insert(self.menuButtonInfo, self.regenerateMoistureMapButton)

	self:setMenuButtonInfoDirty()

end

--InGameMenuSettingsFrame.updateButtons = Utils.appendedFunction(InGameMenuSettingsFrame.updateButtons, RW_InGameMenuSettingsFrame.updateButtons)


function RW_InGameMenuSettingsFrame:onFrameOpen(_)

	for name, setting in pairs(RWSettings.SETTINGS) do

		if setting.dependancy then
			local dependancy = RWSettings.SETTINGS[setting.dependancy.name]
			if dependancy ~= nil and setting.element ~= nil then setting.element:setDisabled(dependancy.state ~= setting.dependancy.state) end
		end

	end

end

InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, RW_InGameMenuSettingsFrame.onFrameOpen)