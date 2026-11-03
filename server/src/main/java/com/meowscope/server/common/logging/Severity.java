package com.meowscope.server.common.logging;

import org.slf4j.Marker;
import org.slf4j.MarkerFactory;

/**
 * ログの重大度（ログ設計書 3章）。
 *
 * <p>SLF4J の重大度は ERROR・WARN・INFO の3つしかないため、設計書の6段階のうち alert・critical・notice は
 * マーカーで表す。例：{@code log.error(Severity.CRITICAL, "DB に接続できない")}。
 */
public final class Severity {

    /** 直ちに対応する（乗っ取りの疑い）。ERROR と一緒に使う。 */
    public static final Marker ALERT = MarkerFactory.getMarker("ALERT");

    /** 主要な機能が止まっている。ERROR と一緒に使う。 */
    public static final Marker CRITICAL = MarkerFactory.getMarker("CRITICAL");

    /** 正常だが、監査のために残す。INFO と一緒に使う。 */
    public static final Marker NOTICE = MarkerFactory.getMarker("NOTICE");

    private Severity() {
    }
}
