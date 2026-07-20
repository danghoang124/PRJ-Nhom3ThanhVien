package com.lucy.content;

import com.lucy.content.service.BulkImportService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Profile;

@Slf4j
@SpringBootApplication
@RequiredArgsConstructor
public class LucyContentApplication {

    public static void main(String[] args) {
        SpringApplication.run(LucyContentApplication.class, args);
        log.info("");
        log.info("╔═══════════════════════════════════════════╗");
        log.info("║   LUCY Content Service đã khởi động!      ║");
        log.info("║   Swagger UI: http://localhost:8085        ║");
        log.info("║            /swagger-ui.html                ║");
        log.info("╚═══════════════════════════════════════════╝");
    }

    /**
     * Auto import khi chạy với profile "import"
     * Dùng: mvn spring-boot:run -Dspring-boot.run.profiles=import
     */
    @Bean
    @Profile("import")
    public CommandLineRunner autoImport(BulkImportService bulkImportService) {
        return args -> {
            String langFolder = System.getProperty("lucy.language.folder",
                "/Users/haidang/Downloads/PRJ/Language");
            log.info("🚀 [import profile] Bắt đầu auto bulk import từ: {}", langFolder);
            var results = bulkImportService.importAll(langFolder);
            results.forEach(r -> log.info("  {} → {} ({})", r.getFileName(), r.getStatus(), r.getMessage()));
        };
    }
}
