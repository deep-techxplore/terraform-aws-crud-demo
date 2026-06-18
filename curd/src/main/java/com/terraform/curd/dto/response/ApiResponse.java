package com.terraform.curd.dto.response;

import com.fasterxml.jackson.annotation.JsonInclude;

/**
 * Standard response envelope returned by every API.
 *
 * <pre>
 * {
 *   "success": true,
 *   "message": "Operation completed successfully",
 *   "data": { ... }
 * }
 * </pre>
 *
 * @param success whether the operation succeeded
 * @param message human-readable outcome message
 * @param data    payload (may be null for errors or no-content responses)
 * @param <T>     payload type
 */
@JsonInclude(JsonInclude.Include.ALWAYS)
public record ApiResponse<T>(
        boolean success,
        String message,
        T data
) {

    /**
     * Builds a success envelope.
     *
     * @param message outcome message
     * @param data    payload
     * @param <T>     payload type
     * @return success response
     */
    public static <T> ApiResponse<T> success(String message, T data) {
        return new ApiResponse<>(true, message, data);
    }

    /**
     * Builds a failure envelope.
     *
     * @param message error message
     * @param data    optional error detail payload
     * @param <T>     payload type
     * @return failure response
     */
    public static <T> ApiResponse<T> failure(String message, T data) {
        return new ApiResponse<>(false, message, data);
    }
}
