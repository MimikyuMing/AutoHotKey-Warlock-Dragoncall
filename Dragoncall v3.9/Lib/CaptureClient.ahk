#Requires AutoHotkey v2.0


#Include StateManager.ahk

; Lib\CaptureClient.ahk
class CaptureClient {
    static pView := 0
    static hDll  := 0
    static hMap  := 0
    static pStopCapture := 0

    static isValid := false


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
        return {skillNames: skillNames, skillIdx: skillIdx,
                buffNames: buffNames, buffIdx: buffIdx}
    }

    static ReadFrame() {
        if !this.pView
            return false

        local frameId := NumGet(this.pView, 0, "UInt")
        local focus   := NumGet(this.pView, 12, "Int")
        local sc      := NumGet(this.pView, 16, "UInt")
        local bc      := NumGet(this.pView, 20, "UInt")

        ; 如果捕获线程还没写入第一帧，所有值可能为 0
        if (frameId == 0 && sc == 0 && bc == 0)
            return false

        ; 限制最大数量
        if (sc > 128 || bc > 128)
            return false

        ; 检查总大小是否超出共享内存
        if (24 + sc + bc + 12 > 4096)
            return false

        local skillBytes := Buffer(sc, 0)
        if (sc > 0)
            DllCall("RtlMoveMemory", "Ptr", skillBytes, "Ptr", this.pView + 24, "UPtr", sc)

        local buffBytes := Buffer(bc, 0)
        if (bc > 0)
            DllCall("RtlMoveMemory", "Ptr", buffBytes, "Ptr", this.pView + 24 + sc, "UPtr", bc)

        return {frameId: frameId, focus: focus, skillBytes: skillBytes, buffBytes: buffBytes}
    }

    static SyncStates(frameData, skillIdx, buffIdx) {
        local sc := frameData.skillBytes.Size
        local bc := frameData.buffBytes.Size

        for name, idx in skillIdx {
            local state := (idx < sc) ? NumGet(frameData.skillBytes, idx, "UChar") : 0
            StateManager._skillState[name] := state
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