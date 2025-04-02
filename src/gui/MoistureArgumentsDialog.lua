MoistureArgumentsDialog = {}

local moistureArgumentsDialog_mt = Class(MoistureArgumentsDialog, YesNoDialog)
local modDirectory = g_currentModDirectory

function MoistureArgumentsDialog.register()
    local dialog = MoistureArgumentsDialog.new()
    g_gui:loadGui(modDirectory .. "gui/MoistureArgumentsDialog.xml", "MoistureArgumentsDialog", dialog)
    MoistureArgumentsDialog.INSTANCE = dialog
end


function MoistureArgumentsDialog.show()

    if MoistureArgumentsDialog.INSTANCE == nil then MoistureArgumentsDialog.register() end

    if MoistureArgumentsDialog.INSTANCE ~= nil then
        local instance = MoistureArgumentsDialog.INSTANCE

        if g_currentMission.moistureSystem == nil then return end

        instance:setCurrentValues()

        g_gui:showDialog("MoistureArgumentsDialog")
    end
end


function MoistureArgumentsDialog.new(target, customMt)
    local dialog = YesNoDialog.new(target, customMt or moistureArgumentsDialog_mt)
    return dialog
end


function MoistureArgumentsDialog.createFromExistingGui(gui, _)

    MoistureArgumentsDialog.register()
    MoistureArgumentsDialog.show()

end


function MoistureArgumentsDialog:onOpen()

    MoistureArgumentsDialog:superClass().onOpen(self)
    FocusManager:setFocus(self.widthInput)

end


function MoistureArgumentsDialog:onClose()
    MoistureArgumentsDialog:superClass().onClose(self)
end


function MoistureArgumentsDialog:setCurrentValues()

    local moistureSystem = g_currentMission.moistureSystem
    local sizes = {}

    for i = 1, 50 do sizes[i] = tostring(i) end

    self.widthInput:setTexts(sizes)
    self.heightInput:setTexts(sizes)

    self.sizes = sizes

    self.widthInput:setState(moistureSystem.cellWidth)
    self.heightInput:setState(moistureSystem.cellWidth)

end


function MoistureArgumentsDialog:onClickRecommended()

    local performanceIndex = Utils.getPerformanceClassId()

    if g_server ~= nil and g_server.netIsRunning and performanceIndex <= 3 then performanceIndex = 4 end

    local width, height = MoistureSystem.CELL_WIDTH[performanceIndex], MoistureSystem.CELL_HEIGHT[performanceIndex]

    if self.sizes[width] == nil then width = tonumber(self.sizes[#self.sizes]) end
    if self.sizes[height] == nil then height = tonumber(self.sizes[#self.sizes]) end

    self.widthInput:setState(width)
    self.heightInput:setState(height)

end


function MoistureArgumentsDialog:onClickOk()

    local moistureSystem = g_currentMission.moistureSystem

    if moistureSystem ~= nil then

        moistureSystem.cellWidth = self.widthInput:getState()
        moistureSystem.cellHeight = self.heightInput:getState()
        moistureSystem:generateNewMapMoisture(nil, true)

    end

    self:close()

end


function MoistureArgumentsDialog:onClickBack()

    self:close()

end