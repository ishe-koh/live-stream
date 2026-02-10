# live-stream

Raspberry Pi 5 と Camera Module v3 を用いて、YouTube Live へ常時配信を行うための配信基盤です。  
rpicam-vid と ffmpeg を組み合わせ、systemd による常駐実行と、日の出・日の入りに応じた撮影プロファイルの自動切替を行います。

---

## 目次

- [概要](#概要)
- [特徴](#特徴)
- [構成要件](#構成要件)
- [ディレクトリ構成](#ディレクトリ構成)
- [セットアップ](#セットアップ)
- [プロファイル設定](#プロファイル設定)
- [systemd サービス](#systemd-サービス)
- [プロファイルの切替](#プロファイルの切替)
- [自動切替（weather_report）](#自動切替weather_report)
- [Slack 通知](#slack-通知)
- [Git 管理方針](#git-管理方針)

---

## 概要

本リポジトリは、Raspberry Pi を用いた **365日稼働の定点ライブ配信** を目的としています。  
配信停止時の復旧や、昼夜による撮影条件の変化を前提に設計されています。

---

## 特徴

- rpicam-vid + ffmpeg による軽量な配信パイプライン
- systemd による自動再起動・常駐実行
- 撮影条件を切り替える「プロファイル」機構
- 日の出・日の入りを基準にした自動プロファイル切替
- Slack Webhook による通知

---

## 構成要件

### ハードウェア

- Raspberry Pi 5
- Raspberry Pi Camera Module v3
- 安定したネットワーク接続

### ソフトウェア

- Raspberry Pi OS（Bookworm 推奨）
- rpicam-apps
- ffmpeg
- curl
- jq
- systemd
- cron

---

## ディレクトリ構成

```text
/opt/live-stream/
├── run.sh                     # systemd から起動されるエントリポイント
├── stream.sh                  # 配信本体
├── profile.env                # 現在有効なプロファイル名
├── profiles/
│   ├── day.conf
│   ├── night.conf
│   └── midnight.conf
├── bin/
│   ├── switch_profile.sh      # プロファイル切替スクリプト
│   ├── weather_report.sh      # 日の出・日の入り判定
│   └── notify_slack.sh        # Slack 通知
└── logs/
    └── weather_report.log
```

```text

/etc/streamer/
├── stream_key                 # YouTube ストリームキー（実体）
├── slack_webhook              # Slack Webhook URL（実体）
└── samples/
    ├── stream_key.sample
    └── slack_webhook.sample
```

## セットアップ
1. 必要パッケージのインストール
```text
bash

sudo apt update
sudo apt install -y rpicam-apps ffmpeg curl jq
```

2. ユーザー・権限設計
実行ユーザー：streamer

開発・保守用ユーザー：ishii

共通グループ：dev

```text

bash

sudo groupadd dev
sudo useradd -m -G dev streamer
sudo usermod -aG dev ishii
```


3. ディレクトリ配置
```text
bash
sudo mkdir -p /opt/live-stream
sudo chown -R streamer:dev /opt/live-stream
sudo chmod -R 775 /opt/live-stream
```

## プロファイル設定
プロファイルとは
撮影条件をまとめた設定ファイルです。
profile.env に記載された名前のプロファイルが読み込まれます。

```text
env
PROFILE=day
```
プロファイル例
```text
day.conf

WIDTH=2304
HEIGHT=1296
FPS=30

SHUTTER=
GAIN=
AWB=
METERING=
DENOISE=
```

```text
night.conf

WIDTH=2304
HEIGHT=1296
FPS=30

SHUTTER=20000
GAIN=1.5
AWB=tungsten
METERING=spot
DENOISE=off
```

未指定の項目は rpicam-vid の自動制御に委ねられます。

## systemd サービス
サービス定義
```text
ini
[Unit]
Description=YouTube Live Camera Stream
After=network.target

[Service]
User=streamer
WorkingDirectory=/opt/live-stream
ExecStart=/opt/live-stream/run.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

## 有効化
```text
bash

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable live-stream.service
sudo systemctl start live-stream.service
```

## プロファイルの切替
手動切替
```text
bash
/opt/live-stream/bin/switch_profile.sh night
```

profile.env を更新

live-stream.service を再起動

## Slack 通知

## 自動切替（weather_report）
動作概要
Sunrise Sunset API から日の出・日の入りを取得

日の出 35分前 → day 系プロファイル

日の入り 35分後 → night 系プロファイル

現在のプロファイルグループと比較し、必要な場合のみ切替

cron 登録例

```text
cron
*/10 * * * * /opt/live-stream/bin/weather_report.sh >> /opt/live-stream/logs/weather_report.log 2>&1
```
Slack 通知
Webhook 設定
```text
bash
sudo mkdir -p /etc/streamer
sudo cp slack_webhook.sample /etc/streamer/slack_webhook
sudo chmod 600 /etc/streamer/slack_webhook
sudo chown streamer:streamer /etc/streamer/slack_webhook
```

## Git 管理方針
/opt/live-stream は Git 管理対象

/etc/streamer の 実体ファイルは管理しない

.sample のみをリポジトリに含める

```text
/etc/streamer/stream_key
/etc/streamer/slack_webhook
```
これらは .gitignore 対象です。

補足
本構成は以下を前提に設計されています。

配信は途切れても自動復帰する

明示的な「停止」より「再起動」を優先

設定はコードではなくプロファイルで切り替える
