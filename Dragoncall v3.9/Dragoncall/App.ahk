#Requires AutoHotkey v2.0

#Include ..\Lib\HiResTimer.ahk
#Include CaptureEngine.ahk
#Include ..\Lib\KeyLogger.ahk
#Include ..\Lib\IniManager.ahk
#Include ..\Lib\Tools.ahk
#Include GUI.ahk
#Include ..\Lib\PerformanceMonitor.ahk
#Include ..\Lib\InputQueue.ahk
#Include LogicEngine.ahk


class App {
    static Init() {
        HiResTimer.Init()
        OutputDebug "1"
        Log.Init()
        OutputDebug "2"
        this.LoadSettings()
        OutputDebug "3"
        CaptureEngine.Start()
        OutputDebug "4"
        StateManager.Init(CaptureEngine)
        OutputDebug "5"
        this.CreateTray()
        OutputDebug "6"
        KeyLogger.Start()
        OutputDebug "7"
        InputQueue.Init(LogicEngine.g_LogicEnabled)
        OutputDebug "8"
        OnExit App.Cleanup
    }

    static LoadSettings() {
        settings := IniManager.ReadToMap("Settings")
        LogicEngine.g_Gold_Wingstorm := ParseBool(settings.Has("Gold_Wingstorm") ? settings["Gold_Wingstorm"] : false)
        LogicEngine.g_Gold_Open := ParseBool(settings.Has("Gold_Open") ? settings["Gold_Open"] : false)
        LogicEngine.g_AutoSoulFlare := ParseBool(settings.Has("AutoSoulFlare") ? settings["AutoSoulFlare"] : false)
        LogicEngine.g_isUseLeechHasLeechBuff := ParseBool(settings.Has("isUseLeechHasLeechBuff") ? settings["isUseLeechHasLeechBuff"] : false)
        LogicEngine.g_Gold_Leech := ParseBool(settings.Has("Gold_Leech") ? settings["Gold_Leech"] : false)
        LogicEngine.g_limitationOpen := ParseBool(settings.Has("LimitationOpen") ? settings["LimitationOpen"] : false)
        LogicEngine.g_limitationLeech := ParseBool(settings.Has("LimitationLeech") ? settings["LimitationLeech"] : false)
        LogicEngine.isUsedInputQueue := ParseBool(settings.Has("IsUsedInputQueue") ? settings["IsUsedInputQueue"] : false)
        LogicEngine.g_enablePriorityUseDragoncall := ParseBool(settings.Has("EnablePriorityUseDragoncall") ? settings["EnablePriorityUseDragoncall"] : false)
        CaptureEngine.RealtimeMode := ParseBool(settings.Has("RealtimeMode") ? settings["RealtimeMode"] : false)
        
        ; 性能检测器
        enablePerf := ParseBool(settings.Has("PerformanceMonitor") ? settings["PerformanceMonitor"] : false)
        enableCpu  := ParseBool(settings.Has("MonitorCpu") ? settings["MonitorCpu"] : false)
        enableMem  := ParseBool(settings.Has("MonitorMemory") ? settings["MonitorMemory"] : false)
        reportInterval  := ParseBool(settings.Has("ReportInterval") ? settings["ReportInterval"] : 0)
        PerformanceMonitor.Init(enablePerf, enableCpu, enableMem, reportInterval)
        globalWriteLog := ParseBool(settings.Has("WRITELOG") ? settings["WRITELOG"] : false)
        Log.Enabled := globalWriteLog
        KeyLogger.Enabled := globalWriteLog
        
    }

    static CreateTray() {
        A_TrayMenu.Delete()
        A_TrayMenu.Add("设置", ShowSettingsGUI)
        A_TrayMenu.Add("退出", (*) => ExitApp())
        A_TrayMenu.Default := "设置"
    }

    static Cleanup(*) {
        CaptureEngine.Cleanup()
        Log.Flush()
        PerformanceMonitor.DumpReport()
        ToolTip "Cleanup completed", 0, 0
    }
}
