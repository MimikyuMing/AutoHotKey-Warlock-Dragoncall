#Requires AutoHotkey v2.0


#Include LogicEngine.ahk
#Include ..\Lib\Globals.ahk
#Include DragoncallGlobals.ahk

ShowSettingsGUI(*) {
    global _settingsGui
    try _settingsGui.Destroy()
    _settingsGui := Gui("", "技能自动化设置")
    _settingsGui.OnEvent("Close", (*) => _settingsGui.Destroy())
    _settingsGui.Add("Checkbox", "vGold_Wingstorm", "金 死灵突袭").Value := LogicEngine.g_Gold_Wingstorm
    _settingsGui["Gold_Wingstorm"].OnEvent("Click", SaveSettingImmediate)
    _settingsGui.Add("Checkbox", "vGold_Open", "金 開門").Value := LogicEngine.g_Gold_Open
    _settingsGui["Gold_Open"].OnEvent("Click", SaveSettingImmediate)
    _settingsGui.Add("Checkbox", "vAutoSoulFlare", "自动释放超神").Value := LogicEngine.g_AutoSoulFlare
    _settingsGui["AutoSoulFlare"].OnEvent("Click", SaveSettingImmediate)
    _settingsGui.Add("Checkbox", "vIsUseLeechHasLeechBuff", "有掠夺Buff时仍可释放掠夺").Value := LogicEngine.g_isUseLeechHasLeechBuff
    
    _settingsGui.Add("Checkbox", "vLimitationLeech", "掠夺是否啟用限制釋放").Value := LogicEngine.g_limitationLeech
    _settingsGui["LimitationLeech"].OnEvent("Click", SaveSettingImmediate)


    _settingsGui.Add("Checkbox", "vLimitationOpen", "開門是否啟用限制釋放").Value := LogicEngine.g_limitationOpen
    _settingsGui["LimitationOpen"].OnEvent("Click", SaveSettingImmediate)


    _settingsGui.Add("Checkbox", "vGold_Leech", "金 掠夺").Value := LogicEngine.g_Gold_Leech
    _settingsGui["Gold_Leech"].OnEvent("Click", SaveSettingImmediate)  

    _settingsGui.Add("Button", "y+10", "关闭").OnEvent("Click", (*) => _settingsGui.Destroy())
    _settingsGui.Show()
}


SaveSettingImmediate(*) {
    global _settingsGui
    LogicEngine.g_Gold_Wingstorm := _settingsGui["Gold_Wingstorm"].Value
    LogicEngine.g_Gold_Open := _settingsGui["Gold_Open"].Value
    LogicEngine.g_AutoSoulFlare := _settingsGui["AutoSoulFlare"].Value
    LogicEngine.g_isUseLeechHasLeechBuff := _settingsGui["IsUseLeechHasLeechBuff"].Value
    LogicEngine.g_Gold_Leech := _settingsGui["Gold_Leech"].Value
    LogicEngine.g_limitationOpen := _settingsGui["LimitationOpen"].Value
    LogicEngine.g_limitationLeech := _settingsGui["LimitationLeech"].Value
    SaveSettingsToFile()
}

SaveSettingsToFile() {
    if !FileExist(A_AppData "\Dragoncall\config.ini") {
        DirCreate(A_AppData "\Dragoncall")
        FileCopy INI, A_AppData "\Dragoncall\config.ini", 1
    }
    IniWrite(LogicEngine.g_Gold_Wingstorm, A_AppData "\Dragoncall\config.ini", "Settings", "Gold_Wingstorm")
    IniWrite(LogicEngine.g_Gold_Open, A_AppData "\Dragoncall\config.ini", "Settings", "Gold_Open")
    IniWrite(LogicEngine.g_AutoSoulFlare, A_AppData "\Dragoncall\config.ini", "Settings", "AutoSoulFlare")
    IniWrite(LogicEngine.g_isUseLeechHasLeechBuff, A_AppData "\Dragoncall\config.ini", "Settings", "isUseLeechHasLeechBuff")
    IniWrite(LogicEngine.g_Gold_Leech, A_AppData "\Dragoncall\config.ini", "Settings", "Gold_Leech")
    IniWrite(LogicEngine.g_limitationOpen, A_AppData "\Dragoncall\config.ini", "Settings", "LimitationOpen")
    IniWrite(LogicEngine.g_limitationLeech, A_AppData "\Dragoncall\config.ini", "Settings", "LimitationLeech")
}