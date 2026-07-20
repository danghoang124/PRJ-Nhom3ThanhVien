package com.lucy.content.service;

import com.lucy.content.dto.LevelContentDTO;
import com.lucy.content.entity.*;
import com.lucy.content.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

/**
 * ContentService – Cung cấp dữ liệu nội dung cho REST API
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ContentService {

    private final LanguageRepository  languageRepo;
    private final StageRepository     stageRepo;
    private final LevelRepository     levelRepo;
    private final SubLevelRepository  subLevelRepo;

    // ── Lấy tất cả ngôn ngữ ──────────────────────────────────
    public List<Language> getAllLanguages() {
        return languageRepo.findAll();
    }

    // ── Lấy tất cả levels theo ngôn ngữ ─────────────────────
    public List<Level> getLevelsByLanguage(String langCode) {
        return levelRepo.findAllByLanguageCode(langCode);
    }

    // ── Lấy chi tiết 1 level (full nested) ───────────────────
    public LevelContentDTO getLevelContent(Integer levelId) {
        Level level = levelRepo.findById(levelId)
            .orElseThrow(() -> new RuntimeException("Level không tồn tại: " + levelId));

        Stage    stage    = level.getStage();
        Language language = stage.getLanguage();
        List<SubLevel> subLevels = subLevelRepo.findByLevelIdOrderBySubNumberAsc(levelId);

        List<LevelContentDTO.SubLevelDTO> subDTOs = subLevels.stream()
            .map(sl -> LevelContentDTO.SubLevelDTO.builder()
                .subId(sl.getId())
                .subNumber(sl.getSubNumber())
                .topic(sl.getTopic())
                .durationMin(sl.getDurationMin())
                .phase(sl.getPhase())
                .questions(sl.getQuestions() == null ? List.of() :
                    sl.getQuestions().stream()
                        .map(q -> LevelContentDTO.QuestionDTO.builder()
                            .questionId(q.getId())
                            .order(q.getQuestionOrder())
                            .questionText(q.getQuestionText())
                            .answers(q.getAnswers() == null ? List.of() :
                                q.getAnswers().stream()
                                    .map(a -> LevelContentDTO.AnswerDTO.builder()
                                        .answerId(a.getId())
                                        .order(a.getAnswerOrder())
                                        .answerText(a.getAnswerText())
                                        .build())
                                    .collect(Collectors.toList()))
                            .build())
                        .collect(Collectors.toList()))
                .build())
            .collect(Collectors.toList());

        return LevelContentDTO.builder()
            .levelId(level.getId())
            .levelNumber(level.getLevelNumber())
            .title(level.getTitle())
            .durationMin(level.getDurationMin())
            .languageCode(language.getCode())
            .stageNumber(stage.getStageNumber())
            .cefrRange(stage.getCefrRange())
            .subLevels(subDTOs)
            .build();
    }

    // ── Thống kê tổng quan ────────────────────────────────────
    public java.util.Map<String, Object> getStats() {
        long totalLevels    = levelRepo.count();
        long totalLanguages = languageRepo.count();
        long totalStages    = stageRepo.count();

        return java.util.Map.of(
            "totalLanguages", totalLanguages,
            "totalStages",    totalStages,
            "totalLevels",    totalLevels,
            "levelsByLanguage", java.util.Map.of(
                "en", levelRepo.countByLanguageCode("en"),
                "zh", levelRepo.countByLanguageCode("zh"),
                "ja", levelRepo.countByLanguageCode("ja")
            )
        );
    }
}
