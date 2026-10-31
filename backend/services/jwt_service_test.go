package services_test

import (
	"testing"
	"time"

	"chat_go/backend/config"
	"chat_go/backend/models"
	"chat_go/backend/services"
)

func TestJWTService_GenerateAndValidateToken(t *testing.T) {
	cfg := &config.Config{
		JWTSecret:   "test-secret-key-12345",
		JWTTTLHours: time.Hour,
		RefreshTTL:  7 * 24 * time.Hour,
	}

	jwtService := services.NewJWTService(cfg)

	user := &models.User{
		ID:       42,
		UUID:     "test-uuid-42",
		Username: "testuser",
	}

	access, refresh, exp, err := jwtService.GenerateTokenPair(user)
	if err != nil {
		t.Fatalf("GenerateTokenPair failed: %v", err)
	}

	if access == "" || refresh == "" {
		t.Fatal("Expected non-empty tokens")
	}

	if exp <= 0 {
		t.Fatalf("Expected positive expiration seconds, got %d", exp)
	}

	// Validate access token
	claims, err := jwtService.ValidateToken(access)
	if err != nil {
		t.Fatalf("ValidateToken failed: %v", err)
	}

	if claims.UserID != 42 || claims.Username != "testuser" || claims.TokenType != "access" {
		t.Fatalf("Unexpected claims in access token: %+v", claims)
	}

	// Validate refresh token
	refreshClaims, err := jwtService.ValidateRefreshToken(refresh)
	if err != nil {
		t.Fatalf("ValidateRefreshToken failed: %v", err)
	}

	if refreshClaims.UserID != 42 || refreshClaims.TokenType != "refresh" {
		t.Fatalf("Unexpected claims in refresh token: %+v", refreshClaims)
	}
}
