package com.terraform.curd.repository;

import com.terraform.curd.entity.Document;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

/**
 * Data access for {@link Document}. Soft-deleted rows are automatically excluded by
 * the entity-level {@code @SQLRestriction}, so all query methods operate only on
 * active documents.
 */
@Repository
public interface DocumentRepository extends JpaRepository<Document, UUID> {

    /**
     * Finds active documents filtered by category.
     *
     * @param category category to match (case-sensitive)
     * @param pageable pagination and sorting
     * @return matching page of documents
     */
    Page<Document> findByCategory(String category, Pageable pageable);
}
