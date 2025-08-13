package com.example.qrlogin.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.License;
import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.security.SecurityScheme;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.servers.Server;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.List;

@Configuration
public class SwaggerConfig {

    @Bean
    public OpenAPI customOpenAPI() {
        return new OpenAPI()
            .info(new Info()
                .title("QR Login System API")
                .description("QR 기반 로그인 시스템 REST API 문서")
                .version("v1.0.0")
                .contact(new Contact()
                    .name("QR Login System")
                    .email("admin@example.com"))
                .license(new License()
                    .name("MIT License")
                    .url("https://opensource.org/licenses/MIT")))
            .servers(List.of(
                new Server().url("https://minjcho.site").description("AWS HTTPS 서버"),
                new Server().url("http://3.36.126.83:8090").description("AWS HTTP 서버"),
                new Server().url("http://localhost:8090").description("로컬 개발 서버")
            ))
            .components(new Components()
                .addSecuritySchemes("bearerAuth", new SecurityScheme()
                    .type(SecurityScheme.Type.HTTP)
                    .scheme("bearer")
                    .bearerFormat("JWT")
                    .description("JWT 토큰을 헤더에 포함하여 인증")))
            .addSecurityItem(new SecurityRequirement().addList("bearerAuth"));
    }
}