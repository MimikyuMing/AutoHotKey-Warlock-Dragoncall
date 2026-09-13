#Requires AutoHotkey v2.0


#Include LogicEngine.ahk
#Include ..\Lib\Globals.ahk
#Include DragoncallGlobals.ahk


GetCurrentVersion(*) {
    return version
}

ShowSettingsGUI(*) {
    global _settingsGui
    try _settingsGui.Destroy()
    
    version := GetCurrentVersion()
    title := "暴魔灵-v" . version

    _settingsGui := Gui("", title)

    _settingsGui.SetFont("s10", "Microsoft YaHei")

    _settingsGui.OnEvent("Close", (*) => _settingsGui.Destroy())

    ; 技能
    _settingsGui.Add("Text", "w300 h2 0x7")             ; 水平分隔线
    _settingsGui.Add("Text", "w300 Center", "技能设置")
    _settingsGui.Add("Text", "w300 h2 0x7")             ; 水平分隔线

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


    _settingsGui.Add("Checkbox", "vEnablePriorityUseDragoncall", "优先暴魔灵(死靈突馳和暴魔靈同時好的時候))").Value := LogicEngine.g_enablePriorityUseDragoncall
    _settingsGui["EnablePriorityUseDragoncall"].OnEvent("Click", SaveSettingImmediate)

    _settingsGui.Add("Checkbox", "vIsUseOpenHasSoulFlareBuff", "有降臨Buff时仍可释放开门").Value := LogicEngine.g_isUseOpenHasSoulFlareBuff
    _settingsGui["IsUseOpenHasSoulFlareBuff"].OnEvent("Click", SaveSettingImmediate)

    _settingsGui.Add("Checkbox", "vIsUsedLeechFromMySelf", "是否只打自己的烙印(需藍結界/藍警戒斬以上)").Value := LogicEngine.g_isUsedLeechFromMySelf
    _settingsGui["IsUsedLeechFromMySelf"].OnEvent("Click", SaveSettingImmediate)

    _settingsGui.Add("Text", "w300 h2 0x7")             ; 水平分隔线
    _settingsGui.Add("Text", "w300 Center", "系统设置")
    _settingsGui.Add("Text", "w300 h2 0x7")             ; 水平分隔线

    _settingsGui.Add("Checkbox", "vRealtimeMode", "实时模式（直接从共享内存读取技能状态）")
        .Value := CaptureEngine.RealtimeMode
    _settingsGui["RealtimeMode"].OnEvent("Click", SaveSettingImmediate)

    _settingsGui.Add("Checkbox", "vPerformanceMonitor", "性能检测（退出时输出耗时报告）")
        .Value := PerformanceMonitor.enabled
    _settingsGui["PerformanceMonitor"].OnEvent("Click", SaveSettingImmediate)

    _settingsGui.Add("Checkbox", "vMonitorCpu", "监控 CPU 使用率")
        .Value := PerformanceMonitor.monitorCpu
    _settingsGui["MonitorCpu"].OnEvent("Click", SaveSettingImmediate)

    _settingsGui.Add("Checkbox", "vMonitorMemory", "监控内存占用")
        .Value := PerformanceMonitor.monitorMem
    _settingsGui["MonitorMemory"].OnEvent("Click", SaveSettingImmediate)


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
    StateManager.realtimeMode := _settingsGui["RealtimeMode"].Value
    PerformanceMonitor.enabled := _settingsGui["PerformanceMonitor"].Value
    PerformanceMonitor.monitorCpu := _settingsGui["MonitorCpu"].Value
    PerformanceMonitor.monitorMem := _settingsGui["MonitorMemory"].Value
    LogicEngine.g_enablePriorityUseDragoncall := _settingsGui["EnablePriorityUseDragoncall"].Value
    LogicEngine.g_isUseOpenHasSoulFlareBuff := _settingsGui["IsUseOpenHasSoulFlareBuff"].Value
    LogicEngine.g_isUsedLeechFromMySelf := _settingsGui["IsUsedLeechFromMySelf"].Value
    SaveSettingsToFile()

}

SaveSettingsToFile() {
    static configPath := A_AppData "\Dragoncall\Dragoncall-Config.ini"

    ; 如果目标目录不存在，创建它
    if !FileExist(A_AppData "\Dragoncall") {
        DirCreate(A_AppData "\Dragoncall")
    }

    ; 如果目标配置文件不存在，从临时文件复制（如果存在）或创建空文件
    if !FileExist(configPath) {
        if FileExist(INI)  ; INI 是全局变量，可能指向 A_Temp 下的文件
            FileCopy INI, configPath, 1
        else
            FileAppend "", configPath   ; 创建空文件
    }

    ; 统一写入所有设置到 configPath
    IniWrite(LogicEngine.g_Gold_Wingstorm, configPath, "Settings", "Gold_Wingstorm")
    IniWrite(LogicEngine.g_Gold_Open, configPath, "Settings", "Gold_Open")
    IniWrite(LogicEngine.g_AutoSoulFlare, configPath, "Settings", "AutoSoulFlare")
    IniWrite(LogicEngine.g_isUseLeechHasLeechBuff, configPath, "Settings", "isUseLeechHasLeechBuff")
    IniWrite(LogicEngine.g_Gold_Leech, configPath, "Settings", "Gold_Leech")
    IniWrite(LogicEngine.g_limitationOpen, configPath, "Settings", "LimitationOpen")
    IniWrite(LogicEngine.g_limitationLeech, configPath, "Settings", "LimitationLeech")
    IniWrite(StateManager.realtimeMode, configPath, "Settings", "RealtimeMode")
    IniWrite(PerformanceMonitor.enabled, configPath, "Settings", "PerformanceMonitor")
    IniWrite(PerformanceMonitor.monitorCpu, configPath, "Settings", "MonitorCpu")
    IniWrite(PerformanceMonitor.monitorMem, configPath, "Settings", "MonitorMemory")
    IniWrite(LogicEngine.g_enablePriorityUseDragoncall, configPath, "Settings", "EnablePriorityUseDragoncall")
    IniWrite(LogicEngine.g_isUseOpenHasSoulFlareBuff, configPath, "Settings", "isUseOpenHasSoulFlareBuff")
    IniWrite(LogicEngine.g_isUsedLeechFromMySelf, configPath, "Settings", "isUsedLeechFromMySelf")
}