package com.terraform.curd.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.License;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * OpenAPI 3 / Swagger UI configuration.
 *
 * <p>A {@code bearerAuth} security scheme is declared (but not enforced) so that JWT
 * authentication can be switched on later without changing the documentation wiring.
 * Swagger UI is served at {@code /swagger-ui.html} and the spec at {@code /v3/api-docs}.</p>
 */
@Configuration
public class OpenApiConfig {

    private static final String SECURITY_SCHEME_NAME = "bearerAuth";

    @Bean
    public OpenAPI documentManagementOpenApi() {
        return new OpenAPI()
                .info(new Info()
                        .title("Document Management Service API")
                        .description("Production-grade document management with S3-backed storage.")
                        .version("v1")
                        .contact(new Contact().name("Platform Team").email("platform@terraform.com"))
                        .license(new License().name("Apache 2.0")))
                .components(new Components()
                        .addSecuritySchemes(SECURITY_SCHEME_NAME, new SecurityScheme()
                                .name(SECURITY_SCHEME_NAME)
                                .type(SecurityScheme.Type.HTTP)
                                .scheme("bearer")
                                .bearerFormat("JWT")));
    }
}
