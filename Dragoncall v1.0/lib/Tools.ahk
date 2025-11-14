#Requires AutoHotkey v2.0

CoordMode("Pixel", "Screen")
CoordMode("ToolTip", "Screen")

; ---------- 获取鼠标位置 ----------
GetMousePosXY() {
    x := 0, y := 0
    MouseGetPos(&x, &y)
    return {x: x, y: y}
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

;-----------------------------------------------------------
; 辅助：欧氏距离（照搬你原来逻辑，省掉开根号）
ColorDist(c1, c2){
    dr := (c1>>16 & 0xFF) - (c2>>16 & 0xFF)
    dg := (c1>>8  & 0xFF) - (c2>>8  & 0xFF)
    db := (c1      & 0xFF) - (c2      & 0xFF)
    return dr*dr + dg*dg + db*db
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


; ========== DLL加载 ==========
; 加载ColorMatch.dll - 修正路径
global dllPath := A_ScriptDir "\lib\Tools.dll"
global hColorMatchDLL := DllCall("LoadLibrary", "Str", dllPath, "Ptr")
if (!hColorMatchDLL) {
    MsgBox "无法加载 Tools.dll！请确保DLL文件在正确位置。`n路径: " dllPath
    ExitApp
}

; 获取DLL函数地址
global pIsColorMatchAt_Opt := DllCall("GetProcAddress", "Ptr", hColorMatchDLL, "AStr", "IsColorMatchAt_Opt", "Ptr")
global pColorDist := DllCall("GetProcAddress", "Ptr", hColorMatchDLL, "AStr", "ColorDist", "Ptr")

if (!pIsColorMatchAt_Opt || !pColorDist) {
    MsgBox "无法在DLL中找到函数！"
    DllCall("FreeLibrary", "Ptr", hColorMatchDLL)
    ExitApp
}


; ========== 包装DLL函数 ==========


IsColorMatchAt_Opt(pos, color, tol:=0, mask:=0xF8F8F8) {
    global isDLL
    if(isDLL){
        return FastIsColorMatchAt(pos, color, tol, mask)  ; 现在这个就是DLL版本
    }else{
        ; 备用AHK版本（如果需要的话）
        c := PixelGetColor(pos.x, pos.y, "RGB")
        if (tol > 0)
            return ColorDist(c, color) <= tol
        return (c & mask) == (color & mask)
    }
}

FastIsColorMatchAt(pos, color, tol:=0, mask:=0xF8F8F8) {
    global pIsColorMatchAt_Opt
    return DllCall(pIsColorMatchAt_Opt, 
                  "Int", pos.x, 
                  "Int", pos.y,  
                  "UInt", color,
                  "Int", tol,
                  "UInt", mask,
                  "Int")
}


ColorDist_(c1, c2) {
    global pColorDist
    
    ; 调用DLL函数
    result := DllCall(pColorDist,
                     "UInt", c1,       ; 颜色1
                     "UInt", c2,       ; 颜色2
                     "Int")            ; 返回值类型
    
    return result
}

OnExit(*) {
    global hColorMatchDLL
    if (hColorMatchDLL) {
        DllCall("FreeLibrary", "Ptr", hColorMatchDLL)
    }
}

