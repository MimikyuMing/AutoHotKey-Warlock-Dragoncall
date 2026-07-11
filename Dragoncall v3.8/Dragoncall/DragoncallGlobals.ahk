#Requires AutoHotkey v2.0

; INI 路径（需要先声明 IniManager.iniPath 但 Init 时才赋值）
global INI := FileExist(A_AppData "\Dragoncall\config.ini") ? A_AppData "\Dragoncall\config.ini" : A_Temp "\config.ini"
; IniManager.iniPath 将在 App.Init 中设置