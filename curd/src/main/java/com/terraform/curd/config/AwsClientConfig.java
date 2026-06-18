package com.terraform.curd.config;

import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;

/**
 * Bean configuration for the AWS SDK v2 clients.
 *
 * <p>The {@link S3Client} is only created when {@code app.storage.provider=s3}; in
 * local mode the app stores files on disk and needs no AWS client. Credentials come
 * from {@link DefaultCredentialsProvider} — on Elastic Beanstalk this resolves to the
 * EC2 instance profile, so no static keys are required anywhere.</p>
 */
@Configuration
@RequiredArgsConstructor
@EnableConfigurationProperties(AwsConfig.class)
public class AwsClientConfig {

    private final AwsConfig awsConfig;

    @Bean
    @ConditionalOnProperty(name = "app.storage.provider", havingValue = "s3")
    public S3Client s3Client() {
        return S3Client.builder()
                .region(Region.of(awsConfig.getRegion()))
                .credentialsProvider(DefaultCredentialsProvider.create())
                .build();
    }
}
