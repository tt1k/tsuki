package com.tsuki.service.version;

import com.tsuki.common.dto.QueryVersionResult;

public interface VersionService {

    QueryVersionResult queryLatestVersion(String currentVersion);
}
