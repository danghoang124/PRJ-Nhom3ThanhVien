package com.lucy.content.controller;

import com.lucy.content.dto.LevelContentDTO;
import com.lucy.content.entity.Language;
import com.lucy.content.entity.Level;
import com.lucy.content.service.ContentService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
@Tag(name = "Content API", description = "Lấy nội dung học ngôn ngữ theo level")
public class ContentController {

    private final ContentService contentService;

    /**
     * GET /api/languages
     */
    @GetMapping("/languages")
    @Operation(summary = "Danh sách ngôn ngữ",
               description = "Trả về 3 ngôn ngữ: English, Chinese, Japanese")
    public ResponseEntity<List<Language>> getLanguages() {
        return ResponseEntity.ok(contentService.getAllLanguages());
    }

    /**
     * GET /api/languages/{code}/levels
     * Ví dụ: GET /api/languages/ja/levels
     */
    @GetMapping("/languages/{code}/levels")
    @Operation(summary = "Danh sách level theo ngôn ngữ",
               description = "Lấy toàn bộ levels của một ngôn ngữ (en / zh / ja)")
    public ResponseEntity<List<Level>> getLevelsByLanguage(
            @Parameter(description = "Mã ngôn ngữ: en, zh, ja")
            @PathVariable String code) {
        return ResponseEntity.ok(contentService.getLevelsByLanguage(code));
    }

    /**
     * GET /api/levels/{levelId}
     * Trả về nội dung đầy đủ 1 level: SubLevel → Question → Answer
     */
    @GetMapping("/levels/{levelId}")
    @Operation(summary = "Nội dung 1 Level",
               description = "Trả về toàn bộ sub-levels, câu hỏi và câu trả lời mẫu của 1 level")
    public ResponseEntity<LevelContentDTO> getLevelContent(
            @Parameter(description = "ID của level trong database")
            @PathVariable Integer levelId) {
        return ResponseEntity.ok(contentService.getLevelContent(levelId));
    }

    /**
     * GET /api/stats
     * Thống kê tổng quan dữ liệu đã import
     */
    @GetMapping("/stats")
    @Operation(summary = "Thống kê dữ liệu",
               description = "Số lượng ngôn ngữ, stage, level đã số hóa vào DB")
    public ResponseEntity<Map<String, Object>> getStats() {
        return ResponseEntity.ok(contentService.getStats());
    }
}
