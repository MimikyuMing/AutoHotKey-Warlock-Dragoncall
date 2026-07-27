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

    static Millisecond := 1000

    static Init() {
        try{
            res:= 0
            HiResTimer.Init()
            res:= 1
            Log.Init()
            res:= 2
            this.LoadSettings()
            res:= 3
            CaptureEngine.Start()
            res:= 4
            StateManager.Init(CaptureEngine)
            res:= 5
            this.CreateTray()
            res:= 6
            KeyLogger.Start()
            res:= 7
            InputQueue.Init(LogicEngine.g_LogicEnabled)
            res:= 8
            OnExit App.Cleanup
        } finally{
            if(res!= 8){
                MsgBox res "!"
            }
        }   
    }

    static LoadSettings() {
        settings := IniManager.ReadToMap("Settings")

        ; 技能書設定
        LogicEngine.g_Gold_Wingstorm := ParseBool(settings.Has("Gold_Wingstorm") ? settings["Gold_Wingstorm"] : false)
        LogicEngine.g_Gold_Open := ParseBool(settings.Has("Gold_Open") ? settings["Gold_Open"] : false)
        LogicEngine.g_Gold_Leech := ParseBool(settings.Has("Gold_Leech") ? settings["Gold_Leech"] : false)

        ; 技能特殊效果設定
        LogicEngine.g_AutoSoulFlare := ParseBool(settings.Has("AutoSoulFlare") ? settings["AutoSoulFlare"] : false)
        LogicEngine.g_isUseLeechHasLeechBuff := ParseBool(settings.Has("isUseLeechHasLeechBuff") ? settings["isUseLeechHasLeechBuff"] : false)
        LogicEngine.g_limitationOpen := ParseBool(settings.Has("LimitationOpen") ? settings["LimitationOpen"] : false)
        LogicEngine.g_limitationLeech := ParseBool(settings.Has("LimitationLeech") ? settings["LimitationLeech"] : false)
        LogicEngine.g_enablePriorityUseDragoncall := ParseBool(settings.Has("EnablePriorityUseDragoncall") ? settings["EnablePriorityUseDragoncall"] : false)

        ; 模式設定
        LogicEngine.isUsedInputQueue := ParseBool(settings.Has("IsUsedInputQueue") ? settings["IsUsedInputQueue"] : false)
        CaptureEngine.RealtimeMode := ParseBool(settings.Has("RealtimeMode") ? settings["RealtimeMode"] : false)
        intervalMs := Integer(settings.Get("InputQueueMinIntervalMs", 10))  ; 默认 10ms
        InputQueue.minIntervalUs := intervalMs * this.Millisecond   ; 转换为微秒
        
        ; 性能检测器
        enablePerf := ParseBool(settings.Has("PerformanceMonitor") ? settings["PerformanceMonitor"] : false)
        enableCpu  := ParseBool(settings.Has("MonitorCpu") ? settings["MonitorCpu"] : false)
        enableMem  := ParseBool(settings.Has("MonitorMemory") ? settings["MonitorMemory"] : false)
        reportInterval  := ParseBool(settings.Has("ReportInterval") ? settings["ReportInterval"] : 0)
        PerformanceMonitor.Init(enablePerf, enableCpu, enableMem, reportInterval)


        ; 日誌寫入設定
        globalWriteLog := ParseBool(settings.Has("WRITELOG") ? settings["WRITELOG"] : false)
        globalWriteKeyLog := ParseBool(settings.Has("WRITEKeyLOG") ? settings["WRITEKeyLOG"] : false)
        Log.Enabled := globalWriteLog
        KeyLogger.Enabled := globalWriteKeyLog
        
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
