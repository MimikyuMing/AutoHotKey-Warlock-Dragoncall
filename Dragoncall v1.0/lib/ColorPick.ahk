#Requires AutoHotkey v2.0

; 取色

; 暴魔靈 
Color_4_instant := 0x174980 ; 瞬发
pos_4_instant := {x: 935, y: 963}

Color_4_NonInstant := 0xac5ad5 ; 
pos_4_NonInstant := {x: 930, y: 963}

Color_4_Blank := 0x454545 ; 
pos_4_Blank := {x: 930, y: 963}

; 死靈突襲 
Color_v_instant := 0x1CA8D4 ; 瞬發
pos_v := {x: 1117, y: 965}

Color_v_NonInstant := 0x7802ae ; 
pos_v_NonInstant := {x: 1111, y: 963}

; 降臨
Color_tab := 0x00379b
pos_tab := {x: 782, y: 630}

Color_tab_2 := 0x00379b ; 
pos_tab_2 := {x: 734, y: 630}

Color_tab_3 := 0x00379b ; 
pos_tab_3 := {x: 686, y: 630}

; 掠夺
Color_leech_1 := 0x192953 
pos_leech_1 := {x: 773, y: 621}

Color_leech_2 := 0x192953 ; 
pos_leech_2 := {x: 725, y: 621}

Color_leech_3 := 0x192953 ; 
pos_leech_3 := {x: 677, y: 621}

; 掠奪1点方向
Color_f_2 := 0x799EF1 
pos_f_2 := {x: 1203, y: 616}

; 掠奪11点方向
Color_f_2_11 := 0x1C74F0 
pos_f_2_11 := {x: 1208, y: 605}

; 真言
Color_r_2 := 0x00A5D3 ; 真言 ok
pos_r_2 := {x: 1158, y: 973}

Color_f := 0x21B8F0 ; 破裂 1點
pos_f := {x: 1203, y: 606}

; 破裂 11點
Color_f_11 := 0xA717D6 ; 破裂 11點
pos_f_11 := {x: 1207, y: 603}



Color_t := 0x2d2d2d ; 
pos_t := {x: 1206, y: 970}

Color_Imprison := 0xE98D0F ; 開門讀條
pos_Imprison := {x: 923, y: 847}

isSoulFlare := false

; ---------- text ----------
Color_ss := 0X2d4869 ; ss
pos_ss := {x: 668, y: 963}

focusTbl := Map(
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