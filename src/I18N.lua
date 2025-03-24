RW_I18N = {}
local modName = g_currentModName

function RW_I18N:getText(superFunc, text, modEnv)

    if (text == "rw_ui_irrigationUpkeep" or text == "finance_irrigationUpkeep") and modEnv == nil then
        return superFunc(self, text, modName)
    end

    return superFunc(self, text, modEnv)

end

I18N.getText = Utils.overwrittenFunction(I18N.getText, RW_I18N.getText)