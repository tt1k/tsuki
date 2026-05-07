package com.tsuki.common.enums;

public enum LangType {
    CN("cn"),
    TW("tw"),
    EN("en"),
    JA("ja");

    private final String code;

    LangType(String code) {
        this.code = code;
    }

    public static boolean isSupported(String value) {
        for (LangType langType : values()) {
            if (langType.code.equals(value)) {
                return true;
            }
        }
        return false;
    }
}
