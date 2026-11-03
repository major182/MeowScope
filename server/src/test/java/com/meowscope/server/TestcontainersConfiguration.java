package com.meowscope.server;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Bean;
import org.testcontainers.postgresql.PostgreSQLContainer;

/**
 * 結合テストで使う本物の PostgreSQL（テスト仕様書 1章）。
 *
 * <p>本番と同じ版のイメージをコンテナで動かし、{@code @ServiceConnection} で接続先を Spring に渡す。
 * テストの間はコンテナを使い回すので、起動は1回で済む。
 */
@TestConfiguration(proxyBeanMethods = false)
public class TestcontainersConfiguration {

    @Bean
    @ServiceConnection
    PostgreSQLContainer postgres() {
        return new PostgreSQLContainer("postgres:18.6");
    }
}
