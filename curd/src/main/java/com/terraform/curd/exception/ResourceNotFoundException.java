package com.terraform.curd.exception;

/**
 * Thrown when a requested resource cannot be found. Maps to HTTP 404.
 */
public class ResourceNotFoundException extends RuntimeException {

    public ResourceNotFoundException(String message) {
        super(message);
    }

    /**
     * Convenience factory for the common "entity by id" case.
     *
     * @param resource resource type name (e.g. "Document")
     * @param id       identifier that was not found
     * @return constructed exception
     */
    public static ResourceNotFoundException of(String resource, Object id) {
        return new ResourceNotFoundException(resource + " not found with id: " + id);
    }
}
