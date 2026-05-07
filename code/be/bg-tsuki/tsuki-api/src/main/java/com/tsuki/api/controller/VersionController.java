package com.tsuki.api.controller;

import com.tsuki.common.dto.QueryVersionResult;
import com.tsuki.common.request.VersionRequest;
import com.tsuki.common.response.BaseResponse;
import com.tsuki.service.version.VersionService;
import jakarta.annotation.Resource;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/version")
public class VersionController {

    @Resource
    private VersionService versionService;

    @GetMapping("/get")
    public BaseResponse<QueryVersionResult> getVersion(VersionRequest request) {
        return BaseResponse.success(versionService.queryLatestVersion(request.getVersion()));
    }
}
