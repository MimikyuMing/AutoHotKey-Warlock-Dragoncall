#Include HiResTimer.ahk

class ActionMutex {
    sleepQueue := []  ; 睡眠队列 {type, expire}
    static sleepMap := Map()

    ; ----- 抽象业务接口（子类必须覆盖）-----
    BeginFrame() => Error("ActionMutex: Must override BeginFrame()", -1)
    CanExecute(action) => Error("ActionMutex: Must override CanExecute()", -1)
    OnExecuted(action) => Error("ActionMutex: Must override OnExecuted()", -1)

    ; ----- 睡眠队列基础操作 -----
    SetSleep(type, durationMs) {
        PerformanceMonitor.Start("ActionMutex-SetSleep")
        ; --- 去重：已存在同类型则直接返回（保留首次） ---
        for item in this.sleepQueue {
            if item.type == type {
                PerformanceMonitor.End("ActionMutex-SetSleep")
                return
            }
        }
        ; --- 正常插入 ---
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
        PerformanceMonitor.End("ActionMutex-SetSleep")
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

    static Init(){

    }

    HasSleepType(type) {
        this.IsInSleep()  ; 先清理过期睡眠
        for item in this.sleepQueue {
            if item.type == type
                return true
        }
        return false
    }

    ; 获取指定类型的睡眠剩余时间（微秒），若不存在则返回 0
    GetSleepRemainingUs(type) {
        this.IsInSleep()  ; 清理过期
        now := HiResTimer.GetTick()
        for item in this.sleepQueue {
            if item.type == type {
                ; 计算剩余计数（QPC 单位），转为微秒
                remaining := item.expire - now
                if remaining > 0
                    return Round(remaining * 1000000.0 / HiResTimer.freq)
                else
                    return 0
            }
        }
        return 0
    }

    ; 取出并移除指定类型的第一个睡眠项，返回 {type, expire}，若不存在则返回 false
    PopSleep(type) {
        this.IsInSleep()  ; 清理过期
        for i, item in this.sleepQueue {
            if item.type == type {
                this.sleepQueue.RemoveAt(i)
                return item
            }
        }
        return false
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


    ; 返回当前所有未过期睡眠项的数据数组（每项包含 type, expire, remainingUs）
    GetAllSleeps() {
        this.IsInSleep()  ; 先清理过期项
        result := []
        now := HiResTimer.GetTick()
        for item in this.sleepQueue {
            remaining := item.expire - now
            result.Push({
                type: item.type,
                expire: item.expire,
                remainingUs: Round(remaining * 1000000.0 / HiResTimer.freq)
            })
        }
        return result
    }

    ; 返回易读的睡眠状态字符串，用于日志或调试
    GetSleepInfoStr() {
        this.IsInSleep()
        if this.sleepQueue.Length == 0
            return "No active sleeps"
        str := ""
        for item in this.sleepQueue {
            remainingMs := HiResTimer.DeltaMs(HiResTimer.GetTick(), item.expire)
            str .= Format("Type{}: {}ms | ", item.type, remainingMs)
        }
        return SubStr(str, 1, -3)  ; 去掉末尾的 " | "
    }


    GetSleepDurations() {
        return Map()   ; 基类返回空，子类负责提供具体值
    }


    ; 返回当前所有睡眠的表格（自动包含全部项）
    ; @param typeNames 可选，类型编号→名称的映射
    GetSleepTable(sleepMap, typeNames?) {
        this.IsInSleep()  ; 清理过期
        if this.sleepQueue.Length == 0
            return "SleepQueue: empty"

        ; 尝试获取时长映射（如果子类提供了）
        durations := this.GetSleepDurations()
        ; 如果子类未提供，尝试从实例自身获取（兼容实例方法）
        if durations.Capacity == 0 && HasMethod(this, "GetSleepDurations")
            durations := this.GetSleepDurations()

        s := "+------------+----------------+----------------+----------------+`n"
        s .= "|    Type    |   totalMs(ms)  |  Remaining(ms) |  Remaining(%)  |`n"
        s .= "+------------+----------------+----------------+----------------+`n"

        now := HiResTimer.GetTick()
        for item in this.sleepQueue {
            ; 类型名称
            typeName := IsSet(typeNames) && typeNames.Has(item.type)
                      ? typeNames[item.type]
                      : sleepMap.Get(item.type)

            ; 剩余时间（毫秒）
            remainingMs := HiResTimer.DeltaMs(now, item.expire)
            if remainingMs < 0
                remainingMs := 0

            ; 原始总时长（毫秒）
            totalMs := durations.Has(item.type) ? durations[item.type] : 1000
            pct := Min(100, Max(0, remainingMs * 100 / totalMs))

            s .= Format("| {1:-10s} | {2:14.1f} | {3:14.1f} | {4:14.1f} |`n",
                        SubStr(typeName, 1, 10),
                        totalMs,
                        remainingMs,
                        pct)
        }

        s .= "+------------+----------------+----------------+----------------+`n"
        return s
    }


    ; 合并睡眠：若同类型已存在，将新时长按比例叠加到现有过期时间上；否则新建
    ; scale: 叠加系数（0~1），例如 0.85 表示新时长仅取 85% 延长
    MergeSleep(type, durationMs, scale := 1) {
        this.IsInSleep()  ; 清理过期
        now := HiResTimer.GetTick()
        extraQpc := Round(durationMs * scale * HiResTimer.freq / 1000)  ; 延长的 QPC 计数

        for i, item in this.sleepQueue {
            if item.type == type {
                ; 计算新的过期时间（原过期 + 延长量）
                newExpire := item.expire + extraQpc
                ; 防止意外：如果延长后仍小于当前时间，就用当前时间 + 完整新时长
                if newExpire <= now {
                    newExpire := now + Round(durationMs * HiResTimer.freq / 1000)
                }
                ; 移除旧项，重新插入以保持排序
                this.sleepQueue.RemoveAt(i)
                this._InsertSleepByExpire(type, newExpire)
                return
            }
        }
        ; 不存在同类型，直接新建
        this.SetSleep(type, durationMs)
    }

    ; 内部辅助：按过期时间升序插入一项（QPC 单位）
    _InsertSleepByExpire(type, expireQpc) {
        inserted := false
        for i, item in this.sleepQueue {
            if expireQpc < item.expire {
                this.sleepQueue.InsertAt(i, {type: type, expire: expireQpc})
                inserted := true
                break
            }
        }
        if !inserted
            this.sleepQueue.Push({type: type, expire: expireQpc})
    }
}