#Requires AutoHotkey v2.0

#Include DLLExport.ahk
#Include ../Param/Config.ahk
#Include ../Param/ColorPick.ahk

#Include Test.ahk

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

; ; ---------- 判断指定位置颜色是否匹配 ----------


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
IsColorMatchAt_AHK(pos, color, tol:=0, mask:=0xF8F8F8){
    c := PixelGetColor(pos.x, pos.y, "RGB")   ; 取屏幕色
    if (tol > 0)                              ; 老规矩：欧氏距离
        return ColorDist(c, color) <= tol
    ; 新功能：掩码容错
    return (c & mask) == (color & mask)
}


; ========== 包装DLL函数 ==========


IsColorMatchAt(pos, color, tol:=0, mask:=0xF8F8F8) {
    global isTest
    ; if (isTest)
    ;     return IsColorMatchAt_Test(pos, color, tol, mask)
    global isDLL
    if(isDLL){
        return IsColorMatchAt_DLL(pos, color, tol, mask)  ; 现在这个就是DLL版本
    }else{
        return IsColorMatchAt_AHK(pos, color, tol, mask)
    }
}




IsLowFocus_AHK(number := 10) {
    if (number < 1 || number > 10)
        return false
    
    local p := focusTbl[number]
    local actC := PixelGetColor(p.x, p.y, "RGB")
    
    ; 计算参考颜色的亮度（ITU-R BT.709）
    local refL := ((p.c >> 16) & 0xFF) * 0.2126
               + ((p.c >> 8)  & 0xFF) * 0.7152
               + ( p.c        & 0xFF) * 0.0722
    
    ; 计算实际颜色的亮度
    local actL := ((actC >> 16) & 0xFF) * 0.2126
               + ((actC >> 8)  & 0xFF) * 0.7152
               + ( actC        & 0xFF) * 0.0722
    
    ; 比参考颜色暗表示内力不足
    return actL < refL
}

IsLowFocus(number := 10) {
    return IsLowFocus_AHK(number)
}


