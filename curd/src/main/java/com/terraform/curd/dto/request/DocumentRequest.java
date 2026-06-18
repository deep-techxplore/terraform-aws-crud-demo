package com.terraform.curd.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Payload used to create document metadata. File-related attributes are populated
 * separately through the upload endpoint.
 *
 * @param title       human-readable document title (required)
 * @param description optional free-text description
 * @param category    classification category used for filtering (required)
 * @param uploadedBy  identifier of the user creating the document (required)
 */
public record DocumentRequest(

        @NotBlank(message = "title is required")
        @Size(max = 255, message = "title must not exceed 255 characters")
        String title,

        @Size(max = 2000, message = "description must not exceed 2000 characters")
        String description,

        @NotBlank(message = "category is required")
        @Size(max = 100, message = "category must not exceed 100 characters")
        String category,

        @NotBlank(message = "uploadedBy is required")
        @Size(max = 255, message = "uploadedBy must not exceed 255 characters")
        String uploadedBy
) {
}
