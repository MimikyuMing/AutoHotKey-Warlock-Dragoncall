#Requires AutoHotkey v2.0

; Lib\LogicRunner.ahk

#Include ActionMutex.ahk
#Include Globals.ahk
#Include InputQueue.ahk

class LogicRunner {
    static g_LogicEnabled := false
    static g_LogicTimerPending := false
    static g_Mutex := ActionMutex()         ; 子类会覆盖为具体类型
    static lastFrameId := 0
    static g_LastExecutionTick := 0
    static startLogic := 0                  ; 供 CaptureEngine 使用
    static isUsedInputQueue := 0


    ; ----- 抽象方法（子类必须实现）-----
    static _MainLogic() => Error("LogicRunner: 必须实现 _MainLogic()", -1)
    static _HandleSleepState() => Error("LogicRunner: 必须实现 _HandleSleepState()", -1)

    ; ----- 调度器实现 -----
    static ScheduleNextLogic() {
        if (!this.g_LogicEnabled || this.g_LogicTimerPending)
            return
        this.g_LogicTimerPending := true
        SetTimer ObjBindMethod(this, "LogicExecuter"), -LOGIC_INTERVAL
    }

    static LogicExecuter() {
        ; 停止条件
        if (!this.g_LogicEnabled || !GetKeyState("XButton2", "P")) {
            this.g_LogicEnabled := false
            SetTimer ObjBindMethod(this, "LogicExecuter"), 0
            this.g_LogicTimerPending := false
            return
        }

        ; 硬间隔防护
        if (HiResTimer.GetTick() - this.g_LastExecutionTick < LOGIC_INTERVAL * 0.9)
            return

        static isRunning := false
        if isRunning
            return

        isRunning := true
        try {
            this._MainLogic()               ; 委派给子类
        } finally {
            this.g_LastExecutionTick := HiResTimer.GetTick()
            isRunning := false
            this.g_LogicTimerPending := false
        }

        if this.g_LogicEnabled
            this.ScheduleNextLogic()
    }

    static SendKey(key){
        if(this.isUsedInputQueue){
            InputQueue.Push(key)
        }else{
            Send key
        }
    }
}