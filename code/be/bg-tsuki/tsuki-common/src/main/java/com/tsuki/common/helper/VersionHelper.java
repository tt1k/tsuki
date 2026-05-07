package com.tsuki.common.helper;

import org.apache.commons.lang3.StringUtils;
import org.apache.maven.artifact.versioning.ComparableVersion;
import org.springframework.stereotype.Component;

@Component
public class VersionHelper {

    public int compareVersion(String currentVersion, String latestVersion) {
        if (StringUtils.isBlank(currentVersion)) {
            return -1;
        }
        ComparableVersion current = new ComparableVersion(normalizeVersion(currentVersion));
        ComparableVersion latest = new ComparableVersion(normalizeVersion(latestVersion));
        return current.compareTo(latest);
    }

    public String normalizeVersion(String version) {
        if (StringUtils.isBlank(version)) {
            return "";
        }
        return version.startsWith("v") ? version.substring(1) : version;
    }
}
