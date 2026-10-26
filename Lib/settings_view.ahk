#Requires AutoHotkey v2.0
;==============================================================================
; settings_view.ahk
; 設定値（各部品の冒頭の「名前 := 値  ; コメント」の行）を、キー割り当て一覧の画面（keymap_view.ahk）で確認・編集する部品。関数は Set_ で始める
;   SET_DEFS            … 画面に出す設定の一覧（グループ・表示名・種類・範囲）。設定を足すときは、ここに 1 行書く
;   Set_Json(hist)      … 画面に渡すデータ（現在の値と、書かれているファイル・行番号・元の行）
;   Set_Save(...)       … 値を種類で確かめて、その行を書き換える（保存の手順は keymap_view.ahk の Km_Save と同じ）
; 種類：int / float（範囲あり）・bool・color（RRGGBB）・choice（選択肢）・text（文字）・expr（AutoHotkey の式。そのまま書き換える）
; 現在の行が種類に合わない書き方のとき（式など）は、expr として扱う。
;==============================================================================
#Include %A_LineFile%\..\keymap_parse.ahk

SET_LAYER := "設定"                              ; 1 つ前の内容の記録（keymap\.history.tsv）で、レイヤー名の代わりに使う
SET_TIP_OPTS := ["corner", "hidden", "cursor"]

; group：画面での分け方、file：書かれているファイル（リポジトリの直下から）、a・b：範囲（int / float）。choice は a に選択肢の配列
Set_Def(group, file, name, label, type, a := "", b := "", note := "") => {group: group, file: file, name: name, label: label
    , type: type, a: a, b: b, note: note}

SET_DEFS := [
    Set_Def("表示・案内", "Lib\config.ahk", "TOOLTIP_FONT_SIZE", "ツールチップの文字の大きさ [pt]", "int", 8, 40),
    Set_Def("表示・案内", "Lib\config.ahk", "TOOLTIP_DURATION_MS", "ツールチップを消すまでの時間 [ms]", "int", 100, 10000),
    Set_Def("表示・案内", "Lib\config.ahk", "IME_TIP_MS", "IME 切り替えの表示を消すまでの時間 [ms]（0 で表示しない）", "int", 0, 5000),
    Set_Def("表示・案内", "Lib\key_mode.ahk", "IHM_HELP_DELAY_MS", "モードの説明を出すまでの待ち [ms]", "int", 0, 10000),
    Set_Def("入力待ち", "keymap\leader_keys.ahk", "LEADER_HELP_DELAY_MS", "割り当て一覧を出すまでの待ち [ms]", "int", 0, 10000),
    Set_Def("入力待ち", "Lib\key_wait.ahk", "IH_TIMEOUT_SEC", "キー入力がなければキャンセルするまで [秒]", "int", 1, 300),
    Set_Def("直前の入力", "Lib\last_input.ahk", "LASTINPUT_ENABLED", "直前の入力を覚える", "bool", , , "パスワード欄などで打った文字も覚えるので、気になる場合は false"),
    Set_Def("直前の入力", "Lib\last_input.ahk", "LASTINPUT_MAX_LEN", "覚える文字数の上限", "int", 1, 5000),
    Set_Def("直前の入力", "Lib\last_input.ahk", "LASTINPUT_GAP_MS", "ひとまとまりが終わるまでの時間 [ms]", "int", 100, 60000),
    Set_Def("日付入力", "Lib\date_input.ahk", "DATEINPUT_TIMEOUT_MS", "操作がなければキャンセルするまで [ms]", "int", 1000, 600000),
    Set_Def("日付入力", "Lib\date_input.ahk", "DATEINPUT_DAY_STEP", "J / `; で動かす日数", "int", 1, 366),
    Set_Def("カーソル移動モード", "Lib\mouse_grid.ahk", "MOUSEGRID_AUTO_END", "赤ポチ・マウスの操作でモードを終える", "bool"),
    Set_Def("カーソル移動モード", "Lib\mouse_grid.ahk", "MOUSEGRID_MANUAL_PX", "マウスの操作とみなすずれ [px]", "int", 1, 100),
    Set_Def("カーソル移動モード", "Lib\mouse_grid.ahk", "MOUSEGRID_MAX_DEPTH", "マスを選ぶ回数（自動で終わるまで）", "int", 1, 4),
    Set_Def("カーソル移動モード", "Lib\mouse_grid.ahk", "MOUSEGRID_ALPHA", "表示の不透明度", "int", 0, 255),
    Set_Def("カーソル移動モード", "Lib\mouse_grid.ahk", "MOUSEGRID_LINE_COLOR", "枠・区切り線の色", "color"),
    Set_Def("カーソル移動モード", "Lib\mouse_grid.ahk", "MOUSEGRID_LABEL_BG", "ラベルの背景色", "color"),
    Set_Def("カーソル移動モード", "Lib\mouse_grid.ahk", "MOUSEGRID_LABEL_FG", "ラベルの文字色", "color"),
    Set_Def("カーソル移動モード", "Lib\mouse_grid.ahk", "MOUSEGRID_TIP", "案内の出し方", "choice", SET_TIP_OPTS),
    Set_Def("Vimium C 風ヒント", "Lib\vimium_c_hints.ahk", "VIMIUMC_ALPHABET", "ラベルに使う文字", "text"),
    Set_Def("Vimium C 風ヒント", "Lib\vimium_c_hints.ahk", "VIMIUMC_LABEL_BG", "ラベルの背景色", "color"),
    Set_Def("Vimium C 風ヒント", "Lib\vimium_c_hints.ahk", "VIMIUMC_LABEL_BG_RIGHT", "右クリックモード中のラベルの背景色", "color"),
    Set_Def("Vimium C 風ヒント", "Lib\vimium_c_hints.ahk", "VIMIUMC_LABEL_FG", "ラベルの文字色", "color"),
    Set_Def("Vimium C 風ヒント", "Lib\vimium_c_hints.ahk", "VIMIUMC_LABEL_ALPHA", "ラベルの不透明度", "int", 0, 255),
    Set_Def("Vimium C 風ヒント", "Lib\vimium_c_hints.ahk", "VIMIUMC_THUMB_CLICK", "親指キーでクリックの種類を選ぶ", "bool", , , "true：Space＝ダブルクリック、変換＝右クリック、無変換＝ホバー。false：Space+A で左手だけのラベル入力"),
    Set_Def("Vimium C 風ヒント", "Lib\vimium_c_hints.ahk", "VIMIUMC_TIP", "案内の出し方", "choice", SET_TIP_OPTS),
    Set_Def("画面キャプチャ", "Lib\screen_capture.ahk", "CAP_SAVE_DIR", "保存先（AutoHotkey の式。空文字なら保存しない）", "expr"),
    Set_Def("画面キャプチャ", "Lib\screen_capture.ahk", "CAP_COPY", "クリップボードにコピーする", "bool"),
    Set_Def("画面キャプチャ", "Lib\screen_capture.ahk", "CAP_DELAY_MS", "実行前の待ち時間 [ms]", "int", 0, 5000),
    Set_Def("画面キャプチャ", "Lib\screen_capture.ahk", "CAP_DIM_ALPHA", "範囲選択中に画面を暗くする濃さ", "int", 0, 255),
    Set_Def("画面キャプチャ", "Lib\screen_capture.ahk", "CAP_FRAME_COLOR", "選択中の枠の色", "color"),
    Set_Def("画面キャプチャ", "Lib\screen_capture.ahk", "CAP_FRAME_PX", "枠の太さ [px]", "int", 1, 20),
    Set_Def("画面キャプチャ", "Lib\screen_capture.ahk", "CAP_TRIM_MAX_PX", "自動トリミングで各辺から削る幅の上限 [px]", "int", 0, 200),
    Set_Def("画面キャプチャ", "Lib\screen_capture.ahk", "CAP_TRIM_TOL", "同じ色とみなす差", "int", 0, 255),
    Set_Def("画面キャプチャ", "Lib\screen_capture.ahk", "CAP_TRIM_NOISE", "色が違っていても許す画素の割合", "float", 0, 1),
    Set_Def("マルチクリップボード", "Lib\multi_clipboard.ahk", "CLIP_ROWS", "一覧の 1 列の行数", "int", 3, 60),
    Set_Def("マルチクリップボード", "Lib\multi_clipboard.ahk", "CLIP_C_SEL", "選んでいる行の背景色", "color"),
    Set_Def("マルチクリップボード", "Lib\multi_clipboard.ahk", "CLIP_C_BG", "一覧の背景色", "color"),
    Set_Def("ウィンドウ操作", "Lib\window_switch.ahk", "APPSWITCH_IDLE_SEC", "アプリ切り替え：操作がなければ決定するまで [秒]", "int", 1, 60),
    Set_Def("ウィンドウ操作", "Lib\window_switch.ahk", "KEYCYCLE_IDLE_SEC", "タブ・ページ切り替え：操作がなければ決定するまで [秒]", "int", 1, 60),
    Set_Def("ウィンドウ操作", "Lib\window_switch.ahk", "WINMONITOR_IDLE_SEC", "モニター移動：操作がなければ決定するまで [秒]", "int", 1, 60),
    Set_Def("マウス", "Lib\mouse_cursor.ahk", "MOUSENAV_VERTICAL_CENTER", "縦のモニターへの移動で、中央へ行く（OFF：同じ相対位置）", "bool"),
    Set_Def("Shift 長押しモード", "Lib\shift_hold.ahk", "SHIFTHOLD_IDLE_MS", "操作がなければ終了するまで [ms]（0 で無効）", "int", 0, 3600000),
    Set_Def("Shift 長押しモード", "Lib\shift_hold.ahk", "SHIFTHOLD_BAR_HEIGHT", "モード中にモニター上端へ出す帯の高さ [px]（0 で出さない）", "int", 0, 100),
    Set_Def("Shift 長押しモード", "Lib\shift_hold.ahk", "SHIFTHOLD_BAR_COLOR", "帯の色", "color"),
    Set_Def("Office", "Lib\office_common.ahk", "OFFICE_REQUIRE_ACTIVE", "Office のアプリが前面のときだけ動かす", "bool"),
    Set_Def("Office", "Lib\office_common.ahk", "OFFICE_EDIT_STEP", "図形編集モードの刻み [pt]", "int", 1, 200),
    Set_Def("Office", "Lib\office_common.ahk", "OFFICE_EDIT_STEP_FINE", "図形編集モードの微調整の刻み [pt]", "int", 1, 50),
    Set_Def("Office", "Lib\office_common.ahk", "OFFICE_EDIT_ROTATE", "図形編集モードの回転の刻み [度]", "int", 1, 180),
    Set_Def("Office", "Lib\office_common.ahk", "OFFICE_EDIT_UNDO_MAX", "図形編集モードで元に戻せる操作の数", "int", 1, 2000),
    Set_Def("Office", "Lib\office_common.ahk", "OFFICE_EDIT_TIP", "案内の出し方", "choice", SET_TIP_OPTS),
    Set_Def("PowerPoint", "Lib\powerpoint_pack.ahk", "PPT_SHOW_LEGACY", "従来機能（整列・等間隔など）をクイックメニューに出す", "bool")]

Set_Root() => RegExReplace(A_LineFile, "\\Lib\\[^\\]+$")

Set_IsEditableFile(file) {
    for d in SET_DEFS
        if (d.file = file)
            return true
    return false
}

Set_FindDef(file, name) {
    for d in SET_DEFS
        if (d.file = file && d.name = name)
            return d
    return ""
}

; 「名前 := 値  ; コメント」の行を、先頭（pre）・値（val）・値のあとの空白とコメント（tail）・コメント（comment）に分ける
Set_ParseLine(raw, name, &pre, &val, &tail, &comment) {
    if !RegExMatch(raw, "i)^(" name "\s*:=\s*)(.*)$", &m)
        return false
    pre := m[1]
    KP_SplitComment(m[2], &val, &comment)
    tail := SubStr(m[2], StrLen(val) + 1)
    return val != ""
}

; 種類に合わせて値を確かめ、行に書く形（lit）にする。問題がなければ ""、あれば理由を返す
Set_Check(def, type, value, &lit) {
    switch type {
        case "int", "float":
            if !RegExMatch(value, type = "int" ? "^-?\d+$" : "^-?\d+(\.\d+)?$")
                return (type = "int" ? "整数" : "数値") "で入力してください。"
            n := Number(value)
            if (n < def.a || n > def.b)
                return def.a " 〜 " def.b " の範囲で入力してください。"
            lit := type = "int" ? String(Integer(value)) : value
        case "bool":
            v := StrLower(value)
            if (v != "true" && v != "false")
                return "true か false を選んでください。"
            lit := v
        case "color":
            if !RegExMatch(value, "^[0-9A-Fa-f]{6}$")
                return "色は RRGGBB の 16 進 6 桁で入力してください（例：FFE066）。"
            lit := '"' StrUpper(value) '"'
        case "choice":
            ok := false
            for o in def.a
                ok := ok || (o == value)
            if !ok
                return "選択肢から選んでください。"
            lit := '"' value '"'
        case "text":
            if (value = "" || RegExMatch(value, '["``\r\n]|\s;'))
                return "空でない 1 行で、引用符・バッククォート・「 `;」を含まない文字を入力してください。"
            lit := '"' value '"'
        default:
            if (Trim(value) = "" || RegExMatch(value, "[\r\n]"))
                return "1 行で、空でない式を入力してください。"
            lit := Trim(value)
    }
    return ""
}

; 現在の値（行に書かれている形）を、種類に合うなら画面で扱う形にする。合わなければ type を expr にして、書かれている形のまま返す
Set_Current(def, valTxt) {
    type := def.type, v := valTxt
    if (type = "color" || type = "choice" || type = "text") {
        if RegExMatch(valTxt, '^"([^"``]*)"$', &m)
            v := m[1]
        else
            return {type: "expr", value: valTxt}
    }
    else if (type = "bool")
        v := StrLower(valTxt)
    if (type != "expr" && Set_Check(def, type, v, &lit) != "")
        return {type: "expr", value: valTxt}
    return {type: type, value: v}
}

; 設定が書かれている行を探す。見つからなければ 0
Set_FindLine(src, name) {
    loop parse src, "`n", "`r" {
        if RegExMatch(A_LoopField, "i)^" name "\s*:=")
            return {lineNo: A_Index, raw: A_LoopField}
    }
    return 0
}

;------------------------------------------------------------------------------
; 画面に渡すデータ
;------------------------------------------------------------------------------
Set_Json(hist) {
    out := ""
    cache := Map()
    for def in SET_DEFS {
        if !cache.Has(def.file) {
            try
                cache[def.file] := FileRead(Set_Root() "\" def.file, "UTF-8")
            catch
                cache[def.file] := ""
        }
        found := Set_FindLine(cache[def.file], def.name)
        if (!found || !Set_ParseLine(found.raw, def.name, &pre, &val, &tail, &comment))
            continue
        cur := Set_Current(def, val)
        prev := ""
        old := hist.Get(Km_HistKey(def.file, SET_LAYER, def.name), "")
        if (old != "" && Set_ParseLine(old, def.name, &p2, &pv, &t2, &c2))
            prev := Set_Current(def, pv).value
        out .= (out != "" ? "," : "") "{`"g`":" Km_Q(def.group) ",`"name`":" Km_Q(def.name) ",`"label`":" Km_Q(def.label)
            . ",`"type`":" Km_Q(cur.type) ",`"file`":" Km_Q(def.file) ",`"l`":" found.lineNo ",`"r`":" Km_Q(found.raw)
            . ",`"v`":" Km_Q(cur.value) ",`"c`":" Km_Q(comment != "" ? comment : def.note) ",`"p`":" Km_Q(prev)
            . ",`"hasPrev`":" (old != "" ? "true" : "false") Set_RangeJson(def, cur.type) "}"
    }
    return "[" out "]"
}

Set_RangeJson(def, type) {
    if (type = "int" || type = "float")
        return ",`"min`":" def.a ",`"max`":" def.b
    if (type = "choice") {
        opts := ""
        for o in def.a
            opts .= (opts != "" ? "," : "") Km_Q(o)
        return ",`"opts`":[" opts "]"
    }
    return ""
}

;------------------------------------------------------------------------------
; 保存
;------------------------------------------------------------------------------
; 設定 name の行（lineNo 行目、元の内容 raw）の値を value に書き換える。結果は {ok, msg}
Set_Save(file, name, lineNo, raw, value) {
    def := Set_FindDef(file, name)
    if !def
        return {ok: false, msg: "この設定は編集できません。"}
    if !Set_ParseLine(raw, name, &pre, &val, &tail, &comment)
        return {ok: false, msg: "元の行を読めませんでした。F5 で更新してから、やり直してください。"}
    type := Set_Current(def, val).type
    err := Set_Check(def, type, value, &lit)
    if (err != "")
        return {ok: false, msg: err}
    return Km_Save(file, SET_LAYER, name, lineNo, raw, pre lit Set_TailFor(tail, StrLen(val), StrLen(lit)))
}

; コメントの位置がずれないように、値の長さの差の分だけ空白を増減する
Set_TailFor(tail, oldLen, newLen) {
    if !InStr(tail, ";")
        return ""
    RegExMatch(tail, "^\s*", &m)
    n := Max(1, StrLen(m[0]) + oldLen - newLen)
    return Format("{:" n "}", "") SubStr(tail, StrLen(m[0]) + 1)
}
