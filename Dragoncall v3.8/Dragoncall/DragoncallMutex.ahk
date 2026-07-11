#Requires AutoHotkey v2.0

#Include ..\Lib\ActionMutex.ahk
#Include ..\Lib\HiResTimer.ahk

class DragoncallMutex extends ActionMutex {
    ; 业务状态
    isSFirst := false
    thisFrameAct := 0

    ; 技能保护时长
    openSleepTime      := 300
    soulflareSleepTime := 1000
    leechSleepTime     := 800
    xSleepTime         := 800

    ; ----- 实现抽象接口 -----
    BeginFrame() {
        this.thisFrameAct := 0
    }

    CanExecute(action) {
        this.IsInSleep()   ; 清理过期
        for item in this.sleepQueue {
            sType := item.type
            expire := item.expire
            switch sType {
                case 1: return false
                case 2:
                    if (this.isSFirst) {
                        if (action == 3 && HiResTimer.GetTick() < HiResTimer.SubMs(800, expire))
                            return false
                        if (action != 1 && action != 3)
                            return false
                    } else {
                        return true
                    }
                case 3:
                    if (action != 2)
                        return false
                case 4:
                    if (action != 2)
                        return true
                    if (action == 2 && this.isSFirst)
                        return false
                case 5: return false
                default: return false
            }
        }

        ; ---- 帧内互斥规则 ----
        if (this.isSFirst && action == 2) {
            if (action == 4 || action == 5)
                return false
        }
        prev := this.thisFrameAct
        if (prev == 0)
            return true
        if (action == 2 && !this.isSFirst)
            return true
        if (prev == 2 && !this.isSFirst)
            return true
        if (action == 5 || prev == 5)
            return false
        if (action == 3 && prev != 2 && prev != 1)
            return false
        if (prev == 3 && action != 2)
            return false
        if (action == 1 && prev == 3)
            return false
        if (action == 1 && prev == 1)
            return false
        if (prev == 1 && action == 5)
            return false
        if (action == 4 && (prev == 3 || prev == 5))
            return false
        if (prev == 4 && (action == 3 || action == 5))
            return false
        return true
    }

    OnExecuted(action) {
        this.thisFrameAct := action
        if (action == 2 && this.isSFirst) {
            this.isSFirst := false
            this.SetSleep(2, this.soulflareSleepTime * 0.999)
        } else if (action == 3) {
            this.SetSleep(3, this.leechSleepTime * 0.90)
        } else if (action == 5) {
            this.SetSleep(1, this.openSleepTime)
        } else if (this.isSFirst && (action != 1 || action != 3)) {
            this.isSFirst := false
        }
    }

    ; ----- 特殊工具方法 -----
    MarkSFirst() {
        this.isSFirst := true
    }

    GetStateToStr() {
        s := "SleepQueue: "
        for item in this.sleepQueue
            s .= Format("[t{1} @{2}] ", item.type, item.expire)
        return Format("IsSFirst: {1}, FrameAct: {2}, {3}", this.isSFirst, this.thisFrameAct, s)
    }
}