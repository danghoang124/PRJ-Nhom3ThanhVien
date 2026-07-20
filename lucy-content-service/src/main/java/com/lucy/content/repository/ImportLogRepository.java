package com.lucy.content.repository;

import com.lucy.content.entity.ImportLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface ImportLogRepository extends JpaRepository<ImportLog, Integer> {
    List<ImportLog> findAllByOrderByImportedAtDesc();
    List<ImportLog> findByLanguageCode(String languageCode);
}
