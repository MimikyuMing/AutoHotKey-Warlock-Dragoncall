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
$*XButton1:: SendInput '^{Numpad9}'

~$X::{
    ; MsgBox "HELLO WORLD"
    LogicEngine.g_Mutex.SetSleep(5, LogicEngine.g_Mutex.xSleepTime)
}

F11:: {
    App.Cleanup()
    Reload
}
