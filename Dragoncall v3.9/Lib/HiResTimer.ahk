#Requires AutoHotkey v2.0

class HiResTimer {
    static freq := 0, isInitialized := false
    static baseTick := 0         ; 初始化时的 QPC
    static baseFileTime := 0     ; 对应的 UTC FILETIME (100ns 单位)
    
    static Init() {
        if this.isInitialized
            return
        DllCall("QueryPerformanceFrequency", "Int64*", &freq := 0)
        DllCall("QueryPerformanceCounter", "Int64*", &baseTick := 0)
        this.baseTick := baseTick
        DllCall("GetSystemTimeAsFileTime", "Int64*", &ft := 0)
        this.baseFileTime := ft
        this.freq := freq
        this.isInitialized := true
    }
    static GetTick() {
        if !this.isInitialized
            throw Error("HiResTimer 未初始化")
        DllCall("QueryPerformanceCounter", "Int64*", &tick := 0)
        return tick
    }
    static DeltaMs(start, end) => Round((end - start) * 1000.0 / this.freq, 2)
    static DeltaUs(start, end) => Round((end - start) * 1000000.0 / this.freq, 2)
    static AddMs(ms, startTick?) {
        if !IsSet(startTick)
            startTick := this.GetTick()
        return startTick + Round(ms * this.freq / 1000)
    }
    static SubMs(ms, startTick?) => this.AddMs(-ms, startTick?)

    static Now() {
        if !this.isInitialized
            throw Error("HiResTimer 未初始化")
        DllCall("QueryPerformanceCounter", "Int64*", &curTick := 0)
        elapsed := curTick - this.baseTick
        elapsed100ns := Round(elapsed * 10000000 / this.freq)
        ft := this.baseFileTime + elapsed100ns

        st := Buffer(16, 0)
        DllCall("FileTimeToSystemTime", "Int64*", &ft, "Ptr", st)
        wYear   := NumGet(st, 0, "UShort")
        wMonth  := NumGet(st, 2, "UShort")
        wDay    := NumGet(st, 6, "UShort")
        wHour   := NumGet(st, 8, "UShort")
        wMinute := NumGet(st, 10, "UShort")
        wSecond := NumGet(st, 12, "UShort")
        wMS     := NumGet(st, 14, "UShort")

        return Format("{:02d}/{:02d} {:02d}:{:02d}:{:02d}:{:03d}",
                    wMonth, wDay, wHour, wMinute, wSecond, wMS)
    }


    ; 返回 UTC+8 时间字符串：月/日 时:分:秒:毫秒
    static NowBeijing() {
        if !this.isInitialized
            throw Error("HiResTimer 未初始化")
        DllCall("QueryPerformanceCounter", "Int64*", &curTick := 0)
        elapsed := curTick - this.baseTick
        elapsed100ns := Round(elapsed * 10000000 / this.freq)
        ; 基准时间 (UTC) + 已过时间 + 8 小时偏移
        ft := this.baseFileTime + elapsed100ns + 8 * 3600 * 10000000  ; 8h in 100ns

        st := Buffer(16, 0)
        DllCall("FileTimeToSystemTime", "Int64*", &ft, "Ptr", st)
        wMonth  := NumGet(st, 2, "UShort")
        wDay    := NumGet(st, 6, "UShort")
        wHour   := NumGet(st, 8, "UShort")
        wMinute := NumGet(st, 10, "UShort")
        wSecond := NumGet(st, 12, "UShort")
        wMS     := NumGet(st, 14, "UShort")
        return Format("{:02d}/{:02d} {:02d}:{:02d}:{:02d}:{:03d}",
                      wMonth, wDay, wHour, wMinute, wSecond, wMS)
    }

    

}