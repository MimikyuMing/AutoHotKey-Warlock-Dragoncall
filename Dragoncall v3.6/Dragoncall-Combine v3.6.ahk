#Requires AutoHotkey v2.0
; ================================================
; Dragoncall-Combine.ahk - 重构版（基于 C++ DLL 架构）
; ================================================
CoordMode "ToolTip", "Screen"

; ==================== 1. 管理员权限请求 ====================
if !A_IsAdmin {
    try Run '*RunAs "' A_ScriptFullPath '"'
    ExitApp
}

; ==================== 2. 嵌入资源与路径设定 ====================
FileInstall "dll\CaptureDXGI.dll", A_Temp "\CaptureDXGI.dll", 1
FileInstall "dll\CaptureConfig.dll", A_Temp "\CaptureConfig.dll", 1
FileInstall "dll\CaptureLogic.dll", A_Temp "\CaptureLogic.dll", 1
FileInstall "config.ini", A_Temp "\config.ini", 1

DLL := A_Temp "\CaptureLogic.dll"

; 配置文件路径策略
global userIniPath := A_AppData "\Dragoncall\config.ini"
global INI := FileExist(userIniPath) ? userIniPath : A_Temp "\config.ini"

; ==================== 3. 全局常量与系统状态 ====================
global GAME_FRAME := 60
global frameMs := Floor(1000 / GAME_FRAME) ; 16ms
global DETECT_INTERVAL := Floor(frameMs * 0.60) ; 2ms
global LOGIC_INTERVAL := Floor(frameMs * 0.15) ; 2ms
global SYS_STANDBY := 0, SYS_ACTIVE := 1
global g_SysState := SYS_STANDBY
global g_Mutex := ActionMutex()

; ==================== 4. 核心类定义 ====================

class ActionMutex {
    ; -- 内部状态 --
    sleepType := 0          ; 0=无, 1=OpenSleep, 2=SoulflareSleep, 3- Leech Sleep
    sleepExpire := 0          ; Sleep 超时时间戳
    isSFirst := false      ; 是否处于 Soulflare 首次触发后的限制期
    sFirstReset := 0          ; S_first 闲置重置计时
    thisFrameAct := 0          ; 本帧已执行的 Action (1-5, 0=无)
    openSleepTime := 300
    soulflareSleepTime := 1000
    leechSleepTime := 0

    /***
     * 
     *         Action1: D, W（互斥）
     * 
     *         Action2: S
     * 
     *         Action3: L
     * 
     *         Action4: M, R, B（互斥）
     * 
     *         Action5: O
     * 
     */

    ; 每帧开始，重置帧内 Action 记录
    BeginFrame() {
        this.thisFrameAct := 0
    }

    ; 检查指定 Action 是否允许执行
    CanExecute(action) {
        ; ---- 1. Sleep 全局阻塞 ----
        if (this.sleepType != 0 && HiResTimer.GetTick() < this.sleepExpire) {
            ; Soulflare Sleep 期间，只放行 Action1(D/W) 和 Action3(L)
            if (this.sleepType == 2) {

                if (action == 3 && HiResTimer.GetTick() < HiResTimer.SubMs(800, this.sleepExpire)) {
                    return false
                }

                return (action == 1 || action == 3)
            }
            if(this.sleepType == 3) ; Leech Sleep
                return (action == 2)
            ; Open Sleep 期间，全部阻塞
            return false
        }

        ; ---- 2. S_first 特殊限制 ----
        if (this.isSFirst && action == 2) {
            ; S 首次释放时，禁止 Action4(M/R/B) 和 Action5(O)（需要另一帧检查）
            ; 注：此条件针对 S 释放那一帧，之后的限制由后续检查处理
            if (action == 4 || action == 5) {
                return false
            }
        }

        ; ---- 3. 帧内互斥 ----
        prev := this.thisFrameAct
        if (prev == 0)
            return true

        ; Action2(S) 非首次时可与其他共存
        if (action == 2 && !this.isSFirst)
            return true
        if (prev == 2 && !this.isSFirst)
            return true

        ; Action5(O) 全互斥
        if (action == 5 || prev == 5)
            return false

        ; Action3(L)：与除 Action2 外的所有 Action 互斥，但 prev==1 时例外
        if (action == 3 && prev != 2 && prev != 1)    ; ← 新增 prev != 1
            return false
        if (prev == 3 && action != 2)
            return false

        ; Action1(D/W) 在 prev == 3/1 时互斥
        if (action == 1 && prev == 3)
            return false
        if (action == 1 && prev == 1)
            return false
        ; prev == 1 时，仅禁止 Action5(O)
        if (prev == 1 && action == 5)
            return false

        ; Action4(M/R/B) 与 Action3、Action5 互斥
        if (action == 4 && (prev == 3 || prev == 5))
            return false
        if (prev == 4 && (action == 3 || action == 5))
            return false

        return true
    }

    ; 标记 Action 已执行，处理副作用
    OnExecuted(action) {
        this.thisFrameAct := action

        if (action == 2 && this.isSFirst) {
            ; S 首次释放，解除首次限制，触发 Soulflare Sleep
            this.isSFirst := false
            this.SetSleep(2, this.soulflareSleepTime * 0.999)
        }else if(action == 3){
            this.SetSleep(3, this.leechSleepTime)
        }
        else if (action == 5) {
            ; O 释放，触发 Open Sleep
            this.SetSleep(1, this.openSleepTime)
        } else if (this.isSFirst && action != 1) {
            this.isSFirst := false
        }
    }

    ; ---- Sleep 管理 ----
    SetSleep(type, durationMs) {
        this.sleepType := type
        this.sleepExpire := HiResTimer.AddMs(durationMs)
    }

    IsInSleep() {
        local res := this.sleepType != 0 && HiResTimer.GetTick() < this.sleepExpire
        if (!res) {
            ; reset sleep type
            this.sleepType := 0
        }
        return res

    }

    ReleaseSleep() {
        this.sleepType := 0
        this.sleepExpire := 0
    }

    ; ---- S_first 管理 ----
    MarkSFirst() {
        this.isSFirst := true
    }

}

; ==================== 高性能异步日志 ====================
global g_LogQueue := Array()            ; 消息队列
SetTimer FlushLogs, 100            ; 每 100ms 批量写入

; 投递日志（主逻辑调用，非阻塞）
LogToFile(msg) {
    g_LogQueue.Push(Format("[{1}] {2}", A_Now, msg))
}

; 消费者：批量写入磁盘
FlushLogs(*) {
    global g_LogQueue
    if (g_LogQueue.Length == 0)
        return

    ; 取出当前所有消息
    local q := g_LogQueue
    g_LogQueue := []                ; 清空队列（微秒级，无需锁）

    ; 拼接为一个大字符串
    local s := ""
    for msg in q
        s .= msg . "`n"

    ; 按日期分文件，避免单文件过大
    local fileName := Format("log_{1}.txt", A_YYYY A_MM A_DD)

    ; 一次性写入
    FileAppend s, A_ScriptDir "\" fileName
}

; 立即写入（用于关键错误，一般不用）
LogToFileImmediate(msg) {
    LogToFile(msg)
    FlushLogs()
}

class StateManager
{
    static _buffState := Map()
    static _skillState := Map()
    static _focusState := Map()

    static InitBuff(baseKeys) {
        this._buffState.Clear()
        for key in baseKeys
            this._buffState[key] := false
    }
    static InitSkill(keys) {
        this._skillState.Clear()
        for key in keys
            this._skillState[key] := false
    }
    static InitFocus(keys) {
        this._focusState.Clear()
        for key in keys
            this._focusState[key] := false
    }
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

class MinHeap {
    heap := []
    lastPush := Map()   ; 记录每个技能名称的最后一次 push 时间戳 (A_TickCount)

    static less(a, b) => a.timestamp < b.timestamp
    static swap(arr, i, j) {
        tmp := arr[i]
        arr[i] := arr[j]
        arr[j] := tmp
    }
    static siftUp(arr, idx) {
        while idx > 1 {
            parent := idx >> 1
            if this.less(arr[idx], arr[parent]) {
                this.swap(arr, idx, parent)
                idx := parent
            } else break
        }
    }
    static siftDown(arr, idx) {
        len := arr.Length
        while true {
            left := idx << 1
            right := left + 1
            smallest := idx
            if left <= len && this.less(arr[left], arr[smallest])
                smallest := left
            if right <= len && this.less(arr[right], arr[smallest])
                smallest := right
            if smallest == idx
                break
            this.swap(arr, idx, smallest)
            idx := smallest
        }
    }
    size() => this.heap.Length
    peek() {
        if this.heap.Length == 0
            return -1
        return this.heap[1]
    }
    ; 新增带冷却的 push 方法
    ; cooldownMs：同名技能多少毫秒内无法重复添加（0 表示无限制）
    push(item, cooldownMs := 0) {
        if (cooldownMs > 0) {
            now := A_TickCount
            lastTime := this.lastPush.Get(item.skillname, 0)
            if (now - lastTime < cooldownMs)
                return false   ; 还在冷却中，不添加
            this.lastPush[item.skillname] := now
        }
        this.heap.Push(item)
        MinHeap.siftUp(this.heap, this.heap.Length)
        return true
    }
    pop() {
        if this.heap.Length == 0
            return
        minItem := this.heap[1]
        if this.heap.Length > 1 {
            this.heap[1] := this.heap.Pop()
            MinHeap.siftDown(this.heap, 1)
        } else this.heap.Pop()
        return minItem
    }
    buildFromArray(arr) {
        this.heap := arr.Clone()
        i := this.heap.Length >> 1
        while i >= 1 {
            MinHeap.siftDown(this.heap, i)
            i--
        }
    }

    ; 批量添加多段事件，支持同名冷却
    ; cooldownMs：同名技能多少毫秒内无法重复调用 pushBatch
    pushBatch(items, cooldownMs := 0) {
        if (cooldownMs > 0 && items.Length > 0) {
            now := A_TickCount
            skillname := items[1].skillname    ; 取第一个元素的技能名作为标识
            lastTime := this.lastPush.Get(skillname, 0)
            if (now - lastTime < cooldownMs)
                return false                    ; 冷却中，不添加
            this.lastPush[skillname] := now     ; 更新冷却
        }
        for item in items {
            this.heap.Push(item)
            MinHeap.siftUp(this.heap, this.heap.Length)
        }
        return true
    }

    ToString() {
        if this.heap.Length == 0
            return "Heap: empty"
        s := "Heap: "
        for item in this.heap
            s .= item.skillname ":" HiResTimer.DeltaMs(HiResTimer.GetTick(), item.timestamp) " | "
        return SubStr(s, 1, -3)   ; 去掉末尾的 " | "
    }

    toArray() => this.heap.Clone()


}

class IniManager
{
    static iniPath := ""   ; 启动时动态赋值
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
            k := Trim(parts[1])
            v := Trim(parts[2])
            m[k] := v
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
            k := Trim(parts[1])
            v := Trim(parts[2])
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

class HiResTimer
{
    static freq := 0
    static isInitialized := false
    static Init() {
        if this.isInitialized
            return
        DllCall("QueryPerformanceFrequency", "Int64*", &freq := 0)
        this.freq := freq
        this.isInitialized := true
    }
    static GetTick() {
        if !this.isInitialized
            throw Error("HiResTimer 未初始化")
        DllCall("QueryPerformanceCounter", "Int64*", &tick := 0)
        return tick
    }
    static DeltaMs(start, end) {
        return Round((end - start) * 1000.0 / this.freq, 2)
    }
    static DeltaUs(start, end) {
        return Round((end - start) * 1000000.0 / this.freq, 2)
    }
    static AddMs(ms, startTick?) {
        if !IsSet(startTick)
            startTick := this.GetTick()
        offset := Round(ms * this.freq / 1000)
        return startTick + offset
    }
    static SubMs(ms, startTick?) {
        return this.AddMs(-ms, startTick?)
    }
}

; ==================== 5. 全局变量与配置参数 ====================
global g_SoulFlareStartTick := 0
global g_CurrentFocus := -1
global g_LogicEnabled := false
global g_LogicTimerFunc := 0
global g_DetectTimer := 0
global isDebug := false
global g_LastLogicTimeUs := 0
global g_LastUpdateStateTime := 0

; 技能冷却堆与配置
global g_skillHeap := MinHeap()
global g_skillCooldownMs := Map(
    "Dragoncall_R", 2500,
    "Wingstorm_R", 2000,
)

; 设置参数（从INI读取）
global g_Gold_Wingstorm := false
global g_Gold_Open := false
global g_AutoSoulFlare := false
global g_isUseLeechHasLeechBuff := false
global TNoUsedLimit := false
global settings := Map()

; GUI 与托盘
global _settingsGui := 0

; 状态管理快捷引用（在 StateManager 类之后创建）
global _buffState := StateManager.GetBuffState()
global _skillState := StateManager.GetSkillState()

global pStopCapture := 0
global frameId := 0
global isMinHeap := false
global FrameCount := 5

global startLogic := 0


; ==================== 6. 初始化配置与时间模块 ====================
IniManager.iniPath := INI
HiResTimer.Init()

InitSettings() {
    global g_Gold_Wingstorm, g_Gold_Open, g_AutoSoulFlare
    global g_isUseLeechHasLeechBuff, TNoUsedLimit, settings, isDebug
    settings := IniManager.ReadToMap("Settings")
    g_Gold_Wingstorm := ParseBool(settings.Has("Gold_Wingstorm") ? settings["Gold_Wingstorm"] : false)
    g_Gold_Open := ParseBool(settings.Has("Gold_Open") ? settings["Gold_Open"] : false)
    g_AutoSoulFlare := ParseBool(settings.Has("AutoSoulFlare") ? settings["AutoSoulFlare"] : false)
    g_isUseLeechHasLeechBuff := ParseBool(settings.Has("isUseLeechHasLeechBuff") ? settings["isUseLeechHasLeechBuff"] : false)
    TNoUsedLimit := ParseBool(settings.Has("TNoUsedLimit") ? settings["TNoUsedLimit"] : true)
    isDebug := ParseBool(settings.Has("isDebug") ? settings["isDebug"] : false)
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

InitSettings()
ShowSettingsGUI()

; ==================== 7. 加载 DLL 并启动捕获 ====================
hDll := DllCall("LoadLibrary", "Str", DLL, "Ptr")
if !hDll {
    MsgBox "无法加载 CaptureLogic.dll"
    ExitApp
}

res := DllCall("CaptureLogic.dll\StartCapture", "Str", INI, "CDecl Int")
if (hDll) {
    pStopCapture := DllCall("GetProcAddress", "Ptr", hDll, "AStr", "StopCapture", "Ptr")
}
if !res {
    MsgBox "StartCapture 失败，请检查 INI 和权限。"
    ExitApp
}

hMap := DllCall("OpenFileMapping", "UInt", 4, "Int", 0, "Str", "Local\DragoncallState")
if !hMap {
    MsgBox "共享内存打开失败"
    ExitApp
}
global pView := DllCall("MapViewOfFile", "Ptr", hMap, "UInt", 4, "UInt", 0, "UInt", 0, "UInt", 0)

; ==================== 8. 建立技能/Buff 名称映射 ====================
global skillNames := [], skillIdx := Map()
sc := DllCall("CaptureLogic.dll\GetSkillCount", "CDecl Int")
loop sc {
    ptr := DllCall("CaptureLogic.dll\GetSkillName", "Int", A_Index - 1, "CDecl Ptr")
    name := StrGet(ptr, "UTF-8")
    skillNames.Push(name)
    skillIdx[name] := A_Index - 1
}

global buffNames := [], buffIdx := Map()
bc := DllCall("CaptureLogic.dll\GetBuffCount", "CDecl Int")
loop bc {
    ptr := DllCall("CaptureLogic.dll\GetBuffName", "Int", A_Index - 1, "CDecl Ptr")
    name := StrGet(ptr, "UTF-8")
    buffNames.Push(name)
    buffIdx[name] := A_Index - 1
}

; ==================== 9. 定时器与状态更新 ====================
SetTimer UpdateState, DETECT_INTERVAL

UpdateState() {
    global pView, skillIdx, buffIdx, g_CurrentFocus
    global g_SoulFlareStartTick, g_LastUpdateStateTime
    global skillNames, buffNames
    global frameId
    global g_Mutex
    global startLogic


    ; 最小堆处理
    now := HiResTimer.GetTick()
    while g_skillHeap.size() > 0 && g_skillHeap.peek().timestamp <= now {
        g_skillHeap.pop()
    }

    OutputDebug g_skillHeap.ToString()


    ; 防止共享内存映射无效时读取
    if (!pView) {
        Critical "Off"
        return
    }

    local start := HiResTimer.GetTick()

    frameId := NumGet(pView, 0, "UInt")
    focus := NumGet(pView, 12, "Int")
    sc := NumGet(pView, 16, "UInt")
    bc := NumGet(pView, 20, "UInt")
    capUs := NumGet(pView, 24 + sc + bc, "UInt")

    for name, idx in skillIdx {
        state := (idx < sc) ? NumGet(pView, 24 + idx, "UChar") : 0
        StateManager._skillState[name] := state
    }
    buffOff := 24 + sc
    for name, idx in buffIdx {
        state := (idx < bc) ? NumGet(pView, buffOff + idx, "UChar") : 0
        StateManager._buffState[name] := state
    }
    g_CurrentFocus := focus
    StateManager._focusState.currentLevel := focus

    ; ---- 5. 逻辑关闭 5 秒后重置 Soulflare 首发状态 ----
    static logicOffStart := 0
    if (!g_LogicEnabled) {
        if (logicOffStart == 0)
            logicOffStart := HiResTimer.GetTick()
        else if (HiResTimer.SubMs(5000, HiResTimer.GetTick()) > logicOffStart) {
            logicOffStart := 0
            g_Mutex.MarkSFirst()
        }
        startLogic := HiResTimer.GetTick()
    } else {
        logicOffStart := 0
    }
    g_LastUpdateStateTime := HiResTimer.DeltaMs(start, HiResTimer.GetTick())
    ; ToolTip startLogic "," g_LastUpdateStateTime, 0, 0

}
; ==================== 10. 托盘菜单与热键 ====================
A_TrayMenu.Delete()
; global toggleMenuItem := A_TrayMenu.Add("启动", ToggleActive)   ; 保存菜单项对象
A_TrayMenu.Add("设置", ShowSettingsGUI)
; A_TrayMenu.Add("打开配置", OpenConfig)
A_TrayMenu.Add("退出", (*) => ExitApp())
A_TrayMenu.Default := "退出"

^F11:: ToggleActive

global g_LogicTimer := 0
global g_LastFrameExecute := 0 ; frame控制

#HotIf (g_SysState == SYS_ACTIVE)
XButton2:: {
    global g_LogicEnabled, g_LogicTimerFunc, g_Mutex, g_LogicTimer, g_LastFrameExecute
    if g_LogicEnabled
        return
    g_LogicEnabled := true


    SetTimer LogicExecuter, -LOGIC_INTERVAL
}
XButton2 Up:: {
    global g_LogicEnabled, g_LogicTimer, g_Mutex
    g_LogicEnabled := false
    SetTimer LogicExecuter, 0
    g_Mutex.ReleaseSleep()
}
#HotIf

#HotIf (g_SysState == SYS_ACTIVE)
XButton1:: SendInput '^{Numpad9}'
#HotIf

F11:: {
    Cleanup()
    Reload
}

^F1:: {
    global g_SysState, g_DetectTimer, DETECT_INTERVAL
    if (g_SysState != SYS_ACTIVE) {
        g_SysState := SYS_ACTIVE
        g_DetectTimer := SetTimer(UpdateState, DETECT_INTERVAL)
        ToolTip("脚本已激活", 0, 0)
        SetTimer(() => ToolTip(), -1000)
    } else {
        g_SysState := SYS_STANDBY
        g_DetectTimer := 0
        ToolTip("脚本已暂停", 0, 0)
        SetTimer(() => ToolTip(), -1000)
    }
}

ToggleActive(*) {
    global g_SysState, SYS_STANDBY, SYS_ACTIVE
    g_SysState := (g_SysState == SYS_ACTIVE) ? SYS_STANDBY : SYS_ACTIVE
}
; ==================== 11. UI 相关函数 ====================
ShowSettingsGUI(*) {
    global _settingsGui, g_Gold_Wingstorm, g_Gold_Open, g_AutoSoulFlare, g_isUseLeechHasLeechBuff

    try _settingsGui.Destroy()
    _settingsGui := Gui("", "技能自动化设置")
    _settingsGui.OnEvent("Close", (*) => _settingsGui.Destroy())

    _settingsGui.Add("Checkbox", "vGold_Wingstorm", "金 死灵突袭").Value := g_Gold_Wingstorm
    _settingsGui["Gold_Wingstorm"].OnEvent("Click", SaveSettingImmediate)
    _settingsGui.Add("Checkbox", "vGold_Open", "金 開門").Value := g_Gold_Open
    _settingsGui["Gold_Open"].OnEvent("Click", SaveSettingImmediate)
    _settingsGui.Add("Checkbox", "vAutoSoulFlare", "自动释放超神").Value := g_AutoSoulFlare
    _settingsGui["AutoSoulFlare"].OnEvent("Click", SaveSettingImmediate)
    _settingsGui.Add("Checkbox", "vIsUseLeechHasLeechBuff", "有掠夺Buff时仍可释放掠夺").Value := g_isUseLeechHasLeechBuff
    _settingsGui["IsUseLeechHasLeechBuff"].OnEvent("Click", SaveSettingImmediate)
    _settingsGui.Add("Button", "y+10", "关闭").OnEvent("Click", (*) => _settingsGui.Destroy())
    _settingsGui.Show()
}

SaveSettingImmediate(*) {
    global _settingsGui, g_Gold_Wingstorm, g_Gold_Open, g_AutoSoulFlare, g_isUseLeechHasLeechBuff
    g_Gold_Wingstorm := _settingsGui["Gold_Wingstorm"].Value
    g_Gold_Open := _settingsGui["Gold_Open"].Value
    g_AutoSoulFlare := _settingsGui["AutoSoulFlare"].Value
    g_isUseLeechHasLeechBuff := _settingsGui["IsUseLeechHasLeechBuff"].Value
    SaveSettingsToFile()
}

SaveSettingsToFile() {
    global userIniPath, INI
    if !FileExist(userIniPath) {
        DirCreate(A_AppData "\Dragoncall")
        FileCopy INI, userIniPath, 1
    }
    IniWrite(g_Gold_Wingstorm, userIniPath, "Settings", "Gold_Wingstorm")
    IniWrite(g_Gold_Open, userIniPath, "Settings", "Gold_Open")
    IniWrite(g_AutoSoulFlare, userIniPath, "Settings", "AutoSoulFlare")
    IniWrite(g_isUseLeechHasLeechBuff, userIniPath, "Settings", "isUseLeechHasLeechBuff")
    IniWrite(isDebug, userIniPath, "Settings", "isDebug")
    IniWrite(TNoUsedLimit, userIniPath, "Settings", "TNoUsedLimit")
}

; ==================== 12. 主逻辑循环 ====================
LogicExecuter() {
    global g_LogicEnabled, startLogic
    if !g_LogicEnabled
        return

    static isRunning := false
    if isRunning
        return

    isRunning := true
    try {
        Critical "On"
        MainLogic()
        Critical "Off"
    } finally {
        isRunning := false
    }

    if g_LogicEnabled
        SetTimer LogicExecuter, -LOGIC_INTERVAL

}
global lastFrameId := 0
MainLogic() {
    global startLogic
    global g_LastLogicTimeUs, frameMs, g_LastFrameExecute, g_Mutex, lastFrameId, frameId
    local start := HiResTimer.GetTick()
    try {
        ; 1帧执行一次
        g_Mutex.BeginFrame()
        lastFrameId := frameId 

        local hasSoulFlareBuff := _buffState.Get("SoulFlare", false)
        local hasLeechBuff := _buffState.Get("Leech", false)
        ; Sleep 狀態機
        if (g_Mutex.IsInSleep()) {
            HandleSleepState()
        }

        ; Action互斥

        ; Action5 : Open
        global g_Gold_Open, isMinHeap
        local OpenReady := _skillState.Get("Open_R", false)
        local dragoncall_state := _skillState.Get("Dragoncall_L", false) && !_skillState.Get("Dragoncall_R", false) && !_skillState.Get("Dragoncall_Mid", false)
        local open_condition := g_Gold_Open && OpenReady && hasLeechBuff && dragoncall_state
        local MinHeapUsed := isMinHeap ? (g_skillHeap.peek() == -1 ? true : HiResTimer.GetTick() > g_skillHeap.peek().timestamp) : true
        if (g_Mutex.CanExecute(5) && open_condition && MinHeapUsed) {
            SendInput "3"
            g_Mutex.OnExecuted(5)
            writeLogEvent("3", start)
            return
        }

        ; Action2 - Soulflare |-1.0s-|
        global g_AutoSoulFlare
        local soulFlareReady := g_AutoSoulFlare && _skillState.Get("SoulFlare", false)
        if (g_Mutex.CanExecute(2) && soulFlareReady) {
            SendInput "{tab}"
            g_Mutex.OnExecuted(2)
            writeLogEvent("tab", start)
        }

        ; Action1 : Dragoncall & Wingstorm
        local wingstormReady := g_Gold_Wingstorm
            ? _skillState.Get("Gold_Wingstorm_R", false)
            : _skillState.Get("Wingstorm_R", false)
        local dragoncallReady := _skillState.Get("Dragoncall_R", false)

        if (g_Mutex.CanExecute(1)) {
            if (dragoncallReady) {
                SendInput "4"
                g_Mutex.OnExecuted(1)
                writeLogEvent("4", start)
                local now := HiResTimer.GetTick()
                res := HiResTimer.AddMs(g_skillCooldownMs["Dragoncall_R"], now)
                g_skillHeap.push({ skillname: "Dragoncall", timestamp: res }, 500)
            }
            else if (wingstormReady) {
                SendInput "v"
                g_Mutex.OnExecuted(1)
                writeLogEvent("v", start)
                local now := HiResTimer.GetTick()
                local event := []
                Loop 3 {
                    res := HiResTimer.AddMs(g_skillCooldownMs["Wingstorm_R"] * A_Index, now)
                    event.push({ skillname: "Wingstorm", timestamp: res })
                }
                g_skillHeap.pushBatch(event, 500)
            }
        }

        ; Action3 : Leech
        global g_isUseLeechHasLeechBuff
        local preLeech := _skillState.Get("Leech_L", false)
        local LeechReady := _skillState.Get("Leech_R", false)
        local leech_condition := dragoncall_state
        local allowLeech := false
        if (g_Mutex.CanExecute(3) && preLeech) { ; 预备状态
            if (hasSoulFlareBuff) {
                if (!hasLeechBuff) {
                    allowLeech := true
                }
            } else if (!hasSoulFlareBuff) {
                if (!hasLeechBuff) {
                    allowLeech := true
                } else if (g_isUseLeechHasLeechBuff && leech_condition) {
                    allowLeech := true
                }
            }

            if (allowLeech) {
                if (LeechReady) {
                    SendInput "f"
                    g_Mutex.OnExecuted(3)
                    writeLogEvent("f", start)
                } else {
                    return
                }
            }
        }


        ; Action4 - Mantra/Rupture/Bombardment
        if (g_Mutex.CanExecute(4)) {
            local MantraReady := g_CurrentFocus <= (hasSoulFlareBuff ? 2 : (hasLeechBuff ? 4 : 5)) && _skillState.Get("Mantra_L", false)
            local RuptureReady := g_CurrentFocus <= (hasSoulFlareBuff ? 1 : (hasLeechBuff ? 4 : 4)) && _skillState.Get("Rupture_L", false)
            local BombardmentReady := true
            
            if (MantraReady) {
                SendInput "r"
                g_Mutex.OnExecuted(4)
                writeLogEvent("r", start)
            } else if (RuptureReady) {
                SendInput "f"
                g_Mutex.OnExecuted(4)
                writeLogEvent("f", start)
            } else if(BombardmentReady){
                SendInput "t"
                g_Mutex.OnExecuted(4)
                writeLogEvent("t", start)
                
            }

            

        }


    } finally {
        g_LastLogicTimeUs := HiResTimer.DeltaMs(start, HiResTimer.GetTick())
        
    }
}

global WRITELOG := true

writeLogEvent(str, start){
    global frameId, g_Mutex, startLogic, WRITELOG

    if(!WRITELOG){
        return
    }
    if (g_Mutex.thisFrameAct != 0)
        LogToFile("[MainLogic] curFrame:" frameId " keybroad:" str " action:" g_Mutex.thisFrameAct "," Round(HiResTimer.DeltaMs(startLogic, start), 2) " ms")
}

HandleSleepState() {
    global g_Mutex, FrameCount, frameMs, g_Gold_Open
    if (g_Mutex.sleepType == 1) { ; Open Sleep
        local OpenReady := _skillState.Get("Open_R", false)
        local openBlackReady := g_Gold_Open && !_skillState.Get("Open_Black", false) && !OpenReady
        if (OpenReady) {
            local realFrame := FrameCount - 2

            ; 多帧抓取判断
            local press_time := HiResTimer.SubMs(g_Mutex.sleepExpire, g_Mutex.openSleepTime)
            if (frameMs * realFrame <= HiResTimer.DeltaMs(press_time, HiResTimer.GetTick())) {
                ; 说明 物理按下 失败
                g_Mutex.ReleaseSleep()
                ; LogToFile("[HandleSleepState-Open Press Fail] " HiResTimer.GetTick() "")
            } else if (g_Mutex.IsInSleep()) {
                ; LogToFile("[HandleSleepState-Open MultFrame] " HiResTimer.GetTick() "")
                return
            }
        } else if (openBlackReady) {
            if (g_Mutex.IsInSleep()) {
                ; LogToFile("[HandleSleepState-Open Press Success Waiting] " HiResTimer.GetTick() "")
                return
            } else {
                ; LogToFile("[HandleSleepState-Open Press Success] " HiResTimer.GetTick() "")
                g_Mutex.ReleaseSleep()
            }
        } else {
            ; 条件不足
            g_Mutex.ReleaseSleep()
        }
    } else if (g_Mutex.sleepType == 2) { ; Soulflare Sleep

    } else if (g_Mutex.sleepType == 3) {

    }
    else {
        g_Mutex.ReleaseSleep()
    }
}

; ==================== 13. 退出清理 ====================
OnExit Cleanup
Cleanup(*) {
    global hDll, hMap, pView, pStopCapture
    ; 先尝试停止捕获（可能失败，但不影响后续清理）
    try {
        if (pStopCapture && hDll)
            DllCall(pStopCapture, "CDecl")
    } catch {
        ; 忽略错误，继续释放资源
    }

    ; 释放共享内存映射
    try {
        if (pView)
            DllCall("UnmapViewOfFile", "Ptr", pView)
    } catch {
    }
    ; 关闭共享内存句柄
    try {
        if (hMap)
            DllCall("CloseHandle", "Ptr", hMap)
    } catch {
    }
    ; 卸载 DLL
    try {
        if (hDll)
            DllCall("FreeLibrary", "Ptr", hDll)
    } catch {
    }
    ; 重置全局变量
    hDll := 0
    hMap := 0
    pView := 0
    pStopCapture := 0
    ToolTip "Cleanup completed", 0, 0
}
OnExit FlushLogs
Persistent