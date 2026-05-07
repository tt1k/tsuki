package com.tsuki.common.util;

import java.util.List;
import java.util.Objects;

public final class ListUtils {

    private ListUtils() {
    }

    public static <T> T first(List<T> list) {
        Objects.requireNonNull(list, "list must not be null");
        if (list.isEmpty()) {
            throw new IllegalArgumentException("list must not be empty");
        }
        return list.get(0);
    }
}
