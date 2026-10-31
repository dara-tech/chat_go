-- Schema for Chat App User Authentication
CREATE DATABASE IF NOT EXISTS `chat_go_db` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `chat_go_db`;

CREATE TABLE IF NOT EXISTS `users` (
    `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `uuid` VARCHAR(36) NOT NULL UNIQUE,
    `username` VARCHAR(50) NOT NULL UNIQUE,
    `email` VARCHAR(100) NOT NULL UNIQUE,
    `password_hash` VARCHAR(255) NOT NULL,
    `display_name` VARCHAR(100) NULL,
    `avatar_url` VARCHAR(255) NULL,
    `is_online` BOOLEAN DEFAULT FALSE,
    `last_seen_at` DATETIME(3) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    `deleted_at` DATETIME(3) NULL,
    INDEX `idx_users_uuid` (`uuid`),
    INDEX `idx_users_username` (`username`),
    INDEX `idx_users_email` (`email`),
    INDEX `idx_users_deleted_at` (`deleted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
