package com.tsuki.api.filter;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.util.Objects;
import lombok.extern.slf4j.Slf4j;
import org.jspecify.annotations.NonNull;
import org.apache.commons.lang3.StringUtils;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.web.util.ContentCachingRequestWrapper;
import org.springframework.web.util.ContentCachingResponseWrapper;

@Slf4j
@Component
public class LoggingFilter extends OncePerRequestFilter {

    private static final int MAX_LOG_BODY_LENGTH = 2000;

    @Override
    protected void doFilterInternal(@NonNull HttpServletRequest request, @NonNull HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        ContentCachingRequestWrapper requestWrapper = new ContentCachingRequestWrapper(request);
        ContentCachingResponseWrapper responseWrapper = new ContentCachingResponseWrapper(response);
        long startAt = System.currentTimeMillis();

        try {
            filterChain.doFilter(requestWrapper, responseWrapper);
        } finally {
            long elapsedMs = System.currentTimeMillis() - startAt;
            String reqBody = bodyToString(requestWrapper.getContentAsByteArray(), requestWrapper.getCharacterEncoding());
            String respBody = bodyToString(responseWrapper.getContentAsByteArray(), responseWrapper.getCharacterEncoding());

            log.info(
                    "REQ method={}, uri={}, query={}, body={} | RSP status={}, body={}, costMs={}",
                    requestWrapper.getMethod(),
                    requestWrapper.getRequestURI(),
                    requestWrapper.getQueryString(),
                    truncate(reqBody),
                    responseWrapper.getStatus(),
                    truncate(respBody),
                    elapsedMs
            );

            responseWrapper.copyBodyToResponse();
        }
    }

    private String bodyToString(byte[] content, String characterEncoding) {
        if (Objects.isNull(content) || content.length == 0) {
            return "";
        }
        Charset charset = StandardCharsets.UTF_8;
        if (StringUtils.isNotBlank(characterEncoding)) {
            try {
                charset = Charset.forName(characterEncoding);
            } catch (Exception ignored) {
            }
        }
        return new String(content, charset);
    }

    private String truncate(String value) {
        if (Objects.isNull(value) || value.length() <= MAX_LOG_BODY_LENGTH) {
            return value;
        }
        return value.substring(0, MAX_LOG_BODY_LENGTH) + "...(truncated)";
    }
}
