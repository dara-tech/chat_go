package main

import (
	"log"
	"os"
	"chat_go/backend/config"
	"chat_go/backend/database"
	"chat_go/backend/handlers"
	"chat_go/backend/middleware"
	"chat_go/backend/repository"
	"chat_go/backend/routes"
	"chat_go/backend/services"
	"chat_go/backend/websocket"
)

func main() {
	// 1. Load application configuration
	cfg := config.LoadConfig()

	// 2. Set up log broker — tees Go's default logger into SSE stream
	logBroker := handlers.NewLogBroker()
	handlers.GlobalLogBroker = logBroker
	log.SetOutput(handlers.NewLogWriter(os.Stderr, logBroker))
	log.SetFlags(log.Ldate | log.Ltime)

	// 3. Connect to MySQL database
	db, err := database.ConnectDatabase(cfg)
	if err != nil {
		log.Fatalf("Fatal: Database initialization failed: %v", err)
	}

	// 3. Initialize layers
	userRepo := repository.NewUserRepository(db)
	messageRepo := repository.NewMessageRepository(db)
	groupRepo := repository.NewGroupRepository(db)
	jwtService := services.NewJWTService(cfg)
	authService := services.NewAuthService(userRepo, jwtService)
	chatService := services.NewChatService(messageRepo, userRepo)
	groupService := services.NewGroupService(groupRepo, messageRepo, userRepo)

	// 4. Initialize and run WebSocket Hub
	wsHub := websocket.NewHub(authService, chatService)
	wsHub.SetGroupService(groupService)
	go wsHub.Run()

	// 5. Initialize Cloudflare R2 media storage service
	r2Service := services.NewR2Service(cfg)
	if r2Service.IsConfigured() {
		log.Println("Cloudflare R2 Object Storage service enabled.")
	} else {
		log.Println("Note: Cloudflare R2 credentials not fully set in .env. Media upload endpoint will prompt for credentials.")
	}

	// 6. Initialize handlers and middleware
	authHandler := handlers.NewAuthHandler(authService, wsHub)
	chatHandler := handlers.NewChatHandler(chatService, wsHub)
	mediaHandler := handlers.NewMediaHandler(r2Service, authService)
	groupHandler := handlers.NewGroupHandler(groupService, wsHub)
	logHandler := handlers.NewLogHandler(logBroker, cfg.LogSecret)
	corsMiddleware := middleware.SetupCORS(cfg)

	// 7. Setup Gin router
	router := routes.SetupRouter(authHandler, chatHandler, mediaHandler, groupHandler, logHandler, jwtService, corsMiddleware)

	// 8. Start server
	addr := ":" + cfg.Port
	log.Printf("Chat Auth Server running at http://localhost%s", addr)
	log.Printf("WebSocket endpoint available at ws://localhost%s/api/v1/ws?token=<ACCESS_TOKEN>", addr)
	if cfg.LogSecret != "" {
		log.Printf("Log dashboard: http://localhost%s/admin/logs?secret=<LOG_SECRET>", addr)
	}

	if err := router.Run(addr); err != nil {
		log.Fatalf("Server terminated: %v", err)
	}
}
