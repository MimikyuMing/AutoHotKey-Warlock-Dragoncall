#Requires AutoHotkey v2.0
; Lib\StatusMonitor.ahk

class StatusMonitor {
    timer := 0
    interval := 1000
    clearTimer := 0
    x := 0
    y := 0
    dataMap := Map()
    obj := 0
    displayDuration := 1000
    hwnd := 0           ; 目标窗口句柄（0=屏幕绝对坐标；非0=窗口相对坐标，且仅在该窗口聚焦时显示）

    Start(obj, displayDuration := 1000, intervalMs := 1000, posX := 0, posY := 0, hwndTarget := 0) {
        this.Stop()
        if IsSet(obj)
            this.obj := obj
        this.interval := intervalMs
        this.displayDuration := displayDuration
        this.x := posX
        this.y := posY
        this.hwnd := hwndTarget
        this.Refresh()
        this.timer := SetTimer(ObjBindMethod(this, "Refresh"), this.interval)
    }

    _ClearTooltip() {
        ToolTip("", this.x, this.y)
    }

    Stop() {
        if this.timer {
            SetTimer(this.timer, 0)
            this.timer := 0
        }
        if this.clearTimer {
            SetTimer(this.clearTimer, 0)
            this.clearTimer := 0
        }
        ToolTip("", this.x, this.y)
    }

    Set(key, value) {
        this.dataMap[key] := value
    }

    Delete(key) {
        this.dataMap.Delete(key)
    }

    Clear() {
        this.dataMap.Clear()
    }

    Refresh() {
        if !this.hwnd {
            ToolTip()    ; 清除已有 ToolTip
            return
        }
        if !WinActive("ahk_id " this.hwnd) {
            ToolTip()
            return
        }

        WinGetPos(&wx, &wy, &ww, &wh, this.hwnd)
        if (wx < -10000 || wy < -10000) {   ; 最小化/隐藏
            ToolTip()
            return
        }

        screenX := wx + this.x
        screenY := wy + this.y

        content := this.Report()
        if (content = "")
            ToolTip()
        else
            ToolTip(content, screenX, screenY)

        ; 鼠标穿透处理
        DetectHiddenWindows(true)
        ttHwnd := WinExist("ahk_class tooltips_class32 ahk_pid " ProcessExist())
        if ttHwnd {
            exStyle := WinGetExStyle(ttHwnd)
            WinSetExStyle(exStyle | 0x08000020, ttHwnd)   ; WS_EX_NOACTIVATE | WS_EX_TRANSPARENT
        }
        DetectHiddenWindows(false)
    }

    Report() {
        s := ""
        for k, v in this.dataMap
            s .= k . ": " . v . "`n"
        return RTrim(s, "`n")
    }
}