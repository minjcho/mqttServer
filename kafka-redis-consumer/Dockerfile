FROM python:3.11-slim

WORKDIR /app

# 시스템 패키지 및 빌드 도구 설치
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    libsnappy-dev \
    && rm -rf /var/lib/apt/lists/*

# 필요한 패키지 설치
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 소스 코드 복사
COPY . .

# 기본 명령어 (docker-compose에서 override 가능)
CMD ["python", "consumer.py"] 