package com.terraform.curd.service;

import org.springframework.web.multipart.MultipartFile;

/**
 * Backend-agnostic abstraction over binary file storage used by the document service.
 *
 * <p>The concrete implementation is chosen at startup from {@code app.storage.provider}:
 * {@code local} activates {@code LocalFileStorageService} (filesystem), {@code s3}
 * activates {@code S3FileStorageService} (AWS S3). The document service is unaware of
 * which one is wired in.</p>
 */
public interface FileStorageService {

    /**
     * Stores a file under a generated, collision-resistant storage key.
     *
     * @param file       multipart file to store
     * @param documentId owning document id, used to namespace the key
     * @return the generated storage key (S3 object key, or relative filesystem path)
     */
    String uploadFile(MultipartFile file, String documentId);

    /**
     * Reads a stored file's bytes.
     *
     * @param storageKey key previously returned by {@link #uploadFile}
     * @return raw file bytes
     */
    byte[] downloadFile(String storageKey);

    /**
     * Deletes a stored file. Implementations should be tolerant of missing keys.
     *
     * @param storageKey key previously returned by {@link #uploadFile}
     */
    void deleteFile(String storageKey);
}
