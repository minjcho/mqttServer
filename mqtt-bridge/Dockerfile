FROM python:3.11-slim

WORKDIR /app

# 의존성 설치
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 브릿지 스크립트 복사
COPY bridge.py .

# 실행 권한 부여
RUN chmod +x bridge.py

# 브릿지 실행
CMD ["python", "bridge.py"] 