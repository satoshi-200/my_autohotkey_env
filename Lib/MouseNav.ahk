#Requires AutoHotkey v2.0
;==============================================================================
; MouseNav : ホームポジションのままマウスカーソルを操作する（AutoHotkey v2）
;------------------------------------------------------------------------------
; 【MoveCursorTo*2 系からの設計変更】
; (1) キーリピート駆動 → タイマー駆動
;     従来は「リピート 1 回 = 1 回移動」のため、初回リピート待ち（約 250ms）と
;     リピート間隔（約 30ms）が、そのまま出だしの遅れと動きのカクつきになっていた。
;     本版は押下で移動を開始し、以降はタイマーで物理キーの状態を監視しながら
;     連続的に移動する。キーを離した瞬間に停止する。
; (2) 速度は「押下からの経過時間」の関数
;     V_START から V_MAX まで CURVE に沿って加速する。
;     フレーム間隔（dt）を QueryPerformanceCounter で実測して移動量を決めるため、
;     タイマーの揺らぎや Arm エミュレーション下の遅延があっても速度が一定になる。
;     1px 未満の端数は次フレームに持ち越すため、低速でも滑らかに動く。
; (3) 2 方向の同時押しで斜め移動（斜めでも速度が速くならないよう正規化）
; (4) 移動中に Slow／Fast キーを押している間だけ、精密モード／高速モードに切替
; (5) Bisect（2 分割ジャンプ）
;     押すたびに対象領域を半分に絞り込み、その中央へ移動する。
;     5～6 回で画面上の任意の位置に到達できる（最初はカーソルのあるモニター全体）。
; (6) Warp：アクティブウィンドウの中央／モニターの中央／モニターの四隅／
;     次のモニター（同じ相対位置 or 中央）へ瞬間移動
;     アクティブウィンドウが対象外（デスクトップ、タスクバー、最小化中など）の場合は
;     カーソルのあるモニターの中央へ移動する。
;     モニターの巡回順は「左から右、同じ左端なら上から下」で、座標から自動判定する。
; (7) 従来版の高速化策は継承
;     API アドレスの事前解決、GetCursorPos/SetCursorPos による生ピクセル座標の統一、
;     per-monitor v2 DPI、Buffer の使い回し
;
; 【前提】
; ・方向キーの「押下時」に MouseNav_Left() 等を呼ぶ。キーリピートで何度呼ばれても問題ない。
;   停止は物理キーを離したことを検知して自動で行うので、キーを離したときの処理は不要。
; ・MouseNav.Keys に、実際に割り当てている物理キー名を必ず設定すること。
;   （離したことの検知に GetKeyState(key, "P") を使用するため）
;
; 【調整ポイント】
; V_START   … 押し始めの速度。短く押したときの移動量に効く。
; V_MAX     … 押し続けたときの最高速度。
; RAMP_MS   … 最高速度に達するまでの時間。短いほどすぐ速くなる。
; CURVE     … 加速の立ち上がり方。大きいほど出だしが穏やかで、後半に一気に加速する。
; V_SLOW    … 精密モードの速度（加速なし）。
;------------------------------------------------------------------------------
; 【2026/09/29 旧マウス関連ファイルからの移行】
; 旧ファイルの関数のうち、MouseNav で代替できないものだけを本ファイルへ移した。
;   継続（名前・呼び出し方はそのまま）
;     Right_click / Get_cursor_xy_pos / FocusUnderCursor / ToggleClick
;   置き換え
;     move_mouse_cursor_to_*、MoveCursorTo*、MoveCursorTo*2  → MouseNav_Left() 等
;     MoveCursorTo*Minimal、MoveCursorTo*Minimal2            → 廃止（微調整はトラックポイント）
;     Jump_to_upper_left_point 等（四隅）                     → MouseNav_Corner*()
;     Jump_to_center_display1～4（モニター巡回）              → MouseNav_WarpMonitorCenter()
;   廃止に伴い削除した変数
;     display1～3、currentDisplay、amount_of_movement*、REPEAT_WINDOW、MAX_ACCEL、ACCEL_STEP、
;     _hUser32、_pSetCursor、_pGetCursor、_ptBuf
;==============================================================================

;--- スクリプト全体の設定（旧ファイルから継承）---------------------------------
#SingleInstance Force
ListLines False
KeyHistory 0
ProcessSetPriority "High"
CoordMode("Mouse", "Screen")
DllCall("SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")


class MouseNav {
    ;--- 設定 -----------------------------------------------------------------
    ; 各操作に割り当てている物理キー（※実際の割り当てに合わせて変更）
    static Keys := Map(
        "Left",  "a",
        "Down",  "d",
        "Up",    "s",
        "Right", "f",
        "Slow",  "g",
        "Fast",  "r")

    static LayerKey       := "vk1D" ; このキーを離したら即停止（不要なら ""）
    static V_START        := 3000  ; 押し始めの速度 [px/s]
    static V_MAX          := 8000  ; 最高速度 [px/s]
    static RAMP_MS        := 150   ; V_MAX に達するまでの時間 [ms]
    static CURVE          := 1.0   ; 加速カーブ（1 = 直線）
    static V_SLOW         := 120   ; 精密モードの速度 [px/s]
    static FAST_MULT      := 2.5   ; 高速モードの倍率
    static TICK_MS        := 8     ; 更新周期 [ms]
    static NUDGE_PX       := 1     ; Nudge の移動量 [px]
    static BISECT_TIMEOUT := 1500  ; Bisect を連続操作とみなす間隔 [ms]

    ;--- 内部状態 -------------------------------------------------------------
    static _held := Map()   ; 押下中の方向 → 物理キー
    static _mods := Map()   ; 押下中のモード（Slow/Fast） → 物理キー
    static _startT := 0, _lastT := 0, _fx := 0.0, _fy := 0.0

    ;--- 初期化（初回アクセス時に自動実行）-------------------------------------
    static __New() {
        DllCall("SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")
        DllCall("winmm\timeBeginPeriod", "UInt", 1)             ; タイマー分解能を 1ms に
        OnExit((*) => (DllCall("winmm\timeEndPeriod", "UInt", 1), 0))

        hU := DllCall("GetModuleHandle", "Str", "user32", "Ptr")
        hK := DllCall("GetModuleHandle", "Str", "kernel32", "Ptr")
        this._pGet := DllCall("GetProcAddress", "Ptr", hU, "AStr", "GetCursorPos", "Ptr")
        this._pSet := DllCall("GetProcAddress", "Ptr", hU, "AStr", "SetCursorPos", "Ptr")
        this._pQpc := DllCall("GetProcAddress", "Ptr", hK, "AStr", "QueryPerformanceCounter", "Ptr")
        DllCall("QueryPerformanceFrequency", "Int64*", &f := 0)
        this._msPerCount := 1000 / f

        this._pt   := Buffer(8, 0)
        this._qpc  := Buffer(8, 0)
        this._timerFn := ObjBindMethod(this, "_Tick")   ; ※_Tick と別名にすること（大文字小文字を区別しないため衝突する）
        InstallKeybdHook()                                      ; 物理キー状態の取得に必要
    }

    ;=== 公開メソッド ===========================================================

    ; 連続移動（dir: "Left"/"Right"/"Up"/"Down"）、モード（dir: "Slow"/"Fast"）
    ; key を省略すると Keys の設定を使用
    static Hold(dir, key := "") {
        if (key = "")
            key := this.Keys[dir]
        if (dir = "Slow" || dir = "Fast") {
            this._mods[dir] := key
            return
        }
        if !this._held.Count {                                  ; 停止状態から開始
            this._startT := this._lastT := this._Now()
            this._fx := 0.0, this._fy := 0.0
            SetTimer(this._timerFn, this.TICK_MS)
        }
        this._held[dir] := key
    }

    ; 強制停止
    static Stop() {
        SetTimer(this._timerFn, 0)
        this._held.Clear()
    }

    ; 固定量の微小移動（ピクセル単位の位置合わせ用）
    static Nudge(dir, px := 0) {
        px := px || this.NUDGE_PX
        v := this._Vec(dir)
        this._MoveBy(v[1] * px, v[2] * px)
    }

    ; 2 分割ジャンプ
    static Bisect(dir) {
        static r := 0, last := 0
        this._GetPos(&x, &y)
        ; 時間が空いた／カーソルが他の手段で動かされた場合は、モニター全体から再開
        if (!r || A_TickCount - last > this.BISECT_TIMEOUT || x != r.cx || y != r.cy)
            r := this._MonitorRect(x, y)
        switch dir {
            case "Left":  r.R := (r.L + r.R) // 2
            case "Right": r.L := (r.L + r.R) // 2
            case "Up":    r.B := (r.T + r.B) // 2
            case "Down":  r.T := (r.T + r.B) // 2
        }
        r.cx := (r.L + r.R) // 2, r.cy := (r.T + r.B) // 2
        DllCall(this._pSet, "Int", r.cx, "Int", r.cy, "Int")
        last := A_TickCount
    }

    ; アクティブウィンドウの中央へ移動
    ; 対象となるウィンドウがない場合（デスクトップ、タスクバー、最小化中など）は、
    ; カーソルのあるモニターの中央へ移動する
    static WarpToActiveWindow() {
        hwnd := DllCall("GetForegroundWindow", "Ptr")
        if this._IsWarpTarget(hwnd) {
            rc := Buffer(16, 0)
            DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rc)
            cx := (NumGet(rc, 0, "Int") + NumGet(rc, 8, "Int")) // 2
            cy := (NumGet(rc, 4, "Int") + NumGet(rc, 12, "Int")) // 2
            ; ウィンドウの中央がどのモニター上にもない場合は採用しない
            if DllCall("MonitorFromPoint", "Int64", (cy << 32) | (cx & 0xFFFFFFFF), "UInt", 0, "Ptr") {
                DllCall(this._pSet, "Int", cx, "Int", cy, "Int")
                return
            }
        }
        this.WarpToMonitorCenter()
    }

    ; カーソルのあるモニターの中央へ移動
    static WarpToMonitorCenter() {
        this._GetPos(&x, &y)
        r := this._MonitorRect(x, y)
        DllCall(this._pSet, "Int", (r.L + r.R) // 2, "Int", (r.T + r.B) // 2, "Int")
    }

    ; カーソルのあるモニターの四隅へ移動（corner: "TL"=左上 / "TR"=右上 / "BL"=左下 / "BR"=右下）
    static WarpToCorner(corner) {
        this._GetPos(&x, &y)
        r := this._MonitorRect(x, y)
        nx := SubStr(corner, 2, 1) = "R" ? r.R - 1 : r.L
        ny := SubStr(corner, 1, 1) = "B" ? r.B - 1 : r.T
        DllCall(this._pSet, "Int", nx, "Int", ny, "Int")
    }

    ; 次のモニターへ移動
    ; center = false : 現在と同じ相対位置へ
    ; center = true  : モニターの中央へ
    static WarpToNextMonitor(center := false) {
        mons := this._Monitors()
        if (mons.Length < 2)
            return
        this._GetPos(&x, &y)
        cur := 1
        for i, m in mons {
            if (x >= m.L && x < m.R && y >= m.T && y < m.B) {
                cur := i
                break
            }
        }
        a := mons[cur], b := mons[Mod(cur, mons.Length) + 1]
        if center {
            nx := (b.L + b.R) // 2
            ny := (b.T + b.B) // 2
        } else {
            nx := b.L + Round((x - a.L) / (a.R - a.L) * (b.R - b.L))
            ny := b.T + Round((y - a.T) / (a.B - a.T) * (b.B - b.T))
        }
        DllCall(this._pSet, "Int", nx, "Int", ny, "Int")
    }

    ;=== 内部処理 ===============================================================

    static _Tick() {
        Critical                                                ; 途中で割り込まれないようにする

        ; 離されたキーを除外
        for dir, key in this._held.Clone()
            if !GetKeyState(key, "P")
                this._held.Delete(dir)
        if (this.LayerKey != "" && !GetKeyState(this.LayerKey, "P"))
            this._held.Clear()
        if !this._held.Count
            return this.Stop()

        now := this._Now()
        dt  := Min(now - this._lastT, 50) / 1000                ; [s]（処理落ち時の飛びを抑制）
        this._lastT := now

        ; 方向ベクトル（逆方向の同時押しは相殺）
        ux := this._held.Has("Right") - this._held.Has("Left")
        uy := this._held.Has("Down")  - this._held.Has("Up")
        if !(ux || uy)
            return
        if (ux && uy)
            ux *= 0.7071, uy *= 0.7071

        ; 速度
        if this._ModDown("Slow") {
            v := this.V_SLOW
            this._startT := now                                 ; 精密モード解除後は低速から再加速
        } else {
            p := Min((now - this._startT) / this.RAMP_MS, 1.0)
            v := this.V_START + (this.V_MAX - this.V_START) * p ** this.CURVE
            if this._ModDown("Fast")
                v *= this.FAST_MULT
        }

        ; 端数を持ち越しつつ移動
        this._fx += ux * v * dt
        this._fy += uy * v * dt
        ix := Integer(this._fx), iy := Integer(this._fy)
        if (ix || iy) {
            this._fx -= ix, this._fy -= iy
            this._MoveBy(ix, iy)
        }
    }

    static _ModDown(name) {
        if !this._mods.Has(name)
            return false
        if GetKeyState(this._mods[name], "P")
            return true
        this._mods.Delete(name)
        return false
    }

    static _Now() {
        DllCall(this._pQpc, "Ptr", this._qpc, "Int")
        return NumGet(this._qpc, 0, "Int64") * this._msPerCount
    }

    static _GetPos(&x, &y) {
        DllCall(this._pGet, "Ptr", this._pt, "Int")
        x := NumGet(this._pt, 0, "Int"), y := NumGet(this._pt, 4, "Int")
    }

    static _MoveBy(dx, dy) {
        this._GetPos(&x, &y)
        DllCall(this._pSet, "Int", x + dx, "Int", y + dy, "Int")
    }

    ; ワープ先として有効な通常ウィンドウかを判定する
    static _IsWarpTarget(hwnd) {
        if (!hwnd
            || !DllCall("IsWindowVisible", "Ptr", hwnd)
            || DllCall("IsIconic", "Ptr", hwnd))                ; 最小化中
            return false
        cls := Buffer(512, 0)
        DllCall("GetClassName", "Ptr", hwnd, "Ptr", cls, "Int", 256)
        switch StrGet(cls) {
            case "Progman", "WorkerW":                          ; デスクトップ
                return false
            case "Shell_TrayWnd", "Shell_SecondaryTrayWnd":     ; タスクバー
                return false
        }
        return true
    }

    static _Vec(dir) => dir = "Left" ? [-1, 0] : dir = "Right" ? [1, 0] : dir = "Up" ? [0, -1] : [0, 1]

    ; カーソルのあるモニターの矩形（タスクバー含む全体）
    static _MonitorRect(x, y) {
        hMon := DllCall("MonitorFromPoint", "Int64", (y << 32) | (x & 0xFFFFFFFF), "UInt", 2, "Ptr")
        mi := Buffer(40, 0), NumPut("UInt", 40, mi)
        DllCall("GetMonitorInfo", "Ptr", hMon, "Ptr", mi)
        return {L: NumGet(mi, 4, "Int"), T: NumGet(mi, 8, "Int")
              , R: NumGet(mi, 12, "Int"), B: NumGet(mi, 16, "Int")}
    }

    ; 全モニターの矩形を「左端の小さい順、同じなら上端の小さい順」で返す
    static _Monitors() {
        mons := []
        loop MonitorGetCount() {
            MonitorGet(A_Index, &l, &t, &r, &b)
            i := mons.Length + 1
            while (i > 1 && (mons[i - 1].L > l || (mons[i - 1].L = l && mons[i - 1].T > t)))
                i--
            mons.InsertAt(i, {L: l, T: t, R: r, B: b})
        }
        return mons
    }
}

;==============================================================================
; 呼び出し用ラッパー（引数なしで呼べる）
;==============================================================================
; 連続移動（押している間だけ動く）
MouseNav_Left()              => MouseNav.Hold("Left")
MouseNav_Right()             => MouseNav.Hold("Right")
MouseNav_Up()                => MouseNav.Hold("Up")
MouseNav_Down()              => MouseNav.Hold("Down")
; モード（移動中に押している間だけ有効）
MouseNav_Slow()              => MouseNav.Hold("Slow")
MouseNav_Fast()              => MouseNav.Hold("Fast")
; 微小移動（1 回押すごとに NUDGE_PX 移動）
MouseNav_NudgeLeft()         => MouseNav.Nudge("Left")
MouseNav_NudgeRight()        => MouseNav.Nudge("Right")
MouseNav_NudgeUp()           => MouseNav.Nudge("Up")
MouseNav_NudgeDown()         => MouseNav.Nudge("Down")
; 2 分割ジャンプ
MouseNav_JumpLeft()          => MouseNav.Bisect("Left")
MouseNav_JumpRight()         => MouseNav.Bisect("Right")
MouseNav_JumpUp()            => MouseNav.Bisect("Up")
MouseNav_JumpDown()          => MouseNav.Bisect("Down")
; ワープ
MouseNav_WarpWindow()        => MouseNav.WarpToActiveWindow()
MouseNav_WarpCenter()        => MouseNav.WarpToMonitorCenter()
MouseNav_WarpMonitor()       => MouseNav.WarpToNextMonitor()
MouseNav_WarpMonitorCenter() => MouseNav.WarpToNextMonitor(true)
; 四隅（カーソルのあるモニター）
MouseNav_CornerTopLeft()     => MouseNav.WarpToCorner("TL")
MouseNav_CornerTopRight()    => MouseNav.WarpToCorner("TR")
MouseNav_CornerBottomLeft()  => MouseNav.WarpToCorner("BL")
MouseNav_CornerBottomRight() => MouseNav.WarpToCorner("BR")
; 強制停止
MouseNav_Stop()              => MouseNav.Stop()


;==============================================================================
; その他のマウス関連関数（旧ファイルから移行。名前・動作は従来どおり）
;==============================================================================

; 右クリックメニュー（アプリケーションキー）を開く
; ※ turn_on_roman_input_mode() は別ファイルで定義されている前提
Right_click() {
    turn_on_roman_input_mode()
    SendInput("{vk5Dsc15D}")
}

; マウスカーソルの現在位置を表示する（座標確認用）
Get_cursor_xy_pos() {
    MouseGetPos(&xpos, &ypos)
    MsgBox("マウスカーソルの位置: X" xpos " Y" ypos)
}

; マウスカーソル下のウィンドウをアクティブにする
FocusUnderCursor() {
    MouseGetPos(, , &winID)
    if winID
        try WinActivate("ahk_id " winID)
}

; 左ボタンの押しっぱなし／解除を切り替える（ドラッグ用）
ToggleClick() {
    if GetKeyState("LButton") {
        Click("Up")
        ToolTip("Released")
    } else {
        Click("Down")
        ToolTip("Holding")
    }
    SetTimer(() => ToolTip(), -3000)    ; 3 秒後にヒントを消す（不要なら削除）
}
