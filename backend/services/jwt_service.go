package services

import (
	"errors"
	"fmt"
	"time"

	"chat_go/backend/config"
	"chat_go/backend/models"

	"github.com/golang-jwt/jwt/v5"
)

var (
	ErrInvalidToken = errors.New("invalid or expired token")
	ErrInvalidTokenType = errors.New("token type is not valid for this action")
)

type JWTClaims struct {
	UserID    uint   `json:"user_id"`
	UUID      string `json:"uuid"`
	Username  string `json:"username"`
	TokenType string `json:"token_type"` // "access" or "refresh"
	jwt.RegisteredClaims
}

type JWTService interface {
	GenerateTokenPair(user *models.User) (accessToken, refreshToken string, expiresIn int64, err error)
	ValidateToken(tokenString string) (*JWTClaims, error)
	ValidateRefreshToken(tokenString string) (*JWTClaims, error)
}

type jwtService struct {
	secretKey     []byte
	accessExpiry  time.Duration
	refreshExpiry time.Duration
}

func NewJWTService(cfg *config.Config) JWTService {
	return &jwtService{
		secretKey:     []byte(cfg.JWTSecret),
		accessExpiry:  cfg.JWTTTLHours,
		refreshExpiry: cfg.RefreshTTL,
	}
}

func (s *jwtService) GenerateTokenPair(user *models.User) (string, string, int64, error) {
	now := time.Now()
	accessExpiration := now.Add(s.accessExpiry)
	refreshExpiration := now.Add(s.refreshExpiry)

	// Access Token
	accessClaims := &JWTClaims{
		UserID:    user.ID,
		UUID:      user.UUID,
		Username:  user.Username,
		TokenType: "access",
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   fmt.Sprintf("%d", user.ID),
			Issuer:    "chat_go_auth",
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(accessExpiration),
		},
	}
	accessTokenObj := jwt.NewWithClaims(jwt.SigningMethodHS256, accessClaims)
	accessToken, err := accessTokenObj.SignedString(s.secretKey)
	if err != nil {
		return "", "", 0, fmt.Errorf("failed to sign access token: %w", err)
	}

	// Refresh Token
	refreshClaims := &JWTClaims{
		UserID:    user.ID,
		UUID:      user.UUID,
		Username:  user.Username,
		TokenType: "refresh",
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   fmt.Sprintf("%d", user.ID),
			Issuer:    "chat_go_auth",
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(refreshExpiration),
		},
	}
	refreshTokenObj := jwt.NewWithClaims(jwt.SigningMethodHS256, refreshClaims)
	refreshToken, err := refreshTokenObj.SignedString(s.secretKey)
	if err != nil {
		return "", "", 0, fmt.Errorf("failed to sign refresh token: %w", err)
	}

	expiresInSeconds := int64(s.accessExpiry.Seconds())
	return accessToken, refreshToken, expiresInSeconds, nil
}

func (s *jwtService) ValidateToken(tokenString string) (*JWTClaims, error) {
	claims := &JWTClaims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return s.secretKey, nil
	})

	if err != nil || !token.Valid {
		return nil, ErrInvalidToken
	}

	return claims, nil
}

func (s *jwtService) ValidateRefreshToken(tokenString string) (*JWTClaims, error) {
	claims, err := s.ValidateToken(tokenString)
	if err != nil {
		return nil, err
	}

	if claims.TokenType != "refresh" {
		return nil, ErrInvalidTokenType
	}

	return claims, nil
}
