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
    ; ReloadScript()
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
    if !running
        return
    global holding
    holding := true
    SetTimer MainLoop, toggleSleepTime
}
HoldUp(*) {
    if !running
        return
    global holding
    holding := false
    SetTimer MainLoop, 0
}

; 取色
Color_4_instant := 0x174980 ; 瞬发暴魔靈 ok
pos_4_instant := {x: 935, y: 963}

Color_v_instant := 0x1CA8D4 ; 瞬發死靈突襲 ok
pos_v := {x: 1117, y: 965}

Color_tab := 0x001a52 ; 降臨
pos_tab := {x: 769, y: 630}

Color_tab_2 := 0x067EB3 ; 
pos_tab_2 := {x: 726, y: 635}

Color_tab_3 := 0x067EB3 ; 
pos_tab_3 := {x: 726, y: 635}


Color_r_2 := 0x00A5D3 ; 真言 ok
pos_r_2 := {x: 1158, y: 973}

Color_f := 0x21B8F0 ; 破裂
pos_f := {x: 1203, y: 606}


Color_f_2 := 0x799EF1 ; 掠奪
pos_f_2 := {x: 1203, y: 616}
; text:0X2d4869 668 963

Color_t := 0x18A5E3 ; 次元彈 ok
pos_t := {x: 1212, y: 969}

; focus 內力判斷

Color_3focus := 0x2C87B4 ; 3格
pos_3focus := {x: 888, y: 897}

Color_5focus := 0x2A7EAB ;  5格
pos_5focus := {x: 946, y: 901}

Color_1focus := 0x2C89B7 ;  5格
pos_1focus := {x: 828, y: 899}

isSoulFlare := false

; ---------- text ----------
Color_ss := 0X2d4869 ; ss
pos_ss := {x: 668, y: 963}

/**
 * 918,845
 * 0xEDB062
 */

; ---------- 循环逻辑 ----------

/*
    降臨/開門/死靈突襲/暴魔靈/真言/次元彈/掠奪/破裂
    1.瞬發狀態下,優先執行暴魔靈+死靈突襲,然後其次打次元彈+破裂
    2.降臨狀態下,只打暴魔靈+死靈突襲+次元彈,降臨情況下不打掠奪,不打破裂
    3.當內力不足一定程度(少於4格)的時候,打真言
    4.沒內的時候(無法打出次元彈),打左鍵

 */

MainLoop(*){
    ; 每次執行一個指令
    global holding
    ; 沒開啟宏的時候,不執行
    if !holding{
        return
    }
    ; 判斷是否處於降臨狀態
    isSoulFlare := 
        IsColorMatchAt(pos_tab, Color_tab) || 
        IsColorMatchAt(pos_tab_2, Color_tab_2) || 
        IsColorMatchAt(pos_tab_3, Color_tab_3)
    Dragoncall := IsColorMatchAt(pos_4_instant, Color_4_instant)
    Wingstorm := IsColorMatchAt(pos_v, Color_v_instant)
    Leech := IsColorMatchAt(pos_f_2, Color_f_2)
    Mantra := IsLowFocus(5) && IsColorMatchAt(pos_r_2, Color_r_2) && !isSoulFlare
    Rupture := IsLowFocus(3) && IsColorMatchAt(pos_f, Color_f) && !isSoulFlare

    ToolTip(
        "Dragoncall: " Dragoncall 
        ",Wingstorm: " Wingstorm 
        ",Leech: " Leech 
        ",Mantra: " Mantra 
        ",Rupture: " Rupture 
        ",isSoulFlare:" isSoulFlare,
         740, 0
        )
    

    ; Dragoncall
    if Dragoncall { ; 瞬發暴魔靈 # 有時候不會立即執行
        Send '4'
        return
    }
    ; Wingstorm
    if Wingstorm { ; 瞬發死靈突襲 # 有時候不會立即執行
        Send 'v'
        return
    }
    ; Leech
    if Leech { ; 掠奪
        Send 'f'
        return
    }
    ; Mantra
    if Mantra {
        Send 'r'
        return
    }
    ; Rupture
    if Rupture {
        Send 'f'
        return
    }
    ; Bombardment
    Send 't'

}

; ---------- 內力判斷 todo:判断不明确，误差很大 ----------
IsLowFocus(number:=10){ 
    static focusTbl := Map(1, {x:828,y:899,c:0x2C89B7}
                       ,2, {x:856,y:899,c:0x2F8DBC}
                       ,3, {x:886,y:898,c:0x2C86B2}
                       ,4, {x:917,y:899,c:0x2B84B1}
                       ,5, {x:947,y:874,c:0x2C87B4}
                       ,6, {x:974,y:900,c:0x2A82AF}
                       ,7, {x:1007,y:899,c:0x2B84B3}
                       ,8, {x:1034,y:900,c:0x2B85B4}
                       ,9, {x:1064,y:897,c:0x3193C2}
                       ,10, {x:1093,y:900,c:0x2B85B4})
    if (number < 1 || number > 10)
        return false
    ; ToolTip("Focus Check: " number " Focus Color:" Format("0x{:06X}", focusTbl[number].c), 0, 100)
    return !IsColorMatchAt(focusTbl[number], focusTbl[number].c, 0)

}

; 0x3093C1 887 896
