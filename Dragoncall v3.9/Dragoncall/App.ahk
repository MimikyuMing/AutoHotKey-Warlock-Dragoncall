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
#Include DragoncallGlobals.ahk
#Include DragoncallStatusMonitor.ahk


class App {

    static debugMode := true

    static Millisecond := 1000

    static Init() {
        if (this.debugMode)
            OutputDebug "Step 1: Init start"
        HiResTimer.Init()

        ; 确保用户配置文件存在（首次运行时从临时模板复制）
        static userConfig := A_AppData "\Dragoncall\Dragoncall-Config.ini"
        if !FileExist(userConfig) {
            if !DirExist(A_AppData "\Dragoncall")
                DirCreate(A_AppData "\Dragoncall")
            if FileExist(A_Temp "\Dragoncall-Config.ini")
                FileCopy A_Temp "\Dragoncall-Config.ini", userConfig, 0   ; 不覆盖
            else
                FileAppend "", userConfig   ; 创建空文件
        }

        if (this.debugMode)
            OutputDebug "Step 2: HiResTimer OK"
        this.LoadSettings()
        if (this.debugMode)
            OutputDebug "Step 3: LoadSettings OK"

        if (this.debugMode)
            OutputDebug "Step 4: Before CaptureEngine.Start"
        CaptureEngine.Start()
        if (this.debugMode)
            OutputDebug "Step 5: CaptureEngine.Start OK"

        ; 逐个添加后续初始化，每加一个测试一次
        if (this.debugMode)
            OutputDebug "Step 6: Before DragoncallMutex.Init"
        DragoncallMutex.Init()
        if (this.debugMode)
            OutputDebug "Step 7: DragoncallMutex.Init OK"

        if (this.debugMode)
            OutputDebug "Step 8: Before StateManager.Init"
        StateManager.Init(CaptureEngine)
        if (this.debugMode)
            OutputDebug "Step 9: StateManager.Init OK"

        if (this.debugMode)
            OutputDebug "Step 10: Before CreateTray"
        this.CreateTray()
        if (this.debugMode)
            OutputDebug "Step 11: CreateTray OK"

        if (this.debugMode)
            OutputDebug "Step 12: Before Log.Init"
        Log.Init()
        if (this.debugMode)
            OutputDebug "Step 13: Log.Init OK"

        if (this.debugMode)
            OutputDebug "Step 14: Before KeyLogger.Start"
        KeyLogger.Start()
        if (this.debugMode)
            OutputDebug "Step 15: KeyLogger.Start OK"

        if (this.debugMode)
            OutputDebug "Step 16: Before InputQueue.Init"
        InputQueue.Init(LogicEngine.g_LogicEnabled)
        if (this.debugMode)
            OutputDebug "Step 17: InputQueue.Init OK"

        intervalMs := 100
        posX := 720
        posY := 570
        duration := 1000
        monitior := DragoncallStatusMonitor()
        monitior.Start(LogicEngine, duration, intervalMs, posX, posY)

        OnExit App.Cleanup
        if (this.debugMode)
            OutputDebug "Step 18: Init complete"

        LogicEngine.InitLastUsed()
        
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
        LogicEngine.g_isUseOpenHasSoulFlareBuff := ParseBool(settings.Has("isUseOpenHasSoulFlareBuff") ? settings["isUseOpenHasSoulFlareBuff"] : false)
        

        ; 模式設定
        LogicEngine.isUsedInputQueue := ParseBool(settings.Has("IsUsedInputQueue") ? settings["IsUsedInputQueue"] : false)
        CaptureEngine.RealtimeMode := ParseBool(settings.Has("RealtimeMode") ? settings["RealtimeMode"] : false)
        intervalMs := Integer(settings.Get("InputQueueMinIntervalMs", 10))  ; 默认 10ms
        InputQueue.minIntervalUs := intervalMs * this.Millisecond   ; 转换为微秒

        ; 性能检测器
        enablePerf := ParseBool(settings.Has("PerformanceMonitor") ? settings["PerformanceMonitor"] : false)
        enableCpu := ParseBool(settings.Has("MonitorCpu") ? settings["MonitorCpu"] : false)
        enableMem := ParseBool(settings.Has("MonitorMemory") ? settings["MonitorMemory"] : false)
        reportInterval := Integer(settings.Get("ReportInterval", 1))
        PerformanceMonitor.Init(enablePerf, enableCpu, enableMem, reportInterval)


        ; 日誌寫入設定
        globalWriteLog := ParseBool(settings.Has("WRITELOG") ? settings["WRITELOG"] : false)
        globalWriteKeyLog := ParseBool(settings.Has("WRITEKeyLOG") ? settings["WRITEKeyLOG"] : false)
        Log.Enabled := globalWriteLog
        KeyLogger.Enabled := globalWriteKeyLog

        slowMs := Integer(settings.Get("PerformanceSlowThresholdMs", 10))
        PerformanceMonitor.slowThresholdUs := slowMs * 1000

        ; 从 INI 读取慢执行阈值（毫秒），默认 10ms
        enabledSlow := settings.Has("PerformanceSlowLogEnabled")
            ? settings["PerformanceSlowLogEnabled"]
            : "true"
        PerformanceMonitor.slowLogEnabled := ParseBool(enabledSlow)

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