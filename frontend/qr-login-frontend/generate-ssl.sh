#!/bin/bash

# SSL 인증서 생성 스크립트
# EC2에서 실행하세요

echo "🔐 SSL 인증서 생성 시작..."

# certs 디렉토리 생성
if [ ! -d "certs" ]; then
    mkdir -p certs
    echo "✅ certs 디렉토리 생성 완료"
fi

# 기존 인증서 확인
if [ -f "certs/cert.pem" ] && [ -f "certs/key.pem" ]; then
    echo "⚠️  기존 인증서가 존재합니다."
    read -p "새로 생성하시겠습니까? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ 인증서 생성 취소"
        exit 0
    fi
fi

# EC2 퍼블릭 IP 가져오기 (IMDSv2 사용)
echo "🔍 EC2 퍼블릭 IP 확인 중..."
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null`
PUBLIC_IP=`curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null`

if [ -z "$PUBLIC_IP" ]; then
    echo "⚠️  EC2 퍼블릭 IP를 가져올 수 없습니다. 수동으로 입력하세요."
    read -p "서버 IP 또는 도메인 입력: " PUBLIC_IP
fi

echo "📍 사용할 IP/도메인: $PUBLIC_IP"

# OpenSSL 설정 파일 생성
cat > certs/openssl.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C = KR
ST = Seoul
L = Seoul
O = Development
CN = $PUBLIC_IP

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
IP.1 = $PUBLIC_IP
IP.2 = 127.0.0.1
DNS.1 = localhost
EOF

# 자체 서명 인증서 생성
echo "🔨 인증서 생성 중..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout certs/key.pem \
    -out certs/cert.pem \
    -config certs/openssl.cnf

# 생성 확인
if [ -f "certs/cert.pem" ] && [ -f "certs/key.pem" ]; then
    echo "✅ SSL 인증서 생성 완료!"
    echo "📁 생성된 파일:"
    echo "   - certs/cert.pem (인증서)"
    echo "   - certs/key.pem (개인키)"
    
    # 권한 설정
    chmod 644 certs/cert.pem
    chmod 600 certs/key.pem
    echo "🔒 파일 권한 설정 완료"
    
    # 임시 설정 파일 삭제
    rm -f certs/openssl.cnf
else
    echo "❌ 인증서 생성 실패"
    exit 1
fi

echo ""
echo "🚀 다음 단계:"
echo "1. Docker 이미지 빌드: docker-compose build"
echo "2. 컨테이너 실행: docker-compose up -d"
echo "3. 브라우저에서 https://$PUBLIC_IP 접속"
echo ""
echo "⚠️  브라우저에서 자체 서명 인증서 경고가 나타나면:"
echo "   Chrome: '고급' → '안전하지 않음으로 이동'"
echo "   Firefox: '고급' → '위험을 감수하고 계속'"