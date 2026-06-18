package com.terraform.curd.service.impl;

import com.terraform.curd.config.StorageProperties;
import com.terraform.curd.exception.FileUploadException;
import com.terraform.curd.exception.ResourceNotFoundException;
import com.terraform.curd.service.FileStorageService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.UUID;

/**
 * Local-filesystem implementation of {@link FileStorageService}.
 *
 * <p>Activated when {@code app.storage.provider=local}. Files are written under
 * {@code app.storage.local.directory} (e.g. {@code D:/document-storage}). The returned
 * storage key is the file's path <em>relative</em> to that base directory, so it stays
 * portable even if the base directory moves, and mirrors the shape of an S3 object key.</p>
 */
@Slf4j
@Service
@ConditionalOnProperty(name = "app.storage.provider", havingValue = "local")
@RequiredArgsConstructor
public class LocalFileStorageService implements FileStorageService {

    private final StorageProperties storageProperties;

    @Override
    public String uploadFile(MultipartFile file, String documentId) {
        if (file == null || file.isEmpty()) {
            throw new FileUploadException("Uploaded file is empty");
        }

        String storageKey = buildStorageKey(documentId, file.getOriginalFilename());
        Path target = resolve(storageKey);

        try {
            // Create the document's sub-directories on demand, then write the bytes.
            Files.createDirectories(target.getParent());
            file.transferTo(target);
            log.info("Stored file '{}' on local disk at '{}' ({} bytes)",
                    storageKey, target, file.getSize());
            return storageKey;
        } catch (IOException e) {
            throw new FileUploadException("Failed to write file to local storage: " + e.getMessage(), e);
        }
    }

    @Override
    public byte[] downloadFile(String storageKey) {
        Path source = resolve(storageKey);
        if (!Files.exists(source)) {
            throw ResourceNotFoundException.of("File", storageKey);
        }
        try {
            byte[] bytes = Files.readAllBytes(source);
            log.info("Read file '{}' from local disk ({} bytes)", storageKey, bytes.length);
            return bytes;
        } catch (IOException e) {
            throw new FileUploadException("Failed to read file from local storage: " + e.getMessage(), e);
        }
    }

    @Override
    public void deleteFile(String storageKey) {
        if (!StringUtils.hasText(storageKey)) {
            return;
        }
        try {
            boolean deleted = Files.deleteIfExists(resolve(storageKey));
            log.info("Local file '{}' delete requested (existed={})", storageKey, deleted);
        } catch (IOException e) {
            throw new FileUploadException("Failed to delete file from local storage: " + e.getMessage(), e);
        }
    }

    /**
     * Resolves a storage key to an absolute path under the configured base directory,
     * rejecting any key that would escape it (path-traversal guard).
     */
    private Path resolve(String storageKey) {
        Path base = baseDir();
        Path resolved = base.resolve(storageKey).normalize();
        if (!resolved.startsWith(base)) {
            throw new FileUploadException("Illegal storage key (path traversal): " + storageKey);
        }
        return resolved;
    }

    /**
     * Reads and validates the configured base directory.
     */
    private Path baseDir() {
        String directory = storageProperties.getLocal().getDirectory();
        if (!StringUtils.hasText(directory)) {
            throw new FileUploadException(
                    "Local storage selected but 'app.storage.local.directory' is not configured");
        }
        return Paths.get(directory).toAbsolutePath().normalize();
    }

    /**
     * Builds a collision-resistant, forward-slash storage key namespaced by document id,
     * matching the layout used by the S3 backend ({@code folder/documentId/uuid-name}).
     */
    private String buildStorageKey(String documentId, String originalFilename) {
        String safeName = StringUtils.hasText(originalFilename)
                ? originalFilename.replaceAll("[^a-zA-Z0-9._-]", "_")
                : "file";
        String folder = storageProperties.getLocal().getFolder();
        return folder + "/" + documentId + "/" + UUID.randomUUID() + "-" + safeName;
    }
}
