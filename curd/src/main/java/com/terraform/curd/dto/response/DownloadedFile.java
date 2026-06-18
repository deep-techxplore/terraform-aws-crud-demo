package com.terraform.curd.dto.response;

/**
 * Carrier for a downloaded file's bytes and the metadata required to build proper
 * HTTP response headers.
 *
 * @param content     raw file bytes
 * @param fileName    original file name for the {@code Content-Disposition} header
 * @param contentType MIME type for the {@code Content-Type} header
 * @param fileSize    content length in bytes
 */
public record DownloadedFile(
        byte[] content,
        String fileName,
        String contentType,
        long fileSize
) {
}
