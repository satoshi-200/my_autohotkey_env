# 依頼メモ

今後やりたい改善・機能追加と、これまでの依頼の一覧。番号は付け直さない（欠番はそのまま）。
状態：着手中 / 済 / 保留。着手したら「着手中」、終わったら「済」にする。
方針は `principles.md`、未実装のアイデアは `ideas.md`。

**このファイルは短く保つ。** 検討メモ・確かめたこと・経緯は、終わった依頼ごとに `archive/backlog_history.md`（当時の全文。#番号で探す）へ移す。
ここには 1 行の要約だけ残す。現在の割り当て・仕様は、`keymap\` と、画面（クイックメニュー S → K）を見る（メモの内容は、その後の割り当て変更で古くなっていることがある）。

## 進行中・要望待ち

| # | 状態 | 内容 |
| :--- | :--- | :--- |
| 5 | 着手中 | PowerPoint / Office の詰め合わせ（`Lib/powerpoint_pack.ahk`、`Lib/office_common.ahk`）。土台はできた。要望を聞いて機能を足す。クイックメニューの O |

## 済（要約。詳細は `archive/backlog_history.md`）

| # | 内容 | 主な場所 |
| :--- | :--- | :--- |
| 1 | フォーカス中の部品をクリックで画面キャプチャ（のち、割り付けを外して archive へ） | `Lib/screen_capture.ahk` |
| 2 | Vimium C 風ヒントの暗転をなくす | `Lib/vimium_c_hints.ahk` |
| 3 | JIS 配列の図でキー割り当てを見える化 | `Lib/keymap_view.ahk` / `.html` |
| 4 | 日付入力（日付 → フォーマットの 2 段階） | `Lib/date_input.ahk` |
| 6 | Shift 長押しモード（Caps → Space。Enter は IME が半角英数なら、まずモードを抜けるだけ。上端の帯でモード中を表示） | `Lib/shift_hold.ahk` |
| 7 | リファクタリング（部品の分割、未使用コードの archive、名前の統一） | 全体 |
| 8 | カーソル移動モード（キーボード配置のグリッドジャンプ） | `Lib/mouse_grid.ahk` |
| 9 | Vimium C 風ヒントを、Space+A で左手だけで入力 | `Lib/vimium_c_hints.ahk` |
| 10 | InputHook モードの共通の骨組み | `Lib/key_mode.ahk` |
| 11 | モードの案内が押したい場所を隠さない（左下に短く） | `Lib/key_mode.ahk` |
| 12 | ウィンドウ・タブ・モニター切り替えの決定キーをそろえる（g / h / v / b / n / Enter） | `Lib/window_switch.ahk` |
| 13 | キー割り当て画面で設定値も編集 | `Lib/settings_view.ahk` |
| 14 | 図形編集モードを Office 共通に（Word・Excel でも） | `Lib/office_common.ahk` |
| 15 | 無変換 + かな：縦に並んだモニターへ | `Lib/mouse_cursor.ahk` |
| 16 | 変換・無変換・Space の短押し（IME 切り替え・空白。Shift+Space / Ctrl+Space も通す） | `keymap/hold_keys.ahk` 末尾 |
| 17 | 変換と無変換を両方押したままの 3 キー割り当て | `keymap/chord_keys.ahk` |
| 18 | Caps → 変換 / Space の入れ替え。短押し・3 キーを一覧に出す。特殊キーの割り当て解除の不具合を直す | `keymap/leader_keys.ahk`、`Lib/keymap_view.*` |
| 19 | 押す順番を区別する 3 キー（無変換 → 変換 は `chord_ordered_keys.ahk`）。割り当てのないキーは何も起きない | `Lib/chord.ahk` |
| 20 | Space + m / , / . / / にクリック類（Ctrl+クリック・ダブル・右・中） | `keymap/hold_keys.ahk` |

## 書き方
- 依頼が来たら、表に 1 行足して「着手中」にする。
- 終わったら「済」にして、詳細（検討・確かめたこと・注意）は `archive/backlog_history.md` の末尾に `### N. 題` として追記し、ここは要約 1 行にする。
- 実機で確かめることが残っているものは、`archive/backlog_history.md` の該当の節に書く。
