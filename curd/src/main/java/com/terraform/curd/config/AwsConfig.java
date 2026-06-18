package com.terraform.curd.config;

import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * AWS settings bound from {@code app.aws.*}. Only the region is configured —
 * credentials are intentionally absent. The deployed app authenticates via the
 * EC2 instance profile (the AWS SDK's default credential chain), so no access
 * keys are ever stored in config or source control.
 */
@Getter
@Setter
@Validated
@ConfigurationProperties(prefix = "app.aws")
public class AwsConfig {

    /** AWS region, e.g. {@code ap-south-1} (from {@code AWS_REGION}). */
    @NotBlank
    private String region;
}
