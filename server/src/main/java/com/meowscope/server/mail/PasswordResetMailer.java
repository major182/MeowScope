package com.meowscope.server.mail;

import java.time.Duration;

/** パスワードの再設定の確認コードをメールで送る（F-AU-03）。送り方は差し替えられるよう、ここで分ける（技術選定書 4章）。 */
public interface PasswordResetMailer {

    /**
     * 確認コードを送る。
     *
     * @param to 送り先
     * @param code 6桁の確認コード
     * @param validFor コードの有効期間
     * @throws MailException 送れなかったとき
     */
    void sendCode(String to, String code, Duration validFor);

    /** メールを送れなかった。 */
    class MailException extends RuntimeException {
        public MailException(String message, Throwable cause) {
            super(message, cause);
        }
    }
}
