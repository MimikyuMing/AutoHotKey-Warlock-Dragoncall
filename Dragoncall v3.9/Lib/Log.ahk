#Requires AutoHotkey v2.0

class Log {
    static queue := []
    static Enabled := true

    static Init() {
        SetTimer(ObjBindMethod(Log, "Flush"), 100)
    }
    static Write(msg) {
        if !this.Enabled         ; 关闭时直接返回，零开销
            return
        this.queue.Push(Format("[{1}] {2}", A_Now, msg))
    }
    static Flush() {
        if this.queue.Length == 0
            return
        q := this.queue
        this.queue := []
        s := ""
        for msg in q
            s .= msg . "`n"
        fileName := Format("log_{1}.txt", A_YYYY A_MM A_DD)
        FileAppend s, A_ScriptDir "\" fileName
    }
}
