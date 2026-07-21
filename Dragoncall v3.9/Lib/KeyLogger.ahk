#Requires AutoHotkey v2.0

class KeyLogger {
    static WH_KEYBOARD_LL := 13
    static WM_KEYDOWN   := 0x100
    static WM_SYSKEYDOWN := 0x104
    static LLKHF_INJECTED := 0x10

    static Enabled := true

    static hHook := 0
    static callback := 0
    static queue := []           ; 批量缓冲
    static flushTimer := 0       ; 冲刷定时器句柄


    static GetLogPath() {
        dir := A_ScriptDir "\log\KeyLog"
        if !DirExist(dir)
            DirCreate(dir)
        return Format("{1}\{2}.txt", dir, Format("{:04d}-{:02d}-{:02d}", A_Year, A_Mon, A_DD))
    }

    ; 启动时改为使用“空闲冲刷”而非固定定时器（更符合“无输入时写入”）
    static Start() {
        this.GetLogPath()

        this.callback := CallbackCreate(ObjBindMethod(KeyLogger, "Proc"), "Fast", 3)
        this.hHook := DllCall("SetWindowsHookEx", "Int", this.WH_KEYBOARD_LL,
                              "Ptr", this.callback, "Ptr", 0, "UInt", 0, "Ptr")
        if !this.hHook {
            MsgBox("钩子安装失败，请以管理员权限运行。")
            ExitApp
        }
        ; 不再使用固定定时器，改为“无输入后冲刷”
        ; this.flushTimer 初始为 0，在每次新条目时重置

        OnExit(ObjBindMethod(KeyLogger, "Cleanup"))
    }


    ; 空闲冲刷定时器重置
    static ResetIdleFlush() {
        static timer := 0  ; 局部静态变量存储最后一次定时器对象
        if timer
            SetTimer(timer, 0)  ; 取消旧定时器
        timer := SetTimer(ObjBindMethod(KeyLogger, "Flush"), -FLUSH_INTERVAL)
    }

    static AppendLog(entry) {
        if !this.Enabled
            return
        this.queue.Push(entry)
        if (this.queue.Length >= MAX_QUEUE_SIZE)
            this.Flush()
        else
            this.ResetIdleFlush()
    }

    static WriteLog(tick, msg) {
        if !this.Enabled
            return
        entry := Format("{1}`t{2}`n", tick, msg)
        this.AppendLog(entry)
    }

    ; 钩子回调改为使用 AppendLog
    static Proc(nCode, wParam, lParam) {
        if (nCode >= 0 && (wParam == this.WM_KEYDOWN || wParam == this.WM_SYSKEYDOWN)) {
            vkCode   := NumGet(lParam, 0, "UInt")
            flags    := NumGet(lParam, 8, "UInt")
            injected := (flags & this.LLKHF_INJECTED) != 0

            if (!ONLY_INJECTED || injected) {
                tick    := HiResTimer.GetTick()
                keyName := GetKeyName("vk" Format("{:X}", vkCode))
                entry   := Format("{1}`t{2}`t{3}`t{4}`n", tick, vkCode, keyName,
                                  injected ? "Injected" : "Physical")
                KeyLogger.AppendLog(entry)
            }
        }
        return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UPtr", wParam, "Ptr", lParam)
    }

    ; Flush 方法不变（这里重复列出确保完整）
    static Flush(*) {
        if (this.queue.Length == 0)
            return
        local tmp := this.queue
        this.queue := []
        local s := ""
        logPath := this.GetLogPath()
        for entry in tmp
            s .= entry
        ; 尝试写入，最多重试 5 次，每次间隔 30ms
        Loop 5 {
            try {
                FileAppend(s, logPath)
                return    ; 写入成功
            } catch Error as e {
                if (A_Index = 5)
                    ; 5 次仍失败：放弃本次写入，打印错误，避免死锁
                    OutputDebug("KeyLogger: 写入失败 (已重试5次) - " e.Message)
                else
                    Sleep 30
            }
        }
    }

    static Cleanup(*) {
        if this.hHook {
            DllCall("UnhookWindowsHookEx", "Ptr", this.hHook)
            this.hHook := 0
        }
        if this.callback {
            CallbackFree(this.callback)
            this.callback := 0
        }
        this.Flush()
    }
}