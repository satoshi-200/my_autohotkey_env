; ==============================================================================
; 【マルチクリップボード・ライブラリ（テキスト＆画像対応版）】
; ※※未完成！！！！！！！！！
; ●概要
;   テキストだけでなく、画像データも「箱」に保存・取り出しができるライブラリです。
;   メインスクリプトから呼び出して使用してください。
;
; ●利用可能な主要関数
;   1. SaveItem()       : 選択中のテキストまたは画像をコピーして保存します。
;   2. CutAndSaveItem() : 選択中のテキストを切り取って保存します（画像はコピーのみ対応）。
;   3. PasteItem()      : 箱の中身（テキストor画像）を取り出し、貼り付けます。
;   4. CheckContent()   : 箱の中身が「テキスト」なら表示、「画像」なら形式のみ通知します。
;   5. ClearBox()       : 指定した一つの箱を空にします。
;   6. ResetAll()       : すべての箱を一括で空にします。
;
; ●共通仕様
;   ・入力待機時間は 10秒、[Escape] キーでキャンセル可能です。
; ==============================================================================

; 変数の箱（Map）を用意
global MyClipBoxes := Map()

; --- 1. 保存する関数 (テキスト・画像自動判別) ---
SaveItem()
{
    targetKey := AskKeyInput("【保存】箱のキーを押してね (Escでキャンセル)")
    if (targetKey == "")
        return

    ; クリップボードを一旦空にしてコピーを実行
    A_Clipboard := ""
    Send "^c"
    if !ClipWait(1) ; 最大1秒待機
    {
        ShowMessage("保存失敗：何も選択されていないか、対応していない形式です。")
        return
    }

    ; --- 保存形式の判別 ---
    ; DllCall("IsClipboardFormatAvailable", "uint", 1) はテキスト形式があるかを確認
    ; DllCall("IsClipboardFormatAvailable", "uint", 2) は画像形式があるかを確認
    if DllCall("IsClipboardFormatAvailable", "uint", 1) {
        ; テキストとして保存
        MyClipBoxes[targetKey] := A_Clipboard
        ShowMessage("箱 [" . targetKey . "] にテキストを保存しました！")
    }
    else if DllCall("IsClipboardFormatAvailable", "uint", 2) {
        ; 画像（すべてのデータ）として保存
        MyClipBoxes[targetKey] := ClipboardAll()
        ShowMessage("箱 [" . targetKey . "] に画像を保存しました！")
    }
    else {
        ShowMessage("対応していないデータ形式です。")
    }
}

; --- 2. 切り取って保存する関数 ---
; ※画像は切り取りが不安定なソフトが多いため、基本はテキスト用として動作します
CutAndSaveItem()
{
    targetKey := AskKeyInput("【切取】箱のキーを押してね (Escでキャンセル)")
    if (targetKey == "")
        return

    A_Clipboard := ""
    Send "^x"
    if !ClipWait(1) {
        ShowMessage("切り取り失敗：選択範囲が正しくありません。")
        return
    }

    ; 保存処理（テキスト優先）
    if DllCall("IsClipboardFormatAvailable", "uint", 1) {
        MyClipBoxes[targetKey] := A_Clipboard
        ShowMessage("箱 [" . targetKey . "] にテキストを切り取り保存しました！")
    } else {
        MyClipBoxes[targetKey] := ClipboardAll()
        ShowMessage("箱 [" . targetKey . "] にデータを切り取り保存しました。")
    }
}

; --- 3. 貼り付ける関数 ---
PasteItem()
{
    targetKey := AskKeyInput("【貼付】箱のキーを押してね (Escでキャンセル)")
    if (targetKey == "")
        return

    if MyClipBoxes.Has(targetKey) {
        BackupClip := ClipboardAll() ; 現在のクリップボードを一時保存
        
        A_Clipboard := MyClipBoxes[targetKey] ; 箱の中身をクリップボードにセット
        
        Send "^v"
        Sleep 200 ; データ反映のために少し待機
        A_Clipboard := BackupClip ; クリップボードを元に戻す
    } else {
        ShowMessage("箱 [" . targetKey . "] は空っぽです。")
    }
}

; --- 4. 中身を確認する関数 ---
CheckContent()
{
    targetKey := AskKeyInput("【確認】箱のキーを押してね (Escでキャンセル)")
    if (targetKey == "")
        return

    if MyClipBoxes.Has(targetKey) {
        content := MyClipBoxes[targetKey]
        
        ; 中身がテキストかどうかで表示を変える
        if (Type(content) == "String") {
            MsgBox("箱 [" . targetKey . "] の中身（テキスト）:`n`n" . content, "中身の確認")
        } else {
            MsgBox("箱 [" . targetKey . "] の中身は「画像」データです。", "中身の確認")
        }
    } else {
        ShowMessage("箱 [" . targetKey . "] は空っぽです。")
    }
}

; --- 5. 一つ消去 ---
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

; --- 6. 全消去 ---
ResetAll()
{
    result := MsgBox("すべての箱を空にしますか？", "全消去の確認", "YesNo Icon!")
    if (result == "Yes") {
        MyClipBoxes.Clear()
        ShowMessage("すべて空にしました！")
    }
}

; ========================================================
; 共通ヘルパー関数
; ========================================================

AskKeyInput(message)
{
    ToolTip(message)
    ih := InputHook("L1 T10")
    ih.KeyOpt("{Esc}", "E")
    ih.Start()
    ih.Wait()
    ToolTip()

    if (ih.EndReason == "EndKey") {
        ShowMessage("キャンセルしました")
        return ""
    }
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