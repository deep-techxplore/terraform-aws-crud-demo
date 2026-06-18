-- Flyway migration: create the documents table with UUID PK, audit columns,
-- soft-delete flag and supporting indexes.

CREATE TABLE documents (
    id            UUID         NOT NULL DEFAULT gen_random_uuid(),
    title         VARCHAR(255) NOT NULL,
    description   VARCHAR(2000),
    category      VARCHAR(100) NOT NULL,
    file_name     VARCHAR(512),
    s3_object_key VARCHAR(1024),
    file_size     BIGINT,
    content_type  VARCHAR(255),
    uploaded_by   VARCHAR(255) NOT NULL,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    is_deleted    BOOLEAN      NOT NULL DEFAULT FALSE,
    CONSTRAINT pk_documents PRIMARY KEY (id)
);

-- Indexes aligned with common query/filter patterns.
CREATE INDEX idx_documents_category    ON documents (category);
CREATE INDEX idx_documents_uploaded_by ON documents (uploaded_by);
CREATE INDEX idx_documents_is_deleted  ON documents (is_deleted);
CREATE INDEX idx_documents_created_at  ON documents (created_at);

COMMENT ON TABLE documents IS 'Document metadata and S3 storage references';
COMMENT ON COLUMN documents.s3_object_key IS 'Key of the stored object in the S3 bucket';
COMMENT ON COLUMN documents.is_deleted IS 'Soft-delete flag; true rows are hidden from queries';
