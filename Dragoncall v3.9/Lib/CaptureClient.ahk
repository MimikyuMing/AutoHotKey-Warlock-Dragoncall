#Requires AutoHotkey v2.0
#Include StateManager.ahk

class CaptureClient {
    static pView := 0
    static hDll := 0
    static hMap := 0
    static pStopCapture := 0
    static isValid := false

    ; 共享内存布局常量（变长布局，数据区从 28 开始）
    static OFFSET_FRAMEID   := 0
    static OFFSET_TIMESTAMP := 4
    static OFFSET_FOCUS     := 12
    static OFFSET_SKILLCNT  := 16
    static OFFSET_BUFFCNT   := 20
    static OFFSET_COLDOWNCNT:= 24
    static DATA_START       := 28
    static MAX_SKILLS       := 128
    static MAX_BUFFS        := 128
    static MAX_COLDDOWNS    := 128
    static TOTAL_SIZE       := 4096   ; 实际映射大小，读取时做边界检查

    ; 帧缓存
    static cachedFrameId := -1
    static cachedFrameData := false
    static RealtimeMode := 0

    static Start(dllPath, iniPath, mapName := "Local\DragoncallState") {
        this.hDll := DllCall("LoadLibrary", "Str", dllPath, "Ptr")
        if !this.hDll
            throw Error("无法加载 " . dllPath)

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

    ; ---------- 导出函数访问 ----------
    static GetSkillCount() => DllCall("CaptureLogic.dll\GetSkillCount", "CDecl Int")
    static GetSkillName(idx) {
        ptr := DllCall("CaptureLogic.dll\GetSkillName", "Int", idx, "CDecl Ptr")
        return ptr ? StrGet(ptr, "UTF-8") : ""
    }
    static GetBuffCount() => DllCall("CaptureLogic.dll\GetBuffCount", "CDecl Int")
    static GetBuffName(idx) {
        ptr := DllCall("CaptureLogic.dll\GetBuffName", "Int", idx, "CDecl Ptr")
        return ptr ? StrGet(ptr, "UTF-8") : ""
    }
    static GetColdDownCount() => DllCall("CaptureLogic.dll\GetColdDownCount", "CDecl Int")
    static GetColdDownName(idx) {
        ptr := DllCall("CaptureLogic.dll\GetColdDownName", "Int", idx, "CDecl Ptr")
        return ptr ? StrGet(ptr, "UTF-8") : ""
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

        local coldDownNames := [], coldDownIdx := Map()
        local cdc := this.GetColdDownCount()
        loop cdc {
            local name := this.GetColdDownName(A_Index - 1)
            coldDownNames.Push(name)
            coldDownIdx[name] := A_Index - 1
        }

        return { skillNames: skillNames, skillIdx: skillIdx,
                 buffNames: buffNames, buffIdx: buffIdx,
                 coldDownNames: coldDownNames, coldDownIdx: coldDownIdx }
    }

    static ReadFrame() {
        if !this.pView
            return false

        local frameId := NumGet(this.pView, this.OFFSET_FRAMEID, "UInt")
        local focus   := NumGet(this.pView, this.OFFSET_FOCUS,   "Int")
        local sc      := NumGet(this.pView, this.OFFSET_SKILLCNT, "UInt")
        local bc      := NumGet(this.pView, this.OFFSET_BUFFCNT,  "UInt")
        local cdc     := NumGet(this.pView, this.OFFSET_COLDOWNCNT, "UInt")

        ; 合法性检查
        if (sc > this.MAX_SKILLS || bc > this.MAX_BUFFS || cdc > this.MAX_COLDDOWNS)
            return false

        ; 计算数据区偏移
        local offset := this.DATA_START
        local skillBytes := Buffer(sc, 0)
        local buffBytes  := Buffer(bc, 0)
        local coldDownBytes := Buffer(cdc, 0)

        ; 逐字节读取（稳妥，避免指针运算问题）
        Loop sc
            NumPut("UChar", NumGet(this.pView, offset + A_Index - 1, "UChar"), skillBytes, A_Index - 1)
        offset += sc
        Loop bc
            NumPut("UChar", NumGet(this.pView, offset + A_Index - 1, "UChar"), buffBytes, A_Index - 1)
        offset += bc
        Loop cdc
            NumPut("UChar", NumGet(this.pView, offset + A_Index - 1, "UChar"), coldDownBytes, A_Index - 1)

        return { frameId: frameId, focus: focus,
                 skillBytes: skillBytes, buffBytes: buffBytes,
                 coldDownBytes: coldDownBytes }
    }

    static SyncStates(frameData, skillIdx, buffIdx, coldDownIdx := "") {
        local sc := frameData.skillBytes.Size
        local bc := frameData.buffBytes.Size
        local cdc := frameData.coldDownBytes.Size

        for name, idx in skillIdx {
            local state := (idx < sc) ? NumGet(frameData.skillBytes, idx, "UChar") : 0
            StateManager._skillState[name] := state
        }
        for name, idx in buffIdx {
            local state := (idx < bc) ? NumGet(frameData.buffBytes, idx, "UChar") : 0
            StateManager._buffState[name] := state
        }
        if (coldDownIdx != "") {
            for name, idx in coldDownIdx {
                local state := (idx < cdc) ? NumGet(frameData.coldDownBytes, idx, "UChar") : 0
                StateManager._coldDownState[name] := state
            }
        }
        StateManager._focusState.currentLevel := frameData.focus
    }

    static GetCachedFrame() {
        if !this.isValid || !this.pView
            return false

        frameId := NumGet(this.pView, 0, "UInt")
        if (frameId != this.cachedFrameId) {
            this.cachedFrameData := this.ReadFrame()
            this.cachedFrameId := frameId
        }
        return this.cachedFrameData
    }
}