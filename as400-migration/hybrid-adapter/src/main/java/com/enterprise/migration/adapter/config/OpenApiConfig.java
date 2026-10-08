package com.enterprise.migration.adapter.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.License;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI customOpenAPI() {
        return new OpenAPI()
                .addServersItem(new io.swagger.v3.oas.models.servers.Server().url("/").description("Current Server URL"))
                .info(new Info()
                        .title("AS/400 Hybrid Adapter API")
                        .version("1.0.0")
                        .description("REST API wrapper for IBM i / AS400 DB2 and RPG Programs (GETINV01) using JT400")
                        .contact(new Contact()
                                .name("Enterprise Modernization Team")
                                .email("modernization@enterprise.internal"))
                        .license(new License()
                                .name("Apache 2.0")
                                .url("https://springdoc.org")));
    }
}

