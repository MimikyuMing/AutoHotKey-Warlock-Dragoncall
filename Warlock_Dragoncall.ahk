#Requires AutoHotkey v2.0.19

CoordMode("Pixel", "Screen")
CoordMode("ToolTip", "Screen")

; --配置--
TOGGLE_KEY := "^F11" ; 宏启动 快捷键
HOLD_KEY_1 := "XButton2" ; 卡刀 快捷键
HOLD_KEY_2 := "XButton1" ; ss 快捷键
RELOAD_KEY := "^F5" ; 重载脚本 快捷键
SHOW_MOUSEPOS_KEY := "^F1" ; 获取鼠标坐标 快捷键

; --参数--
running := false  
holding := false
sleepTime := 5
toggleSleepTime := 10
text := ""
tol := 0 

; ---------- 重载脚本 ----------
Hotkey RELOAD_KEY, ReloadScript
ReloadScript(*){
    Reload
}

; ---------- 取当前位置绝对坐标 ----------

; ---------- 获取鼠标位置 ----------
GetMousePosXY() {
    x := 0, y := 0
    MouseGetPos(&x, &y)
    return {x: x, y: y}
}

; ---------- 显示鼠标位置和颜色 ----------
Hotkey SHOW_MOUSEPOS_KEY, ShowMousePos
ShowMousePos(*) {
    pos := GetMousePosXY()
    color := GetPixelColorAt(pos.x, pos.y).hex
    ToolTip("鼠标 X: " pos.x "  Y: " pos.y " color: " color, 0, 0)
    ; 60 秒后隐藏
    SetTimer(ToggleRunning, 0, -60000)
}

; ---------- 获取指定位置颜色 ----------
GetPixelColorAt(x, y) {
    ; 获取屏幕 DC
    hdc := DllCall("GetDC", "ptr", 0, "ptr")
    color := DllCall("GetPixel", "ptr", hdc, "int", x, "int", y, "uint")
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdc)
    ; 提取 RGB 分量（GetPixel 返回的格式为 0x00BBGGRR）
    r := color & 0xFF
    g := (color >> 8) & 0xFF
    b := (color >> 16) & 0xFF
    hex := Format("0x{1:02X}{2:02X}{3:02X}", r, g, b) ; 格式化为 0xRRGGBB
    return {color: color, r: r, g: g, b: b, hex: hex, x: x, y: y}
}

; ---------- 判断指定位置颜色是否匹配 ----------


; 传入整数坐标 x,y 和 0xRRGGBB 颜色，tol 为 0-255 容差
IsColorMatchAt(pos, color, tol := 0) {
    x := pos.x
    y := pos.y
    c := PixelGetColor(x, y, "RGB")          ; 立即取样
    if (c = color)                           ; 完全相等
        return true
    if (tol <= 0)                            ; 不容差且已不等
        return false

    ; 一次拆 RGB 并算平方距离
    dr := (c >> 16 & 0xFF) - (color >> 16 & 0xFF)
    dg := (c >> 8  & 0xFF) - (color >> 8  & 0xFF)
    db := (c       & 0xFF) - (color       & 0xFF)
    return dr*dr + dg*dg + db*db <= tol*tol  ; 省掉 Sqrt
}

; ---------- 启动/停止宏 ----------
Hotkey TOGGLE_KEY, ToggleRunning
ToggleRunning(*){
    global running
    running := !running
    global text
    text := running ? "宏已启动" : "宏已停止"
    CoordMode("ToolTip", "Screen")
    if running{
        ToolTip(text, 0, 0)
    } else {
        ToolTip("")
    }
}

; ---------- ss ----------
Hotkey HOLD_KEY_2, Toggle_SS
Toggle_SS(*){
    global running
    if !running
        return
    Send 's'
    Sleep 50
    Send 's'
}

; ---------- 卡刀 ----------
Hotkey HOLD_KEY_1, HoldDown
Hotkey HOLD_KEY_1 " up", HoldUp

HoldDown(*) {
    global holding
    holding := true
    SetTimer MainLoop, toggleSleepTime
}
HoldUp(*) {
    global holding
    holding := false
    SetTimer MainLoop, 0
}

; 取色
Color_4_instant := 0x174980 ; 瞬发暴魔靈 ok
pos_4_instant := {x: 935, y: 963}

Color_v_instant := 0x1CA8D4 ; 瞬發死靈突襲 ok
pos_v := {x: 1117, y: 965}

Color_tab := 0X001a52 ; 降臨
pos_tab := {x: 769, y: 630}

Color_r := 0xFFFFF2 ; 暫無
pos_r := {x: 462, y: -76}

Color_r_2 := 0x023086 ; 真言 ok
pos_r_2 := {x: 1168, y: 967}

Color_f := 0x9418CE ; 破裂
pos_f := {x: 1213, y: 603}

Color_f_2 := 0x799EF1 ; 掠奪
pos_f_2 := {x: 1203, y: 616}
; text:0X2d4869 668 963

Color_focus_t := 0x0E1921 ; 黑-次元彈 ok
pos_focus_t := {x: 915, y: 892}

Color_t := 0x17A9E8 ; 次元彈 ok
pos_t := {x: 1213, y: 970}

Color_focus := 0x121C25 ; 黑-内力 ok
pos_focus := {x: 918, y: 895}

isSoulFlare := false

global FreezeG1    := false     ; true = 整组被冻结
global LeechX      := pos_f_2   ; 掠夺图标坐标
global LeechRGB    := Color_f_2
global RuptureX    := pos_f     ; 破裂图标坐标
global RuptureRGB  := Color_f


; ---------- text ----------
Color_ss := 0X2d4869 ; ss
pos_ss := {x: 668, y: 963}

; ---------- 循环逻辑 ----------

/*
    降臨/開門/死靈突襲/暴魔靈/真言/次元彈/掠奪/破裂
    1.瞬發狀態下,優先執行暴魔靈+死靈突襲,然後其次打次元彈+破裂
    2.降臨狀態下,只打暴魔靈+死靈突襲+次元彈,降臨情況下不打掠奪,不打破裂
    3.當內力不足一定程度(少於4格)的時候,打真言
    4.沒內的時候(無法打出次元彈),打左鍵

 */
MainLoop(*){
    global holding
    static busy := false
    if !holding or busy
        return
    busy := true
    try{
        SoulFlare()
        Dragoncall()
        Wingstorm()
        if (IsSpecialStatusDetect()) ; 如果暴魔靈/死靈突襲/掠奪/破裂可用則優先處理
            return
        Mantra()
        Bombardment()
    } finally {
        busy := false
    }

    
    
}

; 真言
Mantra(*){
    global pos_r_2, Color_r_2, tol
    if !Focus_Mantra() && IsColorMatchAt(pos_r_2, Color_r_2, tol){ ; 內力滿足一定條件,則釋放真言
        Send 'r'
    } else{
        return
    }
}

; 暴魔靈
Dragoncall(*){
    BeforeSleep()
    global pos_4_instant, Color_4_instant, tol
    if IsColorMatchAt(pos_4_instant, Color_4_instant, tol) { ; 瞬發暴魔靈
        Send '4'
    }
}

; 破裂
Rupture(*){
    BeforeSleep()
    global pos_f, Color_f, tol
    if IsStatusSoulFlare() { ; 降臨狀態下,不打破裂
        return  
    }
    if IsColorMatchAt(pos_f, Color_f, tol) { ; 破裂
        Send 'f'
    }
}

; 死靈突襲
Wingstorm(*){
    BeforeSleep()
    global pos_v, Color_v_instant, tol
    if IsColorMatchAt(pos_v, Color_v_instant, tol) { ; 瞬發死靈突襲
        Send 'v'
    }
}

; 降臨
SoulFlare(*){
    global isSoulFlare, pos_tab, Color_tab, tol
    if IsColorMatchAt(pos_tab, Color_tab, tol) { ; 降臨狀態
        isSoulFlare := true
    } else {
        SoulFlareEnd()
    }
}

SoulFlareEnd(*){
    global isSoulFlare
    isSoulFlare := false
}

; 次元彈
Bombardment(*){
    BeforeSleep()
    global pos_t, Color_t, tol
    if !Focus_R(){ ; 內力滿足一定條件,則釋放次元彈
        Send 't'
    }else{ ; 不滿足則釋放炎爆破
        R()
    }    
}

; 炎爆破
R(*){
    Send 'r'
}

; 內力判斷-真言 內力充足則返回False,否則返回True
Focus_Mantra(*){
    global pos_focus, Color_focus, tol
    if IsColorMatchAt(pos_focus, Color_focus, tol){
        return true
    }else{ 
        return false
    }
} 

; 內力判斷-R 內力充足則返回False,否則返回True
Focus_R(*){
    global pos_focus_t, Color_focus_t, tol
    if IsColorMatchAt(pos_focus_t, Color_focus_t, tol){
        return true
    }else{
        return false
    }
}

; 掠奪
Leech(*){
    BeforeSleep()
    global pos_f_2, Color_f_2, tol
    if IsColorMatchAt(pos_f_2, Color_f_2, tol) { ; 掠奪
        Send 'f'
    }
}

BeforeSleep(sleepTime := 5){
    Sleep sleepTime
}

IsStatusSoulFlare(*){
    global isSoulFlare
    if isSoulFlare{
        return true
    } else {
        return false
    }
}


; 保护机制
IsSpecialStatusDetect(*){
    global tol, FreezeG1, LeechX, LeechRGB

    ; 每帧只查一次掠夺图标 → 决定是否冻结
    leechUp := IsColorMatchAt(LeechX, LeechRGB, tol)
    ruptUp  := IsColorMatchAt(RuptureX, RuptureRGB, tol)
    FreezeG1 := leechUp || ruptUp     ; 任一亮 → 整组冻
    
    ToolTip("Leech:" leechUp "  Rupture:" ruptUp "  Freeze:" FreezeG1, 0, 0)


    ; ① 冻结期：仅允许掠夺
    if (FreezeG1) {
        if (leechUp) {                     ; 掠夺优先
            Leech()
            FreezeG1 := false
            return true
        }
        if (ruptUp) {                      ; 破裂其次
            Rupture()
            FreezeG1 := false
            return true
        }
        return false                       ; 次元弹被挡
    }
}

