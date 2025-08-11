# Node.js 18을 기반으로 한 멀티스테이지 빌드
FROM node:18-alpine as builder

# 작업 디렉토리 설정
WORKDIR /app

# package.json과 package-lock.json 복사
COPY package*.json ./

# 의존성 설치 (dev dependencies도 포함 - 빌드에 필요)
RUN npm ci

# 소스 코드 복사
COPY . .

# 애플리케이션 빌드
RUN npm run build

# Production 스테이지
FROM nginx:alpine

# 빌드된 파일을 nginx로 복사
COPY --from=builder /app/dist /usr/share/nginx/html

# nginx 설정 파일들 복사
COPY nginx-ssl.conf /etc/nginx/conf.d/default.conf
COPY nginx-http.conf /etc/nginx/conf.d/http.conf

# 시작 스크립트 복사
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# 포트 노출
EXPOSE 80 443

# 시작 스크립트 실행
ENTRYPOINT ["/docker-entrypoint.sh"]