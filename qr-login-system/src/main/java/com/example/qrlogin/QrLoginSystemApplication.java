package com.example.qrlogin;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

@SpringBootApplication
@EnableJpaAuditing
public class QrLoginSystemApplication {

    public static void main(String[] args) {
        SpringApplication.run(QrLoginSystemApplication.class, args);
    }

}