#Requires AutoHotkey v2.0

; ; ========== DLL加载 ==========
; ; 加载ColorMatch.dll - 修正路径
; global dllPath := A_ScriptDir "\lib\Tools\Tools.dll"
; global hColorMatchDLL := DllCall("LoadLibrary", "Str", dllPath, "Ptr")
; if (!hColorMatchDLL) {
;     MsgBox "无法加载 Tools.dll！请确保DLL文件在正确位置。`n路径: " dllPath
;     ExitApp
; }

; ; 获取DLL函数地址
; global pIsColorMatchAt_Opt := DllCall("GetProcAddress", "Ptr", hColorMatchDLL, "AStr", "IsColorMatchAt_Opt", "Ptr")
; global pColorDist := DllCall("GetProcAddress", "Ptr", hColorMatchDLL, "AStr", "ColorDist", "Ptr")

; if (!pIsColorMatchAt_Opt || !pColorDist) {
;     MsgBox "无法在DLL中找到函数！"
;     DllCall("FreeLibrary", "Ptr", hColorMatchDLL)
;     ExitApp
; }

; IsColorMatchAt_DLL(pos, color, tol:=0, mask:=0xF8F8F8) {
;     global pIsColorMatchAt_Opt
;     return DllCall(pIsColorMatchAt_Opt, 
;                   "Int", pos.x, 
;                   "Int", pos.y,  
;                   "UInt", color,
;                   "Int", tol,
;                   "UInt", mask,
;                   "Int")
; }


; ColorDist_DLL(c1, c2) {
;     global pColorDist
    
;     ; 调用DLL函数
;     result := DllCall(pColorDist,
;                      "UInt", c1,       ; 颜色1
;                      "UInt", c2,       ; 颜色2
;                      "Int")            ; 返回值类型
    
;     return result
; }

; ; OnExit(*) {
; ;     global hColorMatchDLL
; ;     if (hColorMatchDLL) {
; ;         DllCall("FreeLibrary", "Ptr", hColorMatchDLL)
; ;     }
; ; }
; global pIsColorMatchAt_Opt := DllCall("GetProcAddress", "Ptr", hColorMatchDLL, "AStr", "IsColorMatchAt_Opt", "Ptr")
; if (!pIsColorMatchAt_Opt) {
;     MsgBox "无法找到 IsColorMatchAt_Opt 函数！"
; }


global _hScreenDC := DllCall("GetDC", "ptr", 0, "ptr")
IsColorMatchAt_DLL(pos, color, tol:=0, mask:=0xF8F8F8){
    global _hScreenDC
    c := DllCall("GetPixel", "ptr", _hScreenDC, "int", pos.x, "int", pos.y, "uint")
    
    if (tol > 0) {
        dr := (c >> 16 & 0xFF) - (color >> 16 & 0xFF)
        dg := (c >> 8 & 0xFF) - (color >> 8 & 0xFF)
        db := (c & 0xFF) - (color & 0xFF)
        return dr*dr + dg*dg + db*db <= tol
    }
    
    return (c & mask) == (color & mask)
}

; 脚本退出时释放
OnExit(*) {
    global _hScreenDC
    if (_hScreenDC) {
        DllCall("ReleaseDC", "ptr", 0, "ptr", _hScreenDC)
    }
}

; IsLowFocus(number := 10) {
;     if (number < 1 || number > 10)
;         return false
    
;     local p := focusTbl[number]
    
;     ; 使用DLL直接获取像素并比较
;     return DllCall(pIsLowFocus, 
;                   "Int", p.x, 
;                   "Int", p.y, 
;                   "UInt", p.c,
;                   "Int")  ; 返回布尔值
; }