package com.lucy.content.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "import_logs")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class ImportLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "file_name", length = 255)
    private String fileName;

    @Column(name = "language_code", length = 10)
    private String languageCode;

    @Column(name = "stage_number")
    private Integer stageNumber;

    @Column(name = "total_levels")
    private Integer totalLevels = 0;

    @Column(name = "total_questions")
    private Integer totalQuestions = 0;

    @Enumerated(EnumType.STRING)
    private ImportStatus status = ImportStatus.SUCCESS;

    @Column(name = "imported_at")
    private LocalDateTime importedAt;

    @Column(name = "error_message", columnDefinition = "TEXT")
    private String errorMessage;

    @PrePersist
    protected void onCreate() {
        this.importedAt = LocalDateTime.now();
    }

    public enum ImportStatus {
        SUCCESS, FAILED, PARTIAL
    }
}
