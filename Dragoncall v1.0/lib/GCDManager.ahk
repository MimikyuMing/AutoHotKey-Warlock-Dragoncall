class GCDManager {
    ; 各技能的实际GCD时间
    static SKILL_GCD_TIMES := Map(
        "Dragoncall_Instant", 150,    ; 暴魔灵瞬发 (原450)
        "Wingstorm_Instant", 150,     ; 死灵突袭瞬发 (原450)
        "Mantra", 600,                ; 真言 (原700)
        "Rupture", 450,               ; 破裂 (原500)
        "Bombardment_True", 200,      ; 真次元弹 (原350)
        "Bombardment_Instant", 200,   ; 次元弹瞬发 (原350)
        "Bombardment_Normal", 300,    ; 次元弹非瞬发 (原850)
        "Leech", 450,                  ; 掠夺 (原500)
        "R", 200
    )

    ; 技能分组定义
    static SKILL_GROUPS := Map(
        "Dragoncall_Instant", "Instant",
        "Wingstorm_Instant", "Instant",
        "Mantra", "Main",
        "Rupture", "Main", 
        "Bombardment_True", "Main",
        "Bombardment_Instant", "Main",
        "Bombardment_Normal", "Main",
        "Leech", "Main",
        "R", "Main"
    )

    static DELAY_COMPENSATION := 50

    __New() {
        this.gcdGroups := Map(
            "Instant", 0,   ; 瞬发GCD组结束时间
            "Main", 0       ; 主GCD组结束时间
        )
        this.lastSkillType := ""
    }

    ; 获取技能所属的GCD组
    GetSkillGroup(skillType) {
        if (!GCDManager.SKILL_GROUPS.Has(skillType)) {
            throw Error("未知的技能类型: " skillType)
        }
        return GCDManager.SKILL_GROUPS[skillType]
    }

    ; 获取技能的GCD时间
    GetSkillGCDTime(skillType) {
        if (!GCDManager.SKILL_GCD_TIMES.Has(skillType)) {
            throw Error("未知的技能类型: " skillType)
        }
        return GCDManager.SKILL_GCD_TIMES[skillType]
    }

    SetGCD(skillType) {
        ; 获取技能分组和GCD时间
        local gcdGroup := this.GetSkillGroup(skillType)
        local gcdTime := this.GetSkillGCDTime(skillType) - GCDManager.DELAY_COMPENSATION
        
        ; 确保GCD时间不小于最小值
        if (gcdTime < 50) {
            gcdTime := 50
        }
        
        ; 设置该GCD组的冷却时间
        this.gcdGroups[gcdGroup] := A_TickCount + gcdTime
        this.lastSkillType := skillType
    }

    IsReady(skillType) {
        local gcdGroup := this.GetSkillGroup(skillType)
        return A_TickCount >= this.gcdGroups[gcdGroup]
    }

    GetRemaining(skillType) {
        local gcdGroup := this.GetSkillGroup(skillType)
        local remaining := this.gcdGroups[gcdGroup] - A_TickCount
        return remaining > 0 ? remaining : 0
    }

    ; 新增：获取所有就绪的技能类型（用于调试）
    GetReadySkills() {
        readySkills := []
        for skillType in GCDManager.SKILL_GROUPS {
            if (this.IsReady(skillType)) {
                readySkills.Push(skillType)
            }
        }
        return readySkills
    }

    ; 新增：重置所有GCD（用于战斗结束）
    ResetAll() {
        for group in this.gcdGroups {
            this.gcdGroups[group] := 0
        }
        this.lastSkillType := ""
    }
}