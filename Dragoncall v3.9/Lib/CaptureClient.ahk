#Requires AutoHotkey v2.0


#Include StateManager.ahk

; Lib\CaptureClient.ahk
class CaptureClient {
    static pView := 0
    static hDll := 0
    static hMap := 0
    static pStopCapture := 0

    static isValid := false


    ; 共享内存布局常量
    static OFFSET_FRAMEID := 0
    static OFFSET_TIMESTAMP := 4
    static OFFSET_FOCUS := 12
    static OFFSET_SKILLCNT := 16
    static OFFSET_BUFFCNT := 20
    static OFFSET_SKILLDATA := 24
    static OFFSET_BUFFDATA := 152
    static OFFSET_PERFUS := 280
    static MAX_SKILLS := 128
    static MAX_BUFFS := 128
    static TOTAL_SIZE := 284   ; 或 4096，但读取时不会超出


    ; 帧缓存（静态）
    static cachedFrameId := -1
    static cachedFrameData := false

    static RealtimeMode := 0


    static Start(dllPath, iniPath, mapName := "Local\DragoncallState") {
        this.hDll := DllCall("LoadLibrary", "Str", dllPath, "Ptr")
        if !this.hDll
            throw Error("无法加载 " . dllPath)

        ; DLL 自定义导出函数保持 "Str"
        res := DllCall("CaptureLogic.dll\StartCapture", "Str", iniPath, "CDecl Int")
        if !res {
            DllCall("FreeLibrary", "Ptr", this.hDll)
            throw Error("StartCapture 失败")
        }

        this.pStopCapture := DllCall("GetProcAddress", "Ptr", this.hDll, "AStr", "StopCapture", "Ptr")

        this.hMap := DllCall("OpenFileMapping", "UInt", 4, "Int", 0, "WStr", mapName)
        if !this.hMap {
            DllCall("FreeLibrary", "Ptr", this.hDll)
            throw Error("OpenFileMapping 失败")
        }

        this.pView := DllCall("MapViewOfFile", "Ptr", this.hMap, "UInt", 4, "UInt", 0, "UInt", 0, "UInt", 0)
        if !this.pView {
            DllCall("CloseHandle", "Ptr", this.hMap)
            DllCall("FreeLibrary", "Ptr", this.hDll)
            throw Error("MapViewOfFile 失败")
        }
        this.isValid := true
    }

    static Cleanup() {
        try {
            if this.pStopCapture && this.hDll
                DllCall(this.pStopCapture, "CDecl")
        } catch {

        }
        try {
            if this.pView
                DllCall("UnmapViewOfFile", "Ptr", this.pView)
        } catch {

        }
        try {
            if this.hMap
                DllCall("CloseHandle", "Ptr", this.hMap)
        } catch {

        }
        try {
            if this.hDll
                DllCall("FreeLibrary", "Ptr", this.hDll)
        } catch {

        }
    }

    static GetSkillCount() => DllCall("CaptureLogic.dll\GetSkillCount", "CDecl Int")
    static GetSkillName(idx) {
        ptr := DllCall("CaptureLogic.dll\GetSkillName", "Int", idx, "CDecl Ptr")
        return StrGet(ptr, "UTF-8")
    }
    static GetBuffCount() => DllCall("CaptureLogic.dll\GetBuffCount", "CDecl Int")
    static GetBuffName(idx) {
        ptr := DllCall("CaptureLogic.dll\GetBuffName", "Int", idx, "CDecl Ptr")
        return StrGet(ptr, "UTF-8")
    }

    static BuildNameIndex() {
        local skillNames := [], skillIdx := Map()
        local sc := this.GetSkillCount()
        loop sc {
            local name := this.GetSkillName(A_Index - 1)
            skillNames.Push(name)
            skillIdx[name] := A_Index - 1
        }

        local buffNames := [], buffIdx := Map()
        local bc := this.GetBuffCount()
        loop bc {
            local name := this.GetBuffName(A_Index - 1)
            buffNames.Push(name)
            buffIdx[name] := A_Index - 1
        }
        return { skillNames: skillNames, skillIdx: skillIdx,
            buffNames: buffNames, buffIdx: buffIdx }
    }

    static ReadFrame() {
        if !this.pView
            return false

        ; OutputDebug "AHK pView: " this.pView         ; 输出地址

        local frameId := NumGet(this.pView, this.OFFSET_FRAMEID, "UInt")
        local focus := NumGet(this.pView, this.OFFSET_FOCUS, "Int")
        local sc := NumGet(this.pView, this.OFFSET_SKILLCNT, "UInt")
        local bc := NumGet(this.pView, this.OFFSET_BUFFCNT, "UInt")

        if (sc > this.MAX_SKILLS || bc > this.MAX_BUFFS)
            return false

        local skillBytes := Buffer(sc, 0)
        local buffBytes := Buffer(bc, 0)

        Loop sc
            NumPut("UChar", NumGet(this.pView, this.OFFSET_SKILLDATA + A_Index - 1, "UChar"), skillBytes, A_Index - 1)
        Loop bc
            NumPut("UChar", NumGet(this.pView, this.OFFSET_BUFFDATA + A_Index - 1, "UChar"), buffBytes, A_Index - 1)

        ; ToolTip "frameId:" frameId ",focus:" focus ",sc:" sc ",bc:" bc
        ;     . "`nSkill0:" (sc > 0 ? NumGet(skillBytes, 0, "UChar") : "N/A"), 0, 0

        return { frameId: frameId, focus: focus, skillBytes: skillBytes, buffBytes: buffBytes }
    }

    static SyncStates(frameData, skillIdx, buffIdx) {
        local sc := frameData.skillBytes.Size
        local bc := frameData.buffBytes.Size

        for name, idx in skillIdx {
            local state := (idx < sc) ? NumGet(frameData.skillBytes, idx, "UChar") : 0
            StateManager._skillState[name] := state
            ; OutputDebug "name: " name ", state:" state
        }
        for name, idx in buffIdx {
            local state := (idx < bc) ? NumGet(frameData.buffBytes, idx, "UChar") : 0
            StateManager._buffState[name] := state
        }
        StateManager._focusState.currentLevel := frameData.focus
    }


    ; 获取当前帧数据（同一帧内只读取一次共享内存）
    static GetCachedFrame() {

        if !this.isValid || !this.pView
            return false

        ; 安全读取帧 ID
        frameId := NumGet(this.pView, 0, "UInt")
        if (frameId != this.cachedFrameId) {
            this.cachedFrameData := this.ReadFrame()
            this.cachedFrameId := frameId
        }
        return this.cachedFrameData

    }
}