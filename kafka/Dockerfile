FROM confluentinc/cp-kafka:7.5.0

# 데이터 디렉토리 생성 및 권한 부여
RUN mkdir -p /tmp/kraft-combined-logs && chmod 777 /tmp/kraft-combined-logs

# 스크립트 디렉토리 생성 및 복사
COPY --chmod=755 ./scripts /scripts

# Kafka 설정 파일 복사
COPY ./kafka-server.properties /etc/kafka/kafka-server.properties

# KRaft 모드용 엔트리포인트 스크립트 추가
COPY --chmod=755 entrypoint.sh /entrypoint.sh

# 기본 명령어 설정
ENTRYPOINT ["/entrypoint.sh"]
