#Requires AutoHotkey v2.0
;==============================================================================
; box_open.ahk
; ブラウザで開いている Box のページ（フォルダ・ファイル）を、Box Drive のフォルダからエクスプローラーで開く
;   クイックメニューの「ウィンドウ → B」から呼ぶ（BoxOpen_Run）
;
; 仕組み
;   ページ内のリンク名（パンくずリスト）を上から順に、Box Drive のフォルダの下で 1 階層ずつ辿る（全体の検索はしない）。
;   ページのタイトル（「名前 | Box」）の名前に着いたらそこで止める。パンくずに現在の名前がないときは、最後にタイトルの名前を足して探す
;==============================================================================
#Include %A_LineFile%\..\config.ahk
#Include %A_LineFile%\..\ui_common.ahk
#Include %A_LineFile%\..\page_export.ahk

BOX_OPEN_ROOT := EnvGet("USERPROFILE") "\Box"   ; Box Drive のフォルダ

BoxOpen_Run() {
    hwnd := WinExist("A")
    title := hwnd ? WinGetTitle(hwnd) : ""
    name := Trim(RegExReplace(title, "\s+-\s+(Google Chrome|Microsoft.*Edge|Mozilla Firefox).*$"))
    name := Trim(RegExReplace(name, "\s*\|\s*(Powered by )?Box.*$"))
    if (name = "" || !InStr(title, "Box")) {
        UI_TipFlash("❌ [Box] Box のページではありません")
        return
    }
    if !DirExist(BOX_OPEN_ROOT) {
        UI_TipFlash("❌ [Box] Box Drive のフォルダがありません`n" BOX_OPEN_ROOT)
        return
    }
    links := []
    try links := _BoxOpen_Links(hwnd)
    cur := BOX_OPEN_ROOT
    for n in links {
        n := Trim(n)
        if (n = "" || RegExMatch(n, '[\\/:*?"<>|]') || !DirExist(cur "\" n))
            continue
        cur .= "\" n
        if (n = name)
            break
    }
    target := cur
    if (SubStr(cur, -StrLen(name)) != "\" name && FileExist(cur "\" name))
        target := cur "\" name
    if (target = BOX_OPEN_ROOT) {
        UI_TipFlash("❌ [Box] 「" name "」の場所をページから辿れませんでした")
        return
    }
    if InStr(FileExist(target), "D")
        Run('explorer.exe "' target '"')
    else
        Run('explorer.exe /select,"' target '"')
}

; ページ内の Hyperlink の名前を、画面の上から順に配列で返す
_BoxOpen_Links(hwnd) {
    uia := UI_Uia()
    ComCall(20, uia, "ptr*", &cr := 0)                  ; CreateCacheRequest
    for id in [30003, 30005]                            ; ControlType・Name
        ComCall(3, cr, "int", id)
    ComCall(7, cr, "int", 5)                            ; 対象の部品とその子孫すべて
    ComCall(11, cr, "int", 0)
    links := []
    loop 4 {
        _PageExport_Wake(hwnd)
        ComCall(10, uia, "ptr", hwnd, "ptr", cr, "ptr*", &root := 0)   ; ElementFromHandleBuildCache
        if root {
            try
                _BoxOpen_Walk(root, links, Buffer(24), 0)
            finally
                ObjRelease(root)
        }
        if links.Length
            break
        Sleep(300)
    }
    return links
}

_BoxOpen_Walk(el, links, v, depth) {
    ct := _PageExport_Int(el, 30003, v)
    if (ct = 50005) {                                   ; Hyperlink
        links.Push(_PageExport_Str(el, 30005, v))
        return
    }
    if (depth > 60 || links.Length > 400)
        return
    ComCall(19, el, "ptr*", &kids := 0)                 ; GetCachedChildren
    if !kids
        return
    try {
        ComCall(3, kids, "int*", &n := 0)
        loop n {
            ComCall(4, kids, "int", A_Index - 1, "ptr*", &kid := 0)
            try
                _BoxOpen_Walk(kid, links, v, depth + 1)
            finally
                ObjRelease(kid)
        }
    } finally
        ObjRelease(kids)
}
