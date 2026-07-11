#Requires AutoHotkey v2.0
; ================================================
; Dragoncall-Combine.ahk - 模块化重构版
; ================================================
CoordMode "ToolTip", "Screen"

; ==================== 1. 管理员权限 ====================
if !A_IsAdmin {
    try Run '*RunAs "' A_ScriptFullPath '"'
    ExitApp
}

; ==================== 2. 资源释放与路径 ====================
FileInstall "dll\CaptureDXGI.dll", A_Temp "\CaptureDXGI.dll", 1
FileInstall "dll\CaptureConfig.dll", A_Temp "\CaptureConfig.dll", 1
FileInstall "dll\CaptureLogic.dll", A_Temp "\CaptureLogic.dll", 1
FileInstall "config.ini", A_Temp "\config.ini", 1

global INI := FileExist(A_AppData "\Dragoncall\config.ini") ? A_AppData "\Dragoncall\config.ini" : A_Temp "\config.ini"
IniManager.iniPath := INI

; ==================== 3. 全局常量 ====================
global GAME_FRAME := 60
global FRAME_MS := Floor(1000 / GAME_FRAME)
global DETECT_INTERVAL := Floor(FRAME_MS * 0.30)
global LOGIC_INTERVAL := Floor(FRAME_MS * 0.15)
global SYS_STANDBY := 0, SYS_ACTIVE := 1
global g_SysState := SYS_STANDBY

; ==================== 4. 工具类定义（无依赖） ====================
global LOG_FILE := A_ScriptDir "\KeyLog.txt"    ; 日志路径
global ONLY_INJECTED := true                    ; true=仅记录模拟按键, false=记录所有
global MAX_QUEUE_SIZE := 500                     ; 队列达到该数量立即写入
global FLUSH_INTERVAL := 1000 
; -----------操作日志写入-----------
class KeyLogger {
    static WH_KEYBOARD_LL := 13
    static WM_KEYDOWN   := 0x100
    static WM_SYSKEYDOWN := 0x104
    static LLKHF_INJECTED := 0x10

    static hHook := 0
    static callback := 0
    static queue := []           ; 批量缓冲
    static flushTimer := 0       ; 冲刷定时器句柄

    ; 启动时改为使用“空闲冲刷”而非固定定时器（更符合“无输入时写入”）
    static Start() {
        try FileDelete(LOG_FILE)

        ; catch {
        ;     ; 文件被占用，自动重命名为 .old 并创建新文件
        ;     newName := SubStr(LOG_FILE, 1, -4) . "_old.txt"
        ;     FileMove(LOG_FILE, newName)
        ; }

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

    ; 核心：添加一条日志（可用于钩子或外部调用）
    static AppendLog(entry) {
        this.queue.Push(entry)
        ; 达到阈值立即冲刷
        if (this.queue.Length >= MAX_QUEUE_SIZE)
            this.Flush()
        ; 每次新条目都重置空闲冲刷定时器（无输入 FLUSH_INTERVAL 毫秒后自动冲刷）
        else
            this.ResetIdleFlush()
    }

    ; 空闲冲刷定时器重置
    static ResetIdleFlush() {
        static timer := 0  ; 局部静态变量存储最后一次定时器对象
        if timer
            SetTimer(timer, 0)  ; 取消旧定时器
        timer := SetTimer(ObjBindMethod(KeyLogger, "Flush"), -FLUSH_INTERVAL)
    }

    ; 外部调用接口：传入绝对 tick 和消息文本
    static WriteLog(tick, msg) {
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
        for entry in tmp
            s .= entry
        ; 尝试写入，最多重试 5 次，每次间隔 30ms
        Loop 5 {
            try {
                FileAppend(s, LOG_FILE)
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


; ---------- HiResTimer ----------
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

}

; ---------- StateManager ----------
class StateManager {
    static _buffState := Map()
    static _skillState := Map()
    static _focusState := Map()
    static GetBuffState() => this._buffState
    static GetSkillState() => this._skillState
    static GetFocusState() => this._focusState
    static GetBuffTrueCount() {
        c := 0
        for _, v in this._buffState
            if v
                c++
        return c
    }
}

class ActionMutex {
    ; 睡眠队列：每一项 {type, expire}，按 expire 升序
    sleepQueue := []
    
    isSFirst := false
    thisFrameAct := 0
    
    openSleepTime      := 300
    soulflareSleepTime := 1000
    leechSleepTime     := 800
    xSleepTime         := 1000

    BeginFrame() {
        this.thisFrameAct := 0
    }

    ; ---------- 睡眠队列操作 ----------
    ; 添加一个睡眠
    SetSleep(type, durationMs) {
        expire := HiResTimer.AddMs(durationMs)
        ; 按过期时间升序插入（队列很短，直接扫）
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

    ; 释放指定类型的睡眠（不传 type 则清空全部）
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

    ; 清理过期项，返回是否仍有未过期睡眠
    IsInSleep() {
        now := HiResTimer.GetTick()
        while this.sleepQueue.Length > 0 && this.sleepQueue[1].expire <= now
            this.sleepQueue.RemoveAt(1)
        return this.sleepQueue.Length > 0
    }

    ; 获取当前最高优先级（最早过期）的睡眠类型（0 表示无）
    CurrentSleepType() {
        if this.sleepQueue.Length == 0
            return 0
        ; 确保第一个项未过期（IsInSleep 已清理）
        return this.sleepQueue[1].type
    }

    ; 获取当前最高优先级睡眠的过期时间（仅当队列非空时有效）
    CurrentSleepExpire() {
        if this.sleepQueue.Length == 0
            return 0
        return this.sleepQueue[1].expire
    }

    ; ---------- 权限检查（只改造 Sleep 部分） ----------
    CanExecute(action) {
        ; 先清理过期睡眠
        this.IsInSleep()

        ; 遍历所有活跃睡眠，任何一条限制不通过则拒绝
        for item in this.sleepQueue {
            sType := item.type
            expire := item.expire

            switch sType {
                case 1: ; Open Sleep
                    return false
                case 2: ; Soulflare Sleep
                    if (this.isSFirst) {
                        if (action == 3 && HiResTimer.GetTick() < HiResTimer.SubMs(800, expire))
                            return false
                        if (action != 1 && action != 3)
                            return false
                    } else {
                        ; 原始逻辑：isSFirst 为 false 时全部放行
                        return true
                    }
                case 3: ; Leech Sleep
                    if (action != 2)
                        return false
                case 4: ; Gold Leech 首次延迟
                    ; 原始逻辑：允许非2动作，对 action==2 按 isSFirst 限制
                    if (action != 2)
                        return true
                    if (action == 2 && this.isSFirst)
                        return false
                    ; action==2 且 !isSFirst 时继续（不返回 false，等后续判断）
                case 5: ; X 
                    return false
                default:
                    return false
            }
        }

        ; ---- 以下原有 S_first 与帧内互斥，完全不动 ----
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

    ; 保留辅助方法
    GetStateToStr() {
        ; 简单打印队列信息
        s := "SleepQueue: "
        for item in this.sleepQueue
            s .= Format("[t{1} @{2}] ", item.type, item.expire)
        return Format("IsSFirst: {1}, FrameAct: {2}, {3}", this.isSFirst, this.thisFrameAct, s)
    }
    MarkSFirst() {
        this.isSFirst := true
    }
}



; ---------- Log ----------
class Log {
    static queue := []
    static Init() {
        SetTimer(ObjBindMethod(Log, "Flush"), 100)
    }
    static Write(msg) {
        this.queue.Push(Format("[{1}] {2}", A_Now, msg))
    }
    static Flush() {
        if this.queue.Length == 0
            return
        q := this.queue
        this.queue := []
        s := ""
        for msg in q
            s .= msg . "`n"
        fileName := Format("log_{1}.txt", A_YYYY A_MM A_DD)
        FileAppend s, A_ScriptDir "\" fileName
    }
}

; ---------- IniManager ----------
class IniManager {
    static iniPath := ""
    static ReadToMap(section) {
        m := Map()
        if !FileExist(this.iniPath)
            return m
        keysStr := IniRead(this.iniPath, section, , "")
        if keysStr = ""
            return m
        for line in StrSplit(keysStr, "`n", "`r") {
            line := Trim(line)
            if line = ""
                continue
            parts := StrSplit(line, "=", , 2)
            if parts.Length < 2
                continue
            m[Trim(parts[1])] := Trim(parts[2])
        }
        return m
    }
    static ReadSplitToMap(section, delimiter := ",") {
        m := Map()
        if !FileExist(this.iniPath)
            return m
        keysStr := IniRead(this.iniPath, section, , "")
        if keysStr = ""
            return m
        for line in StrSplit(keysStr, "`n", "`r") {
            line := Trim(line)
            if line = ""
                continue
            parts := StrSplit(line, "=", , 2)
            if parts.Length < 2
                continue
            k := Trim(parts[1]), v := Trim(parts[2])
            arr := StrSplit(v, delimiter)
            cleaned := []
            for item in arr {
                item := Trim(item)
                if item != ""
                    cleaned.Push(item)
            }
            m[k] := cleaned
        }
        return m
    }
    static Write(section, key, value) {
        IniWrite(value, this.iniPath, section, key)
    }
    static WriteMap(section, map) {
        for k, v in map
            this.Write(section, k, v)
    }
}

; ==================== 5. 捕获引擎（检测模块，可整体注释） ====================
class CaptureEngine {
    static pView := 0
    static hDll := 0
    static hMap := 0
    static pStopCapture := 0
    static frameId := 0
    static g_CurrentFocus := -1
    static g_LastUpdateStateTime := 0
    static skillNames := [], skillIdx := Map()
    static buffNames := [], buffIdx := Map()
    static DetectTimer := 0

    static Start() {
        DLL := A_Temp "\CaptureLogic.dll"
        this.hDll := DllCall("LoadLibrary", "Str", DLL, "Ptr")
        if !this.hDll {
            MsgBox "无法加载 CaptureLogic.dll"
            ExitApp
        }
        res := DllCall("CaptureLogic.dll\StartCapture", "Str", INI, "CDecl Int")
        if this.hDll
            this.pStopCapture := DllCall("GetProcAddress", "Ptr", this.hDll, "AStr", "StopCapture", "Ptr")
        if !res {
            MsgBox "StartCapture 失败"
            ExitApp
        }
        this.hMap := DllCall("OpenFileMapping", "UInt", 4, "Int", 0, "Str", "Local\DragoncallState")
        if !this.hMap {
            MsgBox "共享内存打开失败"
            ExitApp
        }
        this.pView := DllCall("MapViewOfFile", "Ptr", this.hMap, "UInt", 4, "UInt", 0, "UInt", 0, "UInt", 0)
        ; 加载技能名
        sc := DllCall("CaptureLogic.dll\GetSkillCount", "CDecl Int")
        loop sc {
            ptr := DllCall("CaptureLogic.dll\GetSkillName", "Int", A_Index - 1, "CDecl Ptr")
            name := StrGet(ptr, "UTF-8")
            this.skillNames.Push(name)
            this.skillIdx[name] := A_Index - 1
        }
        ; 加载buff名
        bc := DllCall("CaptureLogic.dll\GetBuffCount", "CDecl Int")
        loop bc {
            ptr := DllCall("CaptureLogic.dll\GetBuffName", "Int", A_Index - 1, "CDecl Ptr")
            name := StrGet(ptr, "UTF-8")
            this.buffNames.Push(name)
            this.buffIdx[name] := A_Index - 1
        }
        ; 启动状态更新定时器
        this.DetectTimer := SetTimer(ObjBindMethod(CaptureEngine, "UpdateState"), DETECT_INTERVAL)
    }

    static UpdateState() {
        ; 最小堆处理（独立于捕获逻辑）
        if (!this.pView)
            return
        start := HiResTimer.GetTick()
        this.frameId := NumGet(this.pView, 0, "UInt")
        focus := NumGet(this.pView, 12, "Int")
        sc := NumGet(this.pView, 16, "UInt")
        bc := NumGet(this.pView, 20, "UInt")
        for name, idx in this.skillIdx {
            state := (idx < sc) ? NumGet(this.pView, 24 + idx, "UChar") : 0
            StateManager._skillState[name] := state
        }
        buffOff := 24 + sc
        for name, idx in this.buffIdx {
            state := (idx < bc) ? NumGet(this.pView, buffOff + idx, "UChar") : 0
            StateManager._buffState[name] := state
        }
        this.g_CurrentFocus := focus
        StateManager._focusState.currentLevel := focus

        ; S_first 闲置重置逻辑
        static logicOffStart := 0
        if (!LogicEngine.g_LogicEnabled) {
            if (logicOffStart == 0)
                logicOffStart := HiResTimer.GetTick()
            else if (HiResTimer.SubMs(5000, HiResTimer.GetTick()) > logicOffStart) {
                logicOffStart := 0
                LogicEngine.g_Mutex.MarkSFirst()
            }
            LogicEngine.startLogic := HiResTimer.GetTick()
        } else {
            logicOffStart := 0
        }
        this.g_LastUpdateStateTime := HiResTimer.DeltaMs(start, HiResTimer.GetTick())
    }

    static Cleanup() {
        try {
            if (this.pStopCapture && this.hDll)
                DllCall(this.pStopCapture, "CDecl")
        } catch {

        }
        try {
            if (this.pView)
                DllCall("UnmapViewOfFile", "Ptr", this.pView)
        } catch {

        }
        try {
            if (this.hMap)
                DllCall("CloseHandle", "Ptr", this.hMap)
        } catch {

        }
        try {
            if (this.hDll)
                DllCall("FreeLibrary", "Ptr", this.hDll)
        } catch {

        }
    }
}

; ==================== 6. 逻辑引擎 ====================
class LogicEngine {
    static g_LogicEnabled := false
    static g_LogicTimerPending := false
    static g_Mutex := ActionMutex()
    static g_skillCooldownMs := Map("Dragoncall_R", 2500, "Wingstorm_R", 2000)
    static startLogic := 0
    static lastFrameId := 0
    static g_LastLogicTimeUs := 0
    static g_Gold_Wingstorm := false
    static g_Gold_Open := false
    static g_AutoSoulFlare := false
    static g_isUseLeechHasLeechBuff := false
    static g_limitationOpen := false     
    static g_limitationLeech := false   
    static g_Gold_Leech := false
    static WRITELOG := false
    static FrameCount := 5
    static delayTab := 0
    static g_LastExecutionTick := 0 
    static lastUsedOpen := -1

    static ScheduleNextLogic() {
        if (!this.g_LogicEnabled || this.g_LogicTimerPending)
            return
        this.g_LogicTimerPending := true
        SetTimer ObjBindMethod(LogicEngine, "LogicExecuter"), -LOGIC_INTERVAL
    }

    static LogicExecuter() {
        if (!this.g_LogicEnabled || !GetKeyState("XButton2", "P")) {
            this.g_LogicEnabled := false
            SetTimer ObjBindMethod(LogicEngine, "LogicExecuter"), 0
            ; this.g_Mutex.ReleaseSleep()
            this.g_LogicTimerPending := false
            return
        }

        if (HiResTimer.GetTick() - this.g_LastExecutionTick < LOGIC_INTERVAL * 0.9)   ; 单位需一致，这里假设 tick 是计数
            return

        static isRunning := false
        if isRunning
            return
        isRunning := true
        try {
            this.MainLogic()
        } finally {
            this.g_LastExecutionTick := HiResTimer.GetTick()
            isRunning := false
            this.g_LogicTimerPending := false
        }
        if this.g_LogicEnabled
            this.ScheduleNextLogic()
    }

    static MainLogic() {
        start := HiResTimer.GetTick()
        static lastUsedBombardment := -1
        static lastUsedLeech := -1
        static lastUsedD := -1
        static lastUsedW := -1
        ; 帧级幂等
        if (this.lastFrameId == CaptureEngine.frameId)
            return
        this.lastFrameId := CaptureEngine.frameId
        try {
            this.g_Mutex.BeginFrame()
            hasSoulFlareBuff := StateManager._buffState.Get("SoulFlare", false)
            hasLeechBuff := StateManager._buffState.Get("Leech", false)

            if (this.g_Mutex.IsInSleep()) {
                if(this.HandleSleepState()){
                    return
                }
            }

            ; Action5 : Open
            OpenReady := StateManager._skillState.Get("Open_R", false)
            

            openDragonState := this.g_limitationOpen
                ? StateManager._skillState.Get("Dragoncall_L", false) && !StateManager._skillState.Get("Dragoncall_R", false) && !StateManager._skillState.Get("Dragoncall_Mid", false)
                : true
            local BombardmentPreInput := 200
            local LeechDisableWindow := 800 + 750 ; 1400 ms 0.8s前摇 + 0.75s 禁用期
            ; 伏压下 -1s 暴击 -1s total = 1 + C(48.98% + 24%) * 1 ≈ 1.7298s (C为暴击率)
            ; 超神下 -3s total = 3 
            local OpenTiming := 3000 ; 最大窗口期

            open_condition := this.g_Gold_Open && OpenReady && hasLeechBuff && openDragonState && ((BombardmentPreInput >= HiResTimer.DeltaMs(lastUsedBombardment, HiResTimer.GetTick())) || (LeechDisableWindow >= HiResTimer.DeltaMs(lastUsedLeech, HiResTimer.GetTick()))) && (OpenTiming >= HiResTimer.DeltaMs(lastUsedLeech, HiResTimer.GetTick()))
            if (this.g_Mutex.CanExecute(5) && open_condition) {
                SendInput "3"
                this.g_Mutex.OnExecuted(5)
                ; this.writeLogEvent("3", start)
                this.lastUsedOpen := HiResTimer.GetTick()
                return
            }

            

            ; Action2 - Soulflare
            soulFlareReady := this.g_AutoSoulFlare && StateManager._skillState.Get("SoulFlare", false)
            delaySoulFlare := this.g_Gold_Leech
            if (this.g_Mutex.CanExecute(2) && soulFlareReady) {
                if(delaySoulFlare){
                    if(this.g_Mutex.isSFirst && this.delayTab == 0){
                        ; ToolTip "????" , 0 , 0
                        this.delayTab := SetTimer(() => 
                            this.DelaySendTab()
                        , -2000)
                    }
                }else
                    this.DelaySendTab()
            }

            ; Action1 : Dragoncall & Wingstorm
            wingstormReady := this.g_Gold_Wingstorm
                ? StateManager._skillState.Get("Gold_Wingstorm_R", false)
                : StateManager._skillState.Get("Wingstorm_R", false)
            dragoncallReady := StateManager._skillState.Get("Dragoncall_R", false)
            local D_Limit := 300
            local LeechAfterBanWingstorm := 800 + 350
            local OpenAfterBanWingstorm := 600
            local allow_use_W := 
                D_Limit <= HiResTimer.DeltaMs(lastUsedD, HiResTimer.GetTick()) && 
                (
                    LeechAfterBanWingstorm <= HiResTimer.DeltaMs(lastUsedLeech, HiResTimer.GetTick()) 
                && 
                    OpenAfterBanWingstorm <= HiResTimer.DeltaMs(this.lastUsedOpen, HiResTimer.GetTick())
                )  ; 掠夺之后0.8(前摇) + 0.35s内不能用,以保证首次使用必须是暴魔灵,并且开门使用后的0.6s内不能用,以确保首次使用的是暴魔灵
            if (this.g_Mutex.CanExecute(1)) {
                if (dragoncallReady) {
                    SendInput "4"
                    this.g_Mutex.OnExecuted(1)
                    this.writeLogEvent("4", start)
                    lastUsedD := HiResTimer.GetTick()
                } else if (wingstormReady && allow_use_W) {
                    SendInput "v"
                    this.g_Mutex.OnExecuted(1)
                    this.writeLogEvent("v", start)
                    lastUsedW := HiResTimer.GetTick()
                }
            }

            ; Action3 : Leech
            preLeech := StateManager._skillState.Get("Leech_Dark_L", false) || StateManager._skillState.Get("Leech_L", false) ; 改成Leech Dark的RGB
            LeechReady := StateManager._skillState.Get("Leech_R", false)
            leech_condition := this.g_limitationLeech
                ? StateManager._skillState.Get("Dragoncall_L", false) && !StateManager._skillState.Get("Dragoncall_R", false) && !StateManager._skillState.Get("Dragoncall_Mid", false)
                : true
            allowLeech := false
            if (this.g_Mutex.CanExecute(3) && preLeech) {
                if (hasSoulFlareBuff) {
                    if (!hasLeechBuff)
                        allowLeech := true
                } else if (!hasSoulFlareBuff) {
                    if (!hasLeechBuff)
                        allowLeech := true
                    else if (this.g_isUseLeechHasLeechBuff && leech_condition)
                        allowLeech := true
                }
                if (allowLeech) {
                    if (LeechReady) {
                        SendInput "f"
                        lastUsedLeech := HiResTimer.GetTick()
                        this.g_Mutex.OnExecuted(3)
                        this.writeLogEvent("f", start)
                    } else {
                        return
                    }
                }
            }

            ; Action4 - Mantra/Rupture/Bombardment
            if (this.g_Mutex.CanExecute(4)) {
                MantraReady := CaptureEngine.g_CurrentFocus <= (hasSoulFlareBuff ? 2 : (hasLeechBuff ? 4 : 5)) && StateManager._skillState.Get("Mantra_L", false)
                RuptureReady := CaptureEngine.g_CurrentFocus <= (hasSoulFlareBuff ? 1 : (hasLeechBuff ? 4 : 4)) && StateManager._skillState.Get("Rupture_L", false)
                BombardmentReady := StateManager._skillState.Get("RealBombardment_R", false) || StateManager._skillState.Get("Bombardment_R", false)
                BombardmentReady := true
                if (MantraReady) {
                    SendInput "r"
                    this.g_Mutex.OnExecuted(4)
                    this.writeLogEvent("r", start)
                } else if (RuptureReady) {
                    SendInput "f"
                    this.g_Mutex.OnExecuted(4)
                    this.writeLogEvent("f", start)
                } else if (BombardmentReady) { 
                    SendInput "t"
                    this.g_Mutex.OnExecuted(4)
                    this.writeLogEvent("t", start)
                    lastUsedBombardment := HiResTimer.GetTick()
                }
            }
        } finally {
            ; ToolTip this.g_Mutex.CurrentSleepType() , 0 , 0
            this.g_LastLogicTimeUs := HiResTimer.DeltaMs(start, HiResTimer.GetTick())
        }
    }

    static DelaySendTab(){
        if (this.g_Mutex.CanExecute(2) && this.g_AutoSoulFlare && StateManager._skillState.Get("SoulFlare", false)) {
            SendInput "{tab}"
            this.g_Mutex.OnExecuted(2)
            this.writeLogEvent("tab", HiResTimer.GetTick())
        }
        this.g_Mutex.isSFirst := false
        this.delayTab := 0
    }

    static HandleSleepState() {
        if (this.g_Mutex.CurrentSleepType() == 1) { ; Open Sleep
            OpenReady := StateManager._skillState.Get("Open_R", false)
            openBlackReady := this.g_Gold_Open && !StateManager._skillState.Get("Open_Black", false) && !OpenReady
            expire := this.g_Mutex.CurrentSleepExpire()   ; 取当前 Open 的过期时间
            if (OpenReady) {
                MaxOvertime := Floor(this.g_Mutex.openSleepTime * (1/3))
                if (MaxOvertime <= HiResTimer.DeltaMs(expire, HiResTimer.GetTick())) {
                    msg := "[Open-Ready] Overtime! curOvertime: " HiResTimer.DeltaMs(expire, HiResTimer.GetTick()) " curtimestamp:" HiResTimer.GetTick()
                    KeyLogger.WriteLog(HiResTimer.GetTick(), msg)
                    this.lastUsedOpen := -1 ; 物理使用失败,移除限制
                    this.g_Mutex.ReleaseSleep(1)           ; 只释放 Open 睡眠
                    OutputDebug "Open多帧判断均在亮起,说明没有物理按下," HiResTimer.Now()
                    return false
                } else if (this.g_Mutex.IsInSleep()) {
                    msg := "[Open-Ready] Sleeping! curtimestamp:" HiResTimer.GetTick()
                    KeyLogger.WriteLog(HiResTimer.GetTick(), msg)
                    OutputDebug "Open多帧判断是否亮起中,正在sleep," HiResTimer.Now()
                    return true
                }
                msg := "[Open-Ready] Error! curtimestamp:" HiResTimer.GetTick()
                KeyLogger.WriteLog(HiResTimer.GetTick(), msg)
                OutputDebug "Open多帧判断异常错误!!!!," HiResTimer.Now()
                return false
            } else if (openBlackReady) {
                if (this.g_Mutex.IsInSleep()) {
                    msg := "[Open-Blank] Sleeping! curtimestamp:" HiResTimer.GetTick()
                    KeyLogger.WriteLog(HiResTimer.GetTick(), msg)
                    OutputDebug "Open物理按下/GCD空转中,正在sleep," HiResTimer.Now()
                    return true
                } else {
                    msg := "[Open-Ready] Don't Sleep!Releasing! curtimestamp:" HiResTimer.GetTick()
                    KeyLogger.WriteLog(HiResTimer.GetTick(), msg)
                    this.g_Mutex.ReleaseSleep(1)           ; 只释放 Open 睡眠
                    OutputDebug "Open物理按下/GCD空转中,不处于Sleep,释放Sleep条件," HiResTimer.Now()
                    return false
                }
            } else {
                msg := "[Open] OpenReadyNotExist And OpenBlankNotExist Releasing! curtimestamp:" HiResTimer.GetTick()
                KeyLogger.WriteLog(HiResTimer.GetTick(), msg)
                OutputDebug "均读取不到Open亮起/暗淡状态!!!!," HiResTimer.Now()
                ; 不释放睡眠，保持阻塞等待下一帧
                this.lastUsedOpen := -1 ; 异常状态,移除限制
                return true
            }
        } else if (this.g_Mutex.CurrentSleepType() == 2) { ; Soulflare Sleep
            msg := "[Soulflare] Soulflare Sleep! curtimestamp:" HiResTimer.GetTick()
            KeyLogger.WriteLog(HiResTimer.GetTick(), msg)
            OutputDebug "超神睡眠状态中," HiResTimer.Now()
            return true
        } else if (this.g_Mutex.CurrentSleepType() == 3) { ; Leech Sleep
            msg := "[Leech] Leech Sleep! curtimestamp:" HiResTimer.GetTick()
            KeyLogger.WriteLog(HiResTimer.GetTick(), msg)
            OutputDebug "掠夺睡眠状态中," HiResTimer.Now()
            return true
        } 
        else if(this.g_Mutex.CurrentSleepType() == 5){ ; X Sleep
            msg := "[X] X Sleep! curtimestamp:" HiResTimer.GetTick()
            KeyLogger.WriteLog(HiResTimer.GetTick(), msg)
            OutputDebug "X睡眠状态中," HiResTimer.Now()
            return true
        }
        else {
            msg := "[Unknown] Unknown sleep type! Release Data! curtimestamp:" HiResTimer.GetTick()
            KeyLogger.WriteLog(HiResTimer.GetTick(), msg)
            this.g_Mutex.ReleaseSleep()                   ; 未知类型直接清空，确保安全
            OutputDebug "未知异常," HiResTimer.Now()
            return false
        }
    }

    static writeLogEvent(str, start) {
        if (!this.WRITELOG)
            return
        if (this.g_Mutex.thisFrameAct != 0)
            Log.Write("[MainLogic] curFrame:" CaptureEngine.frameId " keybroad:" str " action:" this.g_Mutex.thisFrameAct "," Round(HiResTimer.DeltaMs(this.startLogic, start), 2) " ms")
    }
}

; ==================== 7. 应用入口与热键 ====================
class App {
    static Init() {
        HiResTimer.Init()
        Log.Init()
        this.LoadSettings()
        CaptureEngine.Start()
        ; this.BindHotkeys()
        this.CreateTray()
        KeyLogger.Start()
        OnExit App.Cleanup
    }

    static LoadSettings() {
        settings := IniManager.ReadToMap("Settings")
        LogicEngine.g_Gold_Wingstorm := ParseBool(settings.Has("Gold_Wingstorm") ? settings["Gold_Wingstorm"] : false)
        LogicEngine.g_Gold_Open := ParseBool(settings.Has("Gold_Open") ? settings["Gold_Open"] : false)
        LogicEngine.g_AutoSoulFlare := ParseBool(settings.Has("AutoSoulFlare") ? settings["AutoSoulFlare"] : false)
        LogicEngine.g_isUseLeechHasLeechBuff := ParseBool(settings.Has("isUseLeechHasLeechBuff") ? settings["isUseLeechHasLeechBuff"] : false)
        LogicEngine.g_Gold_Leech := ParseBool(settings.Has("Gold_Leech") ? settings["Gold_Leech"] : false)
        LogicEngine.g_limitationOpen := ParseBool(settings.Has("LimitationOpen") ? settings["LimitationOpen"] : false)
        LogicEngine.g_limitationLeech := ParseBool(settings.Has("LimitationLeech") ? settings["LimitationLeech"] : false)
    }

    static CreateTray() {
        A_TrayMenu.Delete()
        A_TrayMenu.Add("设置", ShowSettingsGUI)
        A_TrayMenu.Add("退出", (*) => ExitApp())
        A_TrayMenu.Default := "设置"
    }

    static Cleanup(*) {
        CaptureEngine.Cleanup()
        Log.Flush()
        ToolTip "Cleanup completed", 0, 0
    }
}


; 侧键按下启动逻辑
$*XButton2:: {
    if LogicEngine.g_LogicEnabled
        return
    LogicEngine.g_LogicEnabled := true
    LogicEngine.ScheduleNextLogic()
}
; 侧键松开停止逻辑
$*XButton2 Up:: {
    LogicEngine.g_LogicEnabled := false
    SetTimer ObjBindMethod(LogicEngine, "LogicExecuter"), 0
    LogicEngine.g_Mutex.ReleaseSleep()
    LogicEngine.g_LogicTimerPending := false
}
; 鼠标侧键1模拟组合键
$*XButton1:: SendInput '^{Numpad9}'

~$X::{
    ; MsgBox "HELLO WORLD"
    LogicEngine.g_Mutex.SetSleep(5, LogicEngine.g_Mutex.xSleepTime)
}

F11:: {
    App.Cleanup()
    Reload
}

; ==================== 8. GUI（保持原有风格） ====================
ShowSettingsGUI(*) {
    global _settingsGui
    try _settingsGui.Destroy()
    _settingsGui := Gui("", "技能自动化设置")
    _settingsGui.OnEvent("Close", (*) => _settingsGui.Destroy())
    _settingsGui.Add("Checkbox", "vGold_Wingstorm", "金 死灵突袭").Value := LogicEngine.g_Gold_Wingstorm
    _settingsGui["Gold_Wingstorm"].OnEvent("Click", SaveSettingImmediate)
    _settingsGui.Add("Checkbox", "vGold_Open", "金 開門").Value := LogicEngine.g_Gold_Open
    _settingsGui["Gold_Open"].OnEvent("Click", SaveSettingImmediate)
    _settingsGui.Add("Checkbox", "vAutoSoulFlare", "自动释放超神").Value := LogicEngine.g_AutoSoulFlare
    _settingsGui["AutoSoulFlare"].OnEvent("Click", SaveSettingImmediate)
    _settingsGui.Add("Checkbox", "vIsUseLeechHasLeechBuff", "有掠夺Buff时仍可释放掠夺").Value := LogicEngine.g_isUseLeechHasLeechBuff
    
    _settingsGui.Add("Checkbox", "vLimitationLeech", "掠夺是否啟用限制釋放").Value := LogicEngine.g_limitationLeech
    _settingsGui["LimitationLeech"].OnEvent("Click", SaveSettingImmediate)


    _settingsGui.Add("Checkbox", "vLimitationOpen", "開門是否啟用限制釋放").Value := LogicEngine.g_limitationOpen
    _settingsGui["LimitationOpen"].OnEvent("Click", SaveSettingImmediate)


    _settingsGui.Add("Checkbox", "vGold_Leech", "金 掠夺").Value := LogicEngine.g_Gold_Leech
    _settingsGui["Gold_Leech"].OnEvent("Click", SaveSettingImmediate)  

    _settingsGui.Add("Button", "y+10", "关闭").OnEvent("Click", (*) => _settingsGui.Destroy())
    _settingsGui.Show()
}

SaveSettingImmediate(*) {
    global _settingsGui
    LogicEngine.g_Gold_Wingstorm := _settingsGui["Gold_Wingstorm"].Value
    LogicEngine.g_Gold_Open := _settingsGui["Gold_Open"].Value
    LogicEngine.g_AutoSoulFlare := _settingsGui["AutoSoulFlare"].Value
    LogicEngine.g_isUseLeechHasLeechBuff := _settingsGui["IsUseLeechHasLeechBuff"].Value
    LogicEngine.g_Gold_Leech := _settingsGui["Gold_Leech"].Value
    LogicEngine.g_limitationOpen := _settingsGui["LimitationOpen"].Value
    LogicEngine.g_limitationLeech := _settingsGui["LimitationLeech"].Value
    SaveSettingsToFile()
}

SaveSettingsToFile() {
    if !FileExist(A_AppData "\Dragoncall\config.ini") {
        DirCreate(A_AppData "\Dragoncall")
        FileCopy INI, A_AppData "\Dragoncall\config.ini", 1
    }
    IniWrite(LogicEngine.g_Gold_Wingstorm, A_AppData "\Dragoncall\config.ini", "Settings", "Gold_Wingstorm")
    IniWrite(LogicEngine.g_Gold_Open, A_AppData "\Dragoncall\config.ini", "Settings", "Gold_Open")
    IniWrite(LogicEngine.g_AutoSoulFlare, A_AppData "\Dragoncall\config.ini", "Settings", "AutoSoulFlare")
    IniWrite(LogicEngine.g_isUseLeechHasLeechBuff, A_AppData "\Dragoncall\config.ini", "Settings", "isUseLeechHasLeechBuff")
    IniWrite(LogicEngine.g_Gold_Leech, A_AppData "\Dragoncall\config.ini", "Settings", "Gold_Leech")
    IniWrite(LogicEngine.g_limitationOpen, A_AppData "\Dragoncall\config.ini", "Settings", "LimitationOpen")
    IniWrite(LogicEngine.g_limitationLeech, A_AppData "\Dragoncall\config.ini", "Settings", "LimitationLeech")
}

ParseBool(str) {
    if !IsSet(str) || str = ""
        return false
    str := StrLower(Trim(str))
    if str = "true" or str = "yes" or str = "1" or str = "on" or str = "enable"
        return true
    if str = "false" or str = "no" or str = "0" or str = "off" or str = "disable"
        return false
    try
        return Integer(str) != 0
    catch
        return false
}

; ==================== 9. 启动 ====================
App.Init()
Persistent


/**
 * 2026/7/8 12:39
 * SkillName Usage% Count TotalDamage 
 * Dragoncall 50% 16 16117108 
 * Bombardment 33% 37 10788790
 * Wingstorm 15% 18 4994915
 * 
 * 
 * 50/33 = 1.5151515151515151
 * 
 * 
 * 
 * 
 */