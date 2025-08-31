#!/bin/bash

LOGFILE="$HOME/Documents/Personal/mic/mumble-server.log"

# ログファイルがなければ終了
if [ ! -f "$LOGFILE" ]; then
  echo "ログファイルが見つかりません: $LOGFILE"
  exit 1
fi

# ログインを検知したら通知（例: echoで出力、または他のコマンドを実行）
tail -Fn0 "$LOGFILE" | \
while read line; do
  if echo "$line" | grep -q 'Authenticated'; then
    echo "ユーザーが接続しました: $line"
  fi
done
