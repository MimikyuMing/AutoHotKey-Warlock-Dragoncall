class InputQueue {
    static queue        := []
    static timer        := 0
    static isProcessing := false
    static engine       := 0

    ; ---------- 发送间隔控制 ----------
    static minIntervalUs := 5*1000   ; 同一按键最小发送间隔 10 毫秒（微秒）
    static lastSendTicks := Map()    ; 每个按键的上次发送时刻 (QPC)

    static Init(provider := 0) {
        this.Clear()
        if provider
            this.engine := provider
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

            if (this.engine && !this.engine.g_LogicEnabled) {
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
                allowSend := false   ; 间隔不足，丢弃

            if (allowSend) {
                SendInput key
                this.lastSendTicks[key] := HiResTimer.GetTick()
            }
            ; 被丢弃的按键不做任何处理

            this.isProcessing := false

            ; 继续处理下一个或停止定时器
            if (this.queue.Length > 0 && (!this.engine || this.engine.g_LogicEnabled))
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