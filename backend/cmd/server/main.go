package main

import (
	"log"

	"github.com/capstonePraisindo/reporting-service/internal/config"
	"github.com/capstonePraisindo/reporting-service/internal/handlers"
	"github.com/capstonePraisindo/reporting-service/internal/repository"
	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

func main() {
	// Load config
	cfg := config.LoadConfig()

	// Connect to database
	db, err := config.ConnectDB(cfg)
	if err != nil {
		log.Fatalf("❌ Database connection failed: %v", err)
	}

	log.Println("Skipping auto-migration on startup. Use migrate command explicitly.")

	// Initialize layers
	repo := repository.NewSubscriptionRepository(db)
	handler := handlers.NewReportHandler(repo)

	// Setup Gin router
	r := gin.Default()

	// CORS for frontend dev server
	r.Use(cors.New(cors.Config{
		AllowOrigins:     []string{cfg.FrontendURL, "http://localhost:5173", "http://localhost:3000"},
		AllowMethods:     []string{"GET", "POST", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		ExposeHeaders:    []string{"Content-Disposition"},
		AllowCredentials: true,
	}))

	// Health check
	r.GET("/api/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "praisindo-reporting"})
	})

	// API v1 routes
	v1 := r.Group("/api/v1")
	{
		// Report endpoints
		v1.GET("/reports/subscription-by-product", handler.GetSubscriptionReport)
		v1.GET("/reports/subscription-by-product/export", handler.ExportSubscriptionReport)

		// Filter dropdown data
		v1.GET("/funds", handler.GetFunds)
		v1.GET("/channels", handler.GetChannels)
	}

	// Start server
	addr := ":" + cfg.ServerPort
	log.Printf("🚀 Server starting on %s", addr)
	if err := r.Run(addr); err != nil {
		log.Fatalf("❌ Server failed: %v", err)
	}
}
