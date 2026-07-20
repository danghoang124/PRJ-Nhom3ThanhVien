package com.lucy.content.repository;

import com.lucy.content.entity.Level;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public interface LevelRepository extends JpaRepository<Level, Integer> {

    List<Level> findByStageIdOrderByLevelNumberAsc(Integer stageId);

    Optional<Level> findByStageIdAndLevelNumber(Integer stageId, Integer levelNumber);

    // Lấy tất cả levels của một ngôn ngữ (qua stage)
    @Query("SELECT l FROM Level l " +
           "JOIN l.stage s " +
           "JOIN s.language lang " +
           "WHERE lang.code = :langCode " +
           "ORDER BY s.stageNumber ASC, l.levelNumber ASC")
    List<Level> findAllByLanguageCode(@Param("langCode") String langCode);

    // Đếm tổng số levels đã import theo ngôn ngữ
    @Query("SELECT COUNT(l) FROM Level l " +
           "JOIN l.stage s " +
           "JOIN s.language lang " +
           "WHERE lang.code = :langCode")
    long countByLanguageCode(@Param("langCode") String langCode);
}
