#Requires AutoHotkey v2.0
;==============================================================================
; leader_keys.ahk
; 起点キー（リーダーキー）を押して離したあと、次に押したキーで機能を分ける割り当て表
;   CapsLock          … Leader_Caps()
;   Space + F         … Leader_SpaceF()   （hold_keys.ahk の Space レイヤーから呼ぶ）
;   Space + A         … Leader_SpaceA()   （同上）
;   カタカナひらがな  … MouseGrid_Start() （入力待ちではなく、カーソル移動モード。Lib\mouse_grid.ahk）
;
; 割り当ての書き方（各関数の中の表）
;   keys     … 文字キー → 処理（大文字・小文字は区別しない）
;   specials … 特殊キーのスキャンコード → 処理（Tab 0x0F / Caps 0x3A / Space 0x39 / 変換 0x79 / 無変換 0x7B / かな 0x70）。Caps は表にあるときだけキャンセルではなく処理になる
;   処理は「送るキーの文字列」か「呼び出す関数」。"" は未割り当て（空きが分かるように主要なキーはすべて書く）
;   行末のコメントは、入力待ちで止まったときに出る割り当て一覧の説明になる（なければ処理をそのまま表示）
;==============================================================================
#Include %A_LineFile%\..\..\Lib\key_wait.ahk
#Include %A_LineFile%\..\..\Lib\keymap_parse.ahk
#Include %A_LineFile%\..\..\Lib\oneshot_modifiers.ahk
#Include %A_LineFile%\..\..\Lib\text_input.ahk
#Include %A_LineFile%\..\..\Lib\window_switch.ahk
#Include %A_LineFile%\..\..\Lib\window_ops.ahk
#Include %A_LineFile%\..\..\Lib\multi_clipboard.ahk
#Include %A_LineFile%\..\..\Lib\mouse_cursor.ahk
#Include %A_LineFile%\..\..\Lib\mouse_grid.ahk
#Include %A_LineFile%\..\..\Lib\quick_menu.ahk
#Include %A_LineFile%\..\..\Lib\vimium_c_hints.ahk
#Include %A_LineFile%\..\..\Lib\shift_hold.ahk

;------------------------------------------------------------------------------
; 起点キー（Space+F / Space+A は hold_keys.ahk から呼ぶ）
;------------------------------------------------------------------------------
#HotIf !IH_waiting
sc03A:: Leader_Caps()                               ; CapsLock
sc070:: MouseGrid_Start()                           ; カタカナひらがな：カーソル移動モード
#HotIf

; 無変換は hold_keys.ahk の「vk1D & ○」のプレフィックスとして止められ InputHook に届かないので、ホットキーで渡す
#HotIf IH_waiting && IH_hook.InProgress
vk1D:: IH_StopWithKey("sc07B")
#HotIf

; Shift 長押しモード（Lib\shift_hold.ahk）の終了。Shift を押したままの間は、「*」なしの単独キーのホットキーが発動しないので「*」を付ける。
; Caps は上の Leader の起点（sc03A）と別の定義なので、モード中だけこちらが先に働く。Space+Caps は hold_keys.ahk で止める。
#HotIf ShiftHold_IsOn()
*sc03A:: ShiftHold_Stop()
*Escape:: ShiftHold_Stop()
*Enter:: ShiftHold_Enter("{Blind}{Enter}")          ; 確定したらモードを抜ける
*NumpadEnter:: ShiftHold_Enter("{Blind}{NumpadEnter}")
#HotIf

;------------------------------------------------------------------------------
; 割り当て表
;------------------------------------------------------------------------------
Leader_Caps() {
    static keys := Leader_Keys(
        ; --- 数字列 ---
        "1",  "",
        "2",  "",
        "3",  "",
        "4",  "",
        "5",  "",
        "6",  "",
        "7",  "",
        "8",  "",
        "9",  "",
        "0",  "",
        "-",  "",
        "^",  "",
        "\",  "",
        ; --- 上段 ---
        "q",  WindowResizer_Show,                   ; ウィンドウの大きさ
        "w",  QM_DesktopMenu_Show,                  ; 仮想デスクトップメニュー
        "e",  () => AppSwitcher_Show(false, "w"),   ; アプリ切り替え（e：次、w：前）
        "r",  WindowMonitor_Show,                   ; ウィンドウを別のモニターへ（r：次、Shift+r：前）
        "t",  QM_CaptureMenu_Show,                  ; 画面キャプチャメニュー
        "y",  "",
        "u",  QuickPalette_Show,                    ; コマンドパレット
        "i",  Oneshot_AltChar,                      ; Alt + 文字キー
        "o",  Oneshot_CtrlShiftChar,                ; Ctrl + Shift + 文字キー
        "p",  "",
        "@",  "",
        "[",  "",
        ; --- 中段 ---
        "a",  "",
        "s",  VimiumC_ShowHints,                    ; Vimium C 風ヒント（部品に英字を重ねて、打ったところをクリック）
        "d",  TabPageSwitcher_Show,                 ; タブ・ページ切り替え
        "f",  Oneshot_Fn,                           ; Fn キー
        "g",  "{Enter}",
        "h",  "{Enter}",
        "j",  QuickMenu_Show,                       ; クイックメニュー
        "k",  QM_SymbolMenu_Show,                   ; 記号メニュー
        "l",  Oneshot_CtrlChar,                     ; Ctrl + 文字キー
        ";",  Oneshot_WinChar,                      ; Win + 文字キー
        ":",  "",
        "]",  "",
        ; --- 下段 ---
        "z",  "",
        "x",  "",
        "c",  "",
        "v",  "",
        "b",  Mouse_ToggleDrag,                     ; ドラッグ開始／解除
        "n",  Mouse_ToggleDrag,
        "m",  "",
        ",",  Oneshot_CtrlNum,                      ; Ctrl + 数字キー（左手で入力）
        ".",  Oneshot_CtrlNum,
        "/",  "")
    static specials := Map(
        0x39, Ime_Alnum,                            ; Space：IME を半角英数に
        0x79, Ime_Hiragana,                         ; 変換：IME をひらがなに
        0x7B, Text_CapitalizeNext)                  ; 無変換：次の 1 文字を大文字に
    Leader_Run("Caps", keys, specials, true)
}

Leader_SpaceF() {
    static keys := Leader_Keys(
        ; --- 数字列 ---
        "1",  "",
        "2",  "",
        "3",  "",
        "4",  "",
        "5",  "",
        "6",  "",
        "7",  "",
        "8",  "",
        "9",  "",
        "0",  "",
        "-",  "",
        "^",  "",
        "\",  "",
        ; --- 上段 ---
        "q",  "^{Home}",                            ; 文書の先頭
        "w",  "{Home}",                             ; 行頭
        "e",  "{End}",                              ; 行末
        "r",  "^{End}",                             ; 文書の末尾
        "t",  "",
        "y",  "",
        "u",  QM_DateMenu_Show,                     ; 日付・時刻のメニュー（時刻の書式も選べる）
        "i",  DateInput_Start,                      ; 日付入力（日付を調整 → フォーマットを選ぶ）
        "o",  () => Text_InsertDate("yyyy/MM/dd"),
        "p",  () => Text_InsertDate("yyMMdd_"),     ; Obsidian のページ名用
        "@",  "",
        "[",  Window_CloseAndFocus,                 ; ウィンドウを閉じてカーソル下にフォーカス
        ; --- 中段 ---
        "a",  "{LWin}",
        "s",  "{LCtrl}",
        "d",  "{LAlt}",
        "f",  Mouse_ContextMenu,                    ; 右クリックメニュー
        "g",  "",
        "h",  "",
        "j",  "+{Enter}",
        "k",  "^{Enter}",
        "l",  "!{Enter}",
        ";",  "",
        ":",  "",
        "]",  Window_CloseAndFocus,                 ; ウィンドウを閉じてカーソル下にフォーカス
        ; --- 下段 ---
        "z",  "",
        "x",  "",
        "c",  "",
        "v",  "",
        "b",  "",
        "n",  "",
        "m",  "",
        ",",  "",
        ".",  "",
        "/",  "")
    static specials := Map(
        0x3A, ShiftHold_Toggle)                     ; Caps：Shift 長押しモード
    ShiftHold_Remember()
    Leader_Run("Space + F", keys, specials)
}

; 右手側の文字・記号を左手で入力する
Leader_SpaceA() {
    static keys := Leader_Keys(
        ; --- 数字列 ---
        "1",  "{0}",
        "2",  "{9}",
        "3",  "{8}",
        "4",  "{7}",
        "5",  "{6}",
        "6",  "",
        "7",  "",
        "8",  "",
        "9",  "",
        "0",  "",
        "-",  "",
        "^",  "",
        "\",  "",
        ; --- 上段 ---
        "q",  "{p}",
        "w",  "{o}",
        "e",  "{i}",
        "r",  "{u}",
        "t",  "{y}",
        "y",  "",
        "u",  "{|}",
        "i",  "{~}",
        "o",  "{!}",
        "p",  "{^}",
        "@",  "{\}",
        "[",  "",
        ; --- 中段 ---
        "a",  "{Space}",
        "s",  "{l}",
        "d",  "{k}",
        "f",  "{j}",
        "g",  "{h}",
        "h",  "",
        "j",  "{#}",
        "k",  "{$}",
        "l",  "{%}",
        ";",  "{&}",
        ":",  "{~}",
        "]",  "",
        ; --- 下段 ---
        "z",  "{/}",
        "x",  "{.}",
        "c",  "{,}",
        "v",  "{m}",
        "b",  "{n}",
        "n",  "",
        "m",  "",
        ",",  "",
        ".",  "",
        "/",  "")
    Leader_Run("Space + A：左手で文字・記号", keys, , , true)
}

;------------------------------------------------------------------------------
; 共通処理
;------------------------------------------------------------------------------
LEADER_HELP_DELAY_MS := 1000              ; 入力待ちでこの時間キーを押さないと割り当て一覧を表示する
LEADER_END_KEYS := "{Tab}{Esc}{RAlt}{LShift}{Space}{sc079}{sc07B}{sc070}"
LEADER_KEY_NAMES := Map(0x138, "右Alt", 0x2A, "LShift", 0x0F, "Tab", 0x3A, "Caps", 0x39, "Spaceキー"
    , 0x79, "変換キー", 0x7B, "無変換キー", 0x70, "カタカナひらがなキー")

; 文字キーの割り当て表を作る（大文字・小文字を区別しない）
Leader_Keys(pairs*) {
    m := Map()
    m.CaseSense := false
    m.Set(pairs*)
    return m
}

; 次のキーを待ち、表に従って処理する
;   forcedAsSpecial … ホットキーから渡された無変換も特殊キーとして扱う（Caps のみ）
;   shiftAware     … Shift 長押しモード中、待つ間だけ Shift を離して表を引き、送るときに Shift を戻す（送る文字にモードが反映される）
Leader_Run(mode, keys, specials := 0, forcedAsSpecial := false, shiftAware := false) {
    help := Leader_ShowHelp.Bind(mode, Error("", -2).What)   ; 呼び出し元（Leader_Caps など）の表を表示する
    SetTimer(help, -LEADER_HELP_DELAY_MS)
    if shiftAware
        ShiftHold_Pause()
    accepted := IH_WaitNext(mode, , LEADER_END_KEYS, IsObject(specials) && specials.Has(0x3A))
    SetTimer(help, 0)
    if shiftAware
        ShiftHold_Resume()
    if !accepted
        return
    endKey := forcedAsSpecial ? IH_EndKeyOf() : (IH_hook.EndReason = "EndKey" ? IH_hook.EndKey : "")
    if (endKey != "") {
        sc := GetKeySC(endKey)
        if (specials && specials.Has(sc))
            specials[sc]()
        else if LEADER_KEY_NAMES.Has(sc)
            ToolTip(LEADER_KEY_NAMES[sc] "検知")    ; 未割り当ての特殊キー（動作確認用）
    }
    else if keys.Has(IH_hook.Input) {
        action := keys[IH_hook.Input]
        if !(action is String)
            action()
        else if (action != "")
            SendInput(action)
    }
    IH_hook.Stop()
}

; 割り当て一覧をツールチップで表示する
Leader_ShowHelp(mode, funcName) {
    if IH_hook.InProgress
        ToolTip("⌨️ [" mode "] 次のキー待ち...（Esc / Caps：キャンセル）`n" Leader_HelpText(funcName))
}

; 割り当て表の関数（funcName）のソースを読み、割り当て済みの行から一覧の文字列を作る（行の読み取りは Lib\keymap_parse.ahk）
Leader_HelpText(funcName) {
    static cache := Map()
    if cache.Has(funcName)
        return cache[funcName]
    lines := "", specialLines := ""
    for row in KP_LeaderRows(FileRead(A_LineFile, "UTF-8"), funcName) {
        if (row.action = "" || row.action = '""')
            continue
        label := row.comment != "" ? row.comment
            : RegExReplace(RegExReplace(row.action, '^"\{(.)\}"$|^"(.*)"$', "$1$2"), "^\(\) => ")
        if row.special {
            sc := Integer(row.key)
            label := RegExReplace(label, "^[^：]+：")      ; コメント先頭の「Tab：」などを除く
            specialLines .= "`n" (LEADER_KEY_NAMES.Has(sc) ? LEADER_KEY_NAMES[sc] : row.key) "：" label
        }
        else
            lines .= "`n" StrUpper(row.key) "：" label
    }
    return cache[funcName] := LTrim(lines specialLines, "`n")
}

