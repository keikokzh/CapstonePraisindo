package main

import (
	"flag"
	"github.com/capstonePraisindo/reporting-service/internal/config"
	"github.com/capstonePraisindo/reporting-service/internal/migration"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
	"log"
	"os"
)

func main() {
	apply := flag.Bool("apply", false, "Explicitly install pending V2 SQL on urs2026_v2")
	sample := flag.Bool("include-sample-data", false, "Include upstream 13_sample_data.sql once")
	flag.Parse()
	if !*apply {
		log.Fatal("No changes made. Read docs/DATABASE_V2.md and use --apply for an intentional install.")
	}
	_ = config.LoadConfig()
	url := os.Getenv("DATABASE_URL_V2")
	if url == "" {
		log.Fatal("DATABASE_URL_V2 is required; no fallback database is allowed.")
	}
	db, err := gorm.Open(postgres.Open(url), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent)})
	if err != nil {
		log.Fatal("Cannot connect to target database; check local DATABASE_URL_V2 (credentials suppressed).")
	}
	if err := migration.Apply(db, *sample); err != nil {
		log.Fatalf("V2 install stopped: %v", err)
	}
	log.Println("V2 pending files applied, or already recorded. No legacy seed was run.")
}
