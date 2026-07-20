package com.lucy.content.service;

import com.lucy.content.dto.ImportResultDTO;
import com.lucy.content.entity.*;
import com.lucy.content.entity.ImportLog.ImportStatus;
import com.lucy.content.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.poi.xwpf.usermodel.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.InputStream;
import java.time.LocalDateTime;
import java.util.*;
import java.util.regex.*;

/**
 * WordImportService
 * -----------------
 * Đọc file .docx (Apache POI) và số hóa vào MySQL theo cấu trúc:
 *   Language → Stage → Level → SubLevel → Question → Answer
 *
 * Pattern nhận dạng trong file:
 *   - Level header : "1.", "2.", "31." ... hoặc "🔹 レベル61"
 *   - Sub-level    : dòng topic (không có Q1/Q2/👉)
 *   - Question     : "Q1:", "Q2:", "Q3:"
 *   - Answer       : bắt đầu bằng "👉" hoặc "→"
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class WordImportService {

    private final LanguageRepository  languageRepo;
    private final StageRepository     stageRepo;
    private final LevelRepository     levelRepo;
    private final SubLevelRepository  subLevelRepo;
    private final ImportLogRepository importLogRepo;

    // -------------------------------------------------------
    // Regex patterns
    // -------------------------------------------------------
    // Chinese/English level: "1.", "31." ở đầu đoạn
    private static final Pattern LEVEL_NUM_PATTERN =
        Pattern.compile("^(\\d{1,3})\\.[\\s　]*(.*)", Pattern.DOTALL);

    // Japanese level: "🔹 レベル61" hoặc "レベル 1"
    private static final Pattern LEVEL_JA_PATTERN =
        Pattern.compile("レベル[\\s　]*(\\d{1,3})[\\s　]*[–\\-]?[\\s　]*(.*)", Pattern.DOTALL);

    // Question: Q1:, Q2:, Q3:, Q１:
    private static final Pattern QUESTION_PATTERN =
        Pattern.compile("^Q[Qq１２３]?\\s*(\\d)\\s*[:：]\\s*(.*)", Pattern.DOTALL);

    // Answer: 👉 hoặc → ở đầu dòng
    private static final Pattern ANSWER_PATTERN =
        Pattern.compile("^[👉→►]\\s*(.*)", Pattern.DOTALL);

    // -------------------------------------------------------
    // Entry point: import từ InputStream
    // -------------------------------------------------------
    @Transactional
    public ImportResultDTO importFromStream(InputStream inputStream,
                                           String fileName,
                                           String languageCode,
                                           int stageNumber,
                                           boolean isReviewed) {
        log.info("▶ Bắt đầu import: {} [lang={}, stage={}]", fileName, languageCode, stageNumber);

        ImportResultDTO result = ImportResultDTO.builder()
            .fileName(fileName)
            .languageCode(languageCode)
            .stageNumber(stageNumber)
            .importedAt(LocalDateTime.now())
            .build();

        try {
            // 1. Lấy hoặc tạo Language
            Language language = languageRepo.findByCode(languageCode)
                .orElseGet(() -> languageRepo.save(
                    Language.builder().code(languageCode)
                        .name(getLanguageName(languageCode)).build()));

            // 2. Lấy hoặc tạo Stage
            Stage stage = stageRepo
                .findByLanguageIdAndStageNumber(language.getId(), stageNumber)
                .orElseGet(() -> {
                    Stage s = buildStage(language, stageNumber);
                    return stageRepo.save(s);
                });

            // 3. Đọc file Word
            XWPFDocument document = new XWPFDocument(inputStream);
            List<String> lines = extractLines(document);
            log.debug("  Tổng dòng đọc được: {}", lines.size());

            // 4. Parse và lưu
            ParseStats stats = parseAndSave(lines, stage, isReviewed, languageCode);

            // 5. Ghi log
            saveImportLog(fileName, languageCode, stageNumber,
                stats.levelCount, stats.questionCount, ImportStatus.SUCCESS, null);

            result.setTotalLevels(stats.levelCount);
            result.setTotalSubLevels(stats.subLevelCount);
            result.setTotalQuestions(stats.questionCount);
            result.setTotalAnswers(stats.answerCount);
            result.setStatus("SUCCESS");
            result.setMessage("Import thành công " + stats.levelCount + " levels");

            log.info("✅ Hoàn thành: {} levels, {} questions, {} answers",
                stats.levelCount, stats.questionCount, stats.answerCount);

        } catch (Exception e) {
            log.error("❌ Lỗi import {}: {}", fileName, e.getMessage(), e);
            saveImportLog(fileName, languageCode, stageNumber, 0, 0,
                ImportStatus.FAILED, e.getMessage());
            result.setStatus("FAILED");
            result.setMessage("Lỗi: " + e.getMessage());
        }

        return result;
    }

    // -------------------------------------------------------
    // Đọc tất cả paragraphs từ DOCX thành List<String>
    // -------------------------------------------------------
    private List<String> extractLines(XWPFDocument document) {
        List<String> lines = new ArrayList<>();
        for (XWPFParagraph para : document.getParagraphs()) {
            String text = para.getText().trim();
            if (!text.isEmpty()) {
                lines.add(text);
            }
        }
        // Đọc thêm từ Tables (một số file Word dùng bảng)
        for (XWPFTable table : document.getTables()) {
            for (XWPFTableRow row : table.getRows()) {
                for (XWPFTableCell cell : row.getTableCells()) {
                    String cellText = cell.getText().trim();
                    if (!cellText.isEmpty()) {
                        lines.add(cellText);
                    }
                }
            }
        }
        return lines;
    }

    // -------------------------------------------------------
    // Parse danh sách dòng và lưu vào DB
    // -------------------------------------------------------
    private ParseStats parseAndSave(List<String> lines, Stage stage,
                                    boolean isReviewed, String langCode) {
        ParseStats stats = new ParseStats();

        Level currentLevel      = null;
        SubLevel currentSubLevel = null;
        Question currentQuestion = null;
        int subNumber = 0;
        int questionOrder = 0;
        int answerOrder = 0;

        for (String line : lines) {

            // --- Nhận dạng Level header ---
            Integer levelNum = extractLevelNumber(line, langCode);
            String  levelTitle = extractLevelTitle(line, langCode);

            if (levelNum != null) {
                // Lưu level mới
                currentLevel = getOrCreateLevel(stage, levelNum, levelTitle, isReviewed);
                stats.levelCount++;
                subNumber = 0;
                currentSubLevel = null;
                currentQuestion = null;
                log.debug("  📖 Level {}: {}", levelNum, levelTitle);
                continue;
            }

            if (currentLevel == null) continue; // Chưa gặp level nào

            // --- Nhận dạng Question ---
            Matcher qMatcher = QUESTION_PATTERN.matcher(line);
            if (qMatcher.find()) {
                questionOrder = Integer.parseInt(qMatcher.group(1));
                String qText  = qMatcher.group(2).trim();

                // Nếu chưa có sub-level, tạo sub-level mới
                if (currentSubLevel == null) {
                    subNumber++;
                    currentSubLevel = createSubLevel(currentLevel, subNumber, "Topic " + subNumber);
                    stats.subLevelCount++;
                }

                currentQuestion = Question.builder()
                    .subLevel(currentSubLevel)
                    .questionOrder(questionOrder)
                    .questionText(qText)
                    .answers(new ArrayList<>())
                    .build();
                // Lưu question qua cascade khi save subLevel (hoặc save trực tiếp)
                currentSubLevel.getQuestions().add(currentQuestion);
                stats.questionCount++;
                answerOrder = 0;
                continue;
            }

            // --- Nhận dạng Answer (👉 hoặc →) ---
            Matcher aMatcher = ANSWER_PATTERN.matcher(line);
            if (aMatcher.find() && currentQuestion != null) {
                String aText = aMatcher.group(1).trim();
                answerOrder++;
                Answer answer = Answer.builder()
                    .question(currentQuestion)
                    .answerOrder(answerOrder)
                    .answerText(aText)
                    .isSample(true)
                    .build();
                currentQuestion.getAnswers().add(answer);
                stats.answerCount++;
                continue;
            }

            // --- Sub-level topic (dòng không khớp Q hay Answer, sau level header) ---
            if (currentQuestion == null && isSubLevelTopic(line)) {
                subNumber++;
                currentSubLevel = createSubLevel(currentLevel, subNumber, line);
                stats.subLevelCount++;
                currentQuestion = null;
                questionOrder = 0;
            }
        }

        // Flush: lưu tất cả levels còn lại
        levelRepo.flush();
        return stats;
    }

    // -------------------------------------------------------
    // Helper: nhận dạng số level
    // -------------------------------------------------------
    private Integer extractLevelNumber(String line, String langCode) {
        // 1. Japanese pattern: starts with optional emoji, then "レベル" and a number
        Pattern pJa = Pattern.compile("^(?:[🔵🔷🔹🔶]\\s*)?レベル[\\s　]*(\\d{1,3})[\\s　]*[–\\-]?[\\s　]*(.*)", Pattern.DOTALL);
        Matcher mJa = pJa.matcher(line);
        if (mJa.find()) return Integer.parseInt(mJa.group(1));

        // 2. English pattern: starts with optional emoji, then "LEVEL" and a number (non-greedy, does not match Sub-level)
        Pattern pEn = Pattern.compile("^(?:[🔵🔷🔹🔶]\\s*)?LEVEL[\\s　]*(\\d{1,3})[\\s　]*[–\\-]?[\\s　]*(.*)", Pattern.CASE_INSENSITIVE | Pattern.DOTALL);
        Matcher mEn = pEn.matcher(line);
        if (mEn.find()) return Integer.parseInt(mEn.group(1));

        // 3. Chinese pattern / standard number: starts with a number and a dot, e.g., "1." or "31."
        Matcher mNum = LEVEL_NUM_PATTERN.matcher(line);
        if (mNum.find()) {
            int num = Integer.parseInt(mNum.group(1));
            if (num >= 1 && num <= 100) return num;
        }
        return null;
    }

    private String extractLevelTitle(String line, String langCode) {
        Pattern pJa = Pattern.compile("^(?:[🔵🔷🔹🔶]\\s*)?レベル[\\s　]*(\\d{1,3})[\\s　]*[–\\-]?[\\s　]*(.*)", Pattern.DOTALL);
        Matcher mJa = pJa.matcher(line);
        if (mJa.find()) return mJa.group(2).trim();

        Pattern pEn = Pattern.compile("^(?:[🔵🔷🔹🔶]\\s*)?LEVEL[\\s　]*(\\d{1,3})[\\s　]*[–\\-]?[\\s　]*(.*)", Pattern.CASE_INSENSITIVE | Pattern.DOTALL);
        Matcher mEn = pEn.matcher(line);
        if (mEn.find()) return mEn.group(2).trim();

        Matcher mNum = LEVEL_NUM_PATTERN.matcher(line);
        if (mNum.find()) return mNum.group(2).trim();

        return line;
    }

    private boolean isSubLevelTopic(String line) {
        // Loại bỏ các dòng ngắn, dòng số, dòng CEFR
        return line.length() > 3
            && !line.matches("^\\d+.*")
            && !line.startsWith("CEFR")
            && !line.startsWith("STAGE")
            && !line.startsWith("Stage")
            && !line.startsWith("📘")
            && !line.startsWith("🎮")
            && !line.startsWith("🔶");
    }

    // -------------------------------------------------------
    // Helper: getOrCreate Level
    // -------------------------------------------------------
    private Level getOrCreateLevel(Stage stage, int levelNum, String title, boolean isReviewed) {
        return levelRepo.findByStageIdAndLevelNumber(stage.getId(), levelNum)
            .map(existingLevel -> {
                existingLevel.setTitle(title);
                existingLevel.setIsReviewed(isReviewed);
                Level res = levelRepo.save(existingLevel);
                subLevelRepo.deleteByLevelId(res.getId());
                if (res.getSubLevels() != null) {
                    res.getSubLevels().clear();
                }
                return res;
            })
            .orElseGet(() -> {
                Level l = Level.builder()
                    .stage(stage)
                    .levelNumber(levelNum)
                    .title(title)
                    .durationMin(stage.getDurationPerLevelMin())
                    .isReviewed(isReviewed)
                    .subLevels(new ArrayList<>())
                    .build();
                return levelRepo.save(l);
            });
    }

    private SubLevel createSubLevel(Level level, int subNum, String topic) {
        SubLevel sl = SubLevel.builder()
            .level(level)
            .subNumber(subNum)
            .topic(topic)
            .durationMin(level.getDurationMin() / 6)
            .questions(new ArrayList<>())
            .build();
        level.getSubLevels().add(sl);
        return subLevelRepo.save(sl);
    }

    // -------------------------------------------------------
    // Helper: Stage builder theo ngôn ngữ & stage
    // -------------------------------------------------------
    private Stage buildStage(Language language, int stageNum) {
        int levelFrom, levelTo, duration;
        String name, cefr;
        switch (stageNum) {
            case 1  -> { levelFrom=1;  levelTo=30;  duration=60;  name="STAGE 1 – BEGINNER";      cefr="A1 → A2";  }
            case 2  -> { levelFrom=31; levelTo=60;  duration=60;  name="STAGE 2 – INTERMEDIATE";   cefr="A2+ → B1"; }
            case 3  -> { levelFrom=61; levelTo=100; duration=120; name="STAGE 3 – UPPER-INTERMEDIATE"; cefr="B1 → B2"; }
            default -> { levelFrom=1;  levelTo=30;  duration=60;  name="STAGE "+stageNum;          cefr=""; }
        }
        return Stage.builder()
            .language(language)
            .stageNumber(stageNum)
            .name(name)
            .cefrRange(cefr)
            .levelFrom(levelFrom)
            .levelTo(levelTo)
            .durationPerLevelMin(duration)
            .levels(new ArrayList<>())
            .build();
    }

    private String getLanguageName(String code) {
        return switch (code) {
            case "en" -> "English";
            case "zh" -> "Chinese";
            case "ja" -> "Japanese";
            default   -> code;
        };
    }

    private void saveImportLog(String fileName, String langCode, int stageNum,
                                int levels, int questions,
                                ImportStatus status, String error) {
        importLogRepo.save(ImportLog.builder()
            .fileName(fileName)
            .languageCode(langCode)
            .stageNumber(stageNum)
            .totalLevels(levels)
            .totalQuestions(questions)
            .status(status)
            .errorMessage(error)
            .build());
    }

    // -------------------------------------------------------
    // Inner class: thống kê parse
    // -------------------------------------------------------
    private static class ParseStats {
        int levelCount    = 0;
        int subLevelCount = 0;
        int questionCount = 0;
        int answerCount   = 0;
    }
}
