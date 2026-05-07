package com.tsuki.common.dto;

import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class QueryVersionResult {

    private String version;
    private Boolean needUpdate;
    private String url;
    private String dmg;
    private List<DownloadFile> files;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class DownloadFile {
        private String name;
        private String url;
    }
}
