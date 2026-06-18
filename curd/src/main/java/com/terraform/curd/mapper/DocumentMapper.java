package com.terraform.curd.mapper;

import com.terraform.curd.dto.request.DocumentRequest;
import com.terraform.curd.dto.request.DocumentUpdateRequest;
import com.terraform.curd.dto.response.DocumentResponse;
import com.terraform.curd.entity.Document;
import org.mapstruct.BeanMapping;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingTarget;
import org.mapstruct.NullValuePropertyMappingStrategy;

/**
 * MapStruct mapper between {@link Document} entities and their DTO representations.
 * The component model is {@code spring} (configured via the compiler arg), so the
 * generated implementation is a Spring bean available for constructor injection.
 */
@Mapper
public interface DocumentMapper {

    /**
     * Maps a creation request to a new entity. Identifiers, audit fields and
     * storage metadata are intentionally ignored and managed elsewhere.
     *
     * @param request creation payload
     * @return new (unpersisted) entity
     */
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "fileName", ignore = true)
    @Mapping(target = "s3ObjectKey", ignore = true)
    @Mapping(target = "fileSize", ignore = true)
    @Mapping(target = "contentType", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    @Mapping(target = "updatedAt", ignore = true)
    @Mapping(target = "deleted", ignore = true)
    Document toEntity(DocumentRequest request);

    /**
     * Maps an entity to its read model.
     *
     * @param document persisted entity
     * @return response DTO
     */
    DocumentResponse toResponse(Document document);

    /**
     * Applies editable fields from an update request onto an existing entity.
     * Null values in the request are ignored to support partial-safe updates.
     *
     * @param request  update payload
     * @param document target entity (mutated in place)
     */
    @BeanMapping(nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE)
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "fileName", ignore = true)
    @Mapping(target = "s3ObjectKey", ignore = true)
    @Mapping(target = "fileSize", ignore = true)
    @Mapping(target = "contentType", ignore = true)
    @Mapping(target = "uploadedBy", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    @Mapping(target = "updatedAt", ignore = true)
    @Mapping(target = "deleted", ignore = true)
    void updateEntity(DocumentUpdateRequest request, @MappingTarget Document document);
}
