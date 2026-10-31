package database

import (
	"database/sql"
	"fmt"
	"log"
	"time"

	"chat_go/backend/config"
	"chat_go/backend/models"

	_ "github.com/go-sql-driver/mysql"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var DB *gorm.DB

// EnsureDatabaseExists checks if MySQL database exists, and creates it if not.
func EnsureDatabaseExists(cfg *config.Config) error {
	dsnWithoutDB := fmt.Sprintf("%s:%s@tcp(%s:%s)/?charset=utf8mb4&parseTime=True&loc=Local",
		cfg.DBUser, cfg.DBPassword, cfg.DBHost, cfg.DBPort)

	db, err := sql.Open("mysql", dsnWithoutDB)
	if err != nil {
		return fmt.Errorf("failed to connect to MySQL server: %w", err)
	}
	defer db.Close()

	query := fmt.Sprintf("CREATE DATABASE IF NOT EXISTS `%s` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;", cfg.DBName)
	if _, err := db.Exec(query); err != nil {
		return fmt.Errorf("failed to create database %s: %w", cfg.DBName, err)
	}

	return nil
}

// ConnectDatabase initializes GORM MySQL connection with pooling and schema migration
func ConnectDatabase(cfg *config.Config) (*gorm.DB, error) {
	if err := EnsureDatabaseExists(cfg); err != nil {
		log.Printf("Warning during EnsureDatabaseExists: %v (will try connecting directly)", err)
	}

	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?charset=utf8mb4&parseTime=True&loc=Local",
		cfg.DBUser, cfg.DBPassword, cfg.DBHost, cfg.DBPort, cfg.DBName)

	gormConfig := &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	}

	db, err := gorm.Open(mysql.Open(dsn), gormConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to database: %w", err)
	}

	sqlDB, err := db.DB()
	if err != nil {
		return nil, fmt.Errorf("failed to obtain underlying sql.DB: %w", err)
	}

	// Connection pool configuration for high concurrency (ideal for real-time chat)
	sqlDB.SetMaxIdleConns(10)
	sqlDB.SetMaxOpenConns(100)
	sqlDB.SetConnMaxLifetime(time.Hour)

	// Auto-migrate tables
	if err := db.AutoMigrate(&models.User{}, &models.Message{}, &models.MessageAttachment{}, &models.Group{}, &models.GroupMember{}); err != nil {
		return nil, fmt.Errorf("failed to auto-migrate database schema: %w", err)
	}

	DB = db
	log.Println("Database connection established and schema migrated successfully.")
	return db, nil
}
