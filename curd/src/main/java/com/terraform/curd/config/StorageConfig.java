package com.terraform.curd.config;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/**
 * Enables binding of {@link StorageProperties} so the {@code app.storage.*} namespace is
 * available for injection. The active storage implementation is selected at runtime via
 * {@code @ConditionalOnProperty(name = "app.storage.provider", ...)}.
 */
@Configuration
@EnableConfigurationProperties(StorageProperties.class)
public class StorageConfig {
}
