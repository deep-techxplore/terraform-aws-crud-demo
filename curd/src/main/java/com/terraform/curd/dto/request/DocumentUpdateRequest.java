package com.terraform.curd.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Payload used to update mutable document metadata. Storage/file attributes are
 * managed exclusively by the upload endpoint and cannot be edited here.
 *
 * @param title       updated title (required)
 * @param description updated description (optional)
 * @param category    updated category (required)
 */
public record DocumentUpdateRequest(

        @NotBlank(message = "title is required")
        @Size(max = 255, message = "title must not exceed 255 characters")
        String title,

        @Size(max = 2000, message = "description must not exceed 2000 characters")
        String description,

        @NotBlank(message = "category is required")
        @Size(max = 100, message = "category must not exceed 100 characters")
        String category
) {
}
