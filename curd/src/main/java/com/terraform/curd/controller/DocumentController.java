package com.terraform.curd.controller;

import com.terraform.curd.dto.request.DocumentRequest;
import com.terraform.curd.dto.request.DocumentUpdateRequest;
import com.terraform.curd.dto.response.ApiResponse;
import com.terraform.curd.dto.response.DocumentResponse;
import com.terraform.curd.dto.response.DownloadedFile;
import com.terraform.curd.dto.response.PageResponse;
import com.terraform.curd.service.DocumentService;
import com.terraform.curd.util.AppConstants;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.UUID;

/**
 * REST API for document management. All responses are wrapped in the standard
 * {@link ApiResponse} envelope. Endpoints are currently public; the structure
 * supports adding JWT-based security later without contract changes.
 */
@RestController
@RequestMapping("/api/v1/documents")
@RequiredArgsConstructor
@Tag(name = "Documents", description = "Document metadata and S3 file operations")
public class DocumentController {

    private final DocumentService documentService;

    /**
     * Creates document metadata.
     */
    @PostMapping
    @Operation(summary = "Create document metadata")
    public ResponseEntity<ApiResponse<DocumentResponse>> createDocument(
            @Valid @RequestBody DocumentRequest request) {
        DocumentResponse created = documentService.createDocument(request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success("Document created successfully", created));
    }

    /**
     * Retrieves a document by id.
     */
    @GetMapping("/{id}")
    @Operation(summary = "Get document by id")
    public ResponseEntity<ApiResponse<DocumentResponse>> getDocumentById(@PathVariable UUID id) {
        DocumentResponse document = documentService.getDocumentById(id);
        return ResponseEntity.ok(ApiResponse.success(AppConstants.DEFAULT_SUCCESS_MESSAGE, document));
    }

    /**
     * Lists documents with pagination, sorting and optional category filter.
     */
    @GetMapping
    @Operation(summary = "Get all documents (paginated, sortable, filterable by category)")
    public ResponseEntity<ApiResponse<PageResponse<DocumentResponse>>> getAllDocuments(
            @RequestParam(required = false) String category,
            @RequestParam(defaultValue = AppConstants.DEFAULT_PAGE_NUMBER) int page,
            @RequestParam(defaultValue = AppConstants.DEFAULT_PAGE_SIZE) int size,
            @RequestParam(defaultValue = AppConstants.DEFAULT_SORT_BY) String sortBy,
            @RequestParam(defaultValue = AppConstants.DEFAULT_SORT_DIRECTION) String sortDir) {
        PageResponse<DocumentResponse> documents =
                documentService.getAllDocuments(category, page, size, sortBy, sortDir);
        return ResponseEntity.ok(ApiResponse.success(AppConstants.DEFAULT_SUCCESS_MESSAGE, documents));
    }

    /**
     * Updates editable document metadata.
     */
    @PutMapping("/{id}")
    @Operation(summary = "Update document metadata")
    public ResponseEntity<ApiResponse<DocumentResponse>> updateDocument(
            @PathVariable UUID id,
            @Valid @RequestBody DocumentUpdateRequest request) {
        DocumentResponse updated = documentService.updateDocument(id, request);
        return ResponseEntity.ok(ApiResponse.success("Document updated successfully", updated));
    }

    /**
     * Soft-deletes a document.
     */
    @DeleteMapping("/{id}")
    @Operation(summary = "Soft-delete a document")
    public ResponseEntity<ApiResponse<Object>> deleteDocument(@PathVariable UUID id) {
        documentService.deleteDocument(id);
        return ResponseEntity.ok(ApiResponse.success("Document deleted successfully", null));
    }

    /**
     * Uploads a file to S3 and stores its metadata against the document.
     */
    @PostMapping(value = "/{id}/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Upload a file to S3 for a document")
    public ResponseEntity<ApiResponse<DocumentResponse>> uploadFile(
            @PathVariable UUID id,
            @RequestPart("file") MultipartFile file) {
        DocumentResponse updated = documentService.uploadFile(id, file);
        return ResponseEntity.ok(ApiResponse.success("File uploaded successfully", updated));
    }

    /**
     * Downloads a document's stored file from S3 as a stream with proper headers.
     */
    @GetMapping("/{id}/download")
    @Operation(summary = "Download a document's file from S3")
    public ResponseEntity<Resource> downloadFile(@PathVariable UUID id) {
        DownloadedFile file = documentService.downloadFile(id);
        Resource resource = new ByteArrayResource(file.content());

        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        "attachment; filename=\"" + file.fileName() + "\"")
                .contentType(MediaType.parseMediaType(file.contentType()))
                .contentLength(file.fileSize())
                .body(resource);
    }
}
