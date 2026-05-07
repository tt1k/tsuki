package com.tsuki.common.exception;

public class VersionRequestException extends RuntimeException {

    public VersionRequestException(Throwable t) {
        super(t);
    }

    public VersionRequestException(String msg) {
        super(msg);
    }
}
