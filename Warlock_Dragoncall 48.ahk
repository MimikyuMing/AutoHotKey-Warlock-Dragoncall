#Requires AutoHotkey v2.0.19

#HotIf WinActive("ahk_exe BNSR.exe")

CoordMode("Pixel", "Screen")
CoordMode("ToolTip", "Screen")

; --配置--
TOGGLE_KEY := "^F11" ; 宏启动 快捷键
HOLD_KEY_1 := "XButton2" ; 卡刀 快捷键
HOLD_KEY_2 := "XButton1" ; ss 快捷键
RELOAD_KEY := "^F5" ; 重载脚本 快捷键
SHOW_MOUSEPOS_KEY := "^F1" ; 获取鼠标坐标 快捷键
SHOW_MOUSEPOS_KEY2 := "^F2" ; 获取指定位置颜色 快捷键

; --参数--
running := false  
holding := false
toggleSleepTime := 1
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

Hotkey SHOW_MOUSEPOS_KEY2, GetPosPixelColor
GetPosPixelColor(*){
    text := ""
    lastText := ""
    file := A_ScriptDir "\HSV.txt" 
    mode := "w"          ; "a"=追加  "w"=覆盖
    static focusTbl := Map(
        1,  {x: 823, y: 894, c: 0xFDFEFE},
        2,  {x: 852, y: 894, c: 0xFDFEFE},
        3,  {x: 884, y: 894, c: 0xFDFEFE},
        4,  {x: 913, y: 894, c: 0xFEFFFF}, ;
        5,  {x: 941, y: 894, c: 0xFDFEFE},
        6,  {x: 968, y: 894, c: 0xFDFEFE},
        7,  {x:997, y: 894, c: 0xFDFEFE},
        8,  {x:1026, y: 894, c: 0xFEFFFF}, ;
        9,  {x:1055, y: 894, c: 0xFDFEFE},
        10, {x:1084, y: 894, c: 0xFDFEFE}
    )
    for index in focusTbl {
        RGB := GetPixelColorAt(focusTbl[index].x, focusTbl[index].y).hex
        text := index ", {x:" focusTbl[index].x ",y:" focusTbl[index].y ",c:" RGB "},`n"
        lastText .= text
    }
    WriteFile(file, lastText, mode)
}

GetPixelRGB(x, y) {
    ; 0x00BBGGRR → 拆成 R,G,B
    c := DllCall("GetPixel", "ptr", DllCall("GetDC", "ptr", 0, "ptr")
                           , "int", x, "int", y, "uint")
    DllCall("ReleaseDC", "ptr", 0, "ptr", DllCall("GetDC", "ptr", 0, "ptr"))
    return { r: c & 0xFF
           , g: (c >> 8) & 0xFF
           , b: (c >> 16) & 0xFF
           , rgb: (c & 0xFF) | ((c & 0xFF00) >> 8) | ((c & 0xFF0000) >> 16)   ; 0xRRGGBB
           , hex: Format("0x{:06X}", (c & 0xFF) | ((c & 0xFF00) >> 8) | ((c & 0xFF0000) >> 16)) }
}

; 示例：
; rgb := GetPixelRGB(123, 456)
; MsgBox("R=" rgb.r " G=" rgb.g " B=" rgb.b " hex=" rgb.hex)

WriteFile(path, text, mode := "a"){
    try {
        f := FileOpen(path, mode = "a" ? "a" : "w", "UTF-8")
        f.Write(text)
        f.Close()
        ; ToolTip("已写入： " path, 0, 0)
        ; SetTimer(() => ToolTip(), -1500)
    } catch as e {
        MsgBox("写入失败！`n" e.Message, , "IconX")
    }
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
; 传入整数坐标 x,y 和 0xRRGGBB 颜色，tol 为 0-255 容差
;===========================================================
; 像素颜色比较（支持掩码容错）
;  pos  := {x:?, y:?}
;  color:= 0xRRGGBB
;  tol  := 0  时 → 用掩码（默认 0xF8F8F8）
;  tol  >0  时 → 用欧氏距离容差（老逻辑）
;  mask := 当 tol=0 时生效，可自定义掩码位
;===========================================================
IsColorMatchAt(pos, color, tol:=0, mask:=0xF8F8F8){
    c := PixelGetColor(pos.x, pos.y, "RGB")   ; 取屏幕色
    if (tol > 0)                              ; 老规矩：欧氏距离
        return ColorDist(c, color) <= tol
    ; 新功能：掩码容错
    return (c & mask) == (color & mask)
}

;-----------------------------------------------------------
; 辅助：欧氏距离（照搬你原来逻辑，省掉开根号）
ColorDist(c1, c2){
    dr := (c1>>16 & 0xFF) - (c2>>16 & 0xFF)
    dg := (c1>>8  & 0xFF) - (c2>>8  & 0xFF)
    db := (c1      & 0xFF) - (c2      & 0xFF)
    return dr*dr + dg*dg + db*db
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
    while (holding){
        MainLoop()
        DllCall("SwitchToThread") ; 0 成本让出时间片
    }
}
HoldUp(*) {
    if !running
        return
    global holding
    holding := false
    SetTimer MainLoop, -1
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
    ; 15s超神极限右键次数: 36   
    
                
    
    static lastTS := 0, cnt := 0, loopPerSec := 0  
    ;---- 2. 死循环：最快释放 ----
    /*-------- 2. 死循环：极限频率 --------*/
    while holding {
        isSoulFlare := 
            IsColorMatchAt(pos_tab, Color_tab) || 
            IsColorMatchAt(pos_tab_2, Color_tab_2) || 
            IsColorMatchAt(pos_tab_3, Color_tab_3)
        Dragoncall := 0, Wingstorm := 0, Leech := 0, Mantra := 0, Rupture := 0, Mantra_SoulFlare :=0 , Rupture_SoulFlare :=0
        cnt++
        /*---- 按需采样 + 立即执行 ----*/
        if (Dragoncall := IsColorMatchAt(pos_4_instant, Color_4_instant)){
            Send '4'
            Send 't'
        }
        else if (Wingstorm := IsColorMatchAt(pos_v, Color_v_instant)){
            Send 'v'
            Send 't'
        }
        else if (Leech := IsColorMatchAt(pos_f_2, Color_f_2)){
            Send 'f'
        }
        else if (!isSoulFlare && IsLowFocus_2(6) && IsColorMatchAt(pos_r_2, Color_r_2)) {
            ; 非降临：内力 ≤ 6 格，打真言
            Send 'r'
        } else if (isSoulFlare && IsLowFocus_2(4) && IsColorMatchAt(pos_r_2, Color_r_2)) {
            ; 降临：内力 ≤ 4 格，打真言
            Send 'r'
        } else if (!isSoulFlare && IsColorMatchAt(pos_f, Color_f)) {
            ; 非降临：内力 ≤ 3 格，打破裂
            Send 'f'
            Send 't'
        } else if (isSoulFlare && IsLowFocus_2(1) && IsColorMatchAt(pos_f, Color_f)) {
            ; 降临：内力 ≤ 1 格，打破裂
            Send 'f'
            Send 't'
        }
        else {
            Send 't'          ; 最低优先级
        }
        
        ts := A_TickCount
        if (ts - lastTS >= 1000) {
            lastTS := ts
            loopPerSec := cnt
            cnt      := 0
        }

        ToolTip(
            "Loop/s: " loopPerSec "`n"
            "Dragoncall:" (Dragoncall ? "1" : "0") "`n"
            "Wingstorm:" (Wingstorm  ? "1" : "0") "`n"
            "Leech:" (Leech      ? "1" : "0") "`n"
            "Mantra:" (Mantra     ? "1" : "0") "  "
            "Mantra_SoulFlare:" (Mantra_SoulFlare) "`n"
            "Rupture:" (Rupture    ? "1" : "0") "  "
            "Rupture_SoulFlare:" (Rupture_SoulFlare) "`n"
            "isSoulFlare:" (isSoulFlare? "1" : "0") "`n"
            ,
            0 , 1080
        )

        /*---- 让步：CPU 占用 1-3% ----*/
        DllCall("SwitchToThread")
    }

}

; ---------- 內力判斷 !棄用! ----------
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
    return !IsColorMatchAt(focusTbl[number], focusTbl[number].c, 52)

}

; ---------- 內力判斷 ----------
; ------------------------------------------------------------------
; 判断第 number 格内力是否“足够亮”
; 亮度 ≤ 参考亮度  → 返回 false
; 亮度 > 参考亮度  → 继续走原颜色匹配逻辑
; ------------------------------------------------------------------
IsLowFocus_2(number := 10) {
    static focusTbl := Map(
        1,  {x: 823, y: 893, c: 0xFEFFFF},
        2,  {x: 852, y: 893, c: 0xFEFFFF},
        3,  {x: 882, y: 893, c: 0xFEFFFF},
        4,  {x: 911, y: 893, c: 0xFEFFFF},
        5,  {x: 941, y: 893, c: 0xFEFFFF},
        6,  {x: 970, y: 893, c: 0xFEFFFF},
        7,  {x:1000, y: 893, c: 0xFEFFFF},
        8,  {x:1029, y: 893, c: 0xFEFFFF},
        9,  {x:1059, y: 893, c: 0xFEFFFF},
        10, {x:1088, y: 893, c: 0xFEFFFF}
    )

    if (number < 1 || number > 10){
         return false
    }
    p := focusTbl[number]
    actC := PixelGetColor(p.x, p.y, "RGB")

    ; 计算亮度（ITU-R BT.709）
    refL := ((p.c >> 16) & 0xFF) * 0.2126
          + ((p.c >> 8)  & 0xFF) * 0.7152
          + ( p.c        & 0xFF) * 0.0722

    actL := ((actC >> 16) & 0xFF) * 0.2126
          + ((actC >> 8)  & 0xFF) * 0.7152
          + ( actC        & 0xFF) * 0.0722

    return actL < refL   ; 只要比参考暗就 true
}

