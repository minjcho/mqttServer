#!/bin/bash

# EC2 서버 성능 분석 스크립트
# SSH로 EC2에서 실행하거나, EC2 인스턴스에서 직접 실행

echo "==========================================="
echo "    EC2 서버 성능 분석 리포트"
echo "    Date: $(date)"
echo "==========================================="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 결과 저장 디렉토리
RESULT_DIR="ec2-performance-$(date +%Y%m%d-%H%M%S)"
mkdir -p $RESULT_DIR

# 1. EC2 인스턴스 정보
echo -e "${BLUE}1. EC2 인스턴스 정보${NC}"
echo "-------------------------------------------"

# 인스턴스 메타데이터 가져오기
if curl -s http://169.254.169.254/latest/meta-data/ &>/dev/null; then
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)
    REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
    
    echo "Instance ID: $INSTANCE_ID"
    echo "Instance Type: $INSTANCE_TYPE"
    echo "Region: $REGION"
else
    echo "EC2 메타데이터를 가져올 수 없습니다. (로컬 환경일 수 있음)"
fi
echo ""

# 2. 시스템 리소스 정보
echo -e "${BLUE}2. 시스템 리소스 정보${NC}"
echo "-------------------------------------------"

# CPU 정보
echo -e "${YELLOW}CPU 정보:${NC}"
lscpu | grep -E "Architecture|CPU\(s\)|Model name|CPU MHz|Thread|Core|Socket" | tee $RESULT_DIR/cpu-info.txt
echo ""

# 메모리 정보
echo -e "${YELLOW}메모리 정보:${NC}"
free -h | tee $RESULT_DIR/memory-info.txt
echo ""

# 디스크 정보
echo -e "${YELLOW}디스크 정보:${NC}"
df -h | tee $RESULT_DIR/disk-info.txt
echo ""

# 3. 현재 리소스 사용률
echo -e "${BLUE}3. 현재 리소스 사용률${NC}"
echo "-------------------------------------------"

# CPU 사용률
echo -e "${YELLOW}CPU 사용률:${NC}"
top -bn1 | head -5 | tee $RESULT_DIR/cpu-usage.txt
echo ""

# 메모리 사용률
echo -e "${YELLOW}메모리 사용률:${NC}"
ps aux --sort=-%mem | head -10 | tee $RESULT_DIR/memory-usage.txt
echo ""

# 네트워크 연결 상태
echo -e "${YELLOW}네트워크 연결 상태:${NC}"
ss -tuln | grep LISTEN | tee $RESULT_DIR/network-ports.txt
echo ""

# 4. Docker 컨테이너 상태
echo -e "${BLUE}4. Docker 컨테이너 리소스 사용량${NC}"
echo "-------------------------------------------"

if command -v docker &> /dev/null; then
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}" | tee $RESULT_DIR/docker-stats.txt
else
    echo "Docker가 설치되어 있지 않습니다."
fi
echo ""

# 5. 서비스별 포트 확인
echo -e "${BLUE}5. 실행 중인 서비스 포트${NC}"
echo "-------------------------------------------"

declare -A services
services["MQTT Broker"]=3123
services["WebSocket Server"]=8081
services["QR Login API"]=8090
services["Redis (MQTT)"]=6379
services["Redis (QR)"]=6378
services["PostgreSQL"]=5433
services["Kafka"]=9092
services["Nginx"]=443

for service in "${!services[@]}"; do
    port=${services[$service]}
    if ss -tuln | grep -q ":$port "; then
        echo -e "${GREEN}✓${NC} $service (Port $port): Running"
    else
        echo -e "${RED}✗${NC} $service (Port $port): Not Running"
    fi
done
echo ""

# 6. 네트워크 대역폭 테스트
echo -e "${BLUE}6. 네트워크 성능${NC}"
echo "-------------------------------------------"

# 네트워크 인터페이스 정보
echo -e "${YELLOW}네트워크 인터페이스:${NC}"
ip -s link | grep -A 5 "^[0-9]" | tee $RESULT_DIR/network-interfaces.txt
echo ""

# 7. 시스템 한계값
echo -e "${BLUE}7. 시스템 한계값 설정${NC}"
echo "-------------------------------------------"

echo "파일 디스크립터 한계:"
ulimit -n
echo ""

echo "프로세스 한계:"
ulimit -u
echo ""

echo "TCP 설정:"
sysctl net.core.somaxconn 2>/dev/null || echo "net.core.somaxconn: N/A"
sysctl net.ipv4.tcp_max_syn_backlog 2>/dev/null || echo "net.ipv4.tcp_max_syn_backlog: N/A"
sysctl net.core.netdev_max_backlog 2>/dev/null || echo "net.core.netdev_max_backlog: N/A"
echo ""

# 8. 최근 시스템 부하
echo -e "${BLUE}8. 시스템 부하 이력${NC}"
echo "-------------------------------------------"

echo "최근 1분, 5분, 15분 평균 부하:"
uptime
echo ""

echo "최근 CPU 사용 이력:"
sar -u 1 5 2>/dev/null || echo "sar 명령이 설치되어 있지 않습니다. (apt install sysstat)"
echo ""

# 9. 로그 분석
echo -e "${BLUE}9. 에러 로그 확인${NC}"
echo "-------------------------------------------"

echo "최근 시스템 에러 (최근 20줄):"
journalctl -p err -n 20 --no-pager 2>/dev/null || dmesg | grep -i error | tail -20
echo ""

# 10. 성능 권장사항
echo -e "${BLUE}10. 성능 최적화 권장사항${NC}"
echo "-------------------------------------------"

# 메모리 사용률 체크
MEM_USAGE=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
if [ $MEM_USAGE -gt 80 ]; then
    echo -e "${RED}⚠${NC} 메모리 사용률이 ${MEM_USAGE}%로 높습니다. 인스턴스 업그레이드를 고려하세요."
else
    echo -e "${GREEN}✓${NC} 메모리 사용률: ${MEM_USAGE}%"
fi

# CPU 사용률 체크
CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | cut -d'%' -f1)
if (( $(echo "$CPU_IDLE < 20" | bc -l) )); then
    echo -e "${RED}⚠${NC} CPU 여유율이 낮습니다. 인스턴스 업그레이드를 고려하세요."
else
    echo -e "${GREEN}✓${NC} CPU 여유율: ${CPU_IDLE}%"
fi

# 디스크 사용률 체크
DISK_USAGE=$(df -h / | awk 'NR==2 {print int($5)}')
if [ $DISK_USAGE -gt 80 ]; then
    echo -e "${RED}⚠${NC} 디스크 사용률이 ${DISK_USAGE}%로 높습니다. 정리가 필요합니다."
else
    echo -e "${GREEN}✓${NC} 디스크 사용률: ${DISK_USAGE}%"
fi
echo ""

echo "==========================================="
echo "분석 완료! 결과가 $RESULT_DIR 디렉토리에 저장되었습니다."
echo "==========================================="