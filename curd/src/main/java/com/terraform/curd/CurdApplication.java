package com.terraform.curd;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

/**
 * Application entry point for the Document Management Service.
 *
 * <p>Enables JPA auditing so that {@code createdAt} / {@code updatedAt} timestamps
 * are populated automatically by the persistence layer.</p>
 */
@EnableJpaAuditing
@SpringBootApplication
public class CurdApplication {

    public static void main(String[] args) {
        SpringApplication.run(CurdApplication.class, args);
    }
}
