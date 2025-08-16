#!/bin/bash

# 실시간 서버 모니터링 스크립트 (iostat 없이도 작동)
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
CYAN='\033[0;36m'
NC='\033[0m'

# 모니터링 로그 파일
LOG_FILE="monitor-$(date +%Y%m%d-%H%M%S).log"

# CSV 헤더
echo "Timestamp,CPU%,Mem%,MemUsed(MB),MemFree(MB),Load1m,Connections,Docker,DiskRead,DiskWrite" > $LOG_FILE

# 헤더 출력
printf "${CYAN}%-19s ${YELLOW}%-8s ${GREEN}%-8s ${BLUE}%-12s ${YELLOW}%-8s ${CYAN}%-10s ${NC}%-8s\n" \
    "Time" "CPU%" "Mem%" "Used/Free" "Load" "Conn" "Docker"
printf "%-19s %-8s %-8s %-12s %-8s %-10s %-8s\n" \
    "-------------------" "--------" "--------" "------------" "--------" "----------" "--------"

# 이전 디스크 I/O 값 저장
PREV_READ=0
PREV_WRITE=0
if [ -f /proc/diskstats ]; then
    PREV_READ=$(awk '/sda|xvda|nvme0n1/ {print $6}' /proc/diskstats | head -1)
    PREV_WRITE=$(awk '/sda|xvda|nvme0n1/ {print $10}' /proc/diskstats | head -1)
fi

while true; do
    # 현재 시간
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    
    # CPU 사용률 (더 정확한 계산)
    CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print $1}')
    if [ -z "$CPU_IDLE" ]; then
        # 다른 형식의 top 출력 처리
        CPU_IDLE=$(top -bn1 | grep "%Cpu" | awk '{print $8}' | cut -d'%' -f1)
    fi
    CPU_USAGE=$(echo "100 - $CPU_IDLE" | bc)
    
    # 메모리 정보 (MB 단위)
    MEM_TOTAL=$(free -m | grep Mem | awk '{print $2}')
    MEM_USED=$(free -m | grep Mem | awk '{print $3}')
    MEM_FREE=$(free -m | grep Mem | awk '{print $4}')
    MEM_AVAILABLE=$(free -m | grep Mem | awk '{print $7}')
    MEM_USAGE=$(echo "scale=1; $MEM_USED * 100 / $MEM_TOTAL" | bc)
    
    # Load Average (1분, 5분, 15분)
    LOAD_1M=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    LOAD_5M=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $2}' | sed 's/,//')
    LOAD_15M=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $3}' | sed 's/,//')
    
    # 네트워크 연결 수
    CONNECTIONS=$(ss -s | grep "estab" | awk '{print $2}')
    TOTAL_SOCKETS=$(ss -s | grep "Total:" | awk '{print $2}')
    
    # Docker 컨테이너 정보
    if command -v docker &> /dev/null; then
        DOCKER_COUNT=$(docker ps -q 2>/dev/null | wc -l)
        DOCKER_CPU=$(docker stats --no-stream --format "{{.CPUPerc}}" 2>/dev/null | sed 's/%//g' | awk '{sum+=$1} END {printf "%.1f", sum}')
    else
        DOCKER_COUNT="N/A"
        DOCKER_CPU="N/A"
    fi
    
    # 디스크 I/O (초당 읽기/쓰기 - /proc/diskstats 사용)
    DISK_READ=0
    DISK_WRITE=0
    if [ -f /proc/diskstats ]; then
        CURR_READ=$(awk '/sda|xvda|nvme0n1/ {print $6}' /proc/diskstats | head -1)
        CURR_WRITE=$(awk '/sda|xvda|nvme0n1/ {print $10}' /proc/diskstats | head -1)
        
        if [ ! -z "$CURR_READ" ] && [ ! -z "$PREV_READ" ]; then
            DISK_READ=$((CURR_READ - PREV_READ))
            DISK_WRITE=$((CURR_WRITE - PREV_WRITE))
        fi
        
        PREV_READ=$CURR_READ
        PREV_WRITE=$CURR_WRITE
    fi
    
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
    
    if (( $(echo "$LOAD_1M > 8" | bc -l) )); then
        LOAD_COLOR=$RED
    elif (( $(echo "$LOAD_1M > 4" | bc -l) )); then
        LOAD_COLOR=$YELLOW
    else
        LOAD_COLOR=$GREEN
    fi
    
    # 메모리 표시 형식
    MEM_DISPLAY="${MEM_USED}/${MEM_FREE}M"
    
    # 출력
    printf "%-19s ${CPU_COLOR}%-8.1f${NC} ${MEM_COLOR}%-8.1f${NC} ${MEM_COLOR}%-12s${NC} ${LOAD_COLOR}%-8s${NC} %-10s %-8s\n" \
        "$TIMESTAMP" "$CPU_USAGE" "$MEM_USAGE" "$MEM_DISPLAY" "$LOAD_1M" "$CONNECTIONS" "$DOCKER_COUNT"
    
    # CSV 로그 파일에 저장
    echo "$TIMESTAMP,$CPU_USAGE,$MEM_USAGE,$MEM_USED,$MEM_FREE,$LOAD_1M,$CONNECTIONS,$DOCKER_COUNT,$DISK_READ,$DISK_WRITE" >> $LOG_FILE
    
    # 위험 수준 경고
    if (( $(echo "$CPU_USAGE > 90" | bc -l) )); then
        echo -e "${RED}⚠️  경고: CPU 사용률 ${CPU_USAGE}% - 매우 높음!${NC}"
    fi
    
    if (( $(echo "$MEM_USAGE > 90" | bc -l) )); then
        echo -e "${RED}⚠️  경고: 메모리 사용률 ${MEM_USAGE}% - 매우 높음!${NC}"
        echo -e "    사용: ${MEM_USED}MB / 전체: ${MEM_TOTAL}MB"
    fi
    
    if (( $(echo "$LOAD_1M > 10" | bc -l) )); then
        echo -e "${RED}⚠️  경고: 시스템 부하 매우 높음! (Load: $LOAD_1M)${NC}"
    fi
    
    # 연결 수가 많을 때 경고
    if [ $CONNECTIONS -gt 5000 ]; then
        echo -e "${YELLOW}📊 높은 연결 수: $CONNECTIONS (Total sockets: $TOTAL_SOCKETS)${NC}"
    fi
    
    sleep 2
done