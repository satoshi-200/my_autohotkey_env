#Requires AutoHotkey v2.0
;==============================================================================
; powerpoint_pack.ahk
; PowerPoint でスライドを作るときの便利機能の詰め合わせ（アプリ専用。principles.md の「アプリ専用の機能を入れる条件」）
;   呼び出し：クイックメニューの「PowerPoint」（P）→ F（Figure） で「図形編集モード」を始める。PowerPoint が前面にあるときだけ動く。
;   従来の機能（整列・等間隔など）は残してあるが、使っていないのでメニューには出さない（PPT_SHOW_LEGACY := true で再表示）。
;
; 図形編集モード（Ppt_EditStart）：ホームポジションのまま選択中の図形の大きさ・位置を変える（Shift+矢印を使わない）
;   j k l ; … 左 / 上 / 下 / 右へ動かす（Space+j k l ; の矢印と同じ配置）
;   u i o p … 大きさ：左へ小さく(幅−) / 上へ小さく(高さ−) / 下へ大きく(高さ+) / 右へ大きく(幅+)
;   q / r … 左 / 右へ回転           a / f … 前 / 次の図形を選ぶ     z / v … 元に戻す / やり直す
;   w / e … 刻みを 1pt（細かく）/ 10pt（粗く）     s / d … 大きさを変える基準を 左上固定 / 中心固定
;   左手は「小指と人差し指」「薬指と中指」を、対になる動作のペアにしている（docs\principles.md）
;   g / h / b / n / Esc / Caps / Enter / Space / カタカナひらがな … 終わる（押しっぱなしでキーリピートも効く）
;
; 作り方：標準の操作では手数がかかるものだけ、PowerPoint の COM で作る。
;   ・整列・等間隔・大きさをそろえる・位置の入れ替え … 選択中の図形（ShapeRange）を操作
;   ・画像として貼り付け … 公式のコマンド（ExecuteMso）
;   ・Alt のキー列や標準のショートカットで足りるもの（最前面・最背面、テキストだけ貼り付け、グループ化 Ctrl+G、
;     書式のコピー・貼り付け Ctrl+Shift+C / V、選択ウィンドウ Alt+F10）は入れない。
; 画面の見た目や位置には頼らない。
;
; 注意
;   ・図形を選んでいないとき、必要な数の図形を選んでいないときは、ツールチップで知らせる。
;   ・「大きさをそろえる」は、選んだ図形のうち最初のもの（ShapeRange の 1 番目）に合わせる。
;==============================================================================
#Include %A_LineFile%\..\ui_common.ahk
#Include %A_LineFile%\..\key_mode.ahk

PPT_EXE := "ahk_exe POWERPNT.EXE"
PPT_REQUIRE_ACTIVE := true                         ; false にすると、前面でなくても動かす（動作確認用）
PPT_SHOW_LEGACY := false                           ; true にすると、整列・等間隔などの従来機能をクイックメニュー（P）に再び出す
PPT_EDIT_STEP := 10                                ; 図形編集モードの刻み [pt]（通常）
PPT_EDIT_STEP_FINE := 1                            ; 図形編集モードの刻み [pt]（微調整。g で切り替え）
PPT_EDIT_ROTATE := 15                              ; 図形編集モードの回転の刻み [度]
PPT_EDIT_TIP := "corner"                           ; 案内の出し方（Lib\key_mode.ahk の tip）

; MsoAlignCmd
PPT_ALIGN_CMD := Map("left", 0, "center", 1, "right", 2, "top", 3, "middle", 4, "bottom", 5)

; PowerPoint の本体（Application）を返す。使えないときは ""（理由はツールチップで知らせる）
Ppt_App() {
    if (PPT_REQUIRE_ACTIVE && !WinActive(PPT_EXE)) {
        UI_Tip("PowerPoint が前面にありません")
        return ""
    }
    try
        return ComObjActive("PowerPoint.Application")
    try
        return ComObject("PowerPoint.Application")      ; 起動中のものにつながる
    UI_Tip("PowerPoint につなげませんでした")
    return ""
}

; 選択中の図形（ShapeRange）を返す。count 個以上選ばれていなければ ""
Ppt_Shapes(count := 1) {
    app := Ppt_App()
    if !IsObject(app)
        return ""
    try {
        sel := app.ActiveWindow.Selection
        if (sel.Type != 2 && sel.Type != 3)             ; ppSelectionShapes / ppSelectionText
            throw Error("no shapes")
        shapes := sel.ShapeRange
        if (shapes.Count < count)
            throw Error("few shapes")
        return shapes
    }
    UI_Tip(count > 1 ? "図形を " count " 個以上選んでください" : "図形を選んでください")
    return ""
}

;--- 整列・等間隔・大きさ・位置 ----------------------------------------------------
; 図形が 1 つのときはスライドに対して、2 つ以上のときは選んだ図形どうしでそろえる
Ppt_Align(kind) {
    shapes := Ppt_Shapes()
    if !IsObject(shapes)
        return
    try
        shapes.Align(PPT_ALIGN_CMD[kind], shapes.Count = 1 ? -1 : 0)
    catch as e
        UI_Tip("そろえられませんでした：" e.Message)
}

; dir: "h" 横、"v" 縦。3 つ以上は図形どうしの間隔を等しく、2 つならスライドの端に合わせる
Ppt_Distribute(dir) {
    shapes := Ppt_Shapes(2)
    if !IsObject(shapes)
        return
    try
        shapes.Distribute(dir = "h" ? 0 : 1, shapes.Count >= 3 ? 0 : -1)
    catch as e
        UI_Tip("等間隔にできませんでした：" e.Message)
}

; what: "w" 幅、"h" 高さ、"wh" 両方。最初の図形に合わせる
Ppt_MatchSize(what) {
    shapes := Ppt_Shapes(2)
    if !IsObject(shapes)
        return
    try {
        ref := shapes.Item(1)
        w := ref.Width, h := ref.Height
        loop shapes.Count - 1 {
            s := shapes.Item(A_Index + 1)
            lock := s.LockAspectRatio
            s.LockAspectRatio := 0
            if InStr(what, "w")
                s.Width := w
            if InStr(what, "h")
                s.Height := h
            s.LockAspectRatio := lock
        }
    } catch as e
        UI_Tip("大きさをそろえられませんでした：" e.Message)
}

; 2 つの図形の位置を入れ替える（それぞれの中心を入れ替える）
Ppt_Swap() {
    shapes := Ppt_Shapes(2)
    if !IsObject(shapes)
        return
    if (shapes.Count != 2) {
        UI_Tip("入れ替えるには、図形をちょうど 2 つ選んでください")
        return
    }
    try {
        a := shapes.Item(1), b := shapes.Item(2)
        ax := a.Left + a.Width / 2, ay := a.Top + a.Height / 2
        bx := b.Left + b.Width / 2, by := b.Top + b.Height / 2
        a.Left := bx - a.Width / 2, a.Top := by - a.Height / 2
        b.Left := ax - b.Width / 2, b.Top := ay - b.Height / 2
    } catch as e
        UI_Tip("入れ替えられませんでした：" e.Message)
}

;--- 貼り付け ---------------------------------------------------------------------
; 公式のコマンド（idMso）を実行する。今は使えない状態（クリップボードが空など）のときは知らせる
Ppt_Mso(idMso, failMessage) {
    app := Ppt_App()
    if !IsObject(app)
        return
    try {
        if !app.CommandBars.GetEnabledMso(idMso)
            throw Error("disabled")
        app.CommandBars.ExecuteMso(idMso)
    } catch
        UI_Tip(failMessage)
}

Ppt_PastePicture() => Ppt_Mso("PasteAsPicture", "画像として貼り付けられません（クリップボードを確かめてください）")

;--- 図形編集モード ---------------------------------------------------------------
; スキャンコード → 操作。キーリピートを効かせるため、key_mode.ahk の layers := false（そのまま受ける）で動かす
PPT_EDIT_KEYS := Map(0x24, "left", 0x25, "up", 0x26, "down", 0x27, "right"                  ; j k l ; ：移動（Space+jkl; の矢印と同じ）
    , 0x16, "narrower", 0x17, "shorter", 0x18, "taller", 0x19, "wider"                        ; u i o p ：大きさ（右手の 1 段上）
    , 0x10, "rotL", 0x13, "rotR", 0x1E, "prev", 0x21, "next", 0x2C, "undo", 0x2F, "redo"     ; q r / a f / z v（小指と人差し指のペア）
    , 0x11, "fineOn", 0x12, "fineOff", 0x1F, "anchorTL", 0x20, "anchorC")                    ; w e / s d（薬指と中指のペア）
PPT_EDIT_END_SC := [0x01, 0x3A, 0x1C, 0x39, 0x70, 0x22, 0x23, 0x30, 0x31]      ; Esc / Caps / Enter / Space / カタカナひらがな / g h b n（決定）

Ppt_EditStart() {
    st := {fine: false, center: false}
    IHM_Run(st, {message: _PptEdit_Message, onKey: _PptEdit_OnKey, onStart: _PptEdit_OnStart
        , layers: false, tip: PPT_EDIT_TIP})
}

_PptEdit_OnStart(st) {
    if !IsObject(Ppt_App())
        IHM_Finish(st, "noapp")
    else
        _PptEdit_Tip(st)
}

_PptEdit_Message(st) {
    switch st.result {
        case "timeout": return "❌ [図形編集] タイムアウト"
        case "noapp":   return "⚠️ [図形編集] PowerPoint が前面にありません"
        case "error":   return "⚠️ [図形編集] 失敗：" st.err
        default:        return "✅ [図形編集] 終了"
    }
}

_PptEdit_Tip(st) {
    IHM_Tip(st, "✏️ [図形編集] 刻み " (st.fine ? PPT_EDIT_STEP_FINE : PPT_EDIT_STEP) "pt・" (st.center ? "中心固定" : "左上固定")
        , "jkl;：移動　u i o p：左 上 下 右の辺（小 小 大 大）　q/r：回転　a/f：図形選択　z/v：戻す/やり直し　w/e：刻み 細/粗　s/d：基準 左上/中心　g h b n：決定")
}

_PptEdit_OnKey(st, k) {
    for sc in PPT_EDIT_END_SC {
        if (k.sc = sc) {
            IHM_Finish(st, "end")
            return
        }
    }
    if !PPT_EDIT_KEYS.Has(k.sc)
        return
    act := PPT_EDIT_KEYS[k.sc]
    step := st.fine ? PPT_EDIT_STEP_FINE : PPT_EDIT_STEP
    switch act {
        case "fineOn":
            st.fine := true
            _PptEdit_Tip(st)
        case "fineOff":
            st.fine := false
            _PptEdit_Tip(st)
        case "anchorTL":
            st.center := false
            _PptEdit_Tip(st)
        case "anchorC":
            st.center := true
            _PptEdit_Tip(st)
        case "taller":   _PptEdit_Do(st, (s) => _PptEdit_Resize(s, 0, step, st.center))
        case "shorter":  _PptEdit_Do(st, (s) => _PptEdit_Resize(s, 0, -step, st.center))
        case "wider":    _PptEdit_Do(st, (s) => _PptEdit_Resize(s, step, 0, st.center))
        case "narrower": _PptEdit_Do(st, (s) => _PptEdit_Resize(s, -step, 0, st.center))
        case "up":       _PptEdit_Do(st, (s) => s.Top -= step)
        case "down":     _PptEdit_Do(st, (s) => s.Top += step)
        case "left":     _PptEdit_Do(st, (s) => s.Left -= step)
        case "right":    _PptEdit_Do(st, (s) => s.Left += step)
        case "rotL":     _PptEdit_Do(st, (s) => s.Rotation := Mod(s.Rotation - PPT_EDIT_ROTATE + 360, 360))
        case "rotR":     _PptEdit_Do(st, (s) => s.Rotation := Mod(s.Rotation + PPT_EDIT_ROTATE, 360))
        case "next":     _PptEdit_Select(1)
        case "prev":     _PptEdit_Select(-1)
        case "undo":     Ppt_Mso("Undo", "元に戻せません")
        case "redo":     Ppt_Mso("Redo", "やり直せません")
    }
}

; 選択中の図形それぞれに fn を実行する
_PptEdit_Do(st, fn) {
    shapes := Ppt_Shapes()
    if !IsObject(shapes)
        return
    try {
        loop shapes.Count
            fn(shapes.Item(A_Index))
    } catch as e
        UI_Tip("変更できませんでした：" e.Message)
}

; 縦横比の固定を一時的に外して、幅・高さを dw・dh [pt] 変える（最小 2pt）
_PptEdit_Resize(s, dw, dh, center) {
    lock := s.LockAspectRatio
    s.LockAspectRatio := 0
    w := s.Width, h := s.Height
    nw := Max(2, w + dw), nh := Max(2, h + dh)
    s.Width := nw, s.Height := nh
    if center
        s.Left -= (nw - w) / 2, s.Top -= (nh - h) / 2
    s.LockAspectRatio := lock
}

; スライドの図形を重なり順に dir（1：次、-1：前）だけ進めて選ぶ
_PptEdit_Select(dir) {
    app := Ppt_App()
    if !IsObject(app)
        return
    try {
        all := app.ActiveWindow.View.Slide.Shapes
        if (all.Count = 0)
            return
        cur := 0
        sel := app.ActiveWindow.Selection
        if (sel.Type = 2 || sel.Type = 3) {
            id := sel.ShapeRange.Item(1).Id
            loop all.Count
                if (all.Item(A_Index).Id = id) {
                    cur := A_Index
                    break
                }
        }
        n := cur = 0 ? (dir > 0 ? 1 : all.Count) : Mod(cur - 1 + dir + all.Count, all.Count) + 1
        all.Item(n).Select()
    } catch as e
        UI_Tip("図形を選べませんでした：" e.Message)
}

