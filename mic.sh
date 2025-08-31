#!/bin/bash
# スマホや他PCのMumbleマイク音声をPipeWire環境で仮想マイクとして利用する自動スクリプト

set -euo pipefail

# ログファイル
LOGFILE="$HOME/Repos/mic/mumble-server.log"

# 仮想sink/mic名
SINK_NAME="Loopback_of_Mumble"
VIRTUAL_SOURCE_NAME="VirtualMic"

# Mumbleクライアント名
MUMBLE_APP_NAME="Mumble"

# サーバー情報
MUMBLE_USER="ergodic"
MUMBLE_MIC_USER="eric"
MUMBLE_SERVER="shyly.localhost"

# 仮想sinkが存在するか確認
check_sink_exists() {
  pactl list short sinks | grep -q "$SINK_NAME"
}

# 仮想sinkのモジュールIDを取得
get_sink_module_id() {
    pactl list short modules | grep "sink_name=$SINK_NAME" | awk '{print $1}'
}

# 仮想sink作成
create_sink() {
  if check_sink_exists; then
    echo "仮想sink $SINK_NAME は既に存在します。"
  else
    echo "仮想sink $SINK_NAME を作成します..."
    pactl load-module module-null-sink sink_name=$SINK_NAME sink_properties=device.description=$SINK_NAME
    sleep 2
  fi
}

# Mumbleクライアントのsink-input番号取得
get_mumble_sink_input_id() {
  pactl list short sink-inputs | grep "$MUMBLE_APP_NAME" | awk '{print $1}'
}

# Mumbleクライアントのsink-inputを仮想sinkに移動
move_mumble_to_sink() {
  local retries=0
  local max_retries=30
  while [ $retries -lt $max_retries ]; do
    MUMBLE_ID=$(get_mumble_sink_input_id)
    if [ -n "$MUMBLE_ID" ]; then
      echo "Mumbleのsink-input $MUMBLE_ID を $SINK_NAME へ移動します..."
      pactl move-sink-input "$MUMBLE_ID" "$SINK_NAME"
      return 0
    fi
    sleep 1
    retries=$((retries+1))
  done
  echo "Mumbleクライアントのsink-inputが見つかりません。"
  return 1
}

# 仮想マイク(source)が存在するか確認
check_virtual_source_exists() {
  pactl list short sources | grep -q "$VIRTUAL_SOURCE_NAME"
}

# 仮想マイク(source)のモジュールIDを取得
get_virtual_source_module_id() {
  pactl list short modules | grep "source_name=$VIRTUAL_SOURCE_NAME" | awk '{print $1}'
}

# 仮想マイク(source)作成
create_virtual_source() {
  if check_virtual_source_exists; then
    echo "仮想マイク $VIRTUAL_SOURCE_NAME は既に存在します。"
  else
    echo "仮想マイク $VIRTUAL_SOURCE_NAME を作成します..."
    pactl load-module module-virtual-source source_name=$VIRTUAL_SOURCE_NAME master=${SINK_NAME}.monitor
    sleep 2
  fi
}

# 仮想マイク(source)削除
remove_virtual_source() {
  local module_id
  module_id=$(get_virtual_source_module_id || true)
  if [ -n "${module_id:-}" ]; then
    echo "仮想マイク $VIRTUAL_SOURCE_NAME (module-id=$module_id) を削除します..."
    pactl unload-module "$module_id"
  else
    echo "仮想マイク $VIRTUAL_SOURCE_NAME のモジュールIDが見つかりません。"
  fi
}
# mumble-serverを起動
set_server() {
  echo "サーバーを起動..."
  mumble-server -ini "$HOME/.config/mumble-server/mumble-server.ini" > "$LOGFILE" 2>&1 &
  # サーバー起動待ち
  sleep 1
}

# mumbleクライアント接続
connect() {
  echo "サーバーに接続..."
  mumble -m "mumble://${MUMBLE_USER}@${MUMBLE_SERVER}" > /dev/null 2>&1 &
  # クライアント起動待ち
  sleep 1
}

# ログインを検知したら通知しsink移動
check_connect() {
  echo "ユーザー接続待機中..."
  tail -Fn0 "$LOGFILE" | \
  while read -r line; do
    if echo "$line" | grep -q "$MUMBLE_MIC_USER"; then
      echo "ユーザーが接続しました: $line"
      connect
      move_mumble_to_sink
      break
    fi
  done
}

# 仮想sink削除
remove_sink() {
  local module_id
  module_id=$(get_sink_module_id || true)
  if [ -n "${module_id:-}" ]; then
    echo "仮想sink $SINK_NAME (module-id=$module_id) を削除します..."
    pactl unload-module "$module_id"
  else
    echo "仮想sink $SINK_NAME のモジュールIDが見つかりません。"
  fi
}

# 終了処理
end() {
  echo "プログラムを終了中..."
  pkill -f "mumble|mumble-server"
  remove_virtual_source
  remove_sink
  exit 0
}

# メイン処理
main() {
  trap end SIGINT
  create_sink
  create_virtual_source
  set_server
  check_connect
}

main
