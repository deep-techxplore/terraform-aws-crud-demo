package com.terraform.curd.exception;

/**
 * Thrown when an AWS S3 operation fails. Maps to HTTP 502 (bad upstream gateway).
 */
public class AwsOperationException extends RuntimeException {

    public AwsOperationException(String message, Throwable cause) {
        super(message, cause);
    }
}
