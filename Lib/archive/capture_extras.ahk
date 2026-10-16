#Requires AutoHotkey v2.0
;==============================================================================
; capture_extras.ahk（読み込まれない）
; 画面キャプチャ（Lib\screen_capture.ahk）から外した撮り方。あまり使わないので、クイックメニューの割り付けを外したあと、
; 2026-10-16 のリファクタリングで本体からも外した。
;   Cap_Focus()      … いまフォーカスしている部品だけ。フォーカスを動かすと、枠も付いてくる
;                      （F → Tab　A → Shift+Tab　D / E → F6　S / W → Shift+F6。K / L で外側・内側の部品へ）
;   Cap_Active()     … いまのウィンドウ全体
;   Cap_Monitor()    … マウスがあるモニター全体
;   Cap_AllScreens() … すべてのモニター
;
; 戻し方
;   ・Cap_Active / Cap_Monitor / Cap_AllScreens：下の関数を screen_capture.ahk の「呼び出し口」に貼る。
;   ・Cap_Focus：下のホットキー・関数を screen_capture.ahk に貼り、さらに次を直す。
;       _Cap_Run の live を (mode = "window" || mode = "focus") に戻し、switch に
;         case "focus":  rc := _Cap_PickHover(st, _Cap_KeyFocus, _Cap_HoverFocus
;             , "F：Tab　A：Shift+Tab　D / E：F6　S / W：Shift+F6　　K / ホイール↑：外側へ　L / ホイール↓：内側へ　　クリック / Enter / G / H：撮影")
;       を足し、Finish の前に「else if (rc && live) Sleep(CAP_DELAY_MS)」（枠とツールチップが消えるのを待つ）を戻す。
;       _Cap_PickHover のツールチップの位置を、フォーカスのときは枠の左上（rc.l + 8, rc.t + 8）にする。
;       CapUIA に下の Focus メソッドを足す（IUIAutomation 8 GetFocusedElement）。
;   ・クイックメニュー（quick_menu.ahk の「C 画面キャプチャ」）に this.Add を 1 行足す。例：
;       this.Add("C", "A", "cap-active",  "いまのウィンドウ全体",            (*) => Cap_Active(), "capture screenshot window active")
;       this.Add("C", "K", "cap-focus",   "フォーカス中の部品（F6 で移動）",  (*) => Cap_Focus(), "capture screenshot focus f6 buhin")
;       this.Add("C", "S", "cap-monitor", "いまのモニター全体",              (*) => Cap_Monitor(), "capture screenshot screen display")
;       this.Add("C", "F", "cap-all",     "すべてのモニター",                (*) => Cap_AllScreens(), "capture screenshot screen full zenmen")
;==============================================================================

; フォーカスをホームポジションから動かす
#HotIf IsObject(Cap_session) && Cap_session.mode = "focus"
f::          SendInput("{Tab}")
a::          SendInput("+{Tab}")
d::          SendInput("{F6}")
e::          SendInput("{F6}")
s::          SendInput("+{F6}")
w::          SendInput("+{F6}")
#HotIf

Cap_Focus()   => _Cap_Run("focus")

Cap_Active() {
    if !(hwnd := WinExist("A"))
        return
    Sleep(CAP_DELAY_MS)
    _Cap_Finish(_Cap_Clamp(UI_VisibleRect(hwnd)))
}

Cap_Monitor() {
    MouseGetPos(&x, &y)
    MonitorGet(UI_MonitorFromPoint(x, y), &l, &t, &r, &b)
    Sleep(CAP_DELAY_MS)
    _Cap_Finish({l: l, t: t, r: r, b: b})
}

Cap_AllScreens() {
    vx := SysGet(76), vy := SysGet(77)
    Sleep(CAP_DELAY_MS)
    _Cap_Finish({l: vx, t: vy, r: vx + SysGet(78), b: vy + SysGet(79)})
}

_Cap_KeyFocus() {
    try {
        rc := CapUIA.Focus(0, &used)
        return rc ? rc.l "," rc.t "," rc.r "," rc.b : ""
    }
    return ""
}

_Cap_HoverFocus(st) {
    try {
        rc := CapUIA.Focus(st.wheel, &used)
        st.wheel := used
        return _Cap_Clamp(rc)
    }
    return 0
}

; CapUIA に足すメソッド：フォーカス中の部品から up 段だけ親をたどった部品の矩形
;    static Focus(up, &used) {
;        this._Init()
;        ComCall(8, this._ptr, "ptr*", &el := 0)
;        return this._Climb(el, up, &used)
;    }
