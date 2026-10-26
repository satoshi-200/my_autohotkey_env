# My AutoHotkey Environment (Main Script)

## 概要 / Description
私のメインPCで使用している AutoHotkey v2 用のメインスクリプトです。
ホームポジションから手を動かさずに、あらゆる操作（マウス操作、記号入力、ウィンドウ管理、日付入力など）を完結させることを目的としています。

## 動作環境 / Environment
- Windows
- AutoHotkey v2.0 以上
- 日本語 JIS 配列キーボード

## 使い方 / Usage
1. `main.ahk` を実行する（ほかのファイルは `main.ahk` から読み込まれる）。
2. 割り当てや設定を変えたら **Insert** キーで再読み込みする。
3. いまの割り当ては、クイックメニューの **S → K**（Caps → j → s → k）で、JIS 配列の図の上に見られる。キーをクリックすると、その行を書き換えて保存することもできる。

## キー対応表 / Key Reference
スクリプト内では、特殊キーを次のコードで書いています。

| コード | キー |
| :--- | :--- |
| `vk1C` | 変換 |
| `vk1D` | 無変換 |
| `vk20` | Space |
| `sc03A` | CapsLock |
| `sc070` | カタカナひらがな |
| `sc00F` | Tab |
| `sc029` | 半角/全角 |

ほかのキーコード（テンキーなど）は `Lib/config.ahk` の早見表を参照。

## レイヤー構成 / Layers
キー割り当ては `keymap/` の 4 つのファイルにある。**具体的な割り当ては、ここには書かない**（変えるたびに古くなるため）。画面（S → K）か、各ファイルの行末コメントを見る。

| 種類 | ファイル | 内容 |
| :--- | :--- | :--- |
| 押しながら使う | `keymap/hold_keys.ahk` | 変換 / 無変換 / Space を押したまま別のキー。変換：記号・テンキー・編集。無変換：マウス・スクロール・モニター間の移動・アプリ切り替え・矢印・記号。Space：カーソル移動・Enter・タブ・クリック類。末尾に、3 つの親指キーの**短押し**（変換：IME ひらがな、無変換：IME 半角英数、Space：空白） |
| 3 キー | `keymap/chord_keys.ahk`、`keymap/chord_ordered_keys.ahk` | 変換と無変換を両方押したままさらに別のキー。押す順番を区別する（変換 → 無変換 / 無変換 → 変換）。書いていないキーは何も起きない |
| 入力待ち | `keymap/leader_keys.ahk` | Caps、Space+F、Space+A を押して離してから、次のキー。Caps はメニューやモードの入口、Space+F は大きなカーソル移動・日付、Space+A は右手側の文字を左手で入力 |

主な機能の使い方（入力待ち、アプリ切り替え、Vimium C 風ヒント、カーソル移動モード、Shift 長押しモード、クイックメニューなど）は `docs/features.md`。

## ドキュメント / Docs
| ファイル | 内容 |
| :--- | :--- |
| `docs/features.md` | 機能・モードの使い方 |
| `docs/principles.md` | 機能を足す・キーを割り当てるときの判断の基準（地価、モードの決まり） |
| `docs/development.md` | 改修の約束事、ファイル構成、検証のやり方、AutoHotkey の落とし穴 |
| `docs/backlog.md` | 依頼の一覧（短い要約）。詳細は `docs/archive/backlog_history.md` |
| `docs/ideas.md` | 未実装のアイデア。実装した機能の設計の経緯は `docs/archive/ideas_history.md` |
