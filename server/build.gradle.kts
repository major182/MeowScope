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
    testImplementation("org.springframework.boot:spring-boot-starter-actuator-test")
    testImplementation("org.springframework.boot:spring-boot-starter-webmvc-test")
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
