FROM openjdk:17-jdk-slim

WORKDIR /app

# Maven wrapper와 pom.xml 복사
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# Maven wrapper 실행 권한 부여 및 줄바꿈 문자 변환
RUN sed -i 's/\r$//' ./mvnw && chmod +x ./mvnw

# 의존성 다운로드 (캐싱 최적화)
RUN ./mvnw dependency:go-offline -B

# 소스 코드 복사
COPY src src

# 애플리케이션 빌드
RUN ./mvnw clean package -DskipTests

# 애플리케이션 실행
EXPOSE 8081
CMD ["java", "-jar", "target/websocket-server-1.0.0.jar"]