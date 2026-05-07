package com.tsuki.service.version.impl;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import com.tsuki.common.exception.VersionRequestException;
import com.tsuki.common.helper.GithubHelper;
import com.tsuki.common.helper.VersionHelper;
import com.tsuki.common.dto.QueryVersionResult;
import com.tsuki.service.version.VersionService;
import jakarta.annotation.Resource;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.concurrent.TimeUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Objects;
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.lang3.StringUtils;
import org.springframework.http.HttpStatusCode;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class VersionServiceImpl implements VersionService {

    private static final String DEFAULT_RELEASE_URL = "https://github.com/tt1k/tsuki/releases";
    private static final String VERSION_SERVICE_CACHE_KEY = "VERSION_SERVICE_CACHE_KEY";

    @Resource
    private ObjectMapper objectMapper;

    @Resource
    private GithubHelper githubHelper;

    @Resource
    private VersionHelper versionHelper;

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(2))
            .build();

    private final Cache<String, QueryVersionResult> versionCache = Caffeine.newBuilder()
            .expireAfterWrite(5, TimeUnit.MINUTES)
            .maximumSize(1)
            .build();

    @Override
    public QueryVersionResult queryLatestVersion(String currentVersion) {
        QueryVersionResult cachedResult = getCachedResult(currentVersion);
        if (Objects.nonNull(cachedResult)) {
            return cachedResult;
        }

        synchronized (this) {
            QueryVersionResult syncedResult = getCachedResult(currentVersion);
            if (Objects.nonNull(syncedResult)) {
                return syncedResult;
            }
            return getLatestVersion(currentVersion);
        }
    }

    private QueryVersionResult getCachedResult(String currentVersion) {
        QueryVersionResult cached = versionCache.getIfPresent(VERSION_SERVICE_CACHE_KEY);
        if (Objects.isNull(cached)) {
            return null;
        }
        return calcNeedUpdate(cached, currentVersion);
    }

    private QueryVersionResult getLatestVersion(String currentVersion) {
        try {
            HttpRequest request = githubHelper.buildLatestReleaseRequest();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (!HttpStatusCode.valueOf(response.statusCode()).is2xxSuccessful()) {
                log.error("GitHub release API failed, status={}", response.statusCode());
                return null;
            }

            JsonNode root = objectMapper.readTree(response.body());
            String tagName = root.path("tag_name").asText("").trim();
            String version = versionHelper.normalizeVersion(tagName);
            if (StringUtils.isBlank(version)) {
                log.error("GitHub release API missing tag_name");
                return null;
            }

            String releaseUrl = root.path("html_url").asText(DEFAULT_RELEASE_URL).trim();
            List<QueryVersionResult.DownloadFile> files = parseFiles(root.path("assets"));
            String dmgUrl = findDmgUrl(root.path("assets"));

            QueryVersionResult result = QueryVersionResult.builder().version(version).url(releaseUrl).dmg(dmgUrl).files(files).build();
            versionCache.put(VERSION_SERVICE_CACHE_KEY, result);
            return calcNeedUpdate(result, currentVersion);
        } catch (Exception ex) {
            log.error("Failed to query latest version", new VersionRequestException(ex));
            return null;
        }
    }

    private QueryVersionResult calcNeedUpdate(QueryVersionResult result, String currentVersion) {
        boolean needUpdate = versionHelper.compareVersion(currentVersion, result.getVersion()) < 0;
        result.setNeedUpdate(needUpdate);
        return result;
    }

    private List<QueryVersionResult.DownloadFile> parseFiles(JsonNode assetsNode) {
        List<QueryVersionResult.DownloadFile> files = new ArrayList<>();
        if (!assetsNode.isArray()) {
            return files;
        }

        for (JsonNode assetNode : assetsNode) {
            String name = assetNode.path("name").asText("").trim();
            String url = assetNode.path("browser_download_url").asText("").trim();
            if (name.isEmpty() || url.isEmpty()) {
                continue;
            }
            files.add(QueryVersionResult.DownloadFile.builder()
                    .name(name)
                    .url(url)
                    .build());
        }
        return files;
    }

    private String findDmgUrl(JsonNode assetsNode) {
        if (!assetsNode.isArray()) {
            return "";
        }

        for (JsonNode assetNode : assetsNode) {
            String name = assetNode.path("name").asText("").trim();
            String url = assetNode.path("browser_download_url").asText("").trim();
            if (name.isEmpty() || url.isEmpty()) {
                continue;
            }
            if (name.toLowerCase(Locale.ROOT).endsWith(".dmg")) {
                return url;
            }
        }
        return "";
    }

}
