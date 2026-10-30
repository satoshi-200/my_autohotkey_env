#Requires AutoHotkey v2.0
;==============================================================================
; leader_keys.ahk
; 起点キー（リーダーキー）を押して離したあと、次に押したキーで機能を分ける割り当て表
;   CapsLock          … Leader_Caps()
;   Space + F         … Leader_SpaceF()   （hold_keys.ahk の Space レイヤーから呼ぶ）
;   Space + A         … Leader_SpaceA()   （同上）
;   カタカナひらがな  … Leader_Kana()     （前面のアプリ専用の機能。次の 1 キーで選ぶ。Outlook：s メール選択、Office：e 図形編集、VS Code：f 折りたたみ、Obsidian：モードに入って Caps でリンク選択）
;   Caps → Caps       … VimiumC_ShowHints()（Vimium C 風ヒント。表示中に左 Shift で Caps → Caps → LShift = カーソル移動モード、Caps で Ctrl+クリック、変換で右クリック、Space で移動だけ、無変換でダブルクリック）
;   Caps → Space      … IME 半角英数、Caps → 無変換 … Shift 長押しモード、Caps → 変換 … 次の 1 文字を大文字に
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
#Include %A_LineFile%\..\..\Lib\last_input.ahk
#Include %A_LineFile%\..\..\Lib\window_switch.ahk
#Include %A_LineFile%\..\..\Lib\window_ops.ahk
#Include %A_LineFile%\..\..\Lib\multi_clipboard.ahk
#Include %A_LineFile%\..\..\Lib\mouse_cursor.ahk
#Include %A_LineFile%\..\..\Lib\mouse_grid.ahk
#Include %A_LineFile%\..\..\Lib\quick_menu.ahk
#Include %A_LineFile%\..\..\Lib\vimium_c_hints.ahk
#Include %A_LineFile%\..\..\Lib\shift_hold.ahk
#Include %A_LineFile%\..\..\Lib\outlook_mail.ahk
#Include %A_LineFile%\..\..\Lib\obsidian_mode.ahk

;------------------------------------------------------------------------------
; 起点キー（Space+F / Space+A は hold_keys.ahk から呼ぶ）
;------------------------------------------------------------------------------
#HotIf !IH_waiting
sc03A:: Leader_Caps()                               ; CapsLock
sc070:: Leader_Kana()                               ; カタカナひらがな（前面のアプリ専用の機能。Outlook：s、Office：e、VS Code：f、Obsidian：モード→Caps）
^+!F12:: Oneshot_CtrlChar()                         ; Ctrl + 文字キー（Ctrl+Shift+Alt+F12。Logi Options のボタンに割り当てる。Caps → l と同じ）
^+!F11:: QM_CaptureMenu_Show()                      ; 画面キャプチャメニュー（Ctrl+Shift+Alt+F11。Logi Options のボタンに割り当てる。Caps → t と同じ）
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
        "q",  "",
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
        "s",  "",
        "d",  TabPageSwitcher_Show,                 ; タブ・ページ切り替え
        "f",  Oneshot_FnOrCtrlNum,                  ; Fn キー（左手）/ Ctrl + 数字キー（右手）
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
        ",",  "",
        ".",  "",
        "/",  "")
    static specials := Map(
        0x39, Ime_AlnumCommit,                      ; Space：IME を半角英数に（未確定の文字は確定）
        0x3A, VimiumC_ShowHints,                    ; Caps：Vimium C 風ヒント（表示中に左 Shift でカーソル移動モード、Caps で右クリック）
        0x79, Text_CapitalizeNext,                  ; 変換：次の 1 文字を大文字に
        0x7B, ShiftHold_Start)                      ; 無変換：Shift 長押しモード
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
        "u",  QM_DateQuick_Show,                    ; 日付・時刻の一覧（ツールチップ。ファイル名の変更中にも使える）
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
        0x3A, Reload,                               ; Caps：スクリプトを再読み込み
        0x79, "")
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
        "u",  "{``}",
        "i",  "{^}",
        "o",  "{|}",
        "p",  "{\}",
        "@",  "",
        "[",  "",
        ; --- 中段 ---
        "a",  "{;}",
        "s",  "{l}",
        "d",  "{k}",
        "f",  "{j}",
        "g",  "{h}",
        "h",  "",
        "j",  "{#}",
        "k",  "{$}",
        "l",  "{%}",
        ";",  "{&}",
        ":",  "",
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
    static specials := Map(
        0x39, "",
        0x79, "")
    ShiftHold_Remember()
    Leader_Run("Space + A：左手で文字・記号", keys, specials, , true)
}

; カタカナひらがな：前面のアプリ専用の機能へ。アプリごとに次の 1 キーで選ぶ（表はアプリごとに別。Outlook・Office・VS Code）。Obsidian はモードに入ってから Caps
Leader_Kana() {
    if WinActive("ahk_exe OUTLOOK.EXE")
        Leader_KanaOutlook()
    else if IsObject(Office_HostOf(WinExist("A")))
        Leader_KanaOffice()
    else if WinActive("ahk_exe Code.exe")
        Leader_KanaVSCode()
    else if WinActive("ahk_exe Obsidian.exe")
        Obsidian_Mode()
    else
        UI_TipFlash("かな：このアプリ用の機能はありません")
}

Leader_KanaOutlook() {
    static keys := Leader_Keys(
        "s",  OutlookMail_SelectMode)               ; メール選択モード（Select）
    Leader_Run("かな：Outlook", keys)
}

Leader_KanaOffice() {
    static keys := Leader_Keys(
        "e",  Office_EditStart)                     ; 図形編集モード（Edit）
    Leader_Run("かな：Office", keys)
}

Leader_KanaVSCode() {
    static keys := Leader_Keys(
        "f",  QM_FoldMenu_Show)                     ; 折りたたみメニュー（Fold）
    Leader_Run("かな：VS Code", keys)
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
        act := (specials && specials.Has(sc)) ? specials[sc] : ""
        if !(act is String)
            act()
        else if (act != "") {                           ; 関数でなく文字列のときは、送るキー
            SendInput(act)
            LastInput_NoteSendInput(act)
        }
        else if LEADER_KEY_NAMES.Has(sc)
            UI_ToolTip(LEADER_KEY_NAMES[sc] "検知")    ; 未割り当ての特殊キー（動作確認用）
    }
    else if keys.Has(IH_hook.Input) {
        action := keys[IH_hook.Input]
        if !(action is String)
            action()
        else if (action != "") {
            SendInput(action)
            LastInput_NoteSendInput(action)             ; 送った文字を「直前の 1 文字」に覚える
        }
    }
    IH_hook.Stop()
}

; 割り当て一覧をツールチップで表示する
Leader_ShowHelp(mode, funcName) {
    if IH_hook.InProgress
        UI_ToolTip("⌨️ [" mode "] 次のキー待ち...（Esc / Caps：キャンセル）`n" Leader_HelpText(funcName))
}

; 割り当て表の関数（funcName）のソースを読み、割り当て済みの行から一覧の文字列を作る（行の読み取りは Lib\keymap_parse.ahk）
; キーボードの段（数字列・上段・中段・下段）ごとにまとめ、1 行に LEADER_HELP_PER_LINE 個ずつ、短くしたラベルで並べる
LEADER_HELP_PER_LINE := 3                 ; 割り当て一覧の 1 行に並べる個数
LEADER_HELP_LABEL_MAX := 13               ; 割り当て一覧のラベルの最大文字数（それより長いものは切る）

Leader_HelpText(funcName) {
    static cache := Map()
    static rowKeys := ["1234567890-^\", "qwertyuiop@[", "asdfghjkl;:]", "zxcvbnm,./"]
    if cache.Has(funcName)
        return cache[funcName]
    rows := [[], [], [], [], []], specialItems := []
    for row in KP_LeaderRows(FileRead(A_LineFile, "UTF-8"), funcName) {
        if (row.action = "" || row.action = '""')
            continue
        label := Km_Label(row.action, row.comment)         ; 割り当て一覧の画面（Lib\keymap_view.ahk）と同じ表記
        if row.special {
            sc := Integer(row.key)
            label := RegExReplace(label, "^[^：]+：")      ; コメント先頭の「Tab：」などを除く
            name := LEADER_KEY_NAMES.Has(sc) ? RegExReplace(LEADER_KEY_NAMES[sc], "キー$") : row.key
            specialItems.Push(name "：" Leader_ShortLabel(label))
            continue
        }
        at := 5
        for i, keys in rowKeys
            if InStr(keys, row.key) {
                at := i
                break
            }
        rows[at].Push(StrUpper(row.key) "：" Leader_ShortLabel(label))
    }
    rows.Push(specialItems)
    blocks := []
    for items in rows {
        text := ""
        for item in items
            text .= (A_Index = 1 ? "" : Mod(A_Index - 1, LEADER_HELP_PER_LINE) = 0 ? "`n" : "　") item
        if (text != "")
            blocks.Push(text)
    }
    out := ""
    for b in blocks
        out .= (A_Index = 1 ? "" : "`n`n") b
    return cache[funcName] := out
}

; 説明の最初の部分（括弧より前）を、最大 LEADER_HELP_LABEL_MAX 文字にする
Leader_ShortLabel(label) {
    s := Trim(RegExReplace(label, "[（(].*$"))
    if (s = "")
        s := label
    return StrLen(s) > LEADER_HELP_LABEL_MAX ? SubStr(s, 1, LEADER_HELP_LABEL_MAX) "…" : s
}

