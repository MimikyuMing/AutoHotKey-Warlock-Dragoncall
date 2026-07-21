#Requires AutoHotkey v2.0

#Include RealtimeMap.ahk

class StateManager {
    static _buffState := RealtimeMap()
    static _skillState := RealtimeMap()
    static _focusState := Map()

    static realtimeMode := false

    static Init(captureClientObj) {
        ; 为 _skillState 配置实时查询参数
        this._skillState.type := "skill"
        this._skillState.idxMap := CaptureEngine.skillIdx   ; 或从 captureClientObj 获取

        ; 为 _buffState 配置实时查询参数
        this._buffState.type := "buff"
        this._buffState.idxMap := CaptureEngine.buffIdx
    }

    static GetBuffState() => this._buffState
    static GetSkillState() => this._skillState
    static GetFocusState() => this._focusState
    static GetBuffTrueCount() {
        c := 0
        for _, v in this._buffState
            if v
                c++
        return c
    }
}