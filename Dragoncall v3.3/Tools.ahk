#Requires AutoHotkey v2.0

#Include CalCache.ahk

global DefaultConfigFilePath := A_ScriptDir "\config.ini"


isLowFocus(number := 10) {
    global FocusCache, FocusPos
    if (number < 1 || number > 10)
        return false

    local actC := PixelGetColor(FocusPos.Get(number).x, FocusPos.Get(number).y, "RGB")

    local refL := FocusCache[number]
    local actL := ((actC >> 16) & 0xFF) * 0.2126
        + ((actC >> 8) & 0xFF) * 0.7152
        + ( actC & 0xFF) * 0.0722
    ; MsgBox(refL ' , ' actL)
    return actL < refL
}

IsColorCache(target, result, tolerance := 10) {
    r1 := target.red
    g1 := target.green
    b1 := target.blue
    
    r2 := result.red
    g2 := result.green
    b2 := result.blue
    
    ; 计算欧几里得距离
    distance := Sqrt((r1 - r2) ** 2 + (g1 - g2) ** 2 + (b1 - b2) ** 2)
    return distance <= tolerance
}

GetRegionColors(positions) {
    ; 找出坐标范围
    minX := 9999, maxX := 0, minY := 9999, maxY := 0
    for skillName, pos in positions {
        if (pos.x < minX) 
            minX := pos.x
        if (pos.x > maxX) 
            maxX := pos.x
        if (pos.y < minY) 
            minY := pos.y
        if (pos.y > maxY) 
            maxY := pos.y
    }
    ; MsgBox('MIN:' minX "," minY " MAX:" maxX "," maxY)
    
    width := maxX - minX + 1
    height := maxY - minY + 1
    
     ; 创建设备上下文
    hdcScreen := DllCall("GetDC", "Ptr", 0, "Ptr")
    hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdcScreen, "Ptr")
    hBitmap := DllCall("CreateCompatibleBitmap", "Ptr", hdcScreen, "Int", width, "Int", height, "Ptr")
    DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hBitmap)
    
    ; 复制屏幕区域
    DllCall("BitBlt", "Ptr", hdcMem, "Int", 0, "Int", 0, "Int", width, "Int", height,
                    "Ptr", hdcScreen, "Int", minX, "Int", minY, "UInt", 0x00CC0020)
    
    ; 使用32位格式（更可靠）
    bitmapData := Buffer(4 * width * height)
    
    bi := Buffer(40, 0)
    NumPut("UInt", 40, bi, 0)
    NumPut("Int", width, bi, 4)
    NumPut("Int", -height, bi, 8)
    NumPut("UShort", 1, bi, 12)
    NumPut("UShort", 32, bi, 14)    ; 32位
    NumPut("UInt", 0, bi, 16)       ; BI_RGB
    
    DllCall("GetDIBits", "Ptr", hdcScreen, "Ptr", hBitmap, "UInt", 0, "UInt", height,
                    "Ptr", bitmapData, "Ptr", bi, "UInt", 0)
    
    ; 获取每个坐标的颜色
    colors := Map()
    for skillName, pos in positions {
        relX := pos.x - minX
        relY := pos.y - minY
        offset := (relY * width + relX) * 4
        
        ; 32位格式：GetDIBits 返回的是 BGRA（当 biCompression=BI_RGB）
        ; 字节顺序：Blue, Green, Red, Alpha
        
        blue  := NumGet(bitmapData, offset, "UChar")      ; 字节0: Blue
        green := NumGet(bitmapData, offset + 1, "UChar")  ; 字节1: Green
        red   := NumGet(bitmapData, offset + 2, "UChar")  ; 字节2: Red

        colors[skillName] := {red:red, blue:blue, green:green} 
    }
    
    ; 清理资源
    DllCall("DeleteObject", "Ptr", hBitmap)
    DllCall("DeleteDC", "Ptr", hdcMem)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)
    
    return colors
}

readConfig(Section, Key, Path:=DefaultConfigFilePath){
    result := IniRead(DefaultConfigFilePath, Section, Key)
    return result
}

readPosConfig(Section, Key, Path:=DefaultConfigFilePath){
    posStr := IniRead(DefaultConfigFilePath, Section, Key)
    if (posStr = "")
        return {x: 0, y: 0} ; 默认值
    coords := StrSplit(posStr, ",")
    if (coords.Length != 2)
        return {x: 0, y: 0} ; 格式错误，返回默认值
    return {x: coords[1], y: coords[2]}
}

readColorConfig(Section, Key, Path:=DefaultConfigFilePath){
    return readConfig(Section, Key, Path)
}

readBarSpaceConfig(Section, Key, Path:=DefaultConfigFilePath){
    return readConfig(Section, Key, Path)
}

readBuffsNumberConfig(Section, Key, Path:=DefaultConfigFilePath){
    return readConfig(Section, Key, Path)
}