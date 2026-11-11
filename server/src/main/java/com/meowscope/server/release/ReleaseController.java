package com.meowscope.server.release;

import com.meowscope.server.release.ReleaseService.Release;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** アプリの更新（API 設計書 10章）。認証が必要（サーバーの URL が入ったファイルを、利用者だけに配るため）。 */
@RestController
@RequestMapping("/api/v1/app-releases/{platform}")
class ReleaseController {

    private final ReleaseService releases;

    ReleaseController(ReleaseService releases) {
        this.releases = releases;
    }

    @GetMapping("/latest")
    Release latest(@PathVariable String platform) {
        return releases.latest(platform);
    }

    /** ファイルは数十 MB あるので、メモリに読み込まずにそのまま流す（Resource を返すと Spring が少しずつ送る）。 */
    @GetMapping("/file")
    ResponseEntity<Resource> file(@PathVariable String platform) {
        return ResponseEntity.ok().contentType(MediaType.APPLICATION_OCTET_STREAM)
                .body(new FileSystemResource(releases.file(platform)));
    }
}
