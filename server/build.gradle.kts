plugins {
    java
	checkstyle
	jacoco
	id("com.diffplug.spotless") version "8.10.4"
    id("org.springframework.boot") version "4.1.2"
    id("io.spring.dependency-management") version "1.1.7"
}

group = "com.meowscope"
version = "0.0.1-SNAPSHOT"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(25)
    }
}

repositories {
    mavenCentral()
}

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("org.springframework.boot:spring-boot-starter-webmvc")
    implementation("org.springframework.boot:spring-boot-starter-validation")
    // DB：SQL をそのまま書ける JdbcClient を使う。同期は表をまたいだ一括の処理が多く、ORM の自動の動きより見通しがよいため
    implementation("org.springframework.boot:spring-boot-starter-jdbc")
    // DB の変更管理（技術選定書 3章）。PostgreSQL 用の部品は別になっている
    implementation("org.springframework.boot:spring-boot-starter-flyway")
    implementation("org.flywaydb:flyway-database-postgresql")
    runtimeOnly("org.postgresql:postgresql")
    testImplementation("org.springframework.boot:spring-boot-starter-actuator-test")
    testImplementation("org.springframework.boot:spring-boot-starter-webmvc-test")
    // 結合テストは本物の PostgreSQL をコンテナで動かす（テスト仕様書 1章）
    testImplementation("org.springframework.boot:spring-boot-testcontainers")
    testImplementation("org.testcontainers:testcontainers-junit-jupiter")
    testImplementation("org.testcontainers:testcontainers-postgresql")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.withType<Test> {
    useJUnitPlatform()
}

// カバレッジ。NF-MT-01 の 80% を下回ったら check を失敗させる
jacoco {
    toolVersion = "0.8.15"
}

tasks.test {
    finalizedBy(tasks.jacocoTestReport)
}

tasks.jacocoTestCoverageVerification {
    // 起動クラスは Spring Boot の入口だけで、業務の処理がないので対象から外す
    classDirectories.setFrom(classDirectories.files.map { fileTree(it) { exclude("**/ServerApplication*") } })
    violationRules {
        rule {
            limit {
                minimum = "0.80".toBigDecimal()
            }
        }
    }
}

tasks.check {
    dependsOn(tasks.jacocoTestCoverageVerification)
}

// 書式は Spotless で判定する。./gradlew spotlessApply で直せる
spotless {
    java {
        target("src/**/*.java")
        removeUnusedImports()
        leadingTabsToSpaces(4)
        trimTrailingWhitespace()
        endWithNewline()
    }
}

// 書式で直せない書き方は Checkstyle で判定する
checkstyle {
    toolVersion = "14.4.0"
    configFile = file("config/checkstyle/checkstyle.xml")
    maxWarnings = 0
}

// 依存関係のバージョンを gradle.lockfile に固定し、OSV-Scanner で脆弱性を検査する（NF-SC-06）
// 依存関係を変えたら ./gradlew dependencies --write-locks で更新する
dependencyLocking {
    lockAllConfigurations()
}

// 手元で動かすときは開発用の設定（人が読めるログ）を使う
tasks.bootRun {
    systemProperty("spring.profiles.active", "dev")
}
