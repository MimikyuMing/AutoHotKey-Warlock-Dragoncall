#Requires AutoHotkey v2.0

; Globals.ahk
global GAME_FRAME := 60
global FRAME_MS := Floor(1000 / GAME_FRAME)
global DETECT_INTERVAL := Floor(FRAME_MS * 0.30)
global LOGIC_INTERVAL := Floor(FRAME_MS * 0.15)
global SYS_STANDBY := 0, SYS_ACTIVE := 1
global g_SysState := SYS_STANDBY

; KeyLogger 配置
global LOG_FILE := A_ScriptDir "\KeyLog.txt"
global ONLY_INJECTED := true
global MAX_QUEUE_SIZE := 500
global FLUSH_INTERVAL := 1000

