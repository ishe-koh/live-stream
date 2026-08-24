# Raspberry Pi YouTube live stream

Raspberry Pi 5とCamera Module v3からYouTube Liveへ常時配信するシステムです。`rpicam-vid`、`ffmpeg`、systemdで配信を維持し、日の出・日の入りに応じて撮影プロファイルを切り替えます。

## 構成

```text
/opt/live-stream/
├── run.sh
├── stream.sh
├── switch_profile.sh
├── weather_report.sh
├── profile.env                  # 現在値。Git対象外
├── profiles/
│   ├── day.conf
│   ├── night.conf
│   ├── midnight.conf
│   └── profile_groups.conf
├── bin/
│   ├── notify_slack.sh
│   └── reset-youtube-stream.sh
├── systemd/                     # /etc/systemd/systemから参照する正本
│   ├── live-stream.service
│   ├── youtube-stream-reset.{service,timer}
│   ├── weather-report.{service,timer}
│   └── midnight-profile.{service,timer}
└── samples/etc/streamer/        # secretではない雛形のみ
```

実際のsecretはリポジトリ外に置きます。

```text
/etc/streamer/stream_key
/etc/streamer/slack_webhook
```

これらの内容をGit、ログ、issueへ追加しないでください。`.gitignore`はリポジトリ外のファイルを保護しないため、コミット前のsecret検査も必要です。

## 実行の流れ

`live-stream.service`は`streamer:dev`で`run.sh`を起動します。`run.sh`は`stream.sh`を実行し、`profile.env`で選択された設定と`/etc/streamer/stream_key`を読み込みます。プロセス終了時は5秒後に再起動し、異常ループを避けるため5分間に10回の起動制限を設けています。

```text
live-stream.service
  └─ run.sh
      └─ stream.sh
          ├─ rpicam-vid
          └─ ffmpeg → YouTube RTMP
```

現在のプロファイルは次の形式です。

```dotenv
PROFILE=day
```

手動切替は次のコマンドで行います。指定した設定の存在確認、`profile.env`のatomic更新、配信serviceのrestart、Slack通知を順に行います。

```bash
sudo /opt/live-stream/switch_profile.sh night manual
```

## 自動実行

自動処理はすべてsystemd timerで管理します。時刻はunit内で`Asia/Tokyo`を明示しています。

| timer | 時刻 | 処理 |
|---|---:|---|
| `weather-report.timer` | 毎時05分から10分間隔 | 日の出35分前から日の入り35分後をday、それ以外をnightとして必要時のみ切替 |
| `midnight-profile.timer` | 毎日22:00 | `midnight`へ切替 |
| `youtube-stream-reset.timer` | 毎日02:00 | 配信を完全停止し、15秒待ってから起動 |

weather判定を00分ではなく05分から実行することで、02:00の完全再起動と競合しないようにしています。さらに、完全再起動とプロファイル変更は同じ`flock`を取得して直列実行します。

## 初期セットアップ

必要なパッケージを導入します。

```bash
sudo apt update
sudo apt install -y rpicam-apps ffmpeg curl jq util-linux
```

secretを作成します。sampleをコピーした後、実値は実機上でのみ編集してください。

```bash
sudo install -d -o streamer -g dev -m 0750 /etc/streamer
sudo install -o streamer -g dev -m 0640 samples/etc/streamer/stream_key.sample /etc/streamer/stream_key
sudo install -o streamer -g dev -m 0640 samples/etc/streamer/slack_webhook.sample /etc/streamer/slack_webhook
```

リポジトリ内のunitを正本としてsymlinkし、有効化します。

```bash
for unit in /opt/live-stream/systemd/*; do
  sudo ln -sfn "$unit" "/etc/systemd/system/$(basename "$unit")"
done

sudo systemctl daemon-reload
sudo systemctl enable --now live-stream.service
sudo systemctl enable --now weather-report.timer
sudo systemctl enable --now midnight-profile.timer
sudo systemctl enable --now youtube-stream-reset.timer
```

旧cronから移行する場合、systemd timerが動作していることを確認してから、root crontabの以下2行を削除します。二重実行を避けるため、cronとtimerを併用しないでください。

```cron
*/10 * * * * /opt/live-stream/weather_report.sh >> /opt/live-stream/logs/weather_report.log 2>&1
0 22 * * * /opt/live-stream/switch_profile.sh midnight
```

## 確認と運用

```bash
systemctl status live-stream.service
systemctl list-timers --all
journalctl -u live-stream.service -f
journalctl -u weather-report.service --since today
journalctl -u youtube-stream-reset.service --since today
```

`ffmpeg`のプロセス引数や起動ログにはRTMP URLが表示される場合があります。stream keyを含む出力を共有しないでください。

banner合成にはGit対象外の`/opt/live-stream/media/banner/entas_banner_fixed.mp4`が必要です。実機交換時はこのファイルも安全な経路で移行してください。

unitを変更した場合は、配信を不用意に切断しないよう、まず検証してからreloadします。`daemon-reload`だけでは稼働中の`live-stream.service`は再起動されません。

```bash
systemd-analyze verify /opt/live-stream/systemd/*
sudo systemctl daemon-reload
```

## Git管理方針

管理対象:

- 配信・通知・プロファイル切替スクリプト
- 撮影プロファイル
- systemd service/timerの正本
- secretのsample
- README

管理対象外:

- `profile.env`
- `/etc/streamer`の実secret
- ログ、動画、画像、バックアップファイル

コミット前に少なくとも以下を確認します。

```bash
git status --short
git diff --check
git grep -nE 'hooks\.slack\.com|rtmp://[^ ]+/[^ ]+'
```
