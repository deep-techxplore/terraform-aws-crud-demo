package com.terraform.curd.dto.response;

import java.time.Instant;
import java.util.UUID;

/**
 * Read model returned to clients for a single document.
 *
 * @param id          unique document identifier
 * @param title       document title
 * @param description document description
 * @param category    classification category
 * @param fileName    original uploaded file name (null until a file is uploaded)
 * @param s3ObjectKey storage key in S3 (null until a file is uploaded)
 * @param fileSize    file size in bytes (null until a file is uploaded)
 * @param contentType MIME type (null until a file is uploaded)
 * @param uploadedBy  user who created the document
 * @param createdAt   creation timestamp
 * @param updatedAt   last modification timestamp
 */
public record DocumentResponse(
        UUID id,
        String title,
        String description,
        String category,
        String fileName,
        String s3ObjectKey,
        Long fileSize,
        String contentType,
        String uploadedBy,
        Instant createdAt,
        Instant updatedAt
) {
}
