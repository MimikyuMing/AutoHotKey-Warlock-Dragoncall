#Requires AutoHotkey v2.0

; ============================================
;  StatusMonitor 基类
;  · 提供定时 ToolTip 刷新框架
;  · 子类必须实现 Report() 方法
; ============================================
class StatusMonitor {
    ; 状态数据（键值对，子类可自由使用）
    dataMap := Map()

    ; 内部管理
    timer     := 0       ; 定时器句柄
    x         := 0       ; ToolTip X 坐标
    y         := 0       ; ToolTip Y 坐标
    interval  := 1000    ; 刷新间隔（毫秒）

    ; --- 公共方法 ---

    ; 启动定时刷新
    ; @param intervalMs 刷新间隔（毫秒）
    ; @param posX       ToolTip X 坐标（屏幕坐标）
    ; @param posY       ToolTip Y 坐标
    Start(intervalMs := 1000, posX := 0, posY := 0) {
        this.Stop()                     ; 先停止已有定时器
        this.interval := intervalMs
        this.x := posX
        this.y := posY
        this.timer := SetTimer(ObjBindMethod(this, "Refresh"), this.interval)
        this.Refresh()                  ; 立即显示一次
    }

    ; 停止刷新并清除 ToolTip
    Stop() {
        if this.timer {
            SetTimer(this.timer, 0)
            this.timer := 0
        }
        ToolTip("", this.x, this.y)     ; 清除显示
    }

    ; 存储/更新一项状态数据
    Set(key, value) {
        this.dataMap[key] := value
    }

    ; 删除一项状态数据
    Delete(key) {
        this.dataMap.Delete(key)
    }

    ; 清空所有状态数据
    Clear() {
        this.dataMap.Clear()
    }

    ; --- 内部方法 ---

    ; 定时器回调：刷新 ToolTip 内容
    Refresh() {
        content := this.Report()        ; 调用子类实现的 Report
        ToolTip(content, this.x, this.y)
    }

    ; --- 抽象方法（子类必须实现）---
    Report() {
        ; 基类提供默认的简单输出，也可要求子类覆盖
        ; 若希望强制子类实现，可保留此默认，或改成 throw
        s := ""
        for k, v in this.dataMap
            s .= k . ": " . v . "`n"
        return RTrim(s, "`n")
    }
}