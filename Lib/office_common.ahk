#Requires AutoHotkey v2.0
;==============================================================================
; office_common.ahk
; Office（PowerPoint / Word / Excel）で共通の機能（アプリ専用。principles.md の「アプリ専用の機能を入れる条件」）
;   呼び出し：クイックメニューの「Office」（O）→ F（Figure）で「図形編集モード」を始める。Office のどれかが前面にあるときだけ動く。
;   アプリごとの機能は powerpoint_pack.ahk など別の部品に置く。同じ「Office」カテゴリに、前面のアプリの分だけが出る（quick_menu.ahk）。
;
; 図形編集モード（Office_EditStart）：ホームポジションのまま選択中の図形の大きさ・位置を変える（Shift+矢印を使わない）
;   Space+j k l ; … 左 / 上 / 下 / 右へ動かす（通常の Space+j k l ; の矢印と同じ。Space を押している間だけ）
;   j k l ;         … 大きさ：左へ小さく(幅−) / 上へ小さく(高さ−) / 下へ大きく(高さ+) / 右へ大きく(幅+)
;   q / r … 左 / 右へ回転           a / f … 前 / 次の図形を選ぶ     z / v … 元に戻す / やり直す
;   w / e … 刻みを 1pt（細かく）/ 10pt（粗く）     s / d … 大きさを変える基準を 左上固定 / 中心固定
;   左手は「小指と人差し指」「薬指と中指」を、対になる動作のペアにしている（docs\principles.md）
;   g / h / b / n / Esc / Caps / Enter / カタカナひらがな … 終わる（押しっぱなしでキーリピートも効く）
;
; 作り方
;   ・選択中の図形（ShapeRange）の Left / Top / Width / Height / Rotation を COM で書き換える。3 つのアプリで同じ書き方。
;   ・元に戻す・やり直しは、Office 側の履歴に頼らず、モードが変更前の位置・大きさを覚えて戻す（Excel は COM で書き換えると、
;     Excel の元に戻す履歴が消えるため）。モードを終えたら覚えた分は捨てる。続けて行った同じ操作（長押しなど）は、元に戻す 1 回分にまとめる。
;   ・キーは、すぐには Office に書き込まず、いったん列に積んで、同じ操作は 1 つにまとめてから適用する。長押しのキーリピートで
;     COM の呼び出しが溜まって、動きがぎこちなくなったり、離したあとも動き続けたりするのを防ぐ。選択中の図形も、短い間隔なら取り直さず使い回す。
;   ・Word は、浮動図形だけが対象（行内の図には位置がなく、選んでも動かせない）。
;   ・Word・Excel は、前面のウィンドウから直接つなぐ（複数起動していても、前面のものを操作する）。PowerPoint は起動中のものにつなぐ。
; 画面の見た目や位置には頼らない。
;
; 注意：図形を選んでいないとき、必要な数の図形を選んでいないときは、ツールチップで知らせる。
;==============================================================================
#Include %A_LineFile%\..\ui_common.ahk
#Include %A_LineFile%\..\key_mode.ahk

OFFICE_REQUIRE_ACTIVE := true                      ; false にすると、前面でなくても動かす（動作確認用）
OFFICE_EDIT_STEP := 10                             ; 図形編集モードの刻み [pt]（通常）
OFFICE_EDIT_STEP_FINE := 1                         ; 図形編集モードの刻み [pt]（微調整）
OFFICE_EDIT_ROTATE := 15                           ; 図形編集モードの回転の刻み [度]
OFFICE_EDIT_TIP := "corner"                        ; 案内の出し方（Lib\key_mode.ahk の tip）
OFFICE_EDIT_UNDO_MAX := 200                        ; 元に戻せる操作の数
OFFICE_EDIT_MERGE_MS := 400                        ; 同じ操作をこの間隔以内に続けたとき、元に戻す 1 回分にまとめる [ms]
OFFICE_EDIT_CTX_MS := 600                          ; 選択中の図形を取り直さずに使い回す間隔 [ms]

; プロセス名 → アプリ。cls：前面のウィンドウから Application をたどるための子ウィンドウのクラス名
OFFICE_HOSTS := Map()
OFFICE_HOSTS.CaseSense := false
OFFICE_HOSTS.Set("POWERPNT.EXE", {id: "ppt", name: "PowerPoint", prog: "PowerPoint.Application", cls: ""}
    , "WINWORD.EXE", {id: "word", name: "Word", prog: "Word.Application", cls: "_WwG1"}
    , "EXCEL.EXE", {id: "excel", name: "Excel", prog: "Excel.Application", cls: "EXCEL71"})

; hwnd のウィンドウが Office のアプリなら、そのアプリ（OFFICE_HOSTS の値）。違えば ""
Office_HostOf(hwnd) {
    try
        return OFFICE_HOSTS.Get(WinGetProcessName("ahk_id " hwnd), "")
    return ""
}

Office_ById(id) {
    for , h in OFFICE_HOSTS
        if (h.id = id)
            return h
    return ""
}

; 使うアプリを返す。want（"ppt" / "word" / "excel"）を指定すると、そのアプリが前面のときだけ。使えなければ ""（理由はツールチップ）
Office_Host(want := "") {
    h := Office_HostOf(WinExist("A"))
    if !OFFICE_REQUIRE_ACTIVE
        return want != "" ? Office_ById(want) : (IsObject(h) ? h : Office_ById("ppt"))
    if (IsObject(h) && (want = "" || h.id = want))
        return h
    UI_Tip((want = "" ? "Office（PowerPoint / Word / Excel）" : Office_ById(want).name) " が前面にありません")
    return ""
}

; アプリの本体（Application）を返す。つなげなければ ""（理由はツールチップ）
Office_App(host) {
    if (host.cls != "") {
        try {
            hwnd := ControlGetHwnd(host.cls, "A")
            return Office_AppFromHwnd(hwnd)
        }
    }
    try
        return ComObjActive(host.prog)
    UI_Tip(host.name " につなげませんでした")
    return ""
}

; ウィンドウ（Word の _WwG、Excel の EXCEL7）から、そのウィンドウを持つ Application を得る
Office_AppFromHwnd(hwnd) {
    static iid := Office_IDispatchGuid()
    hr := DllCall("oleacc\AccessibleObjectFromWindow", "Ptr", hwnd, "UInt", 0xFFFFFFF0, "Ptr", iid, "Ptr*", &p := 0, "Int")
    if (hr != 0 || !p)
        throw Error("AccessibleObjectFromWindow")
    return ComObjFromPtr(p).Application
}

Office_IDispatchGuid() {
    guid := Buffer(16)
    DllCall("ole32\CLSIDFromString", "WStr", "{00020400-0000-0000-C000-000000000046}", "Ptr", guid)
    return guid
}

; 選択中の図形（ShapeRange）。図形を選んでいなければ例外
Office_Selection(host, app) {
    if (host.id = "ppt") {
        sel := app.ActiveWindow.Selection
        if (sel.Type != 2 && sel.Type != 3)             ; ppSelectionShapes / ppSelectionText
            throw Error("no shapes")
        return sel.ShapeRange
    }
    return app.Selection.ShapeRange                     ; Word は浮動図形、Excel は図形・グラフ（セルを選んでいると例外）
}

; 選択中の図形を count 個以上持っていれば {host, app, shapes}。なければ ""（理由はツールチップ）
Office_Shapes(count := 1, want := "") {
    host := Office_Host(want)
    if !IsObject(host)
        return ""
    app := Office_App(host)
    if !IsObject(app)
        return ""
    try {
        shapes := Office_Selection(host, app)
        if (shapes.Count < count)
            throw Error("few shapes")
        return {host: host, app: app, shapes: shapes}
    }
    UI_Tip((count > 1 ? "図形を " count " 個以上選んでください" : "図形を選んでください") (host.id = "word" ? "（行内の図は対象外）" : ""))
    return ""
}

; 今のページ・スライド・シートの図形の一覧（前後の図形を選ぶ用）
Office_AllShapes(host, app) {
    switch host.id {
        case "ppt":  return app.ActiveWindow.View.Slide.Shapes
        case "word": return app.ActiveDocument.Shapes
        default:     return app.ActiveSheet.Shapes
    }
}

;--- 図形編集モード ---------------------------------------------------------------
; スキャンコード → 操作。キーリピートを効かせるため、key_mode.ahk の layers := false（そのまま受ける）で動かす
OFFICE_EDIT_KEYS := Map(0x24, "narrower", 0x25, "shorter", 0x26, "taller", 0x27, "wider"             ; j k l ; ：大きさ
    , 0x10, "rotL", 0x13, "rotR", 0x1E, "prev", 0x21, "next", 0x2C, "undo", 0x2F, "redo"     ; q r / a f / z v（小指と人差し指のペア）
    , 0x11, "fineOn", 0x12, "fineOff", 0x1F, "anchorTL", 0x20, "anchorC")                    ; w e / s d（薬指と中指のペア）
OFFICE_EDIT_MOVE := Map(0x24, "left", 0x25, "up", 0x26, "down", 0x27, "right")          ; Space を押しながら j k l ; ：移動
OFFICE_EDIT_END_SC := [0x01, 0x3A, 0x1C, 0x70, 0x22, 0x23, 0x30, 0x31]          ; Esc / Caps / Enter / カタカナひらがな / g h b n（決定）

Office_EditStart() {
    st := {fine: false, center: false, host: "", undo: [], redo: [], q: [], flushing: false
        , ctx: "", ctxTick: 0, gAct: "", gTick: 0, space: false}
    st.flushFn := _OfficeEdit_Flush.Bind(st)
    IHM_Run(st, {message: _OfficeEdit_Message, onKey: _OfficeEdit_OnKey, onStart: _OfficeEdit_OnStart
        , onKeyUp: _OfficeEdit_OnKeyUp, onEnd: (st) => SetTimer(st.flushFn, 0), layers: false, critical: true, tip: OFFICE_EDIT_TIP})
}

_OfficeEdit_OnKeyUp(st, vk, sc) {
    if (sc = 0x39)
        st.space := false
}

_OfficeEdit_OnStart(st) {
    st.host := Office_Host()
    if IsObject(st.host)
        _OfficeEdit_Tip(st)
    else
        IHM_Finish(st, "noapp")
}

_OfficeEdit_Message(st) {
    switch st.result {
        case "timeout": return "❌ [図形編集] タイムアウト"
        case "noapp":   return "⚠️ [図形編集] Office（PowerPoint / Word / Excel）が前面にありません"
        case "error":   return "⚠️ [図形編集] 失敗：" st.err
        default:        return "✅ [図形編集] 終了"
    }
}

_OfficeEdit_Tip(st) {
    IHM_Tip(st, "✏️ [図形編集：" st.host.name "] 刻み " (st.fine ? OFFICE_EDIT_STEP_FINE : OFFICE_EDIT_STEP) "pt・" (st.center ? "中心固定" : "左上固定")
        , "Space+jkl;：移動　jkl;：左 上 下 右の辺（小 小 大 大）　q/r：回転　a/f：図形選択　z/v：戻す/やり直し　w/e：刻み 細/粗　s/d：基準 左上/中心　g h b n：決定")
}

_OfficeEdit_OnKey(st, k) {
    if (k.sc = 0x39) {                                  ; Space は押している間だけ「移動」の合図
        st.space := true
        return
    }
    for sc in OFFICE_EDIT_END_SC {
        if (k.sc = sc) {
            _OfficeEdit_Flush(st)                       ; 溜まっている操作を先に済ませてから終わる
            IHM_Finish(st, "end")
            return
        }
    }
    moves := st.space ? OFFICE_EDIT_MOVE : OFFICE_EDIT_KEYS
    if !moves.Has(k.sc)
        return
    if OFFICE_REQUIRE_ACTIVE {                          ; 別のアプリに移ったら、図形を取り違えないよう終える
        h := Office_HostOf(WinExist("A"))
        if (!IsObject(h) || h.id != st.host.id) {
            st.q := []
            IHM_Finish(st, "noapp")
            return
        }
    }
    act := moves[k.sc]
    step := st.fine ? OFFICE_EDIT_STEP_FINE : OFFICE_EDIT_STEP
    switch act {
        case "fineOn":
            st.fine := true
            _OfficeEdit_Tip(st)
        case "fineOff":
            st.fine := false
            _OfficeEdit_Tip(st)
        case "anchorTL":
            st.center := false
            _OfficeEdit_Tip(st)
        case "anchorC":
            st.center := true
            _OfficeEdit_Tip(st)
        case "rotL", "rotR":
            _OfficeEdit_Queue(st, act, OFFICE_EDIT_ROTATE)
        case "undo", "redo", "next", "prev":
            _OfficeEdit_Queue(st, act, 0)
        default:                                        ; 移動・大きさ
            _OfficeEdit_Queue(st, act, step)
    }
}

; 操作を列に積む。同じ操作が続いていれば 1 つにまとめる（長押しのキーリピートで、Office への書き込みが溜まらないように）
_OfficeEdit_Queue(st, act, amount) {
    n := st.q.Length
    if (n && st.q[n].act = act && st.q[n].amount = amount && st.q[n].center = st.center)
        st.q[n].n++
    else
        st.q.Push({act: act, amount: amount, center: st.center, n: 1})
    if !st.flushing
        SetTimer(st.flushFn, -1)
}

; 列を順に処理する。処理中に積まれた分も続けて処理する
_OfficeEdit_Flush(st) {
    if st.flushing
        return
    st.flushing := true
    try {
        while st.q.Length {
            Critical("On")
            el := st.q.RemoveAt(1)
            Critical("Off")
            _OfficeEdit_Run(st, el)
        }
    } finally {
        st.flushing := false
    }
    if st.q.Length
        SetTimer(st.flushFn, -1)
}

_OfficeEdit_Run(st, el) {
    switch el.act {
        case "undo":
            loop el.n
                _OfficeEdit_Step(st.undo, st.redo, "戻せる操作がありません")
            st.gAct := ""
        case "redo":
            loop el.n
                _OfficeEdit_Step(st.redo, st.undo, "やり直せる操作がありません")
            st.gAct := ""
        case "next", "prev":
            loop el.n
                _OfficeEdit_Select(st, el.act = "next" ? 1 : -1)
            st.ctx := "", st.gAct := ""
        default:
            _OfficeEdit_Move(st, el)
    }
}

; 選択中の図形を取り直さずに使い回す（長押しの間、毎回つなぎ直すと遅い）
_OfficeEdit_Ctx(st) {
    if !(IsObject(st.ctx) && A_TickCount - st.ctxTick < OFFICE_EDIT_CTX_MS)
        st.ctx := Office_Shapes(1, st.host.id)
    st.ctxTick := A_TickCount
    return st.ctx
}

; 移動・大きさ・回転を、選択中の図形にまとめて適用する。続けて行った同じ操作は、元に戻す 1 回分にする
_OfficeEdit_Move(st, el) {
    ctx := _OfficeEdit_Ctx(st)
    if !IsObject(ctx)
        return
    amt := el.amount * el.n
    fresh := (st.gAct != el.act || A_TickCount - st.gTick > OFFICE_EDIT_MERGE_MS)
    snap := ""
    try {
        if fresh {
            snap := _OfficeEdit_Snap(ctx.shapes, st.host.id)
            if (st.host.id = "word")
                loop ctx.shapes.Count
                    _OfficeEdit_WordAbs(ctx.shapes.Item(A_Index))
        }
        loop ctx.shapes.Count
            _OfficeEdit_Apply(ctx.shapes.Item(A_Index), el.act, amt, el.center)
    } catch as err {
        if IsObject(snap)
            try _OfficeEdit_Restore(snap)
        st.ctx := "", st.gAct := ""
        UI_Tip("変更できませんでした：" err.Message)
        return
    }
    if IsObject(snap) {
        st.undo.Push(snap)
        if (st.undo.Length > OFFICE_EDIT_UNDO_MAX)
            st.undo.RemoveAt(1)
        st.redo := []
    }
    st.gAct := el.act, st.gTick := A_TickCount
}

_OfficeEdit_Apply(s, act, amt, center) {
    switch act {
        case "left":     s.Left -= amt
        case "right":    s.Left += amt
        case "up":       s.Top -= amt
        case "down":     s.Top += amt
        case "narrower": _OfficeEdit_Resize(s, -amt, 0, center)
        case "wider":    _OfficeEdit_Resize(s, amt, 0, center)
        case "shorter":  _OfficeEdit_Resize(s, 0, -amt, center)
        case "taller":   _OfficeEdit_Resize(s, 0, amt, center)
        case "rotL":     s.Rotation := Mod(Mod(s.Rotation - amt, 360) + 360, 360)
        case "rotR":     s.Rotation := Mod(s.Rotation + amt, 360)
    }
}

; 図形ごとの位置・大きさ・角度を覚える（Word は位置の基準も。これを戻しないと、「配置」指定の図形が絶対位置のまま残る）
_OfficeEdit_Snap(shapes, hostId) {
    snap := []
    loop shapes.Count
        snap.Push(_OfficeEdit_SnapShape(shapes.Item(A_Index), hostId = "word"))
    return snap
}

_OfficeEdit_SnapShape(s, withRel) {
    e := {s: s, l: s.Left, t: s.Top, w: s.Width, h: s.Height, r: s.Rotation}
    if withRel
        e.rv := s.RelativeVerticalPosition, e.rh := s.RelativeHorizontalPosition
    return e
}

_OfficeEdit_Restore(snap) {
    for e in snap {
        s := e.s
        lock := s.LockAspectRatio
        s.LockAspectRatio := 0
        s.Width := e.w, s.Height := e.h
        s.LockAspectRatio := lock
        s.Rotation := e.r
        if e.HasOwnProp("rv")
            s.RelativeVerticalPosition := e.rv, s.RelativeHorizontalPosition := e.rh
        s.Left := e.l, s.Top := e.t
    }
}

; Word：位置を「配置」（中央・上・左など）で指定した図形は、Left / Top が特別な値（-999995 など）で足し引きできない。
; 基準をページにして、いまの配置に相当する絶対位置に直す（余白は PageSetup。段組み・見開きの余白は考えない）
_OfficeEdit_WordAbs(s) {
    top := s.Top, left := s.Left
    if (top > -900000 && left > -900000)
        return
    ps := s.Anchor.PageSetup
    w := s.Width, h := s.Height
    if (top <= -900000) {
        rv := s.RelativeVerticalPosition                ; 0 余白、1 ページ
        if (rv > 1)
            throw Error("縦位置の基準が段落・行のため、動かせません")
        t0 := rv = 0 ? ps.TopMargin : 0
        fh := rv = 0 ? ps.PageHeight - ps.TopMargin - ps.BottomMargin : ps.PageHeight
        y := top = -999999 ? t0 : top = -999995 ? t0 + (fh - h) / 2 : top = -999997 ? t0 + fh - h : ""
        if (y = "")
            throw Error("縦位置が「内側・外側」のため、動かせません")
        s.RelativeVerticalPosition := 1
        s.Top := y
    }
    if (left <= -900000) {
        rh := s.RelativeHorizontalPosition              ; 0 余白、1 ページ、2 段
        if (rh > 2)
            throw Error("横位置の基準が文字のため、動かせません")
        l0 := rh = 1 ? 0 : ps.LeftMargin
        fw := rh = 1 ? ps.PageWidth : ps.PageWidth - ps.LeftMargin - ps.RightMargin
        x := left = -999998 ? l0 : left = -999995 ? l0 + (fw - w) / 2 : left = -999996 ? l0 + fw - w : ""
        if (x = "")
            throw Error("横位置が「内側・外側」のため、動かせません")
        s.RelativeHorizontalPosition := 1
        s.Left := x
    }
}

; from の最後の操作を取り消し、取り消す前の状態を to に積む（元に戻す・やり直し）
_OfficeEdit_Step(from, to, emptyMsg) {
    if (from.Length = 0) {
        UI_Tip(emptyMsg)
        return
    }
    snap := from.Pop()
    try {
        now := []
        for e in snap
            now.Push(_OfficeEdit_SnapShape(e.s, e.HasOwnProp("rv")))
        _OfficeEdit_Restore(snap)
        to.Push(now)
    } catch
        UI_Tip("戻せませんでした（図形が見つからないか、変更できません）")
}

; 縦横比の固定を一時的に外して、幅・高さを dw・dh [pt] 変える（最小 2pt）
_OfficeEdit_Resize(s, dw, dh, center) {
    lock := s.LockAspectRatio
    s.LockAspectRatio := 0
    w := s.Width, h := s.Height
    nw := Max(2, w + dw), nh := Max(2, h + dh)
    s.Width := nw, s.Height := nh
    if center
        s.Left -= (nw - w) / 2, s.Top -= (nh - h) / 2
    s.LockAspectRatio := lock
}

; 今のページ・スライド・シートの図形を一覧の順に dir（1：次、-1：前）だけ進めて選ぶ
_OfficeEdit_Select(st, dir) {
    host := st.host
    app := Office_App(host)
    if !IsObject(app)
        return
    try {
        all := Office_AllShapes(host, app)
        if (all.Count = 0)
            return
        cur := 0
        try {
            id := Office_Selection(host, app).Item(1).Id
            loop all.Count
                if (all.Item(A_Index).Id = id) {
                    cur := A_Index
                    break
                }
        }
        n := cur = 0 ? (dir > 0 ? 1 : all.Count) : Mod(cur - 1 + dir + all.Count, all.Count) + 1
        all.Item(n).Select()
    } catch as err
        UI_Tip("図形を選べませんでした：" err.Message)
}
