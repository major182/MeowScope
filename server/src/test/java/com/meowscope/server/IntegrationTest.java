package com.meowscope.server;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;

/** 結合テストの共通の設定。本物の DB を使い、MockMvc で API を呼ぶ。 */
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
// 署名鍵はテスト専用の値をテストの側から渡す（本物の鍵は秘密の置き場にだけ置く）
// 写真はテスト用の一時フォルダーに置く
@SpringBootTest(properties = {
    "meowscope.auth.jwt-secret=" + IntegrationTest.TEST_JWT_SECRET,
    "meowscope.photos.dir=${java.io.tmpdir}/meowscope-test-photos",
})
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
public @interface IntegrationTest {

    /** 「test-only-signing-key-not-used-in-production」を Base64 にしたもの。 */
    String TEST_JWT_SECRET = "dGVzdC1vbmx5LXNpZ25pbmcta2V5LW5vdC11c2VkLWluLXByb2R1Y3Rpb24=";
}
