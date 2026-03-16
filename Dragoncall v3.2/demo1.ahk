#Requires AutoHotkey v2.0

CoordMode("Pixel", "Screen")
CoordMode("ToolTip", "Screen")

global ToggleHotKey := Map() ; 热键管理
global RunningStatus := Map() ; 运行状态管理
global SkillColor := Map() ; 技能坐标管理
global SkillPos := Map() ; 技能颜色管理
global BasicParam := Map() ; 基础参数管理
global EnableSkill := Map() ; 技能开关管理
global SkillCondition := Map() ; 技能条件管理
global SkillStatus := Map() ; 技能状态管理，事件驱动
global TargetCache := Map() 
global focus_refL := Map()
global focusTable := Map()


InitSkillCondition(){
    global SkillCondition
    SkillCondition['Mantra'] := Map()
    SkillCondition['Rupture'] := Map()

    SkillCondition['Mantra']['normal'] := 6
    SkillCondition['Mantra']['leech'] := 4 
    SkillCondition['Mantra']['soulflare'] := 3

    SkillCondition['Rupture']['normal'] := 5
    SkillCondition['Rupture']['leech'] := 3
    SkillCondition['Rupture']['soulflare'] := 1

}

InitEnableSkill(){
    global EnableSkill
    EnableSkill['Mantra'] := true
    EnableSkill['Rupture'] := true
}

InitBasicParam(){
    global BasicParam
    BasicParam['LoopDelay'] := 2 
}

InitHotKeys(){
    global ToggleHotKey
    ToggleHotKey['StartOrStop'] := '^F11' ; isRunning 切换热键
    ToggleHotKey['Toggle'] := 'XButton2' ; isHolding 热键
    ToggleHotKey['Dogge'] := 'XButton1'
    ToggleHotKey['ShowOrHide'] := '^F3'  ; isShowing 切换热键
    ToggleHotKey['Reload'] := '^F5'
}



InitRunningStatus(){
    global RunningStatus
    RunningStatus['isRunning'] := false
    RunningStatus['isHolding'] := false
    RunningStatus['isShowing'] := false
}

InitSkillPointAndColor(){
    global SkillColor, SkillPos
    ; 暴魔靈 
    SkillColor['Dragoncall'] := 0x174980
    SkillPos['Dragoncall'] := {x: 935, y: 963}
    
    ; 死靈突襲 
    SkillColor['Wingstorm'] := 0x1CA8D4
    SkillPos['Wingstorm'] := {x: 1117, y: 965}
    
    ; 降臨
    SkillColor['SoulFlare1'] := 0x00379b
    SkillPos['SoulFlare1'] := {x: 782, y: 630}
    
    SkillColor['SoulFlare2'] := 0x00379b
    SkillPos['SoulFlare2'] := {x: 734, y: 630}
    
    SkillColor['SoulFlare3'] := 0x00379b
    SkillPos['SoulFlare3'] := {x: 686, y: 630}
    
    ; 掠夺
    SkillColor['Leech1'] := 0x192953
    SkillPos['Leech1'] := {x: 773, y: 621}
    
    SkillColor['Leech2'] := 0x192953
    SkillPos['Leech2'] := {x: 725, y: 621}
    
    SkillColor['Leech3'] := 0x192953
    SkillPos['Leech3'] := {x: 677, y: 621}
    
    ; 掠奪1点方向
    SkillColor['Leech_Dir1'] := 0x799EF1
    SkillPos['Leech_Dir1'] := {x: 1203, y: 616}
    
    ; 掠奪11点方向
    SkillColor['Leech_Dir11'] := 0x1C74F0
    SkillPos['Leech_Dir11'] := {x: 1208, y: 605}
    
    ; 真言
    SkillColor['Mantra'] := 0x00A5D3
    SkillPos['Mantra'] := {x: 1158, y: 973}
    
    ; 破裂
    SkillColor['Rupture_Dir1'] := 0x21B8F0
    SkillPos['Rupture_Dir1'] := {x: 1203, y: 606}
    
    SkillColor['Rupture_Dir11'] := 0xA717D6
    SkillPos['Rupture_Dir11'] := {x: 1207, y: 603}
    
    ; 焦点表格 (focusTbl)
    global focusTable := Map()
    focusTable[1]  := {x: 823, y: 893, c: 0xFEFFFF}
    focusTable[2]  := {x: 852, y: 893, c: 0xFEFFFF}
    focusTable[3]  := {x: 882, y: 893, c: 0xFEFFFF}
    focusTable[4]  := {x: 911, y: 893, c: 0xFEFFFF}
    focusTable[5]  := {x: 941, y: 893, c: 0xFEFFFF}
    focusTable[6]  := {x: 970, y: 893, c: 0xFEFFFF}
    focusTable[7]  := {x:1000, y: 893, c: 0xFEFFFF}
    focusTable[8]  := {x:1029, y: 893, c: 0xFEFFFF}
    focusTable[9]  := {x:1059, y: 893, c: 0xFEFFFF}
    focusTable[10] := {x:1088, y: 893, c: 0xFEFFFF}

}

InitSkillStatus(){
    global SkillStatus
    SkillStatus['Dragoncall'] := false
    SkillStatus['Wingstorm'] := false
    SkillStatus['IsSoulflare'] := false
    SkillStatus['IsLeech'] := false
    SkillStatus['Leech'] := false
    SkillStatus['Rupture'] := false
    SkillStatus['Mantra'] := false
}


InitConfig(){
    InitBasicParam()
    InitRunningStatus()
    InitHotKeys()
    InitEnableSkill()
    InitSkillCondition()
    InitSkillPointAndColor()
    InitTargetCache()
}

InitTargetCache(){
    global TargetCache, SkillColor, focusTable, focus_refL
    if (!TargetCache){
        TargetCache := Map()
    }
    for id, value IN SkillColor{
        color := Integer(SkillColor[id])
        r1 := (color >> 16) & 0xFF
        g1 := (color >> 8) & 0xFF
        b1 := color & 0xFF
        TargetCache[id] := {red:r1, blue:b1, green:g1}
    }

    for id, value IN focusTable{
        color := 0xFEFFFF
        local refL := ((color >> 16) & 0xFF) * 0.2126 + ((color >> 8) & 0xFF) * 0.7152 + (color & 0xFF) * 0.0722
        focus_refL[id] := refL
    }
}


mock(){
    InitConfig()

    local colors := Map()

    local start := A_TickCount
    
    ; 遍历所有坐标
    colors := GetRegionColors(SkillPos)

    text:=''
    for id, value IN colors{
        target := TargetCache[id]
        res := IsColorCache(target, value)
        if (res)
            continue
        local temp := 'res: ' res  ' ,skillName: ' id  ',colors: {red:' value.red ',blue:' value.blue ',green:' value.green '}, ' 'target: {red:' target.red ',blue:' target.blue ',green:' target.green '}'  
        text.= temp '`n'
    }
    local end := A_TickCount
    text := 'delay: ' (end-start) ', color: `n' text



    MsgBox(text)
    text := ''
    local start := A_TickCount
    local cnt := 0
    loop 2 {
        number := Random(1, 10)
        text .= 'result_' cnt ':' isLowFocus(number) '`n'
        cnt++
    }
    local end := A_TickCount

    MsgBox('delay: ' (end-start) ', ' text)

    
}

isLowFocus(number := 10) {
    global focus_refL, focusTable
    if (number < 1 || number > 10)
        return false

    local actC := PixelGetColor(focusTable.Get(number).x, focusTable.Get(number).y, "RGB")

    local refL := focus_refL[number]
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
        ; alpha := NumGet(bitmapData, offset + 3, "UChar") ; 字节3: Alpha
        
        ; 转换为 RGB 格式：0xRRGGBB
        ; rgbColor := (red << 16) | (green << 8) | blue
        ; color1 := Integer(Format("0x{:06X}", rgbColor))
        ; r1 := (color1 >> 16) & 0xFF
        ; g1 := (color1 >> 8) & 0xFF
        ; b1 := color1 & 0xFF
        colors[skillName] := {red:red, blue:blue, green:green} 
        ; colors[skillName] := color1
    }
    
    ; 清理资源
    DllCall("DeleteObject", "Ptr", hBitmap)
    DllCall("DeleteDC", "Ptr", hdcMem)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdcScreen)
    
    return colors
}


; mock()