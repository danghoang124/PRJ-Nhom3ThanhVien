package com.lucy.content.controller;

import com.lucy.content.dto.ImportResultDTO;
import com.lucy.content.entity.ImportLog;
import com.lucy.content.repository.ImportLogRepository;
import com.lucy.content.service.BulkImportService;
import com.lucy.content.service.WordImportService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/api/import")
@RequiredArgsConstructor
@Tag(name = "Import API", description = "Số hóa file Word (.docx) vào MySQL")
public class ImportController {

    private final WordImportService   wordImportService;
    private final BulkImportService   bulkImportService;
    private final ImportLogRepository importLogRepository;

    /**
     * POST /api/import/word
     * Upload 1 file Word để import thủ công
     */
    @PostMapping("/word")
    @Operation(summary = "Import 1 file Word",
               description = "Upload file .docx, chỉ định ngôn ngữ và stage")
    public ResponseEntity<ImportResultDTO> importWord(
            @Parameter(description = "File .docx cần import")
            @RequestParam("file") MultipartFile file,

            @Parameter(description = "Mã ngôn ngữ: en / zh / ja")
            @RequestParam("langCode") String langCode,

            @Parameter(description = "Số stage: 1, 2 hoặc 3")
            @RequestParam("stageNumber") int stageNumber,

            @Parameter(description = "File đã reviewed chưa?")
            @RequestParam(value = "isReviewed", defaultValue = "false") boolean isReviewed
    ) throws Exception {
        ImportResultDTO result = wordImportService.importFromStream(
            file.getInputStream(),
            file.getOriginalFilename(),
            langCode, stageNumber, isReviewed
        );
        return ResponseEntity.ok(result);
    }

    /**
     * POST /api/import/bulk
     * Import toàn bộ 8 file từ đường dẫn thư mục Language trên server
     */
    @PostMapping("/bulk")
    @Operation(summary = "Import tất cả 8 file Word",
               description = "Chạy bulk import từ đường dẫn thư mục Language trên server")
    public ResponseEntity<List<ImportResultDTO>> bulkImport(
            @Parameter(description = "Đường dẫn tuyệt đối tới thư mục Language")
            @RequestParam(value = "folderPath",
                          defaultValue = "/Users/haidang/Downloads/PRJ/Language")
            String folderPath
    ) {
        List<ImportResultDTO> results = bulkImportService.importAll(folderPath);
        return ResponseEntity.ok(results);
    }

    /**
     * GET /api/import/logs
     * Xem lịch sử import
     */
    @GetMapping("/logs")
    @Operation(summary = "Xem log import", description = "Lấy lịch sử import file Word")
    public ResponseEntity<List<ImportLog>> getLogs() {
        return ResponseEntity.ok(importLogRepository.findAllByOrderByImportedAtDesc());
    }
}
