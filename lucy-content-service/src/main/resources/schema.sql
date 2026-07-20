-- ============================================================
--   LUCY Database Schema
--   MySQL 8.x | Charset: utf8mb4 (hỗ trợ CJK + Emoji)
-- ============================================================

-- Tạo database
CREATE DATABASE IF NOT EXISTS lucy_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE lucy_db;

-- ------------------------------------------------------------
-- 1. languages – Bảng ngôn ngữ
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS languages (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    code        VARCHAR(10)  NOT NULL UNIQUE COMMENT 'en, zh, ja',
    name        VARCHAR(100) NOT NULL COMMENT 'English, Chinese, Japanese',
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- 2. stages – Giai đoạn học (Sơ cấp / Trung cấp / Cao cấp)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS stages (
    id                      INT AUTO_INCREMENT PRIMARY KEY,
    language_id             INT NOT NULL,
    stage_number            TINYINT NOT NULL COMMENT '1=Sơ cấp, 2=Trung cấp, 3=Cao cấp',
    name                    VARCHAR(150) COMMENT 'STAGE 1 – BEGINNER',
    cefr_range              VARCHAR(50)  COMMENT 'A1 → A2',
    level_from              TINYINT NOT NULL,
    level_to                TINYINT NOT NULL,
    duration_per_level_min  INT DEFAULT 60 COMMENT 'Phút mỗi level',
    FOREIGN KEY (language_id) REFERENCES languages(id) ON DELETE CASCADE,
    UNIQUE KEY uq_lang_stage (language_id, stage_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- 3. levels – Level học (1–100)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS levels (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    stage_id        INT NOT NULL,
    level_number    TINYINT NOT NULL COMMENT 'Số level: 1..100',
    title           VARCHAR(255) COMMENT 'Tên chủ đề level: Tự giới thiệu, 自己紹介',
    duration_min    INT DEFAULT 60,
    is_reviewed     BOOLEAN DEFAULT FALSE COMMENT 'True nếu file đã được reviewed',
    FOREIGN KEY (stage_id) REFERENCES stages(id) ON DELETE CASCADE,
    UNIQUE KEY uq_stage_level (stage_id, level_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- 4. sub_levels – Sub-level (6 sub / level)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sub_levels (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    level_id        INT NOT NULL,
    sub_number      TINYINT NOT NULL COMMENT '1..6',
    topic           VARCHAR(255) COMMENT 'Tên chủ đề sub-level',
    duration_min    INT DEFAULT 10,
    phase           VARCHAR(100) COMMENT 'Warm-up / Main Speaking / Wrap-up',
    FOREIGN KEY (level_id) REFERENCES levels(id) ON DELETE CASCADE,
    UNIQUE KEY uq_level_sub (level_id, sub_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- 5. questions – Câu hỏi (Q1, Q2, Q3)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS questions (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    sub_level_id    INT NOT NULL,
    question_order  TINYINT NOT NULL COMMENT '1, 2, 3',
    question_text   TEXT NOT NULL,
    FOREIGN KEY (sub_level_id) REFERENCES sub_levels(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- 6. answers – Câu trả lời mẫu
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS answers (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    question_id     INT NOT NULL,
    answer_order    TINYINT NOT NULL,
    answer_text     TEXT NOT NULL,
    is_sample       BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- 7. import_logs – Log quá trình số hóa file Word
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS import_logs (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    file_name       VARCHAR(255),
    language_code   VARCHAR(10),
    stage_number    TINYINT,
    total_levels    INT DEFAULT 0,
    total_questions INT DEFAULT 0,
    status          ENUM('SUCCESS','FAILED','PARTIAL') DEFAULT 'SUCCESS',
    imported_at     DATETIME DEFAULT CURRENT_TIMESTAMP,
    error_message   TEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- Seed data: 3 ngôn ngữ
-- ------------------------------------------------------------
INSERT IGNORE INTO languages (code, name) VALUES
    ('en', 'English'),
    ('zh', 'Chinese'),
    ('ja', 'Japanese');
