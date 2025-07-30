#!/bin/bash
set -e

# 클러스터 포맷(최초 1회만)
if [ ! -f /tmp/kraft-combined-logs/meta.properties ]; then
  kafka-storage format -t $(kafka-storage random-uuid) -c /etc/kafka/kafka-server.properties
fi

exec kafka-server-start /etc/kafka/kafka-server.properties 