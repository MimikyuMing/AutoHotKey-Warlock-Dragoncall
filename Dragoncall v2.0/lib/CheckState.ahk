#Requires AutoHotkey v2.0

#Include Tools\Tools.ahk

; ---------按需检测---------
global FrameStates := Map()

InitFrameStates(){
    global FrameStates
     ; 确保 FrameStates 是 Map 类型
    if (Type(FrameStates) != "Map") {
        FrameStates := Map()
    }
    
    local allKeys := [
        "Tab1", "Tab2", "Tab3",
        "Dragoncall_Instant", "Wingstorm_Instant", 
        "Leech1", "Leech2", "Leech3",
        "Mantra", "Rupture1", "Rupture11", 
        "LeechDir1", "LeechDir11"
    ]
    
    ; 将所有状态初始化为 false
    for key in allKeys {
        FrameStates[key] := false
    }
}


; 瞬发技能状态检测
CheckInstant_DragoncallStates() {
    global FrameStates
    FrameStates["Dragoncall_Instant"] := IsColorMatchAt(pos_4_instant, Color_4_instant)
}

CheckInstant_WingstormStates() {
    global FrameStates
    FrameStates["Wingstorm_Instant"] := IsColorMatchAt(pos_v, Color_v_instant)
}

; 降临状态检测
CheckSoulFlareState() {
    global FrameStates, isSoulFlare
    FrameStates["Tab1"] := IsColorMatchAt(pos_tab, Color_tab)
    if (FrameStates["Tab1"]) {
        isSoulFlare := true
        FrameStates["Tab2"] := false
        FrameStates["Tab3"] := false
    } else {
        FrameStates["Tab2"] := IsColorMatchAt(pos_tab_2, Color_tab_2)
        if (FrameStates["Tab2"]) {
            isSoulFlare := true
            FrameStates["Tab3"] := false
        } else {
            FrameStates["Tab3"] := IsColorMatchAt(pos_tab_3, Color_tab_3)
            isSoulFlare := FrameStates["Tab3"]
        }
    }
}

; 掠夺状态检测
CheckLeechState() {
    global FrameStates, isLeech
    FrameStates["Leech1"] := IsColorMatchAt(pos_leech_1, Color_leech_1)
    if (FrameStates["Leech1"]) {
        isLeech := true
        FrameStates["Leech2"] := false
        FrameStates["Leech3"] := false
    } else {
        FrameStates["Leech2"] := IsColorMatchAt(pos_leech_2, Color_leech_2)
        if (FrameStates["Leech2"]) {
            isLeech := true
            FrameStates["Leech3"] := false
        } else {
            FrameStates["Leech3"] := IsColorMatchAt(pos_leech_3, Color_leech_3)
            isLeech := FrameStates["Leech3"]
        }
    }
}

; 掠夺CD检测
CheckLeechCD() {
    global FrameStates
    FrameStates["LeechDir11"] := IsColorMatchAt(pos_f_2_11, Color_f_2_11)
    if (!FrameStates["LeechDir11"]) {
        FrameStates["LeechDir1"] := IsColorMatchAt(pos_f_2, Color_f_2)
    } else {
        FrameStates["LeechDir1"] := false
    }
}

; 仅检测真言（内力极低时快速检测）
CheckMantra() {
    global FrameStates
    FrameStates["Mantra"] := IsColorMatchAt(pos_r_2, Color_r_2)
}

; 仅检测破裂（内力不足时快速检测）
CheckRupture() {
    global FrameStates
    FrameStates["Rupture11"] := IsColorMatchAt(pos_f_11, Color_f_11)
    if (!FrameStates["Rupture11"]) {
        FrameStates["Rupture1"] := IsColorMatchAt(pos_f, Color_f)
    } else {
        FrameStates["Rupture1"] := false
    }
}