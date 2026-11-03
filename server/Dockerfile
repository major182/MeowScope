# サーバーのイメージ。組み立て用（JDK）と実行用（JRE）を分け、実行用のイメージを小さくする
FROM eclipse-temurin:25.0.5_8-jdk AS build
WORKDIR /src
# 依存関係だけを先に取得し、ソースを変えただけのときは取得をやり直さない（Docker のキャッシュ）
COPY gradlew settings.gradle.kts build.gradle.kts gradle.lockfile ./
COPY gradle gradle
RUN ./gradlew --no-daemon dependencies > /dev/null
COPY config config
COPY src src
RUN ./gradlew --no-daemon bootJar

FROM eclipse-temurin:25.0.5_8-jre
WORKDIR /app
# 管理者の権限で動かさない
RUN useradd --system --uid 10001 meowscope
COPY --from=build /src/build/libs/*.jar app.jar
USER meowscope
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
