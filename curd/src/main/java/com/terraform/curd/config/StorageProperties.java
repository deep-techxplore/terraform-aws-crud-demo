package com.terraform.curd.config;

import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * Externalized file-storage configuration bound from the {@code app.storage.*} namespace.
 * Every value originates from an environment variable (see {@code application.yml}); the
 * deployed app receives them from Elastic Beanstalk, which Terraform populates.
 *
 * <p>{@link #provider} selects which {@code FileStorageService} is activated:</p>
 * <ul>
 *   <li>{@code local} &rarr; on-disk storage ({@link Local#directory}).</li>
 *   <li>{@code s3} &rarr; the AWS S3 bucket ({@link S3#bucket}).</li>
 * </ul>
 */
@Getter
@Setter
@Validated
@ConfigurationProperties(prefix = "app.storage")
public class StorageProperties {

    /** Active storage backend: {@code local} or {@code s3}. */
    @NotBlank
    private String provider = "local";

    /** Settings for the local-filesystem backend. */
    private final Local local = new Local();

    /** Settings for the S3 backend. */
    private final S3 s3 = new S3();

    /** Local-filesystem storage configuration ({@code app.storage.local.*}). */
    @Getter
    @Setter
    public static class Local {
        /** Base directory for uploaded files, e.g. {@code D:/document-storage}. */
        private String directory;
        /** Sub-folder grouping uploads, mirroring the S3 key prefix. */
        private String folder = "document";
    }

    /** S3 storage configuration ({@code app.storage.s3.*}). */
    @Getter
    @Setter
    public static class S3 {
        /** Target bucket for uploaded documents (from {@code S3_BUCKET_NAME}). */
        private String bucket;
        /** Folder (key prefix) inside the bucket. */
        private String folder = "document";
    }
}
