package com.lucy.content.dto;

import lombok.*;
import java.time.LocalDateTime;

/** DTO trả về kết quả import file Word */
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class ImportResultDTO {
    private String  fileName;
    private String  languageCode;
    private Integer stageNumber;
    private Integer totalLevels;
    private Integer totalSubLevels;
    private Integer totalQuestions;
    private Integer totalAnswers;
    private String  status;         // SUCCESS / FAILED / PARTIAL
    private String  message;
    private LocalDateTime importedAt;
}
