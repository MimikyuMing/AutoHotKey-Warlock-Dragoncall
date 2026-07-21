; Lib/InputQueue.ahk
class InputQueue {
    static queue := []
    static timer := 0
    static isProcessing := false
    static engine := 0           ; 期望是一个类，其静态属性 g_LogicEnabled 表示是否允许发送

    ; 注入发送许可提供者（一个包含 g_LogicEnabled 静态属性的类）
    static Init(provider := 0) {
        this.Clear()
        if provider
            this.engine := provider
    }

    static Push(key) {
        if (key == "")
            return
        this.queue.Push(key)
        this.StartTimer()
    }

    static StartTimer() {
        if !this.timer
            this.timer := SetTimer(ObjBindMethod(InputQueue, "Process"), -1)
    }

    static Process() {
        PerformanceMonitor.Start("InputQueue")
        try{
            if this.isProcessing
                return

            ; 检查引擎是否允许发送（如果未注入，默认允许）
            if (this.engine && !this.engine.g_LogicEnabled) {
                this.Clear()
                return
            }

            if this.queue.Length == 0 {
                this.timer := 0
                return
            }

            this.isProcessing := true
            key := this.queue.RemoveAt(1)

            ; 发送前再次检查（防止取出瞬间逻辑被关闭）
            if (!this.engine || this.engine.g_LogicEnabled)
                SendInput key

            this.isProcessing := false

            if (!this.engine || this.engine.g_LogicEnabled)
                this.timer := SetTimer(ObjBindMethod(InputQueue, "Process"), -1)
            else
                this.Clear()
        }finally{
            PerformanceMonitor.End("InputQueue")
        }
    }

    static Clear() {
        this.queue := []
        if this.timer {
            SetTimer(this.timer, 0)
            this.timer := 0
        }
        this.isProcessing := false
    }
}