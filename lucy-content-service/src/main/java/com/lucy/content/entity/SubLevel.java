package com.lucy.content.entity;

import jakarta.persistence.*;
import lombok.*;
import java.util.List;

@Entity
@Table(name = "sub_levels",
    uniqueConstraints = @UniqueConstraint(columnNames = {"level_id", "sub_number"}))
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class SubLevel {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "level_id", nullable = false)
    private Level level;

    @Column(name = "sub_number", nullable = false)
    private Integer subNumber;      // 1..6

    @Column(length = 255)
    private String topic;           // Tên chủ đề sub-level

    @Column(name = "duration_min")
    private Integer durationMin = 10;

    @Column(length = 100)
    private String phase;           // "Warm-up", "Main Speaking", "Wrap-up"

    @OneToMany(mappedBy = "subLevel", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @OrderBy("questionOrder ASC")
    private List<Question> questions;
}
