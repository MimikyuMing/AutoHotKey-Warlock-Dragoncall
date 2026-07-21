#Include HiResTimer.ahk

class ActionMutex {
    sleepQueue := []  ; 睡眠队列 {type, expire}

    ; ----- 抽象业务接口（子类必须覆盖）-----
    BeginFrame() => Error("ActionMutex: Must override BeginFrame()", -1)
    CanExecute(action) => Error("ActionMutex: Must override CanExecute()", -1)
    OnExecuted(action) => Error("ActionMutex: Must override OnExecuted()", -1)

    ; ----- 睡眠队列基础操作 -----
    SetSleep(type, durationMs) {
        expire := HiResTimer.AddMs(durationMs)
        inserted := false
        for i, item in this.sleepQueue {
            if (expire < item.expire) {
                this.sleepQueue.InsertAt(i, {type: type, expire: expire})
                inserted := true
                break
            }
        }
        if (!inserted)
            this.sleepQueue.Push({type: type, expire: expire})
    }

    ReleaseSleep(type?) {
        if !IsSet(type) {
            this.sleepQueue := []
            return
        }
        i := this.sleepQueue.Length
        while (i > 0) {
            if this.sleepQueue[i].type == type
                this.sleepQueue.RemoveAt(i)
            i--
        }
    }

    IsInSleep() {
        now := HiResTimer.GetTick()
        while this.sleepQueue.Length > 0 && this.sleepQueue[1].expire <= now
            this.sleepQueue.RemoveAt(1)
        return this.sleepQueue.Length > 0
    }

    CurrentSleepType() {
        return this.sleepQueue.Length ? this.sleepQueue[1].type : 0
    }

    CurrentSleepExpire() {
        return this.sleepQueue.Length ? this.sleepQueue[1].expire : 0
    }
}