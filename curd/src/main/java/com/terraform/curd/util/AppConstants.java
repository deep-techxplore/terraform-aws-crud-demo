package com.terraform.curd.util;

/**
 * Centralized, non-configurable application constants to avoid magic values
 * scattered across the codebase. Environment-specific values belong in
 * {@code application.yml}, not here.
 */
public final class AppConstants {

    private AppConstants() {
        // Utility class; prevent instantiation.
    }

    /** Default page index for pagination. */
    public static final String DEFAULT_PAGE_NUMBER = "0";

    /** Default page size for pagination. */
    public static final String DEFAULT_PAGE_SIZE = "10";

    /** Default sort field for listing endpoints. */
    public static final String DEFAULT_SORT_BY = "createdAt";

    /** Default sort direction for listing endpoints. */
    public static final String DEFAULT_SORT_DIRECTION = "desc";

    /** Standard success message used in API envelopes. */
    public static final String DEFAULT_SUCCESS_MESSAGE = "Operation completed successfully";
}
