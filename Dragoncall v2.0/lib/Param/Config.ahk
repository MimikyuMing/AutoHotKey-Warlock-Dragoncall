#Requires AutoHotkey v2.0

; ========== 运行参数 ==========
running := false
holding := false
showing := true
LOOP_DELAY_MS := -2          ; -1 = 最快

; ========== 内力阈值 ==========
; 常规状态：保证至少能放1-2个次元弹
MANTRA_FOCUS_NORMAL := 4   ; 4内力时用真言（留1内力缓冲）
RUPTURE_FOCUS_NORMAL := 4  ; 3内力时用破裂（刚好够1个次元弹）

; 掠夺状态：更激进，因为掠夺期间可能有额外回内
MANTRA_FOCUS_LEECH := 4    ; 3内力时用真言
RUPTURE_FOCUS_LEECH := 3   ; 2内力时用破裂

; 降临状态：最激进，最大化次元弹输出
MANTRA_FOCUS_SF := 2       ; 2内力时用真言  
RUPTURE_FOCUS_SF := 1      ; 1内力时用破裂

; ========== 延迟参数（已补偿41ms）==========
DELAY_INSTANT := 0           ; 瞬发无额外延迟
DELAY_MANTRA := 10          ; 真言需要响应时间
DELAY_RUPTURE := 5       ; 破裂需要响应时间


isDLL := false

isTest := false
