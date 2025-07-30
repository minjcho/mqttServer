FROM telegraf:1.28

# Telegraf 설정 파일 복사
COPY telegraf.conf /etc/telegraf/telegraf.conf

# 실행 권한 부여
RUN chmod 644 /etc/telegraf/telegraf.conf

# 기본 명령어
CMD ["telegraf"] 