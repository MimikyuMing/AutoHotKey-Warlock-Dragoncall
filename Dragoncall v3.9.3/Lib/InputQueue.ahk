#Requires AutoHotkey v2.0

class InputQueue {
    static queue        := []
    static timer        := 0
    static isProcessing := false

    ; ---------- 发送间隔控制 ----------
    static minIntervalUs := 5 * 1000     ; 同一按键最小发送间隔（微秒）
    static lastSendTicks := Map()        ; 每个按键的上次发送时刻

    static Init() {
        this.Clear()
    }

    static Push(key) {
        if (key == "")
            return
        this.queue.Push(key)
        if !this.timer && !this.isProcessing
            this.timer := SetTimer(ObjBindMethod(InputQueue, "Process"), -1)
    }

    static Process() {
        PerformanceMonitor.Start("InputQueue")
        try {
            if this.isProcessing
                return

            ; 引擎停止时清空队列
            if (!App.ctx.state.logicEnabled) {
                this.Clear()
                return
            }

            if this.queue.Length == 0 {
                this.StopTimer()
                return
            }

            this.isProcessing := true
            key := this.queue.RemoveAt(1)

            ; 发送前检查该按键的上次发送间隔
            allowSend := true
            lastTick := this.lastSendTicks.Get(key, 0)
            elapsed := HiResTimer.DeltaUs(lastTick, HiResTimer.GetTick())
            if (elapsed < this.minIntervalUs)
                allowSend := false

            if (allowSend) {
                SendInput key
                this.lastSendTicks[key] := HiResTimer.GetTick()
            }

            this.isProcessing := false

            ; 继续处理下一个或停止定时器
            if (this.queue.Length > 0 && App.ctx.state.logicEnabled)
                this.timer := SetTimer(ObjBindMethod(InputQueue, "Process"), -1)
            else
                this.StopTimer()

        } finally {
            PerformanceMonitor.End("InputQueue")
        }
    }

    static StopTimer() {
        if this.timer {
            this.timer.Stop()
            this.timer := 0
        }
    }

    static Clear() {
        this.queue := []
        this.isProcessing := false
        this.StopTimer()
    }
}