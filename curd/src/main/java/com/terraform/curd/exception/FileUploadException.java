package com.terraform.curd.exception;

/**
 * Thrown when an uploaded file is invalid or cannot be read. Maps to HTTP 400.
 */
public class FileUploadException extends RuntimeException {

    public FileUploadException(String message) {
        super(message);
    }

    public FileUploadException(String message, Throwable cause) {
        super(message, cause);
    }
}
