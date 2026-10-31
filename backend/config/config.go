package config

import (
	"log"
	"os"
	"strconv"
	"time"

	"github.com/joho/godotenv"
)

type Config struct {
	Port         string
	DBHost       string
	DBPort       string
	DBUser       string
	DBPassword   string
	DBName       string
	JWTSecret    string
	JWTTTLHours  time.Duration
	RefreshTTL   time.Duration
	AllowOrigins string
	// Cloudflare R2 Configuration
	R2AccountID       string
	R2AccessKeyID     string
	R2SecretAccessKey string
	R2BucketName      string
	R2PublicURL       string
}

func LoadConfig() *Config {
	// Load .env file if it exists, ignore error if missing (fallback to env vars)
	if err := godotenv.Load(); err != nil {
		log.Println("Note: .env file not found, loading environment variables from system")
	}

	jwtTTLHours := getEnvAsInt("JWT_EXPIRATION_HOURS", 24)
	refreshTTLDays := getEnvAsInt("REFRESH_EXPIRATION_DAYS", 7)

	return &Config{
		Port:              getEnv("PORT", "8088"),
		DBHost:            getEnv("DB_HOST", "127.0.0.1"),
		DBPort:            getEnv("DB_PORT", "3306"),
		DBUser:            getEnv("DB_USER", "root"),
		DBPassword:        getEnv("DB_PASSWORD", ""),
		DBName:            getEnv("DB_NAME", "chat_go_db"),
		JWTSecret:         getEnv("JWT_SECRET", "super-secret-chat-jwt-key-change-in-production"),
		JWTTTLHours:       time.Duration(jwtTTLHours) * time.Hour,
		RefreshTTL:        time.Duration(refreshTTLDays) * 24 * time.Hour,
		AllowOrigins:      getEnv("ALLOW_ORIGINS", "*"),
		R2AccountID:       getEnv("R2_ACCOUNT_ID", ""),
		R2AccessKeyID:     getEnv("R2_ACCESS_KEY_ID", ""),
		R2SecretAccessKey: getEnv("R2_SECRET_ACCESS_KEY", ""),
		R2BucketName:      getEnv("R2_BUCKET_NAME", ""),
		R2PublicURL:       getEnv("R2_PUBLIC_URL", ""),
	}
}

func getEnv(key, defaultVal string) string {
	if val, exists := os.LookupEnv(key); exists && val != "" {
		return val
	}
	return defaultVal
}

func getEnvAsInt(key string, defaultVal int) int {
	valStr := getEnv(key, "")
	if valStr == "" {
		return defaultVal
	}
	val, err := strconv.Atoi(valStr)
	if err != nil {
		return defaultVal
	}
	return val
}
