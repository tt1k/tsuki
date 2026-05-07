package com.tsuki.common.helper;

import java.net.URI;
import java.net.http.HttpRequest;
import java.time.Duration;
import org.apache.commons.lang3.StringUtils;
import org.springframework.stereotype.Component;

@Component
public class GithubHelper {

    private static final String LATEST_RELEASE_URL = "https://api.github.com/repos/tt1k/tsuki/releases/latest";
    private static final String ACCEPT_HEADER = "application/vnd.github+json";
    private static final String API_VERSION = "2022-11-28";
    private static final String USER_AGENT = "tsuki-api-version-check";
    private static final String GITHUB_API_KEY_ENV = "GITHUB_API_KEY";

    public HttpRequest buildLatestReleaseRequest() {
        HttpRequest.Builder requestBuilder = HttpRequest.newBuilder()
                .uri(URI.create(LATEST_RELEASE_URL))
                .timeout(Duration.ofSeconds(3))
                .header("Accept", ACCEPT_HEADER)
                .header("X-GitHub-Api-Version", API_VERSION)
                .header("User-Agent", USER_AGENT)
                .GET();

        String token = System.getenv(GITHUB_API_KEY_ENV);
        if (StringUtils.isNotBlank(token)) {
            requestBuilder.header("Authorization", "Bearer " + token.trim());
        }

        return requestBuilder.build();
    }
}
