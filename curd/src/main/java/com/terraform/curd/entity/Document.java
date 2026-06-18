package com.terraform.curd.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.SQLDelete;
import org.hibernate.annotations.SQLRestriction;
import org.hibernate.annotations.UuidGenerator;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.Instant;
import java.util.UUID;

/**
 * Persistent representation of a managed document and its S3 storage metadata.
 *
 * <p>Soft delete is implemented declaratively: {@link SQLDelete} rewrites JPA
 * delete operations to flip the {@code is_deleted} flag, while {@link SQLRestriction}
 * transparently filters soft-deleted rows out of every read query.</p>
 */
@Entity
@Table(name = "documents", indexes = {
        @Index(name = "idx_documents_category", columnList = "category"),
        @Index(name = "idx_documents_uploaded_by", columnList = "uploaded_by"),
        @Index(name = "idx_documents_is_deleted", columnList = "is_deleted"),
        @Index(name = "idx_documents_created_at", columnList = "created_at")
})
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
@EntityListeners(AuditingEntityListener.class)
@SQLDelete(sql = "UPDATE documents SET is_deleted = true, updated_at = now() WHERE id = ?")
@SQLRestriction("is_deleted = false")
public class Document {

    @Id
    @UuidGenerator
    @Column(name = "id", updatable = false, nullable = false)
    private UUID id;

    @Column(name = "title", nullable = false, length = 255)
    private String title;

    @Column(name = "description", length = 2000)
    private String description;

    @Column(name = "category", nullable = false, length = 100)
    private String category;

    @Column(name = "file_name")
    private String fileName;

    @Column(name = "s3_object_key")
    private String s3ObjectKey;

    @Column(name = "file_size")
    private Long fileSize;

    @Column(name = "content_type")
    private String contentType;

    @Column(name = "uploaded_by", nullable = false, length = 255)
    private String uploadedBy;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @LastModifiedDate
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "is_deleted", nullable = false)
    @Builder.Default
    private boolean deleted = false;
}
