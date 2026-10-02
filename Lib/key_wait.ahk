#Requires AutoHotkey v2.0
;==============================================================================
; key_wait.ahk
; 入力待ち（起点キーのあと次のキーを 1 つ受け取る）の共通部品
;   ・入力待ちで共有する InputHook（ih）と、待機中フラグ（isWaitingInput）
;   ・待機中ツールチップの表示、キャンセル・タイムアウトの判定
;   各レイヤーの割り当ては keymap\leader_keys.ahk、修飾キー付き入力は oneshot_modifiers.ahk
;==============================================================================

; 使う部品（単体で開いたときもエディタが変数を見つけられるように。同じファイルは 1 度しか読まれない）
#Include %A_LineFile%\..\config.ahk

ih := InputHook("L1")
isWaitingInput := false              ; 待機中は main.ahk の #HotIf でほかのホットキーを止める
IH_TIMEOUT_SEC := 5                  ; この秒数キー入力がなければ入力待ちをキャンセル

; キャンセル用：Esc・Caps で終了、一定時間でタイムアウト（各モードの KeyOpt でも消えない）
ih.Timeout := IH_TIMEOUT_SEC
ih.KeyOpt("{Esc}{sc03A}", "ES")

; いま何のキー待ちかをツールチップで表示する
IH_TipWaiting(mode, hint := "") {
  global isWaitingInput := true  ; 待機中はほかのホットキーを止める（下位のモードでも）
  SetTimer(IH_TipClear, 0)  ; 前のモードの「消去タイマー」で待ち表示が消えないように
  ToolTip("⌨️ [" mode "] 次のキー待ち..." (hint != "" ? "`n" hint : "")
    "`nEsc / Caps / Space+Caps：キャンセル（" IH_TIMEOUT_SEC " 秒で自動キャンセル）")
}

; 入力待ちの終了処理。受け付けたキーを表示し、キャンセルされたら true を返す
IH_EndWait(mode) {
  global ih, isWaitingInput
  cancelled := ""
  if (ih.EndReason = "Timeout")
    cancelled := "タイムアウト"
  else if (ih.EndKey = "Escape" || ih.EndKey = "CapsLock")
    cancelled := "キャンセル"
  else if (ih.EndKey = "Space" && IH_CapsWhileSpaceHeld())
    cancelled := "キャンセル"
  isWaitingInput := false

  if (cancelled != "")
    ToolTip("❌ [" mode "] " cancelled)
  else
    ToolTip("✅ [" mode "] accepted:[" ((ih.EndKey != "") ? ih.EndKey : ih.Input) "]")
  SetTimer(IH_TipClear, -tooltipDuration)
  return cancelled != ""
}

; Space で入力待ちが終わったとき、Space を離すまでに Caps が押されたか（Space+Caps でのキャンセル）
IH_CapsWhileSpaceHeld() {
  h := InputHook("L0 T" IH_TIMEOUT_SEC)
  h.KeyOpt("{sc03A}", "ES")
  h.KeyOpt("{vk20}", "NS")                    ; 押しっぱなしの Space の連打を止め、離したら終える
  h.OnKeyUp := (hk, vk, sc) => (vk = 0x20 ? hk.Stop() : 0)
  h.Start()
  if !GetKeyState("vk20", "P") {
    h.Stop()
    return false
  }
  h.Wait()
  return h.EndReason = "EndKey"
}

IH_TipClear() => ToolTip()

; 動作チェック用
WaitForKeyInput_show_input(){
  global ih
  ih.Start() ; 入力を開始
  ih.Wait() ; 入力が完了するまで待機
  MsgBox("入力された文字: " ih.Input)
}
