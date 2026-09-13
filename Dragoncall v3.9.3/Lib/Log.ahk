#Requires AutoHotkey v2.0

class Log {
    static queue := []
    static Enabled := true

    static Init() {
        ; 确保日志目录存在
        this.GetLogPath()
        OnExit(ObjBindMethod(Log, "Cleanup"))
    }

    static Write(msg) {
        if !this.Enabled
            return
        entry := Format("{1}`n", msg)
        this.AppendLog(entry)
    }

    static AppendLog(entry) {
        if !this.Enabled
            return
        this.queue.Push(entry)
        ; 达到阈值立即冲刷
        if (this.queue.Length >= MAX_QUEUE_SIZE)
            this.Flush()
        else
            this.ResetIdleFlush()
    }

    ; 空闲冲刷定时器重置（与 KeyLogger 完全相同）
    static ResetIdleFlush() {
        static timer := 0
        if timer
            SetTimer(timer, 0)
        timer := SetTimer(ObjBindMethod(Log, "Flush"), -FLUSH_INTERVAL)
    }

    static Flush(*) {
        if this.queue.Length == 0
            return
        local tmp := this.queue
        this.queue := []
        local s := ""
        for entry in tmp
            s .= entry

        logPath := this.GetLogPath()
        ; 尝试写入，最多重试 5 次，每次间隔 30ms
        Loop 5 {
            try {
                FileAppend(s, logPath)
                return    ; 写入成功
            } catch Error as e {
                if (A_Index = 5)
                    ; 5 次仍失败：放弃本次写入，打印错误，避免死锁
                    OutputDebug("Log: 写入失败 (已重试5次) - " e.Message)
                else
                    Sleep 30
            }
        }
    }

    static GetLogPath() {
        dir := A_ScriptDir "\log\other"
        if !DirExist(dir)
            DirCreate(dir)
        return Format("{1}\{2}.txt", dir, Format("{:04d}-{:02d}-{:02d}", A_Year, A_Mon, A_DD))
    }

    static Cleanup(*) {
        ; 脚本退出时自动冲刷所有剩余日志
        this.Flush()
    }
}