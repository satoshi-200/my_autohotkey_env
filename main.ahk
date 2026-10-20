; ==============================================================================
; 【AutoHotkey v2 メインスクリプト（入口）】
;   このファイルを実行する。部品とキー割り当ての読み込み、全体に関わる操作だけを置く。
;
; ●ファイル構成
;   ・keymap\hold_keys.ahk   : 押しながら使うレイヤー（変換 / 無変換 / Space ＋ 何か）
;   ・keymap\leader_keys.ahk : 押して離してから次のキー（Caps / Space+F / Space+A → 何か）
;   ・Lib\                   : 各機能の部品
;
; ●キー対応表 (JIS キーボード)
;   ・vk1C : [変換] キー
;   ・vk1D : [無変換] キー
;   ・vk20 : [Space] キー
;   ・sc03A: [CapsLock] キー
;   ・sc070: [カタカナひらがな] キー
;   ・sc00F: [Tab] キー
;   ・sc029: [半角/全角] キー
;
; ●メンテナンス
;   ・Insert キーでスクリプトを再読み込みする。
; ==============================================================================

; ------------------------------------------------------------------------------
; 部品の読み込み（上から順に初期化される。各部品も使う部品を自分で読み込むが、一覧としてここにも書く）
; ------------------------------------------------------------------------------
; 土台
#Include Lib\config.ahk
#Include Lib\IME.ahk
#Include Lib\keymap_parse.ahk
#Include Lib\key_wait.ahk
#Include Lib\ui_common.ahk
; 文字入力
#Include Lib\text_input.ahk
#Include Lib\text_ops.ahk
#Include Lib\oneshot_modifiers.ahk
#Include Lib\shift_hold.ahk
#Include Lib\date_input.ahk
; マウス・ウィンドウ
#Include Lib\mouse_cursor.ahk
#Include Lib\mouse_grid.ahk
#Include Lib\window_ops.ahk
#Include Lib\window_switch.ahk
#Include Lib\screen_saver.ahk
#Include Lib\vimium_c_hints.ahk
; メニューと、メニューから呼ぶ機能
#Include Lib\multi_clipboard.ahk
#Include Lib\screen_capture.ahk
#Include Lib\powerpoint_pack.ahk
#Include Lib\keymap_view.ahk
#Include Lib\quick_menu.ahk

; ------------------------------------------------------------------------------
; キーの割り当て
; ------------------------------------------------------------------------------
#Include keymap\hold_keys.ahk
#Include keymap\leader_keys.ahk

; ------------------------------------------------------------------------------
; 全体の操作
; ------------------------------------------------------------------------------
#HotIf !IH_waiting
Insert:: Reload                         ; スクリプトの再読み込み
#HotIf
