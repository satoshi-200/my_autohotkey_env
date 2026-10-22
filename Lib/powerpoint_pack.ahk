#Requires AutoHotkey v2.0
;==============================================================================
; powerpoint_pack.ahk
; PowerPoint 専用の機能（アプリ専用。principles.md の「アプリ専用の機能を入れる条件」）
;   Office 共通の機能（図形編集モードなど）は office_common.ahk に移した。ここには PowerPoint だけで使うものを置く。
;   呼び出し：クイックメニューの「Office」（O）に、PowerPoint が前面のときだけ出る。
;   いまあるのは従来の機能（整列・等間隔など）だけで、使っていないのでメニューには出さない（PPT_SHOW_LEGACY := true で再表示）。
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
#Include %A_LineFile%\..\office_common.ahk

PPT_SHOW_LEGACY := false                           ; true にすると、整列・等間隔などの従来機能をクイックメニュー（O）に再び出す

; MsoAlignCmd
PPT_ALIGN_CMD := Map("left", 0, "center", 1, "right", 2, "top", 3, "middle", 4, "bottom", 5)

; PowerPoint の本体（Application）を返す。使えないときは ""（理由はツールチップで知らせる）
Ppt_App() {
    host := Office_Host("ppt")
    return IsObject(host) ? Office_App(host) : ""
}

; 選択中の図形（ShapeRange）を返す。count 個以上選ばれていなければ ""
Ppt_Shapes(count := 1) {
    ctx := Office_Shapes(count, "ppt")
    return IsObject(ctx) ? ctx.shapes : ""
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
