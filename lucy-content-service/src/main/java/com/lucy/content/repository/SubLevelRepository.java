package com.lucy.content.repository;

import com.lucy.content.entity.SubLevel;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface SubLevelRepository extends JpaRepository<SubLevel, Integer> {
    List<SubLevel> findByLevelIdOrderBySubNumberAsc(Integer levelId);

    @org.springframework.data.jpa.repository.Modifying
    @org.springframework.data.jpa.repository.Query("DELETE FROM SubLevel s WHERE s.level.id = :levelId")
    void deleteByLevelId(@org.springframework.data.repository.query.Param("levelId") Integer levelId);
}
