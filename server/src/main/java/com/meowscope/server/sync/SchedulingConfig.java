package com.meowscope.server.sync;

import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;

/** 定期の処理（削除から90日を過ぎたデータの片付け：{@link PurgeService}）を動かす。 */
@Configuration
@EnableScheduling
class SchedulingConfig {
}
