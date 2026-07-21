#Requires AutoHotkey v2.0

#Requires AutoHotkey v2.0
#SingleInstance Force


CoordMode("Pixel", "Screen")
ProcessSetPriority("High")

; 咒术 主逻辑 参数
global blockDEF := false
global blockEF  := false
global blockF   := false
global mantra_lock_e := 1

global Last_SoulFlace := -1

; 超神2.5s之後不允許使用掠奪
global isUseLeechHasSoulFlace_Duration := 2.5
global RuptureLocked := 1

; ===== 新增：首次 Soulflare 触发延迟控制 =====
global g_FirstSoulflareApplied := false      ; 是否已经触发过延迟
global g_FirstSoulflareDelayUntil := 0       ; 延迟截止时间（A_TickCount）
global g_FirstExecutionInThisPress := false  ; 当前一次按住后是否尚未执行第一次判断

; 帧间隔（毫秒）
global DETECT_INTERVAL := 20
global LOGIC_INTERVAL  := 2

; 系统状态
global SYS_STANDBY := 0
global SYS_ACTIVE  := 1
global g_SysState  := SYS_STANDBY

; Logic 子控制
global g_LogicEnabled := false

; 定时器句柄
global g_DetectTimer := 0
global g_LogicTimer  := 0

global g_LogicEnabled := false
global g_LogicTimerFunc := 0   ; 绑定函数缓存

; 全局点位信息表（用于检测）
global StateMap := Map()
; 用于缓存检测结果，避免重复写入 Map
global StateMapResults := Map()


; Logic 执行参数
global execute_time := -1
global _buffState := StateManager.GetBuffState()
global _skillState := StateManager.GetSkillState()
global focus_level := g_CurrentFocus

MainLogic() {
    Critical "On"

    ; ===== 1. 一次获取时间 =====
    local now := HiResTimer.GetTick()

    ; ===== 2. 声明所有需要读取的全局变量 =====
    global _skillState, _buffState, g_CurrentFocus
    global g_SoulFlareStartTick, g_Gold_Wingstorm
    global g_isUseLeechHasLeechBuff
    global g_FirstSoulflareDelayUntil, g_FirstSoulflareApplied, g_FirstExecutionInThisPress
    global blockDEF, blockEF, blockF, mantra_lock_e, RuptureLocked
    global record_frist, record_leech

    ; ===== 3. 一次性将 Map 读取到局部变量 =====
    local hasSoulFlareBuff := _buffState.Get("SoulFlare", false)
    local hasLeechBuff      := _buffState.Get("Leech", false)

    local soulFlareReady    := _skillState.Get("SoulFlare", false)
    local dragoncallReady   := _skillState.Get("Dragoncall_R", false)
    local wingstormReady    := g_Gold_Wingstorm
        ? _skillState.Get("Gold_Wingstorm_R", false)
        : _skillState.Get("Wingstorm_R", false)
    local leechLAvail       := _skillState.Get("Leech_L", false)
    local leechRAvail       := _skillState.Get("Leech_R", false)
    local mantraLAvail      := _skillState.Get("Mantra_L", false)
    local mantraRAvail      := _skillState.Get("Mantra_R", false)
    local ruptureLAvail     := _skillState.Get("Rupture_L", false)
    local ruptureRAvail     := _skillState.Get("Rupture_R", false)

    ; ===== 4. 焦点容错 =====
    if (g_CurrentFocus == -1)
        g_CurrentFocus := 10

    ; ===== 5. Soulflare 首次延迟期 =====
    if (now <= g_FirstSoulflareDelayUntil) {
        if (dragoncallReady)
            SendInput "4"
        if (wingstormReady)
            SendInput "v"
        Critical "Off"
        return
    }

    ; ===== 6. Soulflare =====
    if (soulFlareReady) {
        SendInput "{tab}"
        record_frist := now
        if (g_FirstExecutionInThisPress) {
            g_FirstSoulflareApplied := true
            ; 为什么只能打出33~35,因为释放0.1,后摇0.7 => 0.8s,而我设定的是0.9s后自动掠夺,那会有0.7s的后摇,因此应该是在后摇结束的一刻, 0.28+0.8=>1.08
            g_FirstSoulflareDelayUntil := HiResTimer.AddMs(280, now)
            g_FirstExecutionInThisPress := false
            Critical "Off"
            return
        }
    }
    g_FirstExecutionInThisPress := false

    ; ===== 7. Dragoncall / Wingstorm =====
    if (dragoncallReady)
        SendInput "4"
    if (wingstormReady)
        SendInput "v"

    ; ===== 8. Leech (C) =====
    local leech_condition := g_isUseLeechHasLeechBuff ? true : !hasLeechBuff

    local allowLeech := true
    if (g_SoulFlareStartTick > 0) {
        local winStart := HiResTimer.AddMs(3000, g_SoulFlareStartTick)
        local winEnd   := HiResTimer.AddMs(12000, g_SoulFlareStartTick)
        if (now >= winStart && now <= winEnd && hasLeechBuff)
            allowLeech := false
    }

    blockDEF := leechLAvail && allowLeech

    if (blockDEF && leech_condition) {
        if (leechRAvail) {
            SendInput "f"
            record_leech := now
            blockDEF := false
            Critical "Off"
            return
        }
    }

    ; ===== 9. Mantra (D) =====
    local d_focus_limit := hasSoulFlareBuff ? 2 : (hasLeechBuff ? 4 : 5)

    blockEF := !blockDEF && mantraLAvail && (g_CurrentFocus <= d_focus_limit)

    if (mantraRAvail && blockEF) {
        SendInput "r"
        mantra_lock_e := HiResTimer.AddMs(RuptureLocked * 1000, now)
        blockEF := false
        Critical "Off"
        return
    }

    ; ===== 10. Rupture (E) =====
    local e_focus_limit := hasSoulFlareBuff ? 1 : (hasLeechBuff ? 3 : 4)

    blockF := !blockDEF && !blockEF && ruptureLAvail && (g_CurrentFocus <= e_focus_limit)

    if (ruptureRAvail && blockF && mantra_lock_e <= now) {
        SendInput "f"
        blockF := false
        Critical "Off"
        return
    }

    ; ===== 11. Bombardment (F) =====
    if (!blockDEF && !blockEF && !blockF)
        SendInput "t"

    Critical "Off"
}




; ========== 系统托盘 ==========
Tray := A_TrayMenu
Tray.Delete()
Tray.Add("打开配置", ShowConfigGUI)
Tray.Add("暂停/恢复", TogglePause)
Tray.Add()
Tray.Add("退出", (*) => ExitApp())
Tray.Default := "打开配置"
Tray.Tip := "SkillBot - 运行中"

global Paused := false
global ConfigGUI := unset
global IniFile := IniManager.iniPath

; ========== 自定义通知音效 ==========
NotifySound() {
    soundPath := A_ScriptDir "\notice.mp3"
    if (soundPath != "" && FileExist(soundPath)) {
        SoundPlay(soundPath)
    } else {
        SoundBeep(800, 100)
    }
}

; ========== 浮动提示 + 声音 ==========
ShowNotification(msg) {
    ToolTip(msg, A_ScreenWidth//2 - 100, A_ScreenHeight - 100)
    SetTimer(RemoveToolTip, -2000)
    NotifySound()
}

RemoveToolTip() {
    ToolTip()
}

; ========== 配置窗口（系统边框 + 背景图缩放至 320x200） ==========
ShowConfigGUI(*) {
    global ConfigGUI, IniFile

    if !IsSet(ConfigGUI) || !ConfigGUI.HasProp("Hwnd") {
        cfg := Gui()
        cfg.Title := "SkillBot"
        ; 使用系统默认边框，调整客户区大小
        cfg.ClientSize := {w: 320, h: 200}
        cfg.SetFont("s10 c000000", "Segoe UI")   ; 深色文字，适合浅色背景

        ; 背景图（可选，拉伸至 320x200）
        bgPath := IniRead(IniFile, "Settings", "GUIBackground", "")
        if (bgPath != "" && FileExist(bgPath)) {
            cfg.Add("Picture", "x0 y0 w320 h200", bgPath)
        } else {
            cfg.BackColor := 0xF0F0F0   ; 浅灰底
        }

        ; 复选框（y 起始 15，间距 25）
        curGoldWing := IniRead(IniFile, "Settings", "Gold_Wingstorm", "false")
        curGoldOpen := IniRead(IniFile, "Settings", "Gold_Open", "false")
        curAutoSoul := IniRead(IniFile, "Settings", "AutoSoulFlare", "false")
        curUseLeech := IniRead(IniFile, "Settings", "isUseLeechHasLeechBuff", "false")

        cb1 := cfg.Add("Checkbox", Format("x20 y15 w280 vGoldWingstorm Checked{}", (curGoldWing = "true" ? "1" : "0")), "金死灵突袭(V)")
        cb2 := cfg.Add("Checkbox", Format("xp y+5 w280 vGoldOpen Checked{}", (curGoldOpen = "true" ? "1" : "0")), "金开门(3,暂未实现)")
        cb3 := cfg.Add("Checkbox", Format("xp y+5 w280 vAutoSoulFlare Checked{}", (curAutoSoul = "true" ? "1" : "0")), "自动超神(TAB)")
        cb4 := cfg.Add("Checkbox", Format("xp y+5 w280 visUseLeechHasLeechBuff Checked{}", (curUseLeech = "true" ? "1" : "0")), "掠夺Buff时可使用掠夺(F)")

        ; 按钮（水平居中）
        btnMacro := cfg.Add("Button", Format("x100 y160 w120 h30 vToggleBtn"), "启动宏")
        btnMacro.OnEvent("Click", ToggleMacroState)

        ; 事件绑定
        cb1.OnEvent("Click", OnCheckChange)
        cb2.OnEvent("Click", OnCheckChange)
        cb3.OnEvent("Click", OnCheckChange)
        cb4.OnEvent("Click", OnCheckChange)

        ; 系统关闭按钮 → 隐藏到托盘（不是退出）
        cfg.OnEvent("Close", (*) => cfg.Hide())
        cfg.OnEvent("Escape", (*) => cfg.Hide())

        ConfigGUI := cfg
    }

    UpdateToggleButton(ConfigGUI)
    ConfigGUI.Show("Center")
}

; ---- 以下为原有函数，未作修改 ----
OnCheckChange(ctrl, info) {
    UpdateSettingFromCheckbox("Gold_Wingstorm", "GoldWingstorm")
    UpdateSettingFromCheckbox("Gold_Open", "GoldOpen")
    UpdateSettingFromCheckbox("AutoSoulFlare", "AutoSoulFlare")
    UpdateSettingFromCheckbox("isUseLeechHasLeechBuff", "isUseLeechHasLeechBuff")
    ReloadAll()
    ShowNotification("配置已更新并应用")
}

UpdateSettingFromCheckbox(sectionKey, ctrlName) {
    global ConfigGUI, IniFile
    val := ConfigGUI[ctrlName].Value ? "true" : "false"
    IniManager.Write("Settings", sectionKey, val)
}

UpdateToggleButton(cfg) {
    global g_SysState, SYS_ACTIVE
    btn := cfg["ToggleBtn"]
    try btn.Text := (g_SysState == SYS_ACTIVE) ? "停止宏" : "启动宏"
}

ToggleMacroState(*) {
    global g_SysState, g_DetectTimer, g_LogicTimer, g_LogicEnabled, DETECT_INTERVAL, SYS_STANDBY, SYS_ACTIVE
    if (g_SysState == SYS_STANDBY) {
        g_SysState := SYS_ACTIVE
        g_DetectTimer := SetTimer(DetectExecuter, DETECT_INTERVAL)
        ShowNotification("宏已启动")
    } else {
        if g_LogicTimer {
            SetTimer(LogicExecuter, 0)
            g_LogicTimer := 0
        }
        g_LogicEnabled := false
        if g_DetectTimer {
            SetTimer(DetectExecuter, 0)
            g_DetectTimer := 0
        }
        g_SysState := SYS_STANDBY
        ShowNotification("宏已停止")
    }
    if IsSet(ConfigGUI) && ConfigGUI.HasProp("Hwnd")
        UpdateToggleButton(ConfigGUI)
}

ReloadAll() {
    HiResTimer.Init()
    LoadConfigAndStateMaps()
    InitSettings()
}

TogglePause(*) {
    global Paused, g_LogicEnabled, g_LogicTimer, g_DetectTimer, g_SysState, SYS_STANDBY, SYS_ACTIVE, DETECT_INTERVAL
    Paused := !Paused
    if Paused {
        if g_LogicTimer {
            SetTimer(LogicExecuter, 0)
            g_LogicTimer := 0
        }
        g_LogicEnabled := false
        if g_DetectTimer {
            SetTimer(DetectExecuter, 0)
            g_DetectTimer := 0
        }
        g_SysState := SYS_STANDBY
        Tray.Tip := "SkillBot - 已暂停"
    } else {
        g_SysState := SYS_ACTIVE
        g_DetectTimer := SetTimer(DetectExecuter, DETECT_INTERVAL)
        Tray.Tip := "SkillBot - 运行中"
    }
}

global g_Gold_Wingstorm := false
global g_Gold_Open := false
global g_AutoSoulFlare := false
global g_isUseLeechHasLeechBuff := false

InitSettings(){
    global g_Gold_Wingstorm, g_Gold_Open, g_AutoSoulFlare, g_isUseLeechHasLeechBuff, settings, TNoUsedLimit
    g_Gold_Wingstorm := ParseBool(settings.Has("Gold_Wingstorm") ? settings["Gold_Wingstorm"] : false)

    g_Gold_Open := ParseBool(settings.Has("Gold_Open") ? settings["Gold_Open"] : false)

    g_AutoSoulFlare := ParseBool(settings.Has("AutoSoulFlare") ? settings["AutoSoulFlare"]  : false)
    g_isUseLeechHasLeechBuff := ParseBool(settings.Has("isUseLeechHasLeechBuff") ? settings["isUseLeechHasLeechBuff"] : false)
    TNoUsedLimit := ParseBool(settings.Has("TNoUsedLimit") ? settings["TNoUsedLimit"] : true)


    ; MsgBox "设置已加载：`n" 
    ;     . "Wingstorm" . (g_Gold_Wingstorm ? "开启" : "关闭") . "`n"
    ;     . "Open" . (g_Gold_Open ? "开启" : "关闭") . "`n"
    ;     . "SoulFlare" . (g_AutoSoulFlare ? "开启" : "关闭") . "`n"
    ;     . "Leech" . (g_isUseLeechHasLeechBuff ? "是" : "否")
}

LogicExecuter() {
    static _running := false
    global g_LogicEnabled, g_LogicTimerFunc, LOGIC_INTERVAL
    ; 急停检查 - 最高优先级
    if (!g_LogicEnabled)
        return

    if _running
        return
    _running := true
    try {
        ; 执行前再确认一次急停（防止获得 _running 后标志被异步修改）
        if (!g_LogicEnabled)
            return
        MainLogic()
    }
    finally {
        _running := false
    }

    ; 自循环：如果仍在按住，安排下一次执行
    if (g_LogicEnabled) {
        SetTimer(g_LogicTimerFunc, -LOGIC_INTERVAL)
    }
}
global record_frist := 0,record_leech := 0

DetectExecuter() {
    static _running := false
    global g_FocusKeySet, g_FocusRefLum, StateMapResults, g_BuffSubKeySet, g_SkillKeySet, g_SysState, SYS_ACTIVE, g_SkillGroups, g_SoulFlareStartTick := 0, g_FirstSoulflareApplied, g_FirstSoulflareDelayUntil, g_LogicEnabled, g_FirstExecutionInThisPress

    static logicOffStart := 0

    global record_frist,record_leech
    local t0 := HiResTimer.GetTick()
    ; ToolTip g_FirstExecutionInThisPress "," g_FirstSoulflareApplied  "," g_FirstSoulflareDelayUntil "," g_LogicEnabled "," logicOffStart, 0 , 0

    ; 163831724308 163836711325
    ; 102522532656,102526529551
    ; OutputDebug Round((record_leech - record_frist) * 1000 / HiResTimer.freq, 2)

    if (!g_LogicEnabled) {
        if (logicOffStart = 0)
            logicOffStart := HiResTimer.GetTick()
        else if (HiResTimer.SubMs(5000, HiResTimer.GetTick()) >  logicOffStart) {
            g_FirstSoulflareApplied := false
            g_FirstSoulflareDelayUntil := 0
            logicOffStart := 0
        }
    } else {
        logicOffStart := 0
    }

    if (_running || g_SysState != SYS_ACTIVE)
        return
    _running := true
    try {
        FastMemoryCapture.Capture()

        local CaptureObj := FastMemoryCapture

        pointCount := 0
        stateTxt := ""

        ; 遍历多点检测组（自动兼容单点技能）
        for baseKey, pts in g_SkillGroups {
            state := false
            for pt in pts {
                if CaptureObj.IsPixelMatch(pt[1], pt[2], pt[3], pt[4]) {
                    state := true
                    break
                }
            }
            ; 写入基础键结果（供 StateManager 和后续逻辑使用）
            StateMapResults[baseKey] := state
            ; 同时写入所有子键结果（如果你后续需要直接用子键名读取，可免去重构）
            if pts.Length > 1 {
                i := 1
                loop {
                    subKey := baseKey "_" i
                    if StateMapResults.Has(subKey)
                        StateMapResults[subKey] := state
                    else
                        break
                    i++
                }
            }
            ; 同步到 StateManager 的技能状态表
            StateManager._skillState[baseKey] := state
            pointCount += pts.Length  ; 计算实际检测点数量
        }

        ; ---- 2. 遍历所有剩余点：Focus 与 Buff 点 ----

        for key, pt in StateMap {
            if (g_SkillGroups.Has(key)) {
                continue
            }
            if g_FocusKeySet.Has(key) {
                ; 直接读取像素颜色（不用容差，我们要的是亮度）
                color := CaptureObj.GetPixel(pt[1], pt[2])
                r := (color >> 16) & 0xFF
                g := (color >> 8) & 0xFF
                b := color & 0xFF
                currentLum := r * 0.2126 + g * 0.7152 + b * 0.0722
                refLum := g_FocusRefLum[key]
                ; 如果当前亮度低于参考亮度，视为“未点亮”
                state := (currentLum >= refLum)   ; true 表示点亮
                StateMapResults[key] := state
                StateManager._focusState[key] := state
            } else {
                state := CaptureObj.IsPixelMatch(pt[1], pt[2], pt[3], pt[4])
                StateMapResults[key] := state
            }
            pointCount++
        }
        ; t2 := HiResTimer.GetTick()

        ; 计算当前 Focus 等级（取所有已点亮的最大序号）
        global g_CurrentFocus
        local curFocus_res := -1
        g_CurrentFocus := curFocus_res
        for key in g_FocusKeySet {
            if StateMapResults[key] {
                ; 从键名中提取数字 ID，例如 "Focus_7"
                id := Integer(SubStr(key, 7))   ; 假设格式固定
                if id > curFocus_res
                    curFocus_res := id
            }
        }
        g_CurrentFocus := curFocus_res

        ; 3. Buff 汇总 OR + 去抖
        local soulFlareInstant := false
        for baseKey, subKeys in g_BuffGroupMap {
            ; 当前帧检测结果（任一子键命中即视为存在）
            exists := false
            for subKey in subKeys {
                if StateMapResults[subKey] {
                    exists := true
                    break
                }
            }
            if (baseKey = "SoulFlare")
                soulFlareInstant := exists

            ; 获取去抖记录
            deb := g_BuffDebounce[baseKey]

            local oldState := false

            ; 与上一帧稳定状态比较
            if (exists = deb.state) {
                ; 状态无变化，重置计数器（或保持阈值不变，这里采用重置以允许快速变化？实际我们想要连续一致才切换，所以只在不一致时计数）
                deb.count := 0
            } else {
                ; 与当前稳定状态不同，增加计数
                deb.count++
                ; 若连续帧数达到阈值，则翻转稳定状态并更新 StateManager
                if (deb.count >= DEBOUNCE_THRESHOLD) {
                    oldState := deb.state
                    deb.state := exists
                    deb.count := 0
                    StateManager._buffState[baseKey] := exists
                }
                ; SoulFlare 首次出现记录
                if (baseKey = "SoulFlare") {
                    if (!oldState && exists) {
                        g_SoulFlareStartTick := HiResTimer.GetTick()
                    }
                }
            }

            if isDebug {
                ; stateTxt .= baseKey " : " deb.state "`n"
            }
        }

        ; ---- SoulFlare 超时丢失监控 (0.5 秒) ----
        static lastSoulFlareSeen := 0
        if soulFlareInstant {
            lastSoulFlareSeen := HiResTimer.GetTick()
        }
        if (HiResTimer.SubMs(500, HiResTimer.GetTick()) > lastSoulFlareSeen) {
            if StateManager._buffState["SoulFlare"] {
                StateManager._buffState["SoulFlare"] := false
                g_SoulFlareStartTick := 0
            }
        }

        local t1 := HiResTimer.GetTick()

        OutputDebug HiResTimer.DeltaMs(t0, t1)

    }
    finally
        _running := false
}

class IniManager
{
    static iniPath := A_ScriptDir "\config.ini"

    ; 读取整个 Section 为 Map(key, value字符串)
    static ReadToMap(section) {
        m := Map()
        ; MsgBox this.iniPath
        if !FileExist(this.iniPath)
            return m
        keysStr := IniRead(this.iniPath, section, , "")
        ; MsgBox keysStr
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

    ; 按分隔符拆分值，返回 Map(key, Array)
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

class StateManager
{
    static _buffState := Map()
    static _skillState := Map()
    static _focusState := Map()

    ; 传入 buff 的基键名称列表，例如 ["buff1", "buff2"]
    static InitBuff(baseKeys) {
        this._buffState.Clear()
        for key in baseKeys
            this._buffState[key] := false
    }

    ; 技能和焦点仍按原来的方式初始化（传入所有子键）
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

    ; 直接访问器
    static GetBuffState() => this._buffState
    static GetSkillState() => this._skillState
    static GetFocusState() => this._focusState

    ; 统计存在的 buff 数量
    static GetBuffTrueCount() {
        c := 0
        for _, v in this._buffState
            if v
                c++
        return c
    }
}
class FastMemoryCapture
{
    static hDesktop := 0
    static hMemDC := 0
    static hBitmap := 0
    static pBits := 0
    static minX := 0, minY := 0, maxX := 0, maxY := 0
    static width := 0, height := 0, stride := 0

    static Init(pointMap) {
        this.Release()
        if !(pointMap is Map) || pointMap.Count = 0
            return

        ; 直接使用屏幕绝对坐标计算包围盒（不再减去客户区偏移）
        minX := 0x7FFFFFFF, maxX := -0x80000000
        minY := 0x7FFFFFFF, maxY := -0x80000000
        for _, arr in pointMap {
            x := arr[1], y := arr[2]
            minX := Min(minX, x), maxX := Max(maxX, x)
            minY := Min(minY, y), maxY := Max(maxY, y)
        }
        this.minX := minX, this.minY := minY
        this.maxX := maxX, this.maxY := maxY
        this.width := maxX - minX + 1
        this.height := maxY - minY + 1
        this.stride := this.width * 4

        ; BITMAPINFO
        bi := Buffer(40, 0)
        NumPut("UInt", 40, bi, 0)
        NumPut("Int", this.width, bi, 4)
        NumPut("Int", -this.height, bi, 8)
        NumPut("UShort", 1, bi, 12)
        NumPut("UShort", 32, bi, 14)

        ; 优先尝试显示器 DC（可能绕过 DWM），失败则回退桌面 DC
        ; this.hDesktop := DllCall("CreateDC", "Str", "DISPLAY", "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr")
        ; if !this.hDesktop
        this.hDesktop := DllCall("GetDC", "Ptr", 0, "Ptr")

        this.hMemDC := DllCall("CreateCompatibleDC", "Ptr", this.hDesktop, "Ptr")
        this.hBitmap := DllCall("CreateDIBSection",
            "Ptr", this.hMemDC,
            "Ptr", bi.Ptr,
            "UInt", 0,
            "Ptr*", &pBits := 0,
            "Ptr", 0,
            "UInt", 0,
            "Ptr")
        DllCall("SelectObject", "Ptr", this.hMemDC, "Ptr", this.hBitmap)
        this.pBits := pBits
    }

    static Capture() {
        if !this.hMemDC
            return
        DllCall("BitBlt",
            "Ptr", this.hMemDC, "Int", 0, "Int", 0,
            "Int", this.width, "Int", this.height,
            "Ptr", this.hDesktop,
            "Int", this.minX, "Int", this.minY,
            "UInt", 0xCC0020) ; SRCCOPY
    }

    static GetPixel(x, y) {
        if (x < this.minX || x > this.maxX || y < this.minY || y > this.maxY)
            return 0
        relX := x - this.minX
        relY := y - this.minY
        offset := (relY * this.stride) + (relX * 4)
        return NumGet(this.pBits, offset, "UInt")
    }

    static IsPixelMatch(x, y, targetRGB, tol) {
        color := this.GetPixel(x, y)
        tr := (targetRGB >> 16) & 0xFF, tg := (targetRGB >> 8) & 0xFF, tb := targetRGB & 0xFF
        cr := (color >> 16) & 0xFF, cg := (color >> 8) & 0xFF, cb := color & 0xFF
        return Abs(tr-cr) <= tol && Abs(tg-cg) <= tol && Abs(tb-cb) <= tol
    }

    static Release() {
        if this.hBitmap {
            DllCall("DeleteObject", "Ptr", this.hBitmap)
            this.hBitmap := 0
        }
        if this.hMemDC {
            DllCall("DeleteDC", "Ptr", this.hMemDC)
            this.hMemDC := 0
        }
        if this.hDesktop {
            if !DllCall("ReleaseDC", "Ptr", 0, "Ptr", this.hDesktop)
                DllCall("DeleteDC", "Ptr", this.hDesktop)
            this.hDesktop := 0
        }
        this.pBits := 0
        this.width := this.height := this.stride := 0
    }

    ; TODO 有問題! 不應該是targetRGB而應該是別的
    static IsArcMatch(baseX, baseY, targetRGB, tol, arcLen := 9) {
        half := arcLen // 2
        loop arcLen {
            dy := A_Index - half - 1
            if FastMemoryCapture.IsPixelMatch(baseX, baseY + dy, targetRGB, tol)
                return true
        }
        return false
    }
}


; ---------- 技能/焦点分类键集合 ----------
global g_SkillKeySet := Map()
global g_FocusKeySet := Map()
global g_BuffSubKeySet := Map()
global g_BuffGroupMap := Map()
global g_SkillGroups := Map()

; ---------- Focus 亮度参考 ----------
global g_FocusRefLum := Map()
global g_CurrentFocus := 0

; ---------- Buff 去抖 ----------
global g_BuffDebounce := Map()
global DEBOUNCE_THRESHOLD := 2

; ---------- 独立 GCD 时间戳 ----------
global g_LastSentDragoncall := 0, g_LastSentWingstorm := 0
global g_LastGCD1 := 0, g_DisableEUntil := 0

; ---------- 核心状态表 ----------
global StateMap := Map()
global StateMapResults := Map()
global isDebug := false
global settings := Map()


; ========== 主加载函数 ==========
LoadConfigAndStateMaps() {
    global isDebug, settings, g_SkillGroups
    ; 读取所有 section
    skillBase := IniManager.ReadSplitToMap("Skill")
    buffBase  := IniManager.ReadSplitToMap("Buff")
    focusConf := IniManager.ReadToMap("Focus")
    settings  := IniManager.ReadToMap("Settings")

    isDebug := ParseBool(settings.Get("isDebug", "false"))

    ; 重置容器
    StateMap.Clear()
    StateMapResults.Clear()
    g_BuffGroupMap.Clear()
    g_SkillKeySet.Clear()
    g_FocusKeySet.Clear()
    g_BuffSubKeySet.Clear()
    buffBaseKeys := []

    ; ---------- 1. Skill ----------
    for key, arr in skillBase {
        x := Integer(arr[1]), y := Integer(arr[2])
        rgb := ParseColor(arr[3]), tol := Integer(arr[4])
        pt := [x, y, rgb, tol]
        StateMap[key] := pt
        StateMapResults[key] := false
        g_SkillKeySet[key] := true
    }

    baseKeys := Map()
    for key in g_SkillKeySet {
        if RegExMatch(key, "^(.+)_\d+$", &m)
            baseKeys[m[1]] := true
        else
            baseKeys[key] := true
    }
    ; 为每个基键收集坐标点（若存在子键则收集多个，否则就一个）
    for base in baseKeys {
        pts := []
        if StateMap.Has(base)
            pts.Push(StateMap[base])
        i := 1
        loop {
            subKey := base "_" i
            if StateMap.Has(subKey) {
                pts.Push(StateMap[subKey])
                i++
            } else
                break
        }
        g_SkillGroups[base] := pts
    }

    ; ---------- 2. Buff 展开 ----------
    vNum := Integer(settings["Buff_Vertical"])
    hNum := Integer(settings["Buff_Horizontal"])
    vSpace := Integer(settings["Buff_Vertical_space"])
    hSpace := Integer(settings["Buff_Horizontal_space"])

    for key, arr in buffBase {
        baseX := Integer(arr[1]), baseY := Integer(arr[2])
        rgb := ParseColor(arr[3]), tol := Integer(arr[4])
        subKeys := []
        loop vNum {
            j := A_Index - 1
            offsetX := 0
            loop hNum {
                i := A_Index - 1
                if (i + 1 = 4 || i + 1 = 8)
                    offsetX += 1
                cellX := baseX - i * hSpace - offsetX
                cellY := baseY + j * vSpace
                fullKey := key "_" (j * hNum + i)
                pt := [cellX, cellY, rgb, tol]
                StateMap[fullKey] := pt
                StateMapResults[fullKey] := false
                g_BuffSubKeySet[fullKey] := true
                subKeys.Push(fullKey)
            }
        }
        g_BuffGroupMap[key] := subKeys
        buffBaseKeys.Push(key)
    }

    ; Buff 去抖初始化
    for key in buffBaseKeys {
        g_BuffDebounce[key] := { count: 0, state: false }
    }

    ; ---------- 3. Focus 生成 ----------
    focusBaseX := Integer(focusConf["FocusBaseX"])
    focusBaseY := Integer(focusConf["FocusBaseY"])
    focusRGB := ParseColor(focusConf["FocusBaseRGB"])
    focusTol := Integer(focusConf["FocusBaseTol"])
    focusSpace := Integer(focusConf["FocusSpace"])

    refR := (focusRGB >> 16) & 0xFF
    refG := (focusRGB >> 8) & 0xFF
    refB := focusRGB & 0xFF
    baseLum := refR * 0.2126 + refG * 0.7152 + refB * 0.0722

    loop 10 {
        idx := A_Index - 1
        ptX := focusBaseX - (9 - idx) * focusSpace
        fullKey := "Focus_" (idx + 1)
        pt := [ptX, focusBaseY, focusRGB, focusTol]
        StateMap[fullKey] := pt
        StateMapResults[fullKey] := false
        g_FocusKeySet[fullKey] := true
        g_FocusRefLum[fullKey] := baseLum
    }

    ; ---------- 4. StateManager 初始化 ----------
    skillArr := []
    for k, _ in g_SkillKeySet
        skillArr.Push(k)
    focusArr := []
    for k, _ in g_FocusKeySet
        focusArr.Push(k)

    StateManager.InitBuff(buffBaseKeys)
    StateManager.InitSkill(skillArr)
    StateManager.InitFocus(focusArr)

    ; ---------- 5. 捕获器初始化 ----------

    FastMemoryCapture.Init(StateMap)

}

; ========== 工具函数 ==========
ParseColor(str) {
    str := Trim(str)
    if str = ""
        return 0
    if SubStr(str, 1, 1) = "#"
        str := "0x" SubStr(str, 2)
    else if SubStr(str, 1, 2) != "0x" && SubStr(str, 1, 2) != "0X"
        str := "0x" str
    return Integer(str)
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



global record_frist := 0, record_leech := 0


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

    ; 对指定时间戳加上指定毫秒数（默认从当前时刻算起）
    static AddMs(ms, startTick?) {
        if !IsSet(startTick)
            startTick := this.GetTick()
        ; ms * freq / 1000 得到需要增加的计数值，四舍五入
        offset := Round(ms * this.freq / 1000)
        return startTick + offset
    }

    ; 从指定时间戳减去指定毫秒数
    static SubMs(ms, startTick?) {
        return this.AddMs(-ms, startTick?)
    }
}

HiResTimer.Init()
LoadConfigAndStateMaps()
InitSettings()

; 退出回调
ExitFunc(ExitReason, ExitCode) {
    global g_DetectTimer, g_LogicTimer
    if g_DetectTimer {
        SetTimer(DetectExecuter, 0)
        g_DetectTimer := 0
    }
    if g_LogicTimer {
        SetTimer(LogicExecuter, 0)
        g_LogicTimer := 0
    }
    ; 根据模式释放资源
    FastMemoryCapture.Release()
}

^F11:: {
    global g_SysState, g_DetectTimer, g_LogicTimer, g_LogicEnabled
    if (g_SysState == SYS_STANDBY) {
        g_SysState := SYS_ACTIVE
        g_DetectTimer := SetTimer(DetectExecuter, DETECT_INTERVAL)
    } else {
        if g_LogicTimer {
            SetTimer(LogicExecuter, 0)
            g_LogicTimer := 0
        }
        g_LogicEnabled := false
        if g_DetectTimer {
            SetTimer(DetectExecuter, 0)
            g_DetectTimer := 0
        }
        g_SysState := SYS_STANDBY
    }
}

#HotIf (g_SysState == SYS_ACTIVE)
XButton2:: {
    global g_LogicEnabled, g_LogicTimerFunc,  g_FirstExecutionInThisPress, g_FirstSoulflareApplied
    if g_LogicEnabled       ; 防重按
        return
    g_LogicEnabled := true
    if (!g_FirstSoulflareApplied) {
        g_FirstExecutionInThisPress := true
    }
    if !g_LogicTimerFunc
        g_LogicTimerFunc := LogicExecuter.Bind()
    ; 立即执行一次，并安排下一次自循环
    SetTimer(g_LogicTimerFunc, -1)
}
XButton2 Up:: {
    global g_LogicEnabled
    g_LogicEnabled := false
    ; 无需操作定时器，正在排队的下一个回调会自己检查标志并退出
}
#HotIf

#HotIf (g_SysState == SYS_ACTIVE)
XButton1:: {
    SendInput '^{Numpad9}'
}
#HotIf

; 重载脚本 (Ctrl+Alt+F5)
^F5::Reload

; 一键启动脚本 (Ctrl+Alt+F1)
^F1:: {
    global g_SysState, g_DetectTimer, DETECT_INTERVAL
    if (g_SysState != SYS_ACTIVE) {
        g_SysState := SYS_ACTIVE
        g_DetectTimer := SetTimer(DetectExecuter, DETECT_INTERVAL)
        ToolTip("脚本已激活", 0, 0)
        SetTimer(() => ToolTip(), -1000)
    }
}

; 3從釋放到第一次命中大約要0.2s~0.3s(注意！！！)
; 

