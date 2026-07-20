package com.lucy.content.entity;

import jakarta.persistence.*;
import lombok.*;
import java.util.List;

@Entity
@Table(name = "questions")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Question {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "sub_level_id", nullable = false)
    private SubLevel subLevel;

    @Column(name = "question_order", nullable = false)
    private Integer questionOrder;      // 1, 2, 3

    @Column(name = "question_text", columnDefinition = "TEXT", nullable = false)
    private String questionText;

    @OneToMany(mappedBy = "question", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @OrderBy("answerOrder ASC")
    private List<Answer> answers;
}
