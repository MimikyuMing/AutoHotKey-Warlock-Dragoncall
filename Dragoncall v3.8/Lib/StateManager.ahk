#Requires AutoHotkey v2.0

class StateManager {
    static _buffState := Map()
    static _skillState := Map()
    static _focusState := Map()
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