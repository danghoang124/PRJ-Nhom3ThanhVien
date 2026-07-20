package com.lucy.content.repository;

import com.lucy.content.entity.Stage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public interface StageRepository extends JpaRepository<Stage, Integer> {
    List<Stage> findByLanguageId(Integer languageId);
    Optional<Stage> findByLanguageIdAndStageNumber(Integer languageId, Integer stageNumber);
}
