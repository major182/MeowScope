package com.meowscope.server.photo;

import com.meowscope.server.common.logging.Severity;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * 写真の本体をサーバーのディスク（Docker のボリューム）に置く（技術選定書 3章：S3 は使わない）。
 *
 * <p>場所は {@code <保存先>/<おうちの ID>/<写真の ID>}。名前は ID だけにし、端末から来た名前は使わない（パスの書き換えを防ぐ）。
 */
@Component
public class PhotoStorage {

    private static final Logger log = LoggerFactory.getLogger(PhotoStorage.class);

    private final Path root;

    public PhotoStorage(@Value("${meowscope.photos.dir}") String dir) {
        this.root = Path.of(dir).toAbsolutePath().normalize();
    }

    /** アイコンなど、場所を決めて保存する（相対の場所は呼ぶ側が ID だけで作る）。 */
    public String saveAt(String relative, byte[] bytes) {
        return write(relative, UUID.nameUUIDFromBytes(relative.getBytes()), bytes);
    }

    /** 保存して、保存先からの相対の場所を返す。いったん別名で書いてから置き換え、書きかけのファイルを残さない。 */
    String save(UUID householdId, UUID photoId, byte[] bytes) {
        return write(householdId + "/" + photoId, photoId, bytes);
    }

    private String write(String relative, UUID photoId, byte[] bytes) {
        Path target = root.resolve(relative);
        try {
            Files.createDirectories(target.getParent());
            Path temp = Files.createTempFile(target.getParent(), photoId.toString(), ".tmp");
            Files.write(temp, bytes);
            Files.move(temp, target, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
        } catch (IOException e) {
            log.atError().addMarker(Severity.CRITICAL).setCause(e)
                    .addKeyValue("evt.name", "photo_write").log("写真を保存先に書けない（写真：{}）", photoId);
            throw new UncheckedIOException(e);
        }
        return relative;
    }

    public byte[] load(String relative) throws IOException {
        return Files.readAllBytes(root.resolve(relative));
    }

    /** 消す。消せなくても処理は続け、後で確かめられるよう warning を残す（ログ設計書 5章）。 */
    public void delete(String relative) {
        if (relative == null) {
            return;
        }
        try {
            Files.deleteIfExists(root.resolve(relative));
        } catch (IOException e) {
            log.atWarn().setCause(e).addKeyValue("evt.name", "photo_delete")
                    .log("写真のファイルを消せない（場所：{}）", relative);
        }
    }
}
