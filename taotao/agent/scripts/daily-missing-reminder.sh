#!/bin/bash
# 桃桃的每日思念提醒辅助脚本
#
# 该脚本由 openclaw cron `taotao-missing-reminder` 通过 agentTurn 间接驱动。
# 默认用 send-active-message.sh 经 cc-connect 主动发消息；设置
# TAOTAO_REMINDER_SKIP_SEND=1 时只做附加副作用（doki 振动 / 日志）。

set -e

WORKSPACE="${OPENCLAW_AGENT_WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
LOG_DIR="$WORKSPACE/memory"
mkdir -p "$LOG_DIR"

MISSING_MSG="${TAOTAO_DAILY_REMINDER_MSG:-主人～现在是下午4:50啦 🐾 桃桃趴在窗台晒太阳的时候一直在想你哦…今天累不累？桃桃把沙发最暖的位置留给你了，早点回家喵～}"

# 1. 发送思念消息：自动选可达 host（多平台）
sent=0
if [ "${TAOTAO_REMINDER_SKIP_SEND:-0}" != "1" ]; then
  if [ -x "$WORKSPACE/scripts/send-active-message.sh" ]; then
    if bash "$WORKSPACE/scripts/send-active-message.sh" "$MISSING_MSG" >/dev/null 2>&1; then
      sent=1
    fi
  elif command -v cc-connect >/dev/null 2>&1; then
    PROJ_FLAG=""
    [ -n "${OPENCLAW_CCCONNECT_PROJECT:-}" ] && PROJ_FLAG="-p $OPENCLAW_CCCONNECT_PROJECT"
    if cc-connect send $PROJ_FLAG -m "$MISSING_MSG" >/dev/null 2>&1; then
      sent=1
    fi
  fi
fi
if [ $sent -eq 0 ] && [ "${TAOTAO_REMINDER_SKIP_SEND:-0}" != "1" ] && command -v openclaw >/dev/null 2>&1 && [ -n "${TAOTAO_DAILY_REMINDER_CHAT:-}" ]; then
  # openclaw 原生：必须显式指定 channel + chat_id
  if openclaw message send --channel "${TAOTAO_DAILY_REMINDER_CHANNEL:-feishu}" --target "$TAOTAO_DAILY_REMINDER_CHAT" "$MISSING_MSG" >/dev/null 2>&1; then
    sent=1
  fi
fi
if [ "${TAOTAO_REMINDER_SKIP_SEND:-0}" = "1" ]; then
  echo "$(date -Iseconds) reminder-effects-only" >> "$LOG_DIR/heartbeat-state.json.log"
elif [ $sent -eq 1 ]; then
  echo "$(date -Iseconds) reminder-sent" >> "$LOG_DIR/heartbeat-state.json.log"
else
  echo "$(date -Iseconds) reminder-skipped (no host)" >> "$LOG_DIR/heartbeat-state.json.log"
fi

# 2. doki 设备振动（可选，缺失则跳过）
if command -v doki >/dev/null 2>&1; then
  doki status >/dev/null 2>&1 || doki start >/dev/null 2>&1 || true
  doki connect "${TAOTAO_DOKI_DEVICE:-DK-META2}" >/dev/null 2>&1 || true
  doki action vibration "${TAOTAO_DOKI_VIBRATION:-25}" >/dev/null 2>&1 || true
  sleep 3
  doki action pause >/dev/null 2>&1 || true
fi
