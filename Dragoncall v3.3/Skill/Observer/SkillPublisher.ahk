#Requires AutoHotkey v2.0

class SkillPublisher {
    static Subjects := Map() ; 存储所有主题
    
    /**
     * 注册观察者
     * @param subjectName 主题名称
     * @param observer 观察者对象（必须实现 Update 方法）
     */
    static Subscribe(subjectName, observer) {
        if (!this.Subjects.Has(subjectName)) {
            this.Subjects[subjectName] := []
        }
        
        ; 避免重复注册
        for existingObserver in this.Subjects[subjectName] {
            if (existingObserver == observer) {
                return false
            }
        }
        
        this.Subjects[subjectName].Push(observer)
        return true
    }
    
    /**
     * 取消注册
     * @param subjectName 主题名称
     * @param observer 观察者对象
     */
    static Unsubscribe(subjectName, observer) {
        if (!this.Subjects.Has(subjectName)) {
            return false
        }
        
        observers := this.Subjects[subjectName]
        for index, existingObserver in observers {
            if (existingObserver == observer) {
                observers.RemoveAt(index)
                return true
            }
        }
        
        return false
    }
    
    /**
     * 通知所有观察者
     * @param subjectName 主题名称
     * @param data 传递的数据
     */
    static Notify(subjectName, data := "") {
        if (!this.Subjects.Has(subjectName)) {
            return 0
        }
        
        notifiedCount := 0
        for observer in this.Subjects[subjectName] {
            try {
                observer.Update(data) ; 调用观察者的 Update 方法
                notifiedCount++
            } catch Error as e {
                ; 可添加错误处理逻辑
                OutputDebug("观察者通知失败: " e.Message)
            }
        }
        
        return notifiedCount
    }
    
    /**
     * 获取主题的所有观察者
     */
    static GetObservers(subjectName) {
        return this.Subjects.Has(subjectName) ? this.Subjects[subjectName].Clone() : []
    }
    
    /**
     * 清除主题的所有观察者
     */
    static ClearSubject(subjectName) {
        if (this.Subjects.Has(subjectName)) {
            this.Subjects.Delete(subjectName)
            return true
        }
        return false
    }
}