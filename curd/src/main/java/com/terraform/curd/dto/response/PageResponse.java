package com.terraform.curd.dto.response;

import org.springframework.data.domain.Page;

import java.util.List;

/**
 * Serialization-friendly pagination wrapper. Avoids leaking Spring Data's
 * {@code Page} implementation details into the API contract.
 *
 * @param content       page items
 * @param pageNumber    current zero-based page index
 * @param pageSize      requested page size
 * @param totalElements total number of matching elements
 * @param totalPages    total number of pages
 * @param last          whether this is the last page
 * @param <T>           element type
 */
public record PageResponse<T>(
        List<T> content,
        int pageNumber,
        int pageSize,
        long totalElements,
        int totalPages,
        boolean last
) {

    /**
     * Adapts a Spring Data {@link Page} into a {@link PageResponse}.
     *
     * @param page source page
     * @param <T>  element type
     * @return mapped page response
     */
    public static <T> PageResponse<T> from(Page<T> page) {
        return new PageResponse<>(
                page.getContent(),
                page.getNumber(),
                page.getSize(),
                page.getTotalElements(),
                page.getTotalPages(),
                page.isLast());
    }
}
