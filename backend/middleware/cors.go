package middleware

import (
	"time"
	"chat_go/backend/config"
	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

// SetupCORS configures CORS policies suitable for web and mobile chat clients
func SetupCORS(cfg *config.Config) gin.HandlerFunc {
	corsConfig := cors.Config{
		AllowOriginFunc: func(origin string) bool {
			return true // Dynamically reflect request origin so credentials + CORS work in Chrome
		},
		AllowMethods:     []string{"GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Length", "Content-Type", "Authorization", "Accept", "X-Requested-With"},
		ExposeHeaders:    []string{"Content-Length", "Authorization"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
	}

	return cors.New(corsConfig)
}
