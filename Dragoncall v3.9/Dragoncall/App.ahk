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
        Log.Init()
        this.LoadSettings()
        CaptureEngine.Start()
        StateManager.Init(CaptureClient)   ; 传入基类引用，也可直接使用 CaptureClient
        StateManager.realtimeMode := CaptureEngine.RealtimeMode  ; 假设该值已从 INI 读取
        this.CreateTray()
        KeyLogger.Start()
        InputQueue.Init(LogicEngine.g_LogicEnabled)
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
        reportInterval  := ParseBool(settings.Has("ReportInterval") ? settings["ReportInterval"] : false)
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
