#Requires AutoHotkey v2.0

#Include HiResTimer.ahk
#Include KeyLogger.ahk

class PerformanceMonitor {
    static enabled := false
    static records := Map()
    static timers  := Map()

    static monitorCpu     := false
    static monitorMem     := false
    static sampleTimer    := 0
    static cpuSamples     := []
    static memSamples     := []
    static lastCpuKernel  := 0
    static lastCpuUser    := 0
    static lastSampleTick := 0

    static reportTimer    := 0
    static reportInterval := 1   ; 分钟，0 = 禁用

    static archiveQueue   := []  ; 存放每分钟的完整报告文本
    static archiveRecords := []  ; 存放每分钟 records 的快照，用于归档报告

    static slowThresholdUs := 10000   ; 慢执行阈值（微秒）
    static slowLogEnabled  := true    ; 是否启用慢日志

    ; ---------- 初始化 ----------
    static Init(enable, enableCpu := false, enableMem := false, reportInterval := 1) {
        this.enabled    := enable
        this.monitorCpu := enableCpu
        this.monitorMem := enableMem
        this.reportInterval := reportInterval
        if this.enabled {
            this.Reset()
            this.archiveQueue := []
            this.archiveRecords := []
        }
        if (this.enabled && (this.monitorCpu || this.monitorMem))
            this.StartResourceSampling()
        else
            this.StopResourceSampling()
        if (this.enabled && this.reportInterval > 0) {
            this.reportTimer := SetTimer(ObjBindMethod(this, "FlushSnapshot"), this.reportInterval * 60000)
        }
    }

    ; ---------- 资源采样（不变） ----------
    static StartResourceSampling() {
        this.lastCpuKernel  := 0
        this.lastCpuUser    := 0
        this.lastSampleTick := HiResTimer.GetTick()
        this.sampleTimer    := SetTimer(ObjBindMethod(this, "SampleResources"), 1000)
    }
    static StopResourceSampling() {
        if this.sampleTimer {
            SetTimer(this.sampleTimer, 0)
            this.sampleTimer := 0
        }
    }
    static SampleResources() {
        hProcess := DllCall("GetCurrentProcess", "Ptr")
        if this.monitorMem {
            pmc := Buffer(72, 0)
            NumPut("UInt", 72, pmc, 0)
            if DllCall("K32GetProcessMemoryInfo", "Ptr", hProcess, "Ptr", pmc, "UInt", 72) {
                memBytes := NumGet(pmc, 16, "UInt64")
                memMb    := Round(memBytes / 1048576, 2)
                this.memSamples.Push(memMb)
            }
        }
        if this.monitorCpu {
            ftCreation := 0, ftExit := 0, kernelTime := 0, userTime := 0
            if DllCall("GetProcessTimes", "Ptr", hProcess,
                       "Int64*", &ftCreation, "Int64*", &ftExit,
                       "Int64*", &kernelTime, "Int64*", &userTime) {
                totalCpu := kernelTime + userTime
                if (this.lastCpuKernel > 0) {
                    deltaCpu := totalCpu - (this.lastCpuKernel + this.lastCpuUser)
                    deltaTime := (HiResTimer.GetTick() - this.lastSampleTick) / HiResTimer.freq * 1000.0
                    if deltaTime > 0 {
                        cpuPercent := Min(100, Max(0, deltaCpu / 10000.0 / deltaTime * 100))
                        this.cpuSamples.Push(Round(cpuPercent, 1))
                    }
                }
                this.lastCpuKernel := kernelTime
                this.lastCpuUser   := userTime
                this.lastSampleTick := HiResTimer.GetTick()
            }
        }
    }

    ; ---------- 重置临时统计（保留归档数据和资源基准） ----------
    static Reset() {
        this.records := Map()
        this.timers  := Map()
        this.cpuSamples := []
        this.memSamples := []
    }

    ; ---------- 阶段计时 ----------
    static Start(stage) {
        if !this.enabled
            return
        this.timers[stage] := HiResTimer.GetTick()
    }
    static End(stage, params := "") {
        if !this.enabled
            return
        if !this.timers.Has(stage)
            return
        startTick := this.timers.Delete(stage)
        elapsedUs := HiResTimer.DeltaUs(startTick, HiResTimer.GetTick())
        if !this.records.Has(stage)
            this.records[stage] := {count: 0, total: 0.0, min: 1e9, max: 0}
        rec := this.records[stage]
        rec.count += 1
        rec.total += elapsedUs
        if (elapsedUs < rec.min)
            rec.min := elapsedUs
        if (elapsedUs > rec.max)
            rec.max := elapsedUs


        ; 慢执行检测
        if (this.slowLogEnabled && this.slowThresholdUs > 0 && elapsedUs >= this.slowThresholdUs) {
            msg := Format("{} [SLOW] {} took {} us", HiResTimer.NowBeijing() , stage, elapsedUs)
            if (params != "")
                msg .= Format(", params: {}", params)
            Log.Write(msg)
        }
    }

    ; ---------- 每分钟快照：生成报告 + 保存 records 快照 ----------
    static FlushSnapshot() {
        if !this.enabled
            return
        if this.records.Count == 0 && this.cpuSamples.Length == 0 && this.memSamples.Length == 0
            return

        dir := A_ScriptDir "\log\Performance"
        if !DirExist(dir)
            DirCreate(dir)
        filePath := Format("{1}\{2}.txt", dir, Format("{:04d}-{:02d}-{:02d}", A_Year, A_Mon, A_DD))

        ; 生成当前周期的完整表格（临时模式）
        report := this.Report("temp")
        this.archiveQueue.Push(report)

        try FileAppend(report, filePath)

        ; 深拷贝当前 records 作为快照保存
        snapshot := this._DeepCopyRecords(this.records)
        this.archiveRecords.Push(snapshot)

        this.Reset()   ; 清空临时数据
    }

    ; 内部辅助：深拷贝 records Map（含子 Map）
    static _DeepCopyRecords(src) {
        copy := Map()
        for stage, rec in src
            copy[stage] := {count: rec.count, total: rec.total, min: rec.min, max: rec.max}
        return copy
    }

    ; ---------- 退出时落盘 ----------
    static DumpReport() {
        if !this.enabled
            return
        this.FlushSnapshot()

        dir := A_ScriptDir "\log\Performance\Archive"
        if !DirExist(dir)
            DirCreate(dir)
        archivePath := Format("{}\archive_{}.txt", dir, Format("{:04d}-{:02d}-{:02d}", A_Year, A_Mon, A_DD))

        s := ""
        ; for i, report in this.archiveQueue {
        ;     s .= report
        ;     if i < this.archiveQueue.Length
        ;         s .= "`n`n"
        ; }
        this.archiveQueue := []

        ; 追加一份总归档报告（合并所有快照）
        totalReport := this.Report("archive")
        s .= "`n--- Total Archive Summary ---`n" . totalReport
        s .= "`n[Exit]`n"

        try FileAppend(s, archivePath)
        OutputDebug "PerformanceMonitor: all reports archived."
    }

    ; ---------- 生成报告：支持 mode = "temp" | "archive" ----------
    static Report(mode := "temp") {
        if !this.enabled
            return "PerformanceMonitor disabled"

        records := (mode == "archive") ? this._MergeArchiveRecords() : this.records

        s := "`n========== Performance Report ==========`n"
        s .= "Generated at " HiResTimer.NowBeijing() "`n"

        s .= "+--------------------------------+--------+------------+------------+------------+`n"
        s .= "| Stage                          |  Count |   Avg (us) |   Min (us) |   Max (us) |`n"
        s .= "+--------------------------------+--------+------------+------------+------------+`n"

        sorted := []
        for stage, rec in records
            sorted.Push({stage: stage, count: rec.count, avg: rec.total / rec.count, min: rec.min, max: rec.max})
        ; 冒泡降序
        Loop sorted.Length - 1 {
            i := A_Index
            Loop sorted.Length - i {
                j := A_Index
                if sorted[j].max < sorted[j + 1].max {
                    tmp := sorted[j]
                    sorted[j] := sorted[j + 1]
                    sorted[j + 1] := tmp
                }
            }
        }

        for item in sorted {
            row := Format("| {1:-30s} | {2:6d} | {3:10.1f} | {4:10.1f} | {5:10.1f} |",
                        item.stage, item.count, item.avg, item.min, item.max)
            s .= row "`n"
        }

        s .= "+--------------------------------+--------+------------+------------+------------+`n"

        if (this.monitorCpu && this.cpuSamples.Length > 0) {
            avgCpu := 0.0
            for val in this.cpuSamples
                avgCpu += val
            avgCpu := avgCpu / this.cpuSamples.Length
            s .= "`n--- System Resources ---`n"
            s .= Format("Avg CPU Usage: {1:.1f}%   (sampled {2} times)`n", avgCpu, this.cpuSamples.Length)
        }
        if (this.monitorMem && this.memSamples.Length > 0) {
            avgMem := 0.0, minMem := 999999.0, maxMem := 0.0
            for val in this.memSamples {
                avgMem += val
                if val < minMem
                    minMem := val
                if val > maxMem
                    maxMem := val
            }
            avgMem := avgMem / this.memSamples.Length
            s .= Format("Memory (MB):  Avg {1:.1f}   Min {2:.1f}   Max {3:.1f}   (sampled {4} times)`n",
                        avgMem, minMem, maxMem, this.memSamples.Length)
        }
        s .= "==========================================`n"
        return s
    }

    ; 合并所有归档快照为一个总 records
    static _MergeArchiveRecords() {
        merged := Map()
        for snapshot in this.archiveRecords {
            for stage, rec in snapshot {
                if merged.Has(stage) {
                    m := merged[stage]
                    m.count += rec.count
                    m.total += rec.total
                    if rec.min < m.min
                        m.min := rec.min
                    if rec.max > m.max
                        m.max := rec.max
                } else {
                    merged[stage] := {count: rec.count, total: rec.total, min: rec.min, max: rec.max}
                }
            }
        }
        return merged
    }
}