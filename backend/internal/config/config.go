package config

import (
	"fmt"
	"log"
	"os"

	"github.com/joho/godotenv"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// Config holds application configuration
type Config struct {
	DatabaseURL string
	DBHost     string
	DBPort     string
	DBUser     string
	DBPassword string
	DBName     string
	DBSSLMode  string
	ServerPort string
	FrontendURL string
}

// LoadConfig reads .env and returns Config
func LoadConfig() *Config {
	// Load .env file if exists (ignore error if not present)
	_ = godotenv.Load()

	return &Config{
		DatabaseURL: getEnv("DATABASE_URL_V2", ""),
		DBHost:      getEnv("DB_HOST", "localhost"),
		DBPort:      getEnv("DB_PORT", "5432"),
		DBUser:      getEnv("DB_USER", "postgres"),
		DBPassword:  getEnv("DB_PASSWORD", "postgres"),
		DBName:      getEnv("DB_NAME", "praisindo_reporting"),
		DBSSLMode:   getEnv("DB_SSLMODE", "disable"),
		ServerPort:  getEnv("SERVER_PORT", "8080"),
		FrontendURL: getEnv("FRONTEND_URL", "http://localhost:5173"),
	}
}

// ConnectDB establishes database connection
func ConnectDB(cfg *Config) (*gorm.DB, error) {
	var dsn string
	if cfg.DatabaseURL != "" {
		dsn = cfg.DatabaseURL
	} else {
		dsn = fmt.Sprintf(
			"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
			cfg.DBHost, cfg.DBPort, cfg.DBUser, cfg.DBPassword, cfg.DBName, cfg.DBSSLMode,
		)
	}

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to connect to database: %w", err)
	}

	log.Println("✅ Database connected successfully")
	return db, nil
}

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}
