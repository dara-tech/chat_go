package handlers

import (
	"errors"
	"fmt"
	"net/http"
	"path/filepath"
	"strings"
	"chat_go/backend/middleware"
	"chat_go/backend/services"
	"github.com/gin-gonic/gin"
)

type MediaHandler struct {
	r2Service   services.R2Service
	authService services.AuthService
}

func NewMediaHandler(r2Service services.R2Service, authService services.AuthService) *MediaHandler {
	return &MediaHandler{
		r2Service:   r2Service,
		authService: authService,
	}
}

// UploadMedia uploads chat attachments (images, audio, video, documents) to Cloudflare R2
func (h *MediaHandler) UploadMedia(c *gin.Context) {
	if !h.r2Service.IsConfigured() {
		c.JSON(http.StatusServiceUnavailable, gin.H{
			"error": "Cloudflare R2 storage is not configured. Please set R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, and R2_BUCKET_NAME in .env.",
		})
		return
	}

	file, err := c.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Please provide a 'file' in the form data"})
		return
	}

	folder := c.DefaultPostForm("folder", "chat")

	mediaResp, err := h.r2Service.UploadFile(c.Request.Context(), file, folder)
	if err != nil {
		if errors.Is(err, services.ErrFileTooLarge) {
			c.JSON(http.StatusRequestEntityTooLarge, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed uploading to Cloudflare R2: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "File uploaded successfully to Cloudflare R2",
		"data":    mediaResp,
	})
}

// UploadAvatar uploads and sets user profile picture
func (h *MediaHandler) UploadAvatar(c *gin.Context) {
	if !h.r2Service.IsConfigured() {
		c.JSON(http.StatusServiceUnavailable, gin.H{
			"error": "Cloudflare R2 storage is not configured in .env",
		})
		return
	}

	userIDVal, exists := c.Get(middleware.ContextUserID)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(uint)

	file, err := c.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Please provide an image 'file' in the form data"})
		return
	}

	// Validate image extension
	ext := strings.ToLower(filepath.Ext(file.Filename))
	validImageExts := map[string]bool{
		".jpg":  true,
		".jpeg": true,
		".png":  true,
		".webp": true,
		".gif":  true,
	}
	if !validImageExts[ext] {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid avatar format. Allowed: .jpg, .jpeg, .png, .webp, .gif"})
		return
	}

	mediaResp, err := h.r2Service.UploadFile(c.Request.Context(), file, "avatars")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Upload failed: " + err.Error()})
		return
	}

	// Update avatar URL in MySQL database
	if err := h.authService.UpdateAvatar(userID, mediaResp.URL); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed updating avatar in database: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":    "Avatar updated successfully",
		"avatar_url": mediaResp.URL,
		"data":       mediaResp,
	})
}

// GetMedia streams a file directly from Cloudflare R2 with HTTP Range support
func (h *MediaHandler) GetMedia(c *gin.Context) {
	key := strings.TrimPrefix(c.Param("key"), "/")
	if key == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Key is required"})
		return
	}

	rangeHeader := c.GetHeader("Range")
	body, contentType, contentLength, contentRange, err := h.r2Service.GetFileWithRange(c.Request.Context(), key, rangeHeader)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "File not found: " + err.Error()})
		return
	}
	defer body.Close()

	c.Header("Cache-Control", "public, max-age=86400")
	c.Header("Accept-Ranges", "bytes")

	if c.Query("download") == "true" || c.Query("download") == "1" {
		fileName := c.Query("filename")
		if fileName == "" {
			fileName = filepath.Base(key)
		}
		c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=\"%s\"", fileName))
	}

	if contentRange != "" {
		c.Header("Content-Range", contentRange)
		c.DataFromReader(http.StatusPartialContent, contentLength, contentType, body, nil)
	} else {
		c.DataFromReader(http.StatusOK, contentLength, contentType, body, nil)
	}
}
