#Requires AutoHotkey v2.0

#Include LogicEngine.ahk
#Include ..\Lib\StateManager.ahk
#Include ..\Lib\KeyLogger.ahk
#Include App.ahk

; 侧键按下启动逻辑
$*XButton2:: {
    if LogicEngine.g_LogicEnabled
        return
    LogicEngine.g_LogicEnabled := true
    LogicEngine.ScheduleNextLogic()
}
; 侧键松开停止逻辑
$*XButton2 Up:: {
    LogicEngine.g_LogicEnabled := false
    SetTimer ObjBindMethod(LogicEngine, "LogicExecuter"), 0
    LogicEngine.g_Mutex.ReleaseSleep()
    LogicEngine.g_LogicTimerPending := false
}
; 鼠标侧键1模拟组合键
$*XButton1:: {
    SendInput '^{Numpad9}'
}

~$X:: {
    ; MsgBox "HELLO WORLD"
    TetherBladeReady := StateManager._skillState.Get("TetherBlade", false)
    if (TetherBladeReady) {
        LogicEngine.g_Mutex.SetSleep(5, LogicEngine.g_Mutex.xSleepTime)
        if (LogicEngine.BrandTriggerTime <= HiResTimer.GetTick()) {
            LogicEngine.BrandTriggerTime := HiResTimer.GetTick()
            temp := HiResTimer.AddMs(4 * 1000, LogicEngine.BrandTriggerTime)
            if (temp >= LogicEngine.BrandOverTime) {
                LogicEngine.BrandOverTime := temp
            }
        }
    }
}

~$2:: {
    ; MsgBox "HELLO WORLD"
    SoulShackleReady := StateManager._skillState.Get("SoulShackle", false)
    if (SoulShackleReady) {
        if (LogicEngine.BrandTriggerTime <= HiResTimer.GetTick()) {
            LogicEngine.BrandTriggerTime := HiResTimer.GetTick()
            temp := HiResTimer.AddMs(8 * 1000, LogicEngine.BrandTriggerTime)
            if (temp >= LogicEngine.BrandOverTime) {
                LogicEngine.BrandOverTime := temp
            }
        }
    }
}


F11:: {
    App.Cleanup()
    Reload
}

~$F:: {
    LeechReady := StateManager._skillState.Get("Leech_R", false)
    if (LeechReady) {
        LogicEngine.lastUsedLeech := HiResTimer.GetTick()
        LogicEngine.g_Mutex.OnExecuted(3)
    }
}


~$Tab:: {
    soulFlareReady := StateManager._skillState.Get("SoulFlare", false)
    if (soulFlareReady) {
        LogicEngine.g_Mutex.OnExecuted(2)
        SetTimer ObjBindMethod(LogicEngine, "SetMarkToFalse"), -500
    }
}

~$3:: {
    OpenReady := StateManager._skillState.Get("Open_R", false)
    if (OpenReady) {
        LogicEngine.g_Mutex.OnExecuted(5)
        LogicEngine.lastUsedOpen := HiResTimer.GetTick()
    }
}