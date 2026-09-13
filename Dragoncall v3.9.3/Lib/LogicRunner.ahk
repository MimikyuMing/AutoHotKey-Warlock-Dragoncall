#Requires AutoHotkey v2.0

#Include ActionMutex.ahk
#Include Globals.ahk
#Include InputQueue.ahk
#Include PerformanceMonitor.ahk

class LogicRunner {
    ; 调度器私有状态（保留）
    static g_LogicTimerPending := false
    static g_LastExecutionTick := 0

    ; 上下文引用，由 App 注入到子类
    static ctx := ""

    ; ----- 抽象方法 -----
    static _MainLogic() => Error("LogicRunner: 必须实现 _MainLogic()", -1)
    static _HandleSleepState(ctx) => Error("LogicRunner: 必须实现 _HandleSleepState()", -1)

    ; ----- 调度器 -----
    static ScheduleNextLogic() {
        ctx := this.ctx
        if (!ctx.state.logicEnabled || this.g_LogicTimerPending)
            return
        this.g_LogicTimerPending := true
        SetTimer ObjBindMethod(this, "LogicExecuter"), -LOGIC_INTERVAL
    }

    static LogicExecuter() {
        ctx := this.ctx

        ; 停止条件
        if (!ctx.state.logicEnabled || !GetKeyState("XButton2", "P")) {
            ctx.state.logicEnabled := false
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
            this._MainLogic()
        } finally {
            this.g_LastExecutionTick := HiResTimer.GetTick()
            isRunning := false
            this.g_LogicTimerPending := false
        }

        if (ctx.state.logicEnabled)
            this.ScheduleNextLogic()
    }

    static SendKey(key, str) {
        params := Format("Keyboard is {} , Logic is {}", key, str)
        PerformanceMonitor.Start(str)
        if (App.isUsedInputQueue) {
            InputQueue.Push(key)
        } else {
            Send key
        }
        PerformanceMonitor.End(str, params)
    }
}