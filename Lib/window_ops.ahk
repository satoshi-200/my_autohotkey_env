#Requires AutoHotkey v2.0
;==============================================================================
; window_ops.ahk
; ウィンドウ・仮想デスクトップ・システムの操作（クイックメニューの W / D / S / A / V から呼ぶ）
;   quick_menu.ahk から分けた。関数名の QM_ はそのまま
;   Window_CloseAndFocus（Space+F → [ / ]）もここにある
;==============================================================================
#Include %A_LineFile%\..\ui_common.ahk
#Include %A_LineFile%\..\mouse_cursor.ahk

BACKUP_KEEP := 10                                  ; Box に残すバックアップの数（超えたら古いものから消す。0 で消さない）

;--- ウィンドウ ---------------------------------------------------------------
QM_ToggleTopmost() {
    WinSetAlwaysOnTop(-1, "A")
    UI_Tip((WinGetExStyle("A") & 0x8) ? "常に最前面：ON" : "常に最前面：OFF")
}

QM_ToggleTransparent() {
    cur := WinGetTransparent("A")
    WinSetTransparent((cur = "") ? 200 : "Off", "A")
    UI_Tip((cur = "") ? "半透明：ON" : "半透明：OFF")
}

QM_CenterWindow() {
    if !(hwnd := WinExist("A"))
        return
    if (WinGetMinMax(hwnd) = 1)
        WinRestore(hwnd)
    WinGetPos(&x, &y, &w, &h, hwnd)
    MonitorGetWorkArea(UI_MonitorFromPoint(x + w // 2, y + h // 2), &l, &t, &r, &b)
    WinMove(l + (r - l - w) // 2, t + (b - t - h) // 2, , , hwnd)
}

QM_CopyWindowInfo() {
    if !WinExist("A")
        return
    text := Format("Title: {}`r`nClass: ahk_class {}`r`nExe:   ahk_exe {}`r`nPath:  {}"
        , WinGetTitle("A"), WinGetClass("A"), WinGetProcessName("A"), WinGetProcessPath("A"))
    A_Clipboard := text
    UI_Tip("ウィンドウ情報をコピーしました`n`n" text, 3000)
}

;--- システム・アプリ ---------------------------------------------------------
QM_ShowClipboard() {
    t := A_Clipboard
    MsgBox((t = "") ? "（文字なし）" : SubStr(t, 1, 2000) (StrLen(t) > 2000 ? "`n…（以下省略）" : "")
        , "クリップボードの内容")
}

QM_DisplayOff() {
    Sleep(500)                                                   ; キーを離した信号で再点灯しないよう待つ
    DllCall("PostMessage", "Ptr", 0xFFFF, "UInt", 0x0112, "Ptr", 0xF170, "Ptr", 2)  ; SC_MONITORPOWER
}

QM_OpenScriptInCode() {
    try Run('code "' A_ScriptDir '"', , "Hide")
    catch
        Run(A_ScriptDir)
}

; 個人のパスを書かないよう、利用者のフォルダと利用者名から組み立てる
QM_BackupRoot() => EnvGet("USERPROFILE") "\Box\" A_UserName "\20_開発・効率化\autohotkey\backup"
QM_BackupLocalDir() => EnvGet("USERPROFILE") "\Desktop\my_autohotkey_env-main"

; Box 同期フォルダへ日時付きでフォルダごとコピーする
QM_BackupScript() {
    root := QM_BackupRoot()
    if !DirExist(root) {
        MsgBox("バックアップ先が見つかりません。`n" root, "バックアップ", "Icon!")
        return
    }
    dest := root "\autohotkey_" FormatTime(, "yyyyMMdd_HHmmss")
    try DirCopy(A_ScriptDir, dest)
    catch as e {
        MsgBox("コピーに失敗しました。`n" e.Message, "バックアップ", "Icon!")
        return
    }
    n := QM_BackupPrune(root)
    UI_Tip("バックアップしました`n" dest (n ? "`n古いもの " n " 件を削除" : ""), 3000)
}

; 日時付きのバックアップのフォルダ名を古い順に返す
QM_BackupList(root) {
    names := ""
    loop files root "\autohotkey_*", "D"
        if RegExMatch(A_LoopFileName, "^autohotkey_\d{8}_\d{6}$")
            names .= (names = "" ? "" : "`n") A_LoopFileName
    return (names = "") ? [] : StrSplit(Sort(names), "`n")
}

; 日時付きのバックアップが BACKUP_KEEP を超えたら、古い順に消す（消した数を返す）
QM_BackupPrune(root) {
    if (BACKUP_KEEP <= 0)
        return 0
    list := QM_BackupList(root)
    n := 0
    loop list.Length - BACKUP_KEEP {
        try {
            DirDelete(root "\" list[A_Index], true)
            n++
        }
    }
    return n
}

; 最新のバックアップをデスクトップへ上書きで展開する。今の中身は先頭に「_old_」を付けたフォルダに 1 世代だけ避難する
QM_BackupRestore() {
    root := QM_BackupRoot()
    list := DirExist(root) ? QM_BackupList(root) : []
    if !list.Length {
        MsgBox("バックアップが見つかりません。`n" root, "ローカルに展開", "Icon!")
        return
    }
    src := root "\" list[list.Length]
    dest := QM_BackupLocalDir()
    SplitPath(dest, &name, &parent)
    old := parent "\_old_" name
    if (MsgBox(list[list.Length] " を`n" dest " に上書きで展開します。`n`n今の中身は " old " に避難します（前の避難分は消えます）。"
        , "ローカルに展開", "OKCancel Icon? Default2") != "OK")
        return
    if DirExist(dest) {
        try {
            if DirExist(old)
                DirDelete(old, true)
            DirCopy(dest, old)
        } catch as e {
            MsgBox("避難に失敗したので、展開をやめました。`n" e.Message, "ローカルに展開", "Icon!")
            return
        }
    }
    failed := 0
    loop files src "\*", "FR" {
        to := dest SubStr(A_LoopFileFullPath, StrLen(src) + 1)
        try {
            SplitPath(to, , &dir)
            DirCreate(dir)
            FileCopy(A_LoopFileFullPath, to, 1)
        } catch
            failed++                                           ; 使用中のファイル（読み込み中の DLL など）は飛ばす
    }
    if failed
        MsgBox("展開しましたが、" failed " 個のファイルは使用中などで上書きできませんでした。`n" dest, "ローカルに展開", "Icon!")
    else
        UI_Tip("展開しました`n" src "`n→ " dest, 3000)
}

;--- VS Code ------------------------------------------------------------------
; Ctrl+K に続けて key を送る（VS Code の 2 段階ショートカット）
QM_VSCodeChord(key, waitMs := 200) {
    SendInput("^k")
    Sleep(waitMs)
    SendInput(key)
}

;--- 仮想デスクトップ ---------------------------------------------------------
; 現在の番号と総数をレジストリから読む（現在の番号が分からなければ false）
QM_DesktopState(&cur, &count) {
    key := "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer"
    cur := 1, count := 1
    ids := ""
    try ids := RegRead(key "\VirtualDesktops", "VirtualDesktopIDs")
    if (StrLen(ids) < 32)                                        ; 一度も追加していないときは値がない
        return true
    count := StrLen(ids) // 32                                   ; GUID 1 個 = 16 バイト = 16 進 32 文字

    curId := ""
    try curId := RegRead(key "\VirtualDesktops", "CurrentVirtualDesktop")          ; Windows 11
    if (curId = "") {                                            ; Windows 10
        sid := 0
        DllCall("ProcessIdToSessionId", "UInt", DllCall("GetCurrentProcessId", "UInt"), "UInt*", &sid)
        try curId := RegRead(key "\SessionInfo\" sid "\VirtualDesktops", "CurrentVirtualDesktop")
    }
    loop count
        if (SubStr(ids, (A_Index - 1) * 32 + 1, 32) = curId) {
            cur := A_Index
            return true
        }
    return false
}

QM_DesktopMoveBy(d) {
    keys := (d > 0) ? "^#{Right}" : "^#{Left}"
    loop Abs(d) {
        SendInput(keys)
        Sleep(100)
    }
}

; 隣のデスクトップへ（carry = true ならアクティブなウィンドウも一緒に移動）
QM_DesktopStep(d, carry := false) {
    known := QM_DesktopState(&cur, &count)
    n := cur + d
    if (known && (n < 1 || n > count)) {
        UI_Tip((d > 0) ? "右側にデスクトップはありません" : "左側にデスクトップはありません")
        return
    }
    if carry
        QM_CarryWindow(() => QM_DesktopMoveBy(d))
    else
        QM_DesktopMoveBy(d)
    if known
        UI_Tip("デスクトップ " n " / " count)
}

; 新しいデスクトップを右端に作って切り替える（carry = true ならウィンドウも移動）
QM_DesktopNew(carry := false) {
    QM_DesktopState(&cur, &count)
    if carry
        QM_CarryWindow(() => SendInput("^#d"))
    else
        SendInput("^#d")
    UI_Tip("デスクトップを作成しました（" count + 1 " / " count + 1 "）")
}

; 今のデスクトップを閉じる（開いていたウィンドウは隣のデスクトップへ移る）
QM_DesktopClose() {
    if (QM_DesktopState(&cur, &count) && count <= 1) {
        UI_Tip("デスクトップが 1 つしかないため閉じられません")
        return
    }
    SendInput("^#{F4}")
    UI_Tip("デスクトップ " cur " を閉じました（残り " count - 1 " 個）")
}

QM_DesktopInfo() {
    if QM_DesktopState(&cur, &count)
        UI_Tip("現在のデスクトップ：" cur " / " count, 2500)
    else
        UI_Tip("仮想デスクトップの状態を取得できませんでした")
}

; アクティブなウィンドウを隠してから切り替え、切り替え先で表示し直す（表示した側のデスクトップに移る）
QM_CarryWindow(switchFn) {
    hwnd := WinExist("A")
    if (!hwnd || UI_IsShellWindow(hwnd)) {
        UI_Tip("移動できるウィンドウがありません")
        return
    }
    WinHide(hwnd)
    try {
        Sleep(50)
        switchFn()
        Sleep(250)
    } finally {
        WinShow(hwnd)
        try WinActivate(hwnd)
    }
}

; アクティブなウィンドウを閉じ、カーソル下のウィンドウにフォーカスする
Window_CloseAndFocus() {
    SendInput("!{F4}")
    Mouse_FocusUnderCursor()
}
