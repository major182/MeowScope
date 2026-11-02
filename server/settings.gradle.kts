plugins {
    // Toolchain の Java 25 が手元になければ自動で取得する（技術選定書 5章）
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}

rootProject.name = "server"
