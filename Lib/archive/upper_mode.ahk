#Requires AutoHotkey v2.0
;==============================================================================
; upper_mode.ahk（使わなくなったので archive へ移した。読み込まれない）
; 大文字入力モード：Caps → 無変換 で入っていた。
;   英字キーを Shift 付きで送る（Shift を押しながら打つのと同じで、IME の未確定文字になる）。
;   数字・記号はそのまま入力してモードを続ける。
;   Esc / Caps / 無変換 / 変換：終了のみ　Space・Enter・BS などほかのキー：終了してそのキーを入力
;
; 外した理由（使いにくい点）
;   ・変換 + g などで送っていた BS が、モードの中では呼ばれない（InputHook が「ほかのキー」として終了させる）。
;   ・数字・記号は Shift なしでそのまま入るので、Shift + 1 の「!」にならず「1」が入る。
; 元の困りごと：Shift を押しながら打つと左手のホームポジションが崩れる。→ ideas.md の「Shift 長押しモード」
;
; 戻すとき
;   ・本体（UpperMode_*）を text_input.ahk へ戻す。
;   ・終了用のホットキー（下の「ホットキー」）を keymap\leader_keys.ahk の起点キーの近くへ戻す。
;   ・keymap\leader_keys.ahk の Leader_Caps の specials に「0x7B, UpperMode_Start」を足す。
;   ・Lib\keymap_view.ahk の KM_FUNC_NAMES に「"UpperMode_Start", "大文字入力モード"」を足す。
;==============================================================================

;--- ホットキー（これらもプレフィックスなので InputHook に届かない）------------------
; #HotIf UpperMode_IsOn()
; vk1D:: UpperMode_Stop()
; vk1C:: UpperMode_Stop()
; vk20:: UpperMode_Stop(), SendInput("{Space}")
; vk1C & b:: UpperMode_Stop(), SendInput("{F8}")      ; 組み合わせが発動すると上の vk1C:: は発動しない
; vk1C & n:: UpperMode_Stop(), SendInput("{F9}")
; #HotIf

;--- 本体 ---------------------------------------------------------------------
UpperMode_hook := 0

UpperMode_IsOn() => UpperMode_hook && UpperMode_hook.InProgress
UpperMode_Stop() => UpperMode_IsOn() && UpperMode_hook.Stop()

UpperMode_Start() {
    global UpperMode_hook
    IH_ModeBegin()

    h := InputHook("L0 V")                          ; 指定しないキーはそのまま入力させる
    h.MinSendLevel := 1                             ; 自分で送った Shift+英字を拾って無限ループしないように
    h.KeyOpt("{All}", "E")                          ; ほかのキーは押したら終了（キーはそのまま届く）
    ; {All} は VK と SC の両方に付くので、外すときも両方から外す
    opt(vk, o) => h.KeyOpt(Format("{{}vk{:X}{}}{{}sc{:X}{}}", vk, GetKeySC(Format("vk{:X}", vk))), o)
    for vk in [0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0x5B, 0x5C]  ; Shift / Ctrl / Alt / Win
        opt(vk, "-E")
    loop 10                                         ; 数字
        opt(0x2F + A_Index, "-E")
    for vk in [0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF, 0xC0, 0xDB, 0xDC, 0xDD, 0xDE, 0xE2]  ; 記号
        opt(vk, "-E")
    loop 26                                         ; 英字：止めて OnKeyDown で Shift+英字を送る
        opt(0x40 + A_Index, "-E +S +N")
    h.KeyOpt("{Esc}{sc03A}", "+E +S")               ; 終了のみ（キーは送らない）
    h.OnKeyDown := _UpperMode_OnKey

    UpperMode_hook := h
    ToolTip("🔠 [大文字モード] 英字を大文字で入力"
        . "`nEsc / Caps / 無変換 / 変換：終了　Space・Enter など：終了してそのキーを入力")
    h.Start()
    h.Wait()
    IH_ModeEnd("🔡 [大文字モード] 終了")
}

_UpperMode_OnKey(h, vk, sc) {
    if (GetKeyState("Ctrl") || GetKeyState("Alt") || GetKeyState("LWin") || GetKeyState("RWin")) {
        h.Stop()                                    ; Ctrl+C などは終了して通常のショートカットとして送る
        SendInput("{Blind}{vk" Format("{:X}", vk) "}")
        return
    }
    SendInput("+{vk" Format("{:X}", vk) "}")
}
