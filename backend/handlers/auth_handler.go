package handlers

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	"chat_go/backend/middleware"
	"chat_go/backend/models"
	"chat_go/backend/services"
	"chat_go/backend/websocket"

	"github.com/gin-gonic/gin"
)

type AuthHandler struct {
	authService services.AuthService
	wsHub       *websocket.Hub
}

func NewAuthHandler(authService services.AuthService, wsHub *websocket.Hub) *AuthHandler {
	return &AuthHandler{
		authService: authService,
		wsHub:       wsHub,
	}
}

// Register creates a new user account
// @Summary Register a new user
// @Tags Auth
// @Accept json
// @Produce json
// @Param body body models.RegisterInput true "Register credentials"
// @Success 201 {object} models.AuthResponse
// @Failure 400,409,500 {object} map[string]string
func (h *AuthHandler) Register(c *gin.Context) {
	var input models.RegisterInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Validation error: " + err.Error()})
		return
	}

	authResp, err := h.authService.Register(input)
	if err != nil {
		if errors.Is(err, services.ErrUserAlreadyExists) {
			c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"message": "User registered successfully",
		"data":    authResp,
	})
}

// Login authenticates a user with username/email and password
// @Summary Login user
// @Tags Auth
// @Accept json
// @Produce json
// @Param body body models.LoginInput true "Login credentials"
// @Success 200 {object} models.AuthResponse
// @Failure 400,401,500 {object} map[string]string
func (h *AuthHandler) Login(c *gin.Context) {
	var input models.LoginInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Validation error: " + err.Error()})
		return
	}

	authResp, err := h.authService.Login(input)
	if err != nil {
		if errors.Is(err, services.ErrInvalidCredentials) {
			c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Login successful",
		"data":    authResp,
	})
}

// RefreshToken issues a new access/refresh token pair
// @Summary Refresh JWT token
// @Tags Auth
// @Accept json
// @Produce json
// @Param body body models.RefreshTokenInput true "Refresh Token"
// @Success 200 {object} models.AuthResponse
// @Failure 400,401,500 {object} map[string]string
func (h *AuthHandler) RefreshToken(c *gin.Context) {
	var input models.RefreshTokenInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Validation error: " + err.Error()})
		return
	}

	authResp, err := h.authService.RefreshToken(input.RefreshToken)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Token refreshed successfully",
		"data":    authResp,
	})
}

// GetMe retrieves profile of currently authenticated user
// @Summary Get current user profile
// @Tags Auth
// @Security BearerAuth
// @Produce json
// @Success 200 {object} models.UserResponse
// @Failure 401,404,500 {object} map[string]string
func (h *AuthHandler) GetMe(c *gin.Context) {
	userIDVal, exists := c.Get(middleware.ContextUserID)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	userID := userIDVal.(uint)
	profile, err := h.authService.GetProfile(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": profile})
}

// UpdateProfile updates the display name and username of current user
// @Summary Update user profile
// @Tags Auth
// @Security BearerAuth
// @Accept json
// @Produce json
// @Param body body models.UpdateProfileInput true "Profile updates"
// @Success 200 {object} models.UserResponse
// @Failure 400,401,409,500 {object} map[string]string
func (h *AuthHandler) UpdateProfile(c *gin.Context) {
	userIDVal, exists := c.Get(middleware.ContextUserID)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	var input models.UpdateProfileInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Validation error: " + err.Error()})
		return
	}

	userID := userIDVal.(uint)
	updated, err := h.authService.UpdateProfile(userID, input)
	if err != nil {
		if errors.Is(err, services.ErrUserAlreadyExists) {
			c.JSON(http.StatusConflict, gin.H{"error": "Username already taken"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Profile updated successfully",
		"data":    updated,
	})
}

// Logout sets user status to offline
// @Summary Logout current user
// @Tags Auth
// @Security BearerAuth
// @Produce json
// @Success 200 {object} map[string]string
func (h *AuthHandler) Logout(c *gin.Context) {
	userIDVal, exists := c.Get(middleware.ContextUserID)
	if exists {
		userID := userIDVal.(uint)
		_ = h.authService.UpdatePresence(userID, false)
	}

	c.JSON(http.StatusOK, gin.H{"message": "Logged out successfully"})
}

// ListUsers retrieves list of users with online presence for chat
// @Summary List chat users
// @Tags Users
// @Security BearerAuth
// @Produce json
// @Success 200 {array} models.UserResponse
func (h *AuthHandler) ListUsers(c *gin.Context) {
	limitStr := c.DefaultQuery("limit", "100")
	offsetStr := c.DefaultQuery("offset", "0")
	search := strings.TrimSpace(c.Query("search"))

	limit, _ := strconv.Atoi(limitStr)
	offset, _ := strconv.Atoi(offsetStr)

	users, err := h.authService.ListUsers(limit, offset, search)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": users})
}

// GetUserProfile retrieves the authorized profile of a user by ID
// @Summary Get user profile by ID
// @Tags Users
// @Security BearerAuth
// @Produce json
// @Success 200 {object} models.UserResponse
// @Failure 400,404,500 {object} map[string]string
func (h *AuthHandler) GetUserProfile(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.ParseUint(idStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	profile, err := h.authService.GetProfile(uint(id))
	if err != nil {
		if errors.Is(err, services.ErrUserNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": profile})
}

// HandleWebSocket upgrades connection to real-time chat socket
func (h *AuthHandler) HandleWebSocket(c *gin.Context) {
	websocket.ServeWs(h.wsHub, c)
}
