package com.meowscope.server.common.logging;

import java.util.regex.Pattern;

/**
 * ログに出す文から、個人情報や利用者の書いた内容を伏せる（ログ設計書 6章、AC-19）。
 *
 * <p>想定外の例外の文や積み重ね（スタックトレース）は、ライブラリが作るので中身を選べない。
 * SMTP の例外は送り先のアドレスを、PostgreSQL の例外は行の値（名前・メモなど）を含むことがあるので、ここでまとめて伏せる。
 */
public final class LogMasking {

    private static final Pattern EMAIL = Pattern.compile("[^\\s@<>\"'(),;:]+@[^\\s@<>\"'(),;:]+\\.[A-Za-z]{2,}");

    /** PostgreSQL の「詳細：Key (列)=(値) …」「Failing row contains (値, …)」の行は、値ごと伏せる。 */
    private static final Pattern PG_DETAIL = Pattern.compile("(?m)((?:Detail|詳細)\\s*[:：]).*$");

    private static final Pattern FAILING_ROW = Pattern.compile("(Failing row contains )\\(.*\\)");

    private LogMasking() {
    }

    /** 伏せた文を返す。空なら空のまま。 */
    public static String mask(String value) {
        if (value == null || value.isEmpty()) {
            return value;
        }
        String masked = PG_DETAIL.matcher(value).replaceAll("$1 ***");
        masked = FAILING_ROW.matcher(masked).replaceAll("$1(***)");
        return EMAIL.matcher(masked).replaceAll("***@***");
    }
}
