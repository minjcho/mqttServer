#!/bin/bash

# 실시간 서버 모니터링 스크립트
# 스트레스 테스트 중 별도 터미널에서 실행

echo "==========================================="
echo "    📊 실시간 서버 모니터링"
echo "    Ctrl+C to exit"
echo "==========================================="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 모니터링 로그 파일
LOG_FILE="monitor-$(date +%Y%m%d-%H%M%S).log"

# 헤더 출력
printf "%-20s %-10s %-10s %-15s %-15s %-10s %-10s\n" \
    "Time" "CPU%" "Mem%" "Load(1m)" "Connections" "Docker" "Disk I/O"
printf "%-20s %-10s %-10s %-15s %-15s %-10s %-10s\n" \
    "----" "----" "----" "-------" "-----------" "------" "--------"

while true; do
    # 현재 시간
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    
    # CPU 사용률
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    
    # 메모리 사용률
    MEM_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100}')
    
    # Load Average (1분)
    LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    
    # 네트워크 연결 수
    CONNECTIONS=$(ss -s | grep "estab" | awk '{print $2}')
    
    # Docker 컨테이너 수
    DOCKER_COUNT=$(docker ps -q | wc -l)
    
    # Disk I/O (읽기/쓰기 합계 MB/s)
    DISK_IO=$(iostat -d 1 2 | tail -n 2 | head -n 1 | awk '{print $3+$4}' 2>/dev/null || echo "N/A")
    
    # 색상 코딩
    if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
        CPU_COLOR=$RED
    elif (( $(echo "$CPU_USAGE > 60" | bc -l) )); then
        CPU_COLOR=$YELLOW
    else
        CPU_COLOR=$GREEN
    fi
    
    if (( $(echo "$MEM_USAGE > 80" | bc -l) )); then
        MEM_COLOR=$RED
    elif (( $(echo "$MEM_USAGE > 60" | bc -l) )); then
        MEM_COLOR=$YELLOW
    else
        MEM_COLOR=$GREEN
    fi
    
    if (( $(echo "$LOAD_AVG > 8" | bc -l) )); then
        LOAD_COLOR=$RED
    elif (( $(echo "$LOAD_AVG > 4" | bc -l) )); then
        LOAD_COLOR=$YELLOW
    else
        LOAD_COLOR=$GREEN
    fi
    
    # 출력
    printf "%-20s ${CPU_COLOR}%-10.1f${NC} ${MEM_COLOR}%-10.1f${NC} ${LOAD_COLOR}%-15s${NC} %-15s %-10s %-10s\n" \
        "$TIMESTAMP" "$CPU_USAGE" "$MEM_USAGE" "$LOAD_AVG" "$CONNECTIONS" "$DOCKER_COUNT" "$DISK_IO"
    
    # 로그 파일에도 저장
    echo "$TIMESTAMP,$CPU_USAGE,$MEM_USAGE,$LOAD_AVG,$CONNECTIONS,$DOCKER_COUNT,$DISK_IO" >> $LOG_FILE
    
    # 위험 수준 경고
    if (( $(echo "$CPU_USAGE > 90" | bc -l) )); then
        echo -e "${RED}⚠️  경고: CPU 사용률 90% 초과!${NC}"
    fi
    
    if (( $(echo "$MEM_USAGE > 90" | bc -l) )); then
        echo -e "${RED}⚠️  경고: 메모리 사용률 90% 초과!${NC}"
    fi
    
    if (( $(echo "$LOAD_AVG > 10" | bc -l) )); then
        echo -e "${RED}⚠️  경고: 시스템 부하 매우 높음!${NC}"
    fi
    
    sleep 2
done