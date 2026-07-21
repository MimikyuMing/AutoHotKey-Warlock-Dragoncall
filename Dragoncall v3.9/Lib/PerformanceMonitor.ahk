#Requires AutoHotkey v2.0

#Include HiResTimer.ahk
#Include KeyLogger.ahk

; Lib\PerformanceMonitor.ahk
class PerformanceMonitor {
    static enabled := false
    static records := Map()
    static timers  := Map()

    ; ---------- 资源监控专用 ----------
    static monitorCpu     := false        ; 是否监控 CPU
    static monitorMem     := false        ; 是否监控内存
    static sampleTimer    := 0            ; 采样定时器句柄
    static cpuSamples     := []           ; 存储每次采样的 CPU 使用率 (%)
    static memSamples     := []           ; 存储每次采样的内存 (MB)
    static lastCpuKernel  := 0            ; 上次的 CPU 内核时间 (100ns)
    static lastCpuUser    := 0            ; 上次的 CPU 用户时间
    static lastSampleTick := 0            ; 上次采样的 QPC 时刻

    static reportTimer := 0            ; 定期报告定时器
    static reportInterval := 0         ; 分钟，0=关闭

    ; ---------- 初始化 ----------
    static Init(enable, enableCpu := false, enableMem := false, reportInterval:= 0) {
        this.enabled    := enable
        this.monitorCpu := enableCpu
        this.monitorMem := enableMem
        this.reportInterval := reportInterval
        if this.enabled
            this.Reset()
        ; 只有总开关和至少一个子开关为真时才启动采样
        if (this.enabled && (this.monitorCpu || this.monitorMem))
            this.StartResourceSampling()
        else
            this.StopResourceSampling()

        ; 启动定期报告定时器（如果间隔>0）
        if (this.enabled && this.reportInterval > 0) {
            this.reportTimer := SetTimer(ObjBindMethod(this, "LogSnapshot"), this.reportInterval * 1000 * 60)
        }
    }

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

    ; ---------- 定时采样系统资源 ----------
    static SampleResources() {
        hProcess := DllCall("GetCurrentProcess", "Ptr")

        ; 内存：工作集大小 (字节 → MB)
        if this.monitorMem {
            pmc := Buffer(72, 0)  ; PROCESS_MEMORY_COUNTERS_EX
            NumPut("UInt", 72, pmc, 0)
            if DllCall("K32GetProcessMemoryInfo", "Ptr", hProcess, "Ptr", pmc, "UInt", 72) {
                memBytes := NumGet(pmc, 16, "UInt64")  ; WorkingSetSize 偏移 16
                memMb    := Round(memBytes / 1048576, 2)
                this.memSamples.Push(memMb)
            }
        }

        ; CPU：计算自上次采样以来的平均使用率
        if this.monitorCpu {
            ; 获取进程时间（Kernel + User，单位 100ns）
            ftCreation := 0, ftExit := 0
            kernelTime := 0, userTime := 0
            if DllCall("GetProcessTimes", "Ptr", hProcess,
                       "Int64*", &ftCreation, "Int64*", &ftExit,
                       "Int64*", &kernelTime, "Int64*", &userTime) {
                totalCpu := kernelTime + userTime
                if (this.lastCpuKernel > 0) {   ; 不是第一次采样
                    deltaCpu := totalCpu - (this.lastCpuKernel + this.lastCpuUser)
                    deltaTime := (HiResTimer.GetTick() - this.lastSampleTick) / HiResTimer.freq * 1000.0   ; 实际经过的毫秒
                    if deltaTime > 0 {
                        ; CPU 使用率 = (CPU时间增量 / 实际时间增量) * 100
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

    ; ---------- 原有方法不变 ----------
    static Reset() {
        this.records := Map()
        this.timers  := Map()
        this.cpuSamples := []
        this.memSamples := []
    }

    static Start(stage) {
        if !this.enabled
            return
        this.timers[stage] := HiResTimer.GetTick()
    }
    static End(stage) {
        if !this.enabled
            return
        startTick := this.timers.Delete(stage)
        if !IsSet(startTick)
            return
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
    }

    ; ---------- 报告增强 ----------
    static Report() {
        if !this.enabled
        return "PerformanceMonitor disabled"

        s := "`n========== Performance Report ==========`n"

        s .= "Generated at " HiResTimer.NowBeijing() "`n"

        s .= "+----------------------+--------+------------+------------+------------+`n"
        s .= "| Stage                |  Count |   Avg (us) |   Min (us) |   Max (us) |`n"
        s .= "+----------------------+--------+------------+------------+------------+`n"

        for stage, rec in this.records {
            avg := rec.count > 0 ? rec.total / rec.count : 0
            row := Format("| {1:-20s} | {2:6d} | {3:10.1f} | {4:10.1f} | {5:10.1f} |",
                        stage, rec.count, avg, rec.min, rec.max)
            s .= row "`n"
        }

        s .= "+----------------------+--------+------------+------------+------------+`n"

        ; 资源统计
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

    static DumpReport() {
        if !this.enabled
            return
        report := this.Report()

        ; 按日期存放到 log\Performance 文件夹
        dir := A_ScriptDir "\log\Performance"
        if !DirExist(dir)
            DirCreate(dir)
        filePath := Format("{1}\{2}.txt", dir, Format("{:04d}-{:02d}-{:02d}", A_Year, A_Mon, A_DD))

        FileAppend(report, filePath)
        OutputDebug(report)
        KeyLogger.WriteLog(HiResTimer.GetTick(), report)
    }


    ; 追加一条当前统计快照到文件（紧凑格式，每分钟一行）
    static LogSnapshot() {
        if !this.enabled
            return

        ; 确保目录存在
        dir := A_ScriptDir "\log\Performance"
        if !DirExist(dir)
            DirCreate(dir)
        filePath := Format("{1}\{2}.txt", dir, Format("{:04d}-{:02d}-{:02d}", A_Year, A_Mon, A_DD))

        ; 收集各阶段的平均耗时
        
        report := this.Report()

        ; 写入一行：时间戳 + 各阶段平均耗时
        line := Format("[{1}] {2}`n", HiResTimer.NowBeijing(), report)
        try FileAppend(line, filePath)
    }
}