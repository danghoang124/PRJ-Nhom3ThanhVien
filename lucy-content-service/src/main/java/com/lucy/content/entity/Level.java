package com.lucy.content.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.*;
import java.util.List;

@Entity
@Table(name = "levels",
    uniqueConstraints = @UniqueConstraint(columnNames = {"stage_id", "level_number"}))
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Level {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @JsonIgnore
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "stage_id", nullable = false)
    private Stage stage;

    @Column(name = "level_number", nullable = false)
    private Integer levelNumber;        // 1..100

    @Column(length = 255)
    private String title;               // Tên chủ đề level

    @Column(name = "duration_min")
    private Integer durationMin = 60;

    @Column(name = "is_reviewed")
    private Boolean isReviewed = false; // True nếu file đã reviewed

    @JsonIgnore
    @OneToMany(mappedBy = "level", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @OrderBy("subNumber ASC")
    private List<SubLevel> subLevels;
}
