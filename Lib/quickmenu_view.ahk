#Requires AutoHotkey v2.0
;==============================================================================
; quickmenu_view.ahk
; クイックメニュー（Lib\quick_menu.ahk）の項目を、キー割り当て・設定の画面（keymap_view.ahk）の「クイックメニュー」タブで確認・編集する部品。関数は Qmv_ で始める
;   Qmv_Json(hist)   … 画面に渡すデータ（カテゴリ、項目、使用回数、書かれている行番号と元の行）。quick_menu.ahk の「this.Add("カテゴリ", "キー", ...」の行を読む
;   Qmv_Save(...)    … 項目のキー（Add の 2 つ目の文字列）だけを書き換える。保存の手順は keymap_view.ahk の Km_Save と同じ
; 項目の定義（処理・名前）は quick_menu.ahk の行がそのまま出典で、ここでは重ねて持たない。キーは空白区切りで複数書ける（"N F `;" など）。
;==============================================================================
QMV_FILE := "Lib\quick_menu.ahk"
QMV_LAYER := "クイックメニュー"                    ; 1 つ前の内容の記録（keymap\.history.tsv）で、レイヤー名の代わりに使う
QMV_ITEM_RE := '^\s*this\.Add\("(\w)",\s*"([^"]*)",\s*"([^"]*)",\s*("[^"]*"|\x27[^\x27]*\x27)'

Qmv_IsFile(file) => file = QMV_FILE

; 項目ごとの使用回数（quick_usage.ini）
Qmv_Counts() {
    counts := Map()
    try txt := IniRead(Set_Root() "\quick_usage.ini", "count")
    catch
        return counts
    loop parse txt, "`n", "`r"
        if RegExMatch(A_LoopField, "^(.+?)=(\d+)$", &m)
            counts[m[1]] := Integer(m[2])
    return counts
}

; 画面に渡す JSON。{"cats":[{k, n, u}], "items":[{c, k, t, n, a, w, u, l, r, f, p, hasPrev}]}
;   c：カテゴリの英字、k：キー、t：タグ、n：名前、a：対象アプリ、w：出る条件（変数名）、u：使用回数、l・r：行番号と元の行、f：ファイル
Qmv_Json(hist) {
    try src := FileRead(Set_Root() "\" QMV_FILE, "UTF-8")
    catch
        return '{"cats":[],"items":[]}'
    counts := Qmv_Counts()
    cats := "", items := "", total := Map()
    cond := ""
    loop parse src, "`n", "`r" {
        line := A_LoopField
        if RegExMatch(line, '^\s*\{key: "(\w)", name: "([^"]*)"\}', &c)
            cats .= (cats != "" ? "," : "") "{`"k`":" Km_Q(c[1]) ",`"n`":" Km_Q(c[2]) "}"
        else if RegExMatch(line, "^\s*if\s+([A-Z_]+)\s*\{\s*$", &c)
            cond := c[1]
        else if (cond != "" && RegExMatch(line, "^\s*\}\s*$"))
            cond := ""
        else if RegExMatch(line, QMV_ITEM_RE, &m) {
            app := RegExMatch(line, ',\s*"(office|ppt|word|excel)"\)\s*(;.*)?$', &a) ? a[1] : ""
            tag := StrLower(m[3])
            prev := ""
            old := hist.Get(Km_HistKey(QMV_FILE, QMV_LAYER, tag), "")
            if (old != "" && RegExMatch(old, QMV_ITEM_RE, &om))
                prev := StrReplace(om[2], "``;", ";")
            items .= (items != "" ? "," : "") "{`"c`":" Km_Q(m[1]) ",`"k`":" Km_Q(StrReplace(m[2], "``;", ";"))
                . ",`"t`":" Km_Q(tag) ",`"n`":" Km_Q(SubStr(m[4], 2, -1)) ",`"a`":" Km_Q(app) ",`"w`":" Km_Q(cond)
                . ",`"u`":" counts.Get(tag, 0) ",`"l`":" A_Index ",`"r`":" Km_Q(line) ",`"f`":" Km_Q(QMV_FILE)
                . ",`"p`":" Km_Q(prev) ",`"hasPrev`":" (old != "" ? "true" : "false") "}"
        }
    }
    return "{`"cats`":[" cats "],`"items`":[" items "]}"
}

; タグ tag の項目（lineNo 行目、元の内容 raw）のキーを newKey に書き換える。結果は {ok, msg}
Qmv_Save(file, tag, lineNo, raw, newKey) {
    newKey := Trim(newKey)
    if !RegExMatch(newKey, "^[A-Za-z0-9/;](?: [A-Za-z0-9/;])*$")
        return {ok: false, msg: "英数字・/ ・; を、空白 1 つで区切って入力してください（例：U、N F `;）。"}
    if !RegExMatch(raw, '^(\s*this\.Add\("\w",\s*")([^"]*)(".*)$', &m)
        return {ok: false, msg: "元の行を読めませんでした。F5 で更新してから、やり直してください。"}
    lit := StrReplace(StrUpper(newKey), ";", "``;")             ; 文字列の中の「空白 + ;」はコメントになるので、バッククォートを付ける
    return Km_Save(file, QMV_LAYER, tag, lineNo, raw, m[1] lit m[3])
}
