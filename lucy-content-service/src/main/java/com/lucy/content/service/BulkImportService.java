package com.lucy.content.service;

import com.lucy.content.dto.ImportResultDTO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.io.File;
import java.io.FileInputStream;
import java.util.*;

/**
 * BulkImportService – Import tự động tất cả 8 file Word trong thư mục /Language
 *
 * Mapping file → (languageCode, stageNumber, isReviewed):
 *   Eng - STAGE 1 (LEVELS 1-30).docx            → en, 1, false
 *   Eng - STAGE 2 (LEVEL 31-60).docx             → en, 2, false
 *   Eng - STAGE 2 (LEVEL 31-60) REVIEWED_SID.docx→ en, 2, true
 *   Chinese - level 1-30.docx                    → zh, 1, false
 *   Chinese - level 31-60.docx                   → zh, 2, false
 *   Janpanes - ステージ1(レベル1-30).docx           → ja, 1, false
 *   Janpanes - ステージ2(レベル31-60).docx          → ja, 2, false
 *   Janpanes  - ステージ3(レベル61-100).docx        → ja, 3, false
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class BulkImportService {

    private final WordImportService wordImportService;

    // Config: tên file → metadata
    private static final List<FileConfig> FILE_CONFIGS = List.of(
        new FileConfig("Eng - STAGE 1 (LEVELS 1-30).docx",                     "en", 1, false),
        new FileConfig("Eng - STAGE 2 (LEVEL 31-60).docx",                     "en", 2, false),
        new FileConfig("Eng - STAGE 2 (LEVEL 31-60) REVIEWED_SID.docx",        "en", 2, true),
        new FileConfig("Chinese - level 1-30.docx",                             "zh", 1, false),
        new FileConfig("Chinese - level 31-60.docx",                            "zh", 2, false),
        new FileConfig("Janpanes - \u30b9\u30c6\u30fc\u30b81(\u30ec\u30d9\u30eb1-30).docx",  "ja", 1, false),
        new FileConfig("Janpanes - \u30b9\u30c6\u30fc\u30b82(\u30ec\u30d9\u30eb31-60).docx", "ja", 2, false),
        new FileConfig("Janpanes  - \u30b9\u30c6\u30fc\u30b83(\u30ec\u30d9\u30eb61-100).docx","ja", 3, false)
    );

    /**
     * Import toàn bộ 8 file từ đường dẫn thư mục Language
     * @param languageFolderPath đường dẫn tuyệt đối tới thư mục /Language
     */
    public List<ImportResultDTO> importAll(String languageFolderPath) {
        List<ImportResultDTO> results = new ArrayList<>();
        log.info("🚀 Bắt đầu bulk import từ: {}", languageFolderPath);

        for (FileConfig cfg : FILE_CONFIGS) {
            File file = new File(languageFolderPath, cfg.fileName);

            if (!file.exists()) {
                log.warn("⚠️  Không tìm thấy file: {}", file.getAbsolutePath());
                results.add(ImportResultDTO.builder()
                    .fileName(cfg.fileName)
                    .languageCode(cfg.langCode)
                    .stageNumber(cfg.stageNumber)
                    .status("SKIPPED")
                    .message("File không tồn tại: " + file.getAbsolutePath())
                    .build());
                continue;
            }

            try (FileInputStream fis = new FileInputStream(file)) {
                log.info("📄 Import file: {}", cfg.fileName);
                ImportResultDTO result = wordImportService.importFromStream(
                    fis, cfg.fileName, cfg.langCode, cfg.stageNumber, cfg.isReviewed);
                results.add(result);
            } catch (Exception e) {
                log.error("❌ Lỗi import {}: {}", cfg.fileName, e.getMessage());
                results.add(ImportResultDTO.builder()
                    .fileName(cfg.fileName)
                    .languageCode(cfg.langCode)
                    .stageNumber(cfg.stageNumber)
                    .status("FAILED")
                    .message("Lỗi: " + e.getMessage())
                    .build());
            }
        }

        long success = results.stream().filter(r -> "SUCCESS".equals(r.getStatus())).count();
        log.info("✅ Bulk import hoàn thành: {}/{} file thành công", success, FILE_CONFIGS.size());
        return results;
    }

    // ── Inner config record ────────────────────────────────────
    private record FileConfig(String fileName, String langCode, int stageNumber, boolean isReviewed) {}
}
