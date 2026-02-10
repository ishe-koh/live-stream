live-stream

Raspberry Pi 5 と Camera Module V3 を用いた
YouTube Live 向け常時配信システム。

rpicam-vid と ffmpeg をベースに、
systemd / cron / Slack 通知を組み合わせることで、

安定した常時ライブ配信

時間帯（日中・夜間・深夜）に応じたカメラ設定の自動切替

日の出・日の入り時刻を基準とした自動制御

プロファイル切替時の通知

プロセス異常時の自動再起動

を実現する。

特徴

Raspberry Pi 5 + Camera Module V3 に最適化

rpicam-vid | ffmpeg によるシンプルな映像パイプライン

設定ファイルによるプロファイル管理

systemd による常駐・自動復旧

cron による定期的な環境判定

Slack Webhook による状態通知

秘密情報を Git 管理対象から分離

ディレクトリ構成
/opt/live-stream/            # 実装本体（Git 管理対象）
├─ stream.sh                 # 配信処理本体
├─ run.sh                    # systemd 用ラッパ
├─ switch_profile.sh         # プロファイル切替
├─ weather_report.sh         # 日の出・日の入り判定
├─ profile.env               # 現在有効なプロファイル
├─ profiles/
│   ├─ day.conf
│   ├─ night.conf
│   └─ midnight.conf
├─ logs/
└─ bin/
    └─ notify_slack.sh

/etc/streamer/               # 秘密情報（Git 管理対象外）
├─ stream_key
├─ slack_webhook
└─ *.sample

設計方針
実装ディレクトリ /opt/live-stream

実行コード・設定ロジックを集約

GitHub で管理・共有可能

clone しても安全に動作する構成

秘密情報ディレクトリ /etc/streamer

YouTube ストリームキー

Slack Webhook URL

これらは Git 管理対象から完全に除外する。

理由：

誤 push 防止

権限管理の明確化

Linux の慣例（機密設定は /etc）

動作環境
ハードウェア

Raspberry Pi 5

Raspberry Pi Camera Module V3

OS

Raspberry Pi OS (Bookworm)

必要パッケージ
sudo apt update
sudo apt install -y \
  git curl jq ffmpeg cron

初期セットアップ
1. リポジトリ配置
cd /opt
git clone git@github.com:ishe-koh/live-stream.git
cd live-stream

2. 秘密情報の作成
sudo mkdir -p /etc/streamer
sudo chmod 755 /etc/streamer

YouTube ストリームキー
sudo nano /etc/streamer/stream_key
sudo chmod 600 /etc/streamer/stream_key

Slack Webhook
sudo nano /etc/streamer/slack_webhook
sudo chmod 600 /etc/streamer/slack_webhook

プロファイル設定
profiles/day.conf

昼間用。
自動制御を優先するため、最低限の指定のみとする。

WIDTH=2304
HEIGHT=1296
FPS=30

profiles/night.conf

夜間用。

WIDTH=2304
HEIGHT=1296
FPS=30

SHUTTER=20000
GAIN=1.5
AWB=tungsten
METERING=spot
DENOISE=off

profiles/midnight.conf

深夜用。

WIDTH=2304
HEIGHT=1296
FPS=30

SHUTTER=30000
GAIN=2.0
AWB=tungsten
METERING=spot
DENOISE=off

systemd サービス
登録
sudo cp systemd/live-stream.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable live-stream
sudo systemctl start live-stream

状態確認
journalctl -u live-stream -f

プロファイル切替
手動切替
sudo /opt/live-stream/switch_profile.sh day
sudo /opt/live-stream/switch_profile.sh night
sudo /opt/live-stream/switch_profile.sh midnight


切替時には Slack に通知が送信される。

自動切替（日の出・日の入り）

weather_report.sh は以下の基準で動作する。

日の出 35分前 から day

日の入り 35分後 から night

それ以外の時間帯は midnight / night

cron 登録例
*/1 * * * * /opt/live-stream/weather_report.sh >> /opt/live-stream/logs/weather_report.log 2>&1

実行フロー概要

systemd が run.sh を起動

stream.sh が現在の profile.env を読み込み

rpicam-vid + ffmpeg で配信開始

cron が定期的に weather_report.sh を実行

必要に応じて switch_profile.sh がプロファイル変更

Slack に通知

セキュリティ（権限・sudo）設計の明文化

ここまで来たら、もう立派な「再利用できる基盤」だと思っていい。
