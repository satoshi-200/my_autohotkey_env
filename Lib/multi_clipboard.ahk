#Requires AutoHotkey v2.0

; =========================================================
; 【マルチクリップボード・ライブラリ】
;
; ●概要
;   キーボードの各キーを「保存用の箱」として扱うための関数群です。
;   このファイル自体にはショートカットキー（ホットキー）の割り当ては含まれません。
;   メインのスクリプトから各関数を呼び出して使用してください。
;
; ●利用可能な主要関数（Functions）
;   1. SaveText()       : 選択範囲をコピーして、指定した箱に保存します。
;   2. CutAndSaveText() : 選択範囲を切り取って、指定した箱に保存します。
;   3. PasteText()      : 指定した箱の中身を取り出し、貼り付けます。
;   4. CheckContent()   : 指定した箱の中身をポップアップで確認します。
;   5. ClearBox()       : 指定した一つの箱の中身を空にします。
;   6. ResetAll()       : すべての箱の中身を一括で空にします（確認ダイアログ付き）。
;
; ●共通仕様
;   ・箱を指定する際の入力待機時間は 10秒 です。
;   ・[Escape] キーで操作をキャンセルできます。
;
; ●作成日: 2026-02-18
; ●環境: AutoHotkey v2.0
; ========================================================

; ========================================================
; 変数の箱（ロッカー）を用意
; ========================================================
global MyClipBoxes := Map()

; ========================================================
; ホットキー設定エリア
; ========================================================

; #s::SaveText()          ; Windows + S -> コピーして保存
; #x::CutAndSaveText()    ; Windows + X -> 切り取って保存
; #v::PasteText()         ; Windows + V -> 貼り付け
; #d::CheckContent()      ; Windows + D -> 中身を確認
; #Del::ClearBox()        ; Windows + Delete -> 箱を一つ空にする
; #^Del::ResetAll()       ; Windows + Ctrl + Delete -> 全て空にする

; ========================================================
; 関数定義エリア
; ========================================================

; --- 1. 文字列をコピーして保存 ---
SaveText()
{
    targetKey := AskKeyInput("【保存】箱のキーを押してね (Escでキャンセル)")
    if (targetKey == "")
        return

    A_Clipboard := ""
    Send "^c"
    if ClipWait(0.5) {
        MyClipBoxes[targetKey] := A_Clipboard
        ShowMessage("箱 [" . targetKey . "] にコピーしました！")
    } else {
        ShowMessage("コピー失敗。文字を選択してる？")
    }
}

; --- 2. 文字列を切り取って保存 ---
CutAndSaveText()
{
    targetKey := AskKeyInput("【切取】箱のキーを押してね (Escでキャンセル)")
    if (targetKey == "")
        return

    A_Clipboard := ""
    Send "^x"
    if ClipWait(0.5) {
        MyClipBoxes[targetKey] := A_Clipboard
        ShowMessage("箱 [" . targetKey . "] に切り取って保存しました！")
    } else {
        ShowMessage("切り取り失敗。文字を選択してる？")
    }
}

; --- 3. 文字列をペースト ---
PasteText()
{
    targetKey := AskKeyInput("【貼付】箱のキーを押してね (Escでキャンセル)")
    if (targetKey == "")
        return

    if MyClipBoxes.Has(targetKey) {
        BackupClip := A_Clipboard
        A_Clipboard := MyClipBoxes[targetKey]
        Send "^v"
        Sleep 100
        A_Clipboard := BackupClip
    } else {
        ShowMessage("箱 [" . targetKey . "] は空っぽです。")
    }
}

; --- 4. 箱の中身を確認 ---
CheckContent()
{
    targetKey := AskKeyInput("【確認】箱のキーを押してね (Escでキャンセル)")
    if (targetKey == "")
        return

    if MyClipBoxes.Has(targetKey) {
        MsgBox("箱 [" . targetKey . "] の中身:`n`n" . MyClipBoxes[targetKey], "中身の確認")
    } else {
        ShowMessage("箱 [" . targetKey . "] は空っぽです。")
    }
}

; --- 5. 特定の箱を空にする ---
ClearBox()
{
    targetKey := AskKeyInput("【消去】箱のキーを押してね (Escでキャンセル)")
    if (targetKey == "")
        return

    if MyClipBoxes.Has(targetKey) {
        MyClipBoxes.Delete(targetKey)
        ShowMessage("箱 [" . targetKey . "] を空にしました。")
    }
}

; --- 6. すべての箱をリセット ---
ResetAll()
{
    ; "Icon!" と書くことで、ビックリマークのアイコンが表示されます
    result := MsgBox("すべての箱を空にしますか？", "全消去の確認", "YesNo Icon!")
    if (result == "Yes") {
        MyClipBoxes.Clear()
        ShowMessage("すべて空にしました！")
    }
}

; ========================================================
; 共通ツール（ヘルパー関数）
; ========================================================

; キー入力を待ち、キャンセル（Esc）も受け付ける関数
AskKeyInput(message)
{
    ToolTip(message)
    
    ; L1: 1文字入力で終了
    ; T10: 10秒でタイムアウト
    ih := InputHook("L1 T10")
    
    ; {Esc} を終了キー（EndKey）として登録します
    ih.KeyOpt("{Esc}", "E") 
    
    ih.Start()
    ih.Wait()
    
    ToolTip() ; ヒントを消す

    ; もしEscが押されて終わった（EndReasonが'EndKey'）なら、空を返す
    if (ih.EndReason == "EndKey") {
        ShowMessage("キャンセルしました")
        return ""
    }
    
    ; タイムアウトした時もメッセージを出す
    if (ih.EndReason == "Timeout") {
        ShowMessage("時間切れです")
        return ""
    }

    return ih.Input
}

ShowMessage(text)
{
    ToolTip("✨ " . text)
    SetTimer () => ToolTip(), -2000
}

