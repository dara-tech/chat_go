package routes

import (
	"net/http"

	"chat_go/backend/handlers"
	"chat_go/backend/middleware"
	"chat_go/backend/services"

	"github.com/gin-gonic/gin"
)

// SetupRouter sets up Gin router with all HTTP endpoints and WebSocket
func SetupRouter(authHandler *handlers.AuthHandler, chatHandler *handlers.ChatHandler, mediaHandler *handlers.MediaHandler, groupHandler *handlers.GroupHandler, logHandler *handlers.LogHandler, jwtService services.JWTService, corsMiddleware gin.HandlerFunc) *gin.Engine {
	r := gin.Default()

	// Apply CORS
	r.Use(corsMiddleware)

	// Health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "healthy",
			"service": "chat-go-auth",
		})
	})

	// ── Admin: log dashboard (secret-protected, no JWT required) ──────────
	r.GET("/admin/logs", logHandler.ServeUI)
	r.GET("/logs/stream", logHandler.StreamSSE)

	api := r.Group("/api/v1")
	{
		// Public Auth Routes
		authGroup := api.Group("/auth")
		{
			authGroup.POST("/register", authHandler.Register)
			authGroup.POST("/login", authHandler.Login)
			authGroup.POST("/refresh", authHandler.RefreshToken)
		}

		// Public media file serving from Cloudflare R2
		api.GET("/media/file/*key", mediaHandler.GetMedia)

		// Protected Routes
		protected := api.Group("")
		protected.Use(middleware.AuthMiddleware(jwtService))
		{
			// Current user profile & session
			protected.GET("/auth/me", authHandler.GetMe)
			protected.PUT("/users/profile", authHandler.UpdateProfile)
			protected.POST("/auth/logout", authHandler.Logout)

			// Users list and profile for real-time chat buddy list
			protected.GET("/users", authHandler.ListUsers)
			protected.GET("/users/:id", authHandler.GetUserProfile)

			// 1-to-1 Chat and conversation routes
			protected.GET("/chats/conversations", chatHandler.GetConversations)
			protected.GET("/conversations", chatHandler.GetConversations)
			protected.GET("/chats/:userId/messages", chatHandler.GetMessages)
			protected.DELETE("/chats/:userId", chatHandler.DeleteConversation)
			protected.DELETE("/conversations/:userId", chatHandler.DeleteConversation)
			protected.GET("/chats/:userId/media", chatHandler.GetSharedMedia)
			protected.POST("/chats/messages", chatHandler.SendMessage)
			protected.DELETE("/chats/messages/:id", chatHandler.DeleteMessage)
			protected.POST("/chats/messages/:id/reaction", chatHandler.ReactMessage)
			protected.PUT("/chats/:userId/read", chatHandler.MarkAsRead)
			protected.GET("/chats/unread", chatHandler.GetUnreadCount)

			// User Avatar upload to Cloudflare R2
			protected.POST("/users/avatar", mediaHandler.UploadAvatar)

			// Chat media upload (images, voice, video, files) to Cloudflare R2
			protected.POST("/media/upload", mediaHandler.UploadMedia)

			// Group Chat routes
			protected.POST("/groups", groupHandler.CreateGroup)
			protected.GET("/groups", groupHandler.GetGroups)
			protected.GET("/groups/:groupId", groupHandler.GetGroup)
			protected.PUT("/groups/:groupId", groupHandler.UpdateGroup)
			protected.POST("/groups/:groupId/members", groupHandler.AddMembers)
			protected.DELETE("/groups/:groupId/members/:userId", groupHandler.RemoveMember)
			protected.POST("/groups/:groupId/leave", groupHandler.LeaveGroup)
			protected.GET("/groups/:groupId/messages", groupHandler.GetGroupMessages)
			protected.POST("/groups/:groupId/messages", groupHandler.SendGroupMessage)
			protected.PUT("/groups/:groupId/read", groupHandler.MarkGroupAsRead)
			protected.GET("/groups/:groupId/messages/:messageId/readers", groupHandler.GetMessageReaders)

			// Real-time WebSocket connection (accepts ?token=... or Bearer token header)
			protected.GET("/ws", authHandler.HandleWebSocket)
		}
	}

	return r
}
