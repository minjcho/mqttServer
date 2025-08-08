package com.example.websocket.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.servers.Server;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.List;

@Configuration
public class SwaggerConfig {

    @Bean
    public OpenAPI openAPI() {
        return new OpenAPI()
                .info(new Info()
                        .title("MQTT Command API")
                        .description("REST API for sending MQTT commands to IoT devices")
                        .version("1.0.0")
                        .contact(new Contact()
                                .name("API Support")
                                .email("support@example.com")))
                .servers(List.of(
                        new Server().url("http://3.36.126.83:8081").description("AWS server"),
                        new Server().url("http://localhost:8081").description("Local server"),
                        new Server().url("http://i13a205.p.ssafy.io:8081").description("SSAFY server")
                ));
    }
}