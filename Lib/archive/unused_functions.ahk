#Requires AutoHotkey v2.0
;==============================================================================
; unused_functions.ahk（読み込まれない）
; どこからも呼ばれていなかった小さな関数（2026-10-16 のリファクタリングで外した）。戻し方は各関数の上に書く。
;==============================================================================

;--- 仮想デスクトップを番号で切り替える（元は quick_menu.ahk）----------------------------
; Lib\window_ops.ahk の QM_DesktopState / QM_DesktopMoveBy を使う。
; 戻すときは window_ops.ahk に貼り、quick_menu.ahk の「D 仮想デスクトップ」に次の 2 行を足す。
;   loop 9
;       this.Add("D", String(A_Index), "desk-" A_Index, "デスクトップ " A_Index " へ", QM_DesktopGo.Bind(A_Index), "virtual desktop switch kirikae")
QM_DesktopGo(n) {
    if !QM_DesktopState(&cur, &count) {
        UI_Tip("仮想デスクトップの状態を取得できませんでした")
        return
    }
    if (n > count) {
        UI_Tip("デスクトップ " n " はありません（全 " count " 個）")
        return
    }
    if (n != cur)
        QM_DesktopMoveBy(n - cur)
    UI_Tip("デスクトップ " n " / " count)
}

;--- マルチクリップボードの箱をすべて空にする（元は multi_clipboard.ahk。以前は Caps → \）----------
; 戻すときは multi_clipboard.ahk に貼り、割り当てを足す（例：leader_keys.ahk の Leader_Caps で "\",  Clip_ClearAll,）。
Clip_ClearAll() {
    if (MsgBox("すべての箱を空にしますか？", "全消去の確認", "YesNo Icon!") = "Yes") {
        Clip_boxes.Clear()
        _Clip_Tip("すべて空にしました！")
    }
}

;--- ウィンドウの大きさ変更（元は window_switch.ahk。以前は Caps → q。w / e は Caps → r のモニター移動モードにもある）----------
; 戻すときは window_switch.ahk の TabPageSwitcher_Show の下に貼り、leader_keys.ahk の Leader_Caps で "q",  WindowResizer_Show,  を割り当てる。
; keymap_view.ahk の KM_FUNC_NAMES に "WindowResizer_Show", "ウィンドウの大きさ" を足す。
; q：最大化、w：Win+↑、e：Win+↓、r：最小化
WINSIZE_ACTIONS := Map(
    "q", [WinSize_Set.Bind(1),  "", "最大化"],
    "w", ["#{Up}",   "#{Down}", "大きく（Win+↑）"],
    "e", ["#{Down}", "#{Up}",   "小さく（Win+↓）"],
    "r", [WinSize_Set.Bind(-1), "", "最小化"])

WindowResizer_Show() => KeyCycler_Show("ウィンドウの大きさ", WINSIZE_ACTIONS)

; state 1：最大化、-1：最小化。元の状態に戻す関数を返す
WinSize_Set(state) {
    if !(hwnd := WinExist("A"))
        return () => 0
    prev := WinGetMinMax(hwnd)
    (state = 1) ? WinMaximize(hwnd) : WinMinimize(hwnd)
    return WinSize_Restore.Bind(hwnd, prev)
}

WinSize_Restore(hwnd, prev) {
    if !WinExist(hwnd)
        return
    if (prev = 1)
        WinMaximize(hwnd)
    else if (prev = -1)
        WinMinimize(hwnd)
    else {
        WinRestore(hwnd)
        if (WinGetMinMax(hwnd) = 1)                 ; 最小化前が最大化だと 1 回では戻らない
            WinRestore(hwnd)
    }
    if (prev != -1)
        WinActivate(hwnd)
}
