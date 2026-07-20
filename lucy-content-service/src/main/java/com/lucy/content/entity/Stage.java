package com.lucy.content.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.*;
import java.util.List;

@Entity
@Table(name = "stages",
    uniqueConstraints = @UniqueConstraint(columnNames = {"language_id", "stage_number"}))
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Stage {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @JsonIgnore
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "language_id", nullable = false)
    private Language language;

    @Column(name = "stage_number", nullable = false)
    private Integer stageNumber;        // 1, 2, 3

    @Column(length = 150)
    private String name;                // "STAGE 1 – BEGINNER"

    @Column(name = "cefr_range", length = 50)
    private String cefrRange;           // "A1 → A2"

    @Column(name = "level_from", nullable = false)
    private Integer levelFrom;          // 1

    @Column(name = "level_to", nullable = false)
    private Integer levelTo;            // 30

    @Column(name = "duration_per_level_min")
    private Integer durationPerLevelMin = 60;

    @JsonIgnore
    @OneToMany(mappedBy = "stage", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @OrderBy("levelNumber ASC")
    private List<Level> levels;
}
