package com.terraform.curd.service.impl;

import com.terraform.curd.config.StorageProperties;
import com.terraform.curd.exception.AwsOperationException;
import com.terraform.curd.exception.FileUploadException;
import com.terraform.curd.service.FileStorageService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.ResponseBytes;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectResponse;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.S3Exception;

import java.io.IOException;
import java.util.UUID;

/**
 * AWS S3 implementation of {@link FileStorageService}.
 *
 * <p>Activated only when {@code app.storage.provider=s3}. When it is active the
 * {@link S3Client} bean is also created (see {@code AwsClientConfig}).</p>
 */
@Slf4j
@Service
@ConditionalOnProperty(name = "app.storage.provider", havingValue = "s3")
@RequiredArgsConstructor
public class S3FileStorageService implements FileStorageService {

    private final S3Client s3Client;
    private final StorageProperties storageProperties;

    @Override
    public String uploadFile(MultipartFile file, String documentId) {
        if (file == null || file.isEmpty()) {
            throw new FileUploadException("Uploaded file is empty");
        }

        String objectKey = buildObjectKey(documentId, file.getOriginalFilename());
        String bucket = storageProperties.getS3().getBucket();

        try {
            PutObjectRequest putRequest = PutObjectRequest.builder()
                    .bucket(bucket)
                    .key(objectKey)
                    .contentType(file.getContentType())
                    .contentLength(file.getSize())
                    .build();

            s3Client.putObject(putRequest, RequestBody.fromInputStream(file.getInputStream(), file.getSize()));
            log.info("Uploaded object '{}' to bucket '{}' ({} bytes)", objectKey, bucket, file.getSize());
            return objectKey;
        } catch (IOException e) {
            throw new FileUploadException("Failed to read uploaded file stream", e);
        } catch (S3Exception e) {
            throw new AwsOperationException("Failed to upload file to S3: " + e.awsErrorDetails().errorMessage(), e);
        }
    }

    @Override
    public byte[] downloadFile(String objectKey) {
        String bucket = storageProperties.getS3().getBucket();
        try {
            GetObjectRequest getRequest = GetObjectRequest.builder()
                    .bucket(bucket)
                    .key(objectKey)
                    .build();

            ResponseBytes<GetObjectResponse> objectBytes = s3Client.getObjectAsBytes(getRequest);
            log.info("Downloaded object '{}' from bucket '{}'", objectKey, bucket);
            return objectBytes.asByteArray();
        } catch (S3Exception e) {
            throw new AwsOperationException("Failed to download file from S3: " + e.awsErrorDetails().errorMessage(), e);
        }
    }

    @Override
    public void deleteFile(String objectKey) {
        if (!StringUtils.hasText(objectKey)) {
            return;
        }
        String bucket = storageProperties.getS3().getBucket();
        try {
            DeleteObjectRequest deleteRequest = DeleteObjectRequest.builder()
                    .bucket(bucket)
                    .key(objectKey)
                    .build();
            s3Client.deleteObject(deleteRequest);
            log.info("Deleted object '{}' from bucket '{}'", objectKey, bucket);
        } catch (S3Exception e) {
            throw new AwsOperationException("Failed to delete file from S3: " + e.awsErrorDetails().errorMessage(), e);
        }
    }

    /**
     * Builds a collision-resistant object key namespaced by document id.
     *
     * @param documentId       owning document id
     * @param originalFilename original file name (may be null)
     * @return generated object key
     */
    private String buildObjectKey(String documentId, String originalFilename) {
        String safeName = StringUtils.hasText(originalFilename)
                ? originalFilename.replaceAll("[^a-zA-Z0-9._-]", "_")
                : "file";
        String folder = storageProperties.getS3().getFolder();
        return folder + "/" + documentId + "/" + UUID.randomUUID() + "-" + safeName;
    }
}
