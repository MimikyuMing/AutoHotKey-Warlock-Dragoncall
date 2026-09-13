#Requires AutoHotkey v2.0

#Include ..\Lib\ActionMutex.ahk
#Include ..\Lib\HiResTimer.ahk

class DragoncallMutex extends ActionMutex {
    ; 业务状态
    isSFirst := true
    thisFrameAct := 0

    ; 技能保护时长
    openSleepTime      := 300
    soulflareSleepTime := 1000
    leechSleepTime     := 800
    xSleepTime         := 800

    sleepDurationsMap := Map()


    static Init(){
        this.sleepMap.Set(1, "Open")
        this.sleepMap.Set(2, "SoulFlare")
        this.sleepMap.Set(3, "Leech")
        this.sleepMap.Set(5, "X")
    }


    GetSleepDurations(){
        if(this.sleepDurationsMap.Capacity != 0)
            return this.sleepDurationsMap
        this.sleepDurationsMap.Set(1, this.openSleepTime)
        this.sleepDurationsMap.Set(2, this.soulflareSleepTime)
        this.sleepDurationsMap.Set(3, this.leechSleepTime)
        this.sleepDurationsMap.Set(5, this.xSleepTime)
        return this.sleepDurationsMap
    }

    ; ----- 实现抽象接口 -----
    BeginFrame() {
        this.thisFrameAct := 0
    }

    CanExecute(action) {
        this.IsInSleep()   ; 清理过期
        for item in this.sleepQueue {
            sType := item.type
            expire := item.expire


            if(sType == 1){ ; open
                return false
            }else if(sType == 2){ ; soulflare
                if(action == 1){
                    return true
                } else if(action == 2){ ; 这里onexecuted对重复的操作进行合并操作，取两者之差的70%
                    return true
                } else if(action == 3){
                    if(HiResTimer.GetTick() >= HiResTimer.SubMs(800, expire)){
                        return true
                    }else {
                        return false
                    }
                } else if(action == 4 || action == 5){
                    return false
                } else {
                    return false
                }
            } else if(sType == 3){
                if(action == 2){
                    return true
                }else{
                    return false
                }
            } else if(sType == 5){
                return false
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

        if (action == 2) {
            this.SetSleep(2, this.soulflareSleepTime * 0.999)
        } else if (action == 3) {
            this.SetSleep(3, this.leechSleepTime * 0.90)
        } else if (action == 5) {
            this.SetSleep(1, this.openSleepTime)
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