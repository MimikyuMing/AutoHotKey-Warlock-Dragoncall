#Requires AutoHotkey v2.0

GetCurrentVersion(*) {
    return App.version
}

ShowSettingsGUI(*) {
    global _settingsGui
    try _settingsGui.Destroy()

    version := GetCurrentVersion()
    title := "暴魔灵-v" . version

    _settingsGui := Gui("", title)
    _settingsGui.SetFont("s10", "Microsoft YaHei")
    _settingsGui.OnEvent("Close", (*) => _settingsGui.Destroy())

    cfg := App.ctx.config

    ; ---------- 技能设置 ----------
    _settingsGui.Add("Text", "w300 h2 0x7")
    _settingsGui.Add("Text", "w300 Center", "技能设置")
    _settingsGui.Add("Text", "w300 h2 0x7")

    _settingsGui.Add("Checkbox", "vGold_Wingstorm", "金 死灵突袭").Value := cfg.goldWingstorm
    _settingsGui["Gold_Wingstorm"].OnEvent("Click", SaveSettingImmediate)

    _settingsGui.Add("Checkbox", "vGold_Open", "金 開門").Value := cfg.goldOpen
    _settingsGui["Gold_Open"].OnEvent("Click", SaveSettingImmediate)

    _settingsGui.Add("Checkbox", "vAutoSoulFlare", "自动释放超神").Value := cfg.autoSoulFlare
    _settingsGui["AutoSoulFlare"].OnEvent("Click", SaveSettingImmediate)

    _settingsGui.Add("Checkbox", "vIsUseLeechHasLeechBuff", "有掠夺Buff时仍可释放掠夺").Value := cfg.isUseLeechHasLeechBuff

    _settingsGui.Add("Checkbox", "vLimitationLeech", "掠夺是否啟用限制釋放").Value := cfg.limitationLeech
    _settingsGui["LimitationLeech"].OnEvent("Click", SaveSettingImmediate)

    _settingsGui.Add("Checkbox", "vLimitationOpen", "開門是否啟用限制釋放").Value := cfg.limitationOpen
    _settingsGui["LimitationOpen"].OnEvent("Click", SaveSettingImmediate)

    _settingsGui.Add("Checkbox", "vGold_Leech", "金 掠夺").Value := cfg.goldLeech
    _settingsGui["Gold_Leech"].OnEvent("Click", SaveSettingImmediate)

    _settingsGui.Add("Checkbox", "vEnablePriorityUseDragoncall", "优先暴魔灵(死靈突馳和暴魔靈同時好的時候))").Value := cfg.enablePriorityUseDragoncall
    _settingsGui["EnablePriorityUseDragoncall"].OnEvent("Click", SaveSettingImmediate)

    _settingsGui.Add("Checkbox", "vIsUseOpenHasSoulFlareBuff", "有降臨Buff时仍可释放开门").Value := cfg.isUseOpenHasSoulFlareBuff
    _settingsGui["IsUseOpenHasSoulFlareBuff"].OnEvent("Click", SaveSettingImmediate)

    _settingsGui.Add("Checkbox", "vIsUsedLeechFromMySelf", "是否只打自己的烙印(需藍結界/藍警戒斬以上)").Value := cfg.isUsedLeechFromMySelf
    _settingsGui["IsUsedLeechFromMySelf"].OnEvent("Click", SaveSettingImmediate)

    ; ---------- 系统设置 ----------
    _settingsGui.Add("Text", "w300 h2 0x7")
    _settingsGui.Add("Text", "w300 Center", "系统设置")
    _settingsGui.Add("Text", "w300 h2 0x7")

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
    cfg := App.ctx.config

    ; 技能设置
    cfg.goldWingstorm               := _settingsGui["Gold_Wingstorm"].Value
    cfg.goldOpen                    := _settingsGui["Gold_Open"].Value
    cfg.autoSoulFlare               := _settingsGui["AutoSoulFlare"].Value
    cfg.isUseLeechHasLeechBuff      := _settingsGui["IsUseLeechHasLeechBuff"].Value
    cfg.goldLeech                   := _settingsGui["Gold_Leech"].Value
    cfg.limitationOpen              := _settingsGui["LimitationOpen"].Value
    cfg.limitationLeech             := _settingsGui["LimitationLeech"].Value
    cfg.enablePriorityUseDragoncall := _settingsGui["EnablePriorityUseDragoncall"].Value ? 1 : 0
    cfg.isUseOpenHasSoulFlareBuff   := _settingsGui["IsUseOpenHasSoulFlareBuff"].Value
    cfg.isUsedLeechFromMySelf       := _settingsGui["IsUsedLeechFromMySelf"].Value

    ; 派生字段：Gold_Leech 切换时刷新 LeechBuff 时长
    cfg.leechBuffDuration := cfg.goldLeech ? 18 : 15

    ; 系统设置
    StateManager.realtimeMode := _settingsGui["RealtimeMode"].Value
    PerformanceMonitor.enabled := _settingsGui["PerformanceMonitor"].Value
    PerformanceMonitor.monitorCpu := _settingsGui["MonitorCpu"].Value
    PerformanceMonitor.monitorMem := _settingsGui["MonitorMemory"].Value

    App.SaveSettingsToFile()
}