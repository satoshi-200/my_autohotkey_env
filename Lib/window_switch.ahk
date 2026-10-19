#Requires AutoHotkey v2.0
;==============================================================================
; window_switch.ahk
; キーを押すたびにその場で切り替え、ほかのキーで決定するモード
;   ・アプリ切り替え（Alt+Tab の一覧を出したまま選ぶ。Caps → e）
;   ・タブ・ページの連続切り替え（Caps → d）／ウィンドウの大きさ変更（Caps → q）（KeyCycler）
;   ・ウィンドウを別のモニターへ移す（Caps → r）
; 共通の部品（IH_HotkeyTrigger / IH_ChoiceHook / IH_IsCancelKey）は key_wait.ahk にある
;==============================================================================
#Include %A_LineFile%\..\config.ahk
#Include %A_LineFile%\..\key_wait.ahk
#Include %A_LineFile%\..\ui_common.ahk

; タブ・ページ切り替え、ウィンドウの大きさ、モニター移動で決定するキー（ほかのキーは無視する）
;   キャプチャの選択の G / H、Space+g / h（Enter）・Space+b / n（クリック）に合わせる。v は b より近いので加える
SWITCH_DECIDE_KEYS := ["g", "h", "v", "b", "n", "Enter", "NumpadEnter"]
SWITCH_DECIDE_HINT := "g / h / v / b / n / Enter：決定　Esc / Caps / Space+Caps：元に戻す"

_Switch_IsDecideKey(key) {
    for k in SWITCH_DECIDE_KEYS
        if (key = k)
            return true
    return false
}

; Space が来たとき：押したまま打ったキーが決定・取り消しならそのキー、それ以外（Space だけを含む）は ""（無視）
_Switch_SpaceChord() {
    key := IH_KeyWhileSpaceHeld()
    return (_Switch_IsDecideKey(key) || IH_IsCapsKey(key)) ? key : ""
}

;------------------------------------------------------------------------------
; アプリ切り替え
;   Alt を押したままの状態を代わりに作り、Alt+Tab の一覧を出したまま選ばせる。
;   AppSwitcher_Show(reverse, pairKey)
;     reverse … false：次のアプリから、true：前（一覧の最後）のアプリから
;     pairKey … 逆方向に動かすキー（省略可）
;   呼び出しに使ったキーは自動で調べ、そのキーで同じ方向へ続けて動かせる。
;     例：Caps → e で AppSwitcher_Show(false, "w") … e：次、w：前
;   j k l ; / a s d f：一覧の中で ← / ↑ / ↓ / → に動かす
;   変換や v など他のキー：決定　Delete / x / c：選択中のウィンドウを閉じる　Esc / Caps / Space / :：キャンセル
;   APPSWITCH_IDLE_SEC 秒操作がなければ、そのとき選んでいるアプリに決定する。
;   決定後はマウスカーソルをそのウィンドウの中央へ移し、Ctrl を押して位置を表示する
;   （Windows の「Ctrl キーを押すとポインターの位置を表示する」をオンにしておくこと）。
;------------------------------------------------------------------------------
APPSWITCH_IDLE_SEC := 3
APPSWITCH_ARROWS := Map(
    "j", "Left", "k", "Up", "l", "Down", ";", "Right",
    "a", "Left", "s", "Up", "d", "Down", "f", "Right")
APPSWITCH_CLOSE_KEYS := ["Delete", "x", "c"]   ; 選択中のウィンドウを閉じるキー

AppSwitcher_Show(reverse := false, pairKey := "") {
    global IH_waiting
    IH_ModeBegin()

    triggerKey := IH_HotkeyTrigger(&prefix, IH_hook.Input)
    sameVK := (triggerKey != "") ? GetKeyVK(triggerKey) : 0
    pairVK := (pairKey != "") ? GetKeyVK(pairKey) : 0
    h := IH_ChoiceHook(APPSWITCH_IDLE_SEC, prefix)

    nextName := reverse ? pairKey : triggerKey
    prevName := reverse ? triggerKey : pairKey
    hint := (nextName != "" ? nextName "：次　" : "") (prevName != "" ? prevName "：前　" : "")
    closeHint := ""
    for k in APPSWITCH_CLOSE_KEYS
        closeHint .= (closeHint = "" ? "" : " / ") k

    startHwnd := WinExist("A")
    Send("{Alt down}" (reverse ? "+{Tab}" : "{Tab}"))
    steps := reverse ? -1 : 1                       ; 一覧で動かした量（0 なら元のウィンドウに戻る）
    posUnknown := false                             ; 矢印で動かす・閉じると、steps では判断できなくなる
    result := "決定"
    loop {
        ToolTip("🔀 [アプリ切り替え] " hint "j k l `; / a s d f：←↑↓→`n変換 / Enter など：決定　" closeHint "：閉じる　Esc / Caps / Space / :：キャンセル"
            . "`n（" APPSWITCH_IDLE_SEC " 秒操作しなければ決定）")
        h.Start()                                   ; 待ち時間は押すたびに数え直す
        h.Wait()
        key := h.EndKey
        vk := (h.EndReason = "EndKey") ? GetKeyVK(key) : 0
        if (vk && vk = sameVK) {
            Send(reverse ? "{Blind}+{Tab}" : "{Blind}{Tab}")
            steps += reverse ? -1 : 1
        }
        else if (vk && vk = pairVK) {
            Send(reverse ? "{Blind}{Tab}" : "{Blind}+{Tab}")
            steps += reverse ? 1 : -1
        }
        else if APPSWITCH_ARROWS.Has(key) {
            Send("{Blind}{" APPSWITCH_ARROWS[key] "}")
            posUnknown := true
        }
        else if _AppSwitcher_IsCloseKey(key) {      ; Alt+Tab 標準の「選んでいるウィンドウを閉じる」
            Send("{Blind}{Delete}")
            posUnknown := true
        }
        else {
            if (key = "Escape" || IH_IsCapsKey(key) || vk = 0x20  ; Esc / Caps / Space / :（JIS）
                || (vk && DllCall("MapVirtualKey", "UInt", vk, "UInt", 2, "UInt") = Ord(":"))) {
                Send("{Blind}{Esc}")
                result := "キャンセル"
            }
            break
        }
    }
    Send("{Alt up}")
    IH_waiting := false

    if (result = "決定") {
        ; 切り替わったウィンドウの中央へカーソルを移し、Ctrl で位置を知らせる波紋を出す
        _AppSwitcher_MoveCursorToCenter(_AppSwitcher_WaitTarget(startHwnd, steps != 0 || posUnknown))
        Send("{LCtrl}")
    }
    IH_ModeEnd((result = "決定" ? "✅" : "❌") " [アプリ切り替え] " result)
}

_AppSwitcher_IsCloseKey(key) {
    for k in APPSWITCH_CLOSE_KEYS
        if (key = k)
            return true
    return false
}

; 切り替え先のウィンドウが前面に来るのを待つ（Alt+Tab の一覧画面自体は除く）
; expectOther = true なら、元と違うウィンドウに替わるまで timeoutMs まで待つ
_AppSwitcher_WaitTarget(startHwnd, expectOther := true, timeoutMs := 1500, sameWinMs := 200) {
    t0 := A_TickCount
    last := 0
    loop {
        hwnd := DllCall("GetForegroundWindow", "Ptr")
        if (hwnd && !_AppSwitcher_IsSwitcherUI(hwnd)) {
            last := hwnd
            if (hwnd != startHwnd)
                return hwnd
            if (!expectOther && A_TickCount - t0 >= sameWinMs)
                return hwnd
        }
        if (A_TickCount - t0 >= timeoutMs)
            return last                             ; 一覧画面そのものは返さない
        Sleep(1)                                    ; タイマー分解能は mouse_cursor.ahk で 1ms にしてある
    }
}

_AppSwitcher_IsSwitcherUI(hwnd) {
    try cls := WinGetClass(hwnd)
    catch
        return true
    return cls = "XamlExplorerHostIslandWindow" || cls = "MultitaskingViewFrame"
        || cls = "TaskSwitcherWnd" || cls = "ForegroundStaging"
}

; ウィンドウの見えている範囲（影を除く）の中央へカーソルを移す
_AppSwitcher_MoveCursorToCenter(hwnd) {
    if (!hwnd || !WinExist(hwnd))
        return
    t0 := A_TickCount
    while (WinGetMinMax(hwnd) = -1) {               ; 最小化から復元中は位置が確定しないので待つ
        if (A_TickCount - t0 >= 1000)
            return
        Sleep(10)
    }
    rc := UI_VisibleRect(hwnd)
    DllCall("SetCursorPos", "Int", (rc.l + rc.r) // 2, "Int", (rc.t + rc.b) // 2)
}

;------------------------------------------------------------------------------
; KeyCycler：キーを押すたびにその場で操作し、Esc で送った分を逆順に戻すモード
;   actions … キー → [送るキー（または元に戻す関数を返す関数）, 戻すときに送るキー, 表示名]
;   SWITCH_DECIDE_KEYS（g / h / v / b / n / Enter。Space を押したままでも同じ）：決定　Esc / Caps / Space+Caps：動かした分を戻す
;   ほかのキーは無視。KEYCYCLE_IDLE_SEC 秒操作がなければ決定する。
;------------------------------------------------------------------------------
KEYCYCLE_IDLE_SEC := 3

KeyCycler_Show(title, actions) {
    IH_ModeBegin()
    h := IH_ChoiceHook(KEYCYCLE_IDLE_SEC)

    ; 同じ動作のキーはまとめて表示する（例：次のタブ：f j）
    keysOf := Map(), order := []
    for k, a in actions {
        if !keysOf.Has(a[3])
            keysOf[a[3]] := "", order.Push(a[3])
        keysOf[a[3]] .= " " k
    }
    hint := ""
    for label in order
        hint .= label "：" Trim(keysOf[label]) "　"

    undo := []                                      ; Esc で戻すための履歴
    result := "決定"
    loop {
        ToolTip("📑 [" title "] " hint "`n" SWITCH_DECIDE_HINT
            . "`n（" KEYCYCLE_IDLE_SEC " 秒操作しなければ決定）")
        h.Start()                                   ; 待ち時間は押すたびに数え直す
        h.Wait()
        if (h.EndReason = "Timeout")
            break
        key := StrLower(h.EndKey)
        if (GetKeyVK(key) = 0x20)                   ; Space：押したまま打ったキーで決める（Space だけなら何もしない）
            key := StrLower(_Switch_SpaceChord())
        if actions.Has(key) {
            a := actions[key]
            if (a[1] is Func)
                undo.Push(a[1]())                   ; 関数は戻す処理（関数）を返す
            else {
                SendInput(a[1])
                undo.Push(a[2])
            }
        }
        else if _Switch_IsDecideKey(key)
            break
        else if (key = "Escape" || IH_IsCapsKey(key)) {
            while undo.Length {
                u := undo.Pop()
                (u is Func) ? u() : SendInput(u)
                Sleep(30)                           ; 連続で送ると取りこぼすアプリがある
            }
            result := "元に戻しました"
            break
        }
    }
    IH_ModeEnd((result = "決定" ? "✅" : "↩️") " [" title "] " result)
}

;--- タブ・ページの連続切り替え（Caps → d）-------------------------------------
; 右手は左＝前・右＝次の向き
TABPAGE_ACTIONS := Map(
    "f", ["^{Tab}",  "^+{Tab}", "次のタブ"],
    "a", ["^+{Tab}", "^{Tab}",  "前のタブ"],
    "d", ["^{PgDn}", "^{PgUp}", "次のページ"],
    "s", ["^{PgUp}", "^{PgDn}", "前のページ"],
    "w", ["^{w}",    "^+{t}",   "タブを閉じる"],
    "e", ["^{t}",    "^{w}",    "新しいタブ"],
    "t", ["^+{PgDn}", "^+{PgUp}", "タブを右へ移動"],
    "tab", ["^+{PgUp}", "^+{PgDn}", "タブを左へ移動"],
    "r", ["^+{t}",   "^{w}",    "閉じたタブを復元"],
    "j", ["^+{Tab}", "^{Tab}",  "前のタブ"],
    ";", ["^{Tab}",  "^+{Tab}", "次のタブ"],
    "k", ["^{PgUp}", "^{PgDn}", "前のページ"],
    "l", ["^{PgDn}", "^{PgUp}", "次のページ"],
    "i", ["^{PgUp}", "^{PgDn}", "前のページ"],
    "o", ["^{PgDn}", "^{PgUp}", "次のページ"])

TabPageSwitcher_Show() => KeyCycler_Show("タブ・ページ切り替え", TABPAGE_ACTIONS)

;--- ウィンドウの大きさ変更（Caps → q）-----------------------------------------
; Win+↑ / Win+↓ を送る（連打可）。q：最大化、r：最小化
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

;------------------------------------------------------------------------------
; ウィンドウを別のモニターへ移す（Caps → r）
;   Win+Shift+→ / ← でアクティブウィンドウを移し、カーソルも移した先のモニターの中央へ動かす。
;   WindowMonitor_Show(reverse)
;     reverse … false：次のモニターへ、true：前のモニターへ
;   呼び出しに使ったキー（Caps → Tab なら Tab）で次へ、Shift 付きで前へ。
;   w：Win+↑、e：Win+↓ で大きさを変える。
;   SWITCH_DECIDE_KEYS（g / h / v / b / n / Enter。Space を押したままでも同じ）：決定　Esc / Caps / Space+Caps：元のモニターに戻す
;   ほかのキー（Space だけを含む）は無視する。WINMONITOR_IDLE_SEC 秒操作がなければ、そのときのモニターで決定する。
;------------------------------------------------------------------------------
WINMONITOR_IDLE_SEC := 3

WindowMonitor_Show(reverse := false) {
    IH_ModeBegin()
    count := MonitorGetCount()
    hwnd := WinExist("A")
    if (count < 2 || !hwnd) {
        IH_ModeEnd("🖥 [モニター移動] " (count < 2 ? "モニターが 1 台です" : "対象のウィンドウがありません"))
        return
    }

    triggerKey := IH_HotkeyTrigger(&prefix, (IH_hook.EndKey != "") ? IH_hook.EndKey : IH_hook.Input)
    sameVK := (triggerKey != "") ? GetKeyVK(triggerKey) : 0
    h := IH_ChoiceHook(WINMONITOR_IDLE_SEC, prefix)

    startPt := Buffer(8, 0)
    DllCall("GetCursorPos", "Ptr", startPt)
    steps := 0                                      ; 次へ +1、前へ -1（元に戻すときに使う）
    sizeUndo := []                                  ; w / e で変えた大きさを戻すための履歴
    mon := _WinMonitor_Step(hwnd, reverse)
    steps += reverse ? -1 : 1
    result := "決定"
    loop {
        ToolTip("🖥 [モニター移動] モニター " mon.idx " / " count
            . "`n" triggerKey "：次　Shift+" triggerKey "：前　w：大きく（Win+↑）　e：小さく（Win+↓）"
            . "`n" SWITCH_DECIDE_HINT
            . "`n（" WINMONITOR_IDLE_SEC " 秒操作しなければ決定）")
        h.Start()                                   ; 待ち時間は押すたびに数え直す
        h.Wait()
        if (h.EndReason = "Timeout")
            break
        key := h.EndKey
        vk := (h.EndReason = "EndKey") ? GetKeyVK(key) : 0
        if (vk = 0x20)                              ; Space：押したまま打ったキーで決める（Space だけなら何もしない）
            key := _Switch_SpaceChord(), vk := (key != "") ? GetKeyVK(key) : 0
        if (vk && vk = sameVK) {
            back := (reverse != GetKeyState("Shift"))   ; Shift 付きなら逆方向
            mon := _WinMonitor_Step(hwnd, back)
            steps += back ? -1 : 1
        }
        else if (key = "w" || key = "e") {
            if (WinGetMinMax(hwnd) = -1) {          ; 最小化中は Win+↑ が効かないので元に戻すだけ
                if (key = "w") {
                    WinRestore(hwnd), WinActivate(hwnd)
                    sizeUndo.Push("#{Down}")
                }
            }
            else {
                try WinActivate(hwnd)
                Send(key = "w" ? "#{Up}" : "#{Down}")
                sizeUndo.Push(key = "w" ? "#{Down}" : "#{Up}")
            }
        }
        else if _Switch_IsDecideKey(key)
            break
        else if (key = "Escape" || IH_IsCapsKey(key)) {
            while sizeUndo.Length {
                u := sizeUndo.Pop()
                if (WinGetMinMax(hwnd) = -1)
                    WinActivate(hwnd)               ; 最小化からの復帰 = Win+↑ 1 回分
                else {
                    try WinActivate(hwnd)
                    Send(u)
                }
                Sleep(30)
            }
            n := Mod(Mod(steps, count) + count, count)  ; 元のモニターまで「前へ」を何回押すか
            loop n
                _WinMonitor_Step(hwnd, true)
            DllCall("SetCursorPos", "Int", NumGet(startPt, 0, "Int"), "Int", NumGet(startPt, 4, "Int"))
            result := "元に戻しました"
            break
        }
    }
    IH_ModeEnd((result = "決定" ? "✅" : "❌") " [モニター移動] " result)
}

; ウィンドウを隣のモニターへ移し、カーソルをそのモニターの中央へ動かす
_WinMonitor_Step(hwnd, back) {
    before := DllCall("MonitorFromWindow", "Ptr", hwnd, "UInt", 2, "Ptr")
    try WinActivate(hwnd)
    Send(back ? "#+{Left}" : "#+{Right}")
    deadline := A_TickCount + 500
    while (DllCall("MonitorFromWindow", "Ptr", hwnd, "UInt", 2, "Ptr") = before && A_TickCount < deadline)
        Sleep(15)
    mon := _WinMonitor_Info(hwnd)
    DllCall("SetCursorPos", "Int", mon.cx, "Int", mon.cy)
    return mon
}

; ウィンドウがいるモニターの番号と中央の座標
_WinMonitor_Info(hwnd) {
    r := UI_MonitorRectFromWindow(hwnd)
    cx := (r.L + r.R) // 2, cy := (r.T + r.B) // 2
    return {idx: UI_MonitorFromPoint(cx, cy), cx: cx, cy: cy}
}
