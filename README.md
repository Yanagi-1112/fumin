# Fumin 🌙→🟠

**不眠 — 眠らないMac。**

メニューバーに常駐し、**クリックひとつで「フタを閉じてもスリープしないモード」⇄「通常モード」**を切り替える小さなMacアプリ。
Claude Code / Codex などの長時間ジョブを、MacBookを閉じたまま走らせたいとき用。

## アイコンの意味
- 🌙 `moon.zzz`（通常色）= **通常モード**（フタを閉じると普通にスリープ）
- 🟠 オレンジのカップ = **スリープ無効モード ON**（フタを閉じても起き続ける）

## 操作
- **左クリック** … モードをトグル
- **右クリック**（または Control+クリック）… メニュー
  - **画面をすぐ消す** … 画面出力だけオフにする（本体は動き続ける）
  - **フタを閉じたら画面も消す（ON中のみ）** … クラムシェルで外部モニタも自動で暗くする
  - 自動起動の切替 / 終了

## 仕組み
- ON: `sudo -n pmset -a disablesleep 1`（フタ閉じスリープを無効化）＋ `caffeinate -imsu`（アイドルスリープ抑止）
- OFF / 終了 / 起動時: 必ず `pmset -a disablesleep 0` に戻す → 「永久にスリープできない」事故を防ぐ三重の安全装置
- 画面消し: `pmset displaysleepnow`（root不要）。フタの開閉は `IOPMrootDomain` の `AppleClamshellState` で検出。キーボード・マウスに触れると画面は復帰する

## セットアップ（初回1回だけ）
アプリがスリープ設定を変更できるよう、`pmset` だけをパスワード無しで許可する1行を入れる。
ターミナルで実行（Macのログインパスワードを聞かれます）:

```sh
echo "$(whoami) ALL=(root) NOPASSWD: /usr/bin/pmset" | sudo tee /etc/sudoers.d/fumin >/dev/null && sudo chmod 440 /etc/sudoers.d/fumin
```

> アプリを初めてクリックしたとき、この設定が無ければ「コマンドをコピー」ボタン付きの案内が出ます。

## ビルド / 再ビルド
```sh
./build.sh          # ~/Applications/Fumin.app を生成
open ~/Applications/Fumin.app
```

## 自動起動
右クリックメニュー →「ログイン時に自動起動」にチェック。

## 困ったときの魔法の呪文
何かおかしいと感じたら、ターミナルでこれを実行すれば即・通常状態に戻る:
```sh
sudo pmset -a disablesleep 0
```

## アンインストール
```sh
osascript -e 'quit app "Fumin"' 2>/dev/null
rm -rf ~/Applications/Fumin.app
sudo rm -f /etc/sudoers.d/fumin
```

## 使うときの注意（物理）
- 🔌 フタ閉じ＋長時間は **必ずACに接続**
- 🔥 **カバン・引き出し・布団の上は厳禁**。硬く風通しのよい台かスタンドで（放熱のため）

## 動作環境
- macOS 13 (Ventura) 以降 / Xcode Command Line Tools（ビルドに `swiftc` を使用）

## ライセンス
[MIT](LICENSE)
