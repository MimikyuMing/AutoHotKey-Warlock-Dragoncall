#Requires AutoHotkey v2.0
; Dragoncall - Main.ahk
CoordMode "ToolTip", "Screen"

; 管理员权限
if !A_IsAdmin {
    try Run '*RunAs "' A_ScriptFullPath '"'
    ExitApp
}

; 资源释放（FileInstall 必须放在主脚本，不能移到 include 文件）
FileInstall "dll\CaptureDXGI.dll", A_Temp "\CaptureDXGI.dll", 1
FileInstall "dll\CaptureConfig.dll", A_Temp "\CaptureConfig.dll", 1
FileInstall "dll\CaptureLogic.dll", A_Temp "\CaptureLogic.dll", 1
FileInstall "config.ini", A_Temp "\config.ini", 1

; 全局定义
#include "Lib\Globals.ahk"
#Include "Dragoncall\DragoncallGlobals.ahk"

; 工具类（按依赖顺序）
#include "Lib\HiResTimer.ahk"
#include "Lib\StateManager.ahk"
#include "Lib\ActionMutex.ahk"
#include "Lib\IniManager.ahk"
#include "Lib\Log.ahk"
#include "Lib\KeyLogger.ahk"

; 核心引擎
#include "Dragoncall\CaptureEngine.ahk"
#include "Dragoncall\LogicEngine.ahk"

; 应用入口
#include "Dragoncall\App.ahk"

; 热键与GUI（必须在所有类定义之后）
#include "Dragoncall\Hotkeys.ahk"
#include "Dragoncall\GUI.ahk"

; 启动
IniManager.iniPath := INI   ; 必须在 App.Init 之前设置
App.Init()
Persistent