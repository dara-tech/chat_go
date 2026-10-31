package middleware

import (
	"net/http"
	"strings"

	"chat_go/backend/services"

	"github.com/gin-gonic/gin"
)

const (
	ContextUserID   = "userID"
	ContextUUID     = "userUUID"
	ContextUsername = "username"
	ContextClaims   = "claims"
)

// AuthMiddleware validates JWT from HTTP Authorization header OR URL query param (token=...)
// Extracting from query param is essential for WebSockets in browsers.
func AuthMiddleware(jwtService services.JWTService) gin.HandlerFunc {
	return func(c *gin.Context) {
		tokenString := extractToken(c)

		if tokenString == "" {
			c.JSON(http.StatusUnauthorized, gin.H{
				"error": "Authentication token required. Provide 'Authorization: Bearer <token>' header or '?token=<token>' query parameter.",
			})
			c.Abort()
			return
		}

		claims, err := jwtService.ValidateToken(tokenString)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid or expired authentication token"})
			c.Abort()
			return
		}

		if claims.TokenType != "access" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Access token required"})
			c.Abort()
			return
		}

		// Inject user details into gin context
		c.Set(ContextUserID, claims.UserID)
		c.Set(ContextUUID, claims.UUID)
		c.Set(ContextUsername, claims.Username)
		c.Set(ContextClaims, claims)

		c.Next()
	}
}

// extractToken retrieves the JWT token from Authorization header, query parameter, or Sec-WebSocket-Protocol
func extractToken(c *gin.Context) string {
	// 1. Try standard Authorization header (Bearer <token>)
	authHeader := c.GetHeader("Authorization")
	if authHeader != "" {
		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) == 2 && strings.EqualFold(parts[0], "Bearer") {
			return strings.TrimSpace(parts[1])
		}
	}

	// 2. Try URL query parameter (?token=...) - Standard for browser WebSocket upgrades
	if tokenQuery := c.Query("token"); tokenQuery != "" {
		return strings.TrimSpace(tokenQuery)
	}

	// 3. Try Sec-WebSocket-Protocol header fallback
	if wsProtocol := c.GetHeader("Sec-WebSocket-Protocol"); wsProtocol != "" {
		parts := strings.Split(wsProtocol, ",")
		if len(parts) > 0 {
			return strings.TrimSpace(parts[0])
		}
	}

	return ""
}
