package com.terraform.curd.exception;

/**
 * Thrown for business/domain validation failures that are not covered by bean
 * validation annotations. Maps to HTTP 400.
 */
public class ValidationException extends RuntimeException {

    public ValidationException(String message) {
        super(message);
    }
}
