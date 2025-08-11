#!/bin/sh

# SSL 인증서 확인
if [ -f "/etc/nginx/certs/cert.pem" ] && [ -f "/etc/nginx/certs/key.pem" ]; then
    echo "🔐 SSL 인증서 발견 - HTTPS 모드로 실행"
    # SSL 설정 사용
    rm -f /etc/nginx/conf.d/http.conf
else
    echo "⚠️  SSL 인증서 없음 - HTTP 모드로 실행"
    echo "💡 HTTPS를 사용하려면 generate-ssl.sh 스크립트를 실행하세요"
    # HTTP 설정 사용
    rm -f /etc/nginx/conf.d/default.conf
    mv /etc/nginx/conf.d/http.conf /etc/nginx/conf.d/default.conf
fi

# nginx 실행
exec nginx -g "daemon off;"