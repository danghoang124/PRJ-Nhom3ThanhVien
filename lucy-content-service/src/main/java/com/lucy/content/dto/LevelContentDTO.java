package com.lucy.content.dto;

import lombok.*;
import java.util.List;

/** DTO trả về nội dung đầy đủ 1 Level cho Node.js */
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class LevelContentDTO {
    private Integer levelId;
    private Integer levelNumber;
    private String  title;
    private Integer durationMin;
    private String  languageCode;
    private Integer stageNumber;
    private String  cefrRange;
    private List<SubLevelDTO> subLevels;

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
    public static class SubLevelDTO {
        private Integer subId;
        private Integer subNumber;
        private String  topic;
        private Integer durationMin;
        private String  phase;
        private List<QuestionDTO> questions;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
    public static class QuestionDTO {
        private Integer questionId;
        private Integer order;
        private String  questionText;
        private List<AnswerDTO> answers;
    }

    @Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
    public static class AnswerDTO {
        private Integer answerId;
        private Integer order;
        private String  answerText;
    }
}
