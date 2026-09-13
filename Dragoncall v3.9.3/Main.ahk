#Requires AutoHotkey v2.0
; Dragoncall - Main.ahk

CoordMode "ToolTip", "Screen"
SendMode "Input"

; ---------- 管理员权限 ----------
if !A_IsAdmin {
    try Run '*RunAs "' A_ScriptFullPath '"'
    ExitApp
}

OutputDebug "ScriptDir: " A_ScriptDir
OutputDebug "Exist dll: " DirExist(A_ScriptDir "\dll")
OutputDebug "Exist CaptureDXGI: " FileExist(A_ScriptDir "\dll\CaptureDXGI.dll")


; ---------- 资源释放 ----------
try FileDelete A_Temp "\CaptureDXGI.dll"
try FileDelete A_Temp "\CaptureConfig.dll"
try FileDelete A_Temp "\CaptureLogic.dll"

FileInstall "dll\CaptureDXGI.dll",   A_Temp "\CaptureDXGI.dll",   1
FileInstall "dll\CaptureConfig.dll", A_Temp "\CaptureConfig.dll", 1
FileInstall "dll\CaptureLogic.dll",  A_Temp "\CaptureLogic.dll",  1

; ============================================================
; Include 顺序（严格按依赖排列，子文件不再写 #Include）
; ============================================================

; ---------- 基础层（无依赖）----------
#include "Lib\Globals.ahk"
#include "Lib\HiResTimer.ahk"
#include "Lib\Tools.ahk"

; ---------- 工具层 ----------
#include "Lib\Log.ahk"
#include "Lib\IniManager.ahk"
#include "Lib\KeyLogger.ahk"          ; 依赖 HiResTimer, Globals
#include "Lib\PerformanceMonitor.ahk" ; 依赖 HiResTimer, KeyLogger

; ---------- 互斥层 ----------
#include "Lib\ActionMutex.ahk"        ; 依赖 HiResTimer, PerformanceMonitor

; ---------- 状态层 ----------
#include "Lib\CaptureClient.ahk"      ; 依赖 StateManager
#include "Lib\RealtimeMap.ahk"        ; 依赖 StateManager, PerformanceMonitor
#include "Lib\StateManager.ahk"       ; 依赖 RealtimeMap
#include "Lib\StatusMonitor.ahk"

; ---------- 传输层 ----------
#include "Lib\InputQueue.ahk"         ; 依赖 PerformanceMonitor, HiResTimer

; ---------- 游戏专用层 ----------
#include "Core\CoreConfig.ahk"
#include "Core\CoreMutex.ahk"
#include "Core\CaptureEngine.ahk"
#include "Core\CoreStatusMonitor.ahk"

; ---------- 运行时与引擎 ----------
#include "Core\RuntimeContext.ahk"
#include "Lib\LogicRunner.ahk"
#include "Core\LogicEngine.ahk"

; ---------- 应用层 ----------
#include "Core\App.ahk"

; ---------- 交互层（必须在 App 之后）----------
#include "Core\Hotkeys.ahk"
#include "Core\GUI.ahk"

; ============================================================
; 启动
; ============================================================
IniManager.iniPath := App.configPath
App.Init()
Persistent