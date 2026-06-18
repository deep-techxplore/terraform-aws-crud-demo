package com.terraform.curd.service;

import com.terraform.curd.dto.request.DocumentRequest;
import com.terraform.curd.dto.request.DocumentUpdateRequest;
import com.terraform.curd.dto.response.DocumentResponse;
import com.terraform.curd.dto.response.DownloadedFile;
import com.terraform.curd.dto.response.PageResponse;
import org.springframework.web.multipart.MultipartFile;

import java.util.UUID;

/**
 * Application service defining document management use cases. Controllers depend on
 * this abstraction rather than the concrete implementation (SOLID / DIP).
 */
public interface DocumentService {

    /**
     * Creates document metadata.
     *
     * @param request creation payload
     * @return created document
     */
    DocumentResponse createDocument(DocumentRequest request);

    /**
     * Retrieves a document by id.
     *
     * @param id document id
     * @return found document
     */
    DocumentResponse getDocumentById(UUID id);

    /**
     * Lists documents with pagination, sorting and optional category filtering.
     *
     * @param category      optional category filter (null/blank = no filter)
     * @param page          zero-based page index
     * @param size          page size
     * @param sortBy        sort field
     * @param sortDirection {@code asc} or {@code desc}
     * @return page of documents
     */
    PageResponse<DocumentResponse> getAllDocuments(String category, int page, int size,
                                                   String sortBy, String sortDirection);

    /**
     * Updates editable document metadata.
     *
     * @param id      document id
     * @param request update payload
     * @return updated document
     */
    DocumentResponse updateDocument(UUID id, DocumentUpdateRequest request);

    /**
     * Soft-deletes a document.
     *
     * @param id document id
     */
    void deleteDocument(UUID id);

    /**
     * Uploads a file for a document to S3 and persists its storage metadata.
     *
     * @param id   document id
     * @param file multipart file
     * @return updated document with storage metadata
     */
    DocumentResponse uploadFile(UUID id, MultipartFile file);

    /**
     * Downloads a document's stored file from S3.
     *
     * @param id document id
     * @return downloaded file payload and metadata
     */
    DownloadedFile downloadFile(UUID id);
}
