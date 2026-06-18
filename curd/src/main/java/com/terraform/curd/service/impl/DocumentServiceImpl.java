package com.terraform.curd.service.impl;

import com.terraform.curd.dto.request.DocumentRequest;
import com.terraform.curd.dto.request.DocumentUpdateRequest;
import com.terraform.curd.dto.response.DocumentResponse;
import com.terraform.curd.dto.response.DownloadedFile;
import com.terraform.curd.dto.response.PageResponse;
import com.terraform.curd.entity.Document;
import com.terraform.curd.exception.FileUploadException;
import com.terraform.curd.exception.ResourceNotFoundException;
import com.terraform.curd.exception.ValidationException;
import com.terraform.curd.mapper.DocumentMapper;
import com.terraform.curd.repository.DocumentRepository;
import com.terraform.curd.service.DocumentService;
import com.terraform.curd.service.FileStorageService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import java.util.UUID;

/**
 * Default {@link DocumentService} implementation. Orchestrates persistence, mapping
 * and S3 storage while keeping the controller layer thin.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class DocumentServiceImpl implements DocumentService {

    private final DocumentRepository documentRepository;
    private final DocumentMapper documentMapper;
    // Backend is chosen via app.storage.provider (local disk vs S3).
    private final FileStorageService fileStorageService;

    @Override
    @Transactional
    public DocumentResponse createDocument(DocumentRequest request) {
        Document document = documentMapper.toEntity(request);
        Document saved = documentRepository.save(document);
        log.info("Created document with id {}", saved.getId());
        return documentMapper.toResponse(saved);
    }

    @Override
    @Transactional(readOnly = true)
    public DocumentResponse getDocumentById(UUID id) {
        return documentMapper.toResponse(findActiveDocument(id));
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<DocumentResponse> getAllDocuments(String category, int page, int size,
                                                          String sortBy, String sortDirection) {
        Sort.Direction direction = "asc".equalsIgnoreCase(sortDirection)
                ? Sort.Direction.ASC
                : Sort.Direction.DESC;
        Pageable pageable = PageRequest.of(page, size, Sort.by(direction, sortBy));

        Page<Document> documents = StringUtils.hasText(category)
                ? documentRepository.findByCategory(category, pageable)
                : documentRepository.findAll(pageable);

        return PageResponse.from(documents.map(documentMapper::toResponse));
    }

    @Override
    @Transactional
    public DocumentResponse updateDocument(UUID id, DocumentUpdateRequest request) {
        Document document = findActiveDocument(id);
        documentMapper.updateEntity(request, document);
        Document saved = documentRepository.save(document);
        log.info("Updated document with id {}", saved.getId());
        return documentMapper.toResponse(saved);
    }

    @Override
    @Transactional
    public void deleteDocument(UUID id) {
        Document document = findActiveDocument(id);
        // @SQLDelete translates this into a soft delete (is_deleted = true).
        documentRepository.delete(document);
        log.info("Soft-deleted document with id {}", id);
    }

    @Override
    @Transactional
    public DocumentResponse uploadFile(UUID id, MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new FileUploadException("Uploaded file is empty");
        }
        Document document = findActiveDocument(id);

        String objectKey = fileStorageService.uploadFile(file, id.toString());
        document.setS3ObjectKey(objectKey);
        document.setFileName(file.getOriginalFilename());
        document.setContentType(file.getContentType());
        document.setFileSize(file.getSize());

        Document saved = documentRepository.save(document);
        log.info("Stored file metadata for document {} (key={})", id, objectKey);
        return documentMapper.toResponse(saved);
    }

    @Override
    @Transactional(readOnly = true)
    public DownloadedFile downloadFile(UUID id) {
        Document document = findActiveDocument(id);
        if (!StringUtils.hasText(document.getS3ObjectKey())) {
            throw new ValidationException("No file has been uploaded for document: " + id);
        }

        byte[] content = fileStorageService.downloadFile(document.getS3ObjectKey());
        String contentType = StringUtils.hasText(document.getContentType())
                ? document.getContentType()
                : "application/octet-stream";
        String fileName = StringUtils.hasText(document.getFileName())
                ? document.getFileName()
                : "download";

        return new DownloadedFile(content, fileName, contentType, content.length);
    }

    /**
     * Loads an active (non-soft-deleted) document or throws {@link ResourceNotFoundException}.
     *
     * @param id document id
     * @return active document entity
     */
    private Document findActiveDocument(UUID id) {
        return documentRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Document", id));
    }
}
