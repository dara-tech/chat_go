package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// User represents the user entity in the database
type User struct {
	ID           uint           `gorm:"primaryKey;autoIncrement" json:"id"`
	UUID         string         `gorm:"type:varchar(36);uniqueIndex;not null" json:"uuid"`
	Username     string         `gorm:"type:varchar(50);uniqueIndex;not null" json:"username"`
	Email        string         `gorm:"type:varchar(100);uniqueIndex;not null" json:"email"`
	PasswordHash string         `gorm:"type:varchar(255);not null" json:"-"`
	DisplayName  string         `gorm:"type:varchar(100)" json:"display_name"`
	AvatarURL    string         `gorm:"type:varchar(255)" json:"avatar_url"`
	IsOnline     bool           `gorm:"default:false" json:"is_online"`
	LastSeenAt   *time.Time     `json:"last_seen_at"`
	CreatedAt    time.Time      `json:"created_at"`
	UpdatedAt    time.Time      `json:"updated_at"`
	DeletedAt    gorm.DeletedAt `gorm:"index" json:"-"`
}

// BeforeCreate hook to generate UUID before inserting user
func (u *User) BeforeCreate(tx *gorm.DB) (err error) {
	if u.UUID == "" {
		u.UUID = uuid.NewString()
	}
	return nil
}

// RegisterInput defines the payload for user registration
type RegisterInput struct {
	Username    string `json:"username" binding:"required,min=3,max=50"`
	Email       string `json:"email" binding:"required,email"`
	Password    string `json:"password" binding:"required,min=6,max=72"`
	DisplayName string `json:"display_name" binding:"max=100"`
	AvatarURL   string `json:"avatar_url" binding:"omitempty,url"`
}

// LoginInput defines the payload for user authentication
type LoginInput struct {
	UsernameOrEmail string `json:"username_or_email" binding:"required"`
	Password        string `json:"password" binding:"required"`
}

// RefreshTokenInput defines payload to exchange refresh token for access token
type RefreshTokenInput struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

// UserResponse safe user representation sent to clients
type UserResponse struct {
	ID          uint       `json:"id"`
	UUID        string     `json:"uuid"`
	Username    string     `json:"username"`
	Email       string     `json:"email"`
	DisplayName string     `json:"display_name"`
	AvatarURL   string     `json:"avatar_url"`
	IsOnline    bool       `json:"is_online"`
	LastSeenAt  *time.Time `json:"last_seen_at"`
	CreatedAt   time.Time  `json:"created_at"`
}

// AuthResponse returns tokens and sanitized user info
type AuthResponse struct {
	AccessToken  string       `json:"access_token"`
	RefreshToken string       `json:"refresh_token"`
	ExpiresIn    int64        `json:"expires_in"` // in seconds
	User         UserResponse `json:"user"`
}

// ToResponse formats a User model into safe UserResponse
func (u *User) ToResponse() UserResponse {
	return UserResponse{
		ID:          u.ID,
		UUID:        u.UUID,
		Username:    u.Username,
		Email:       u.Email,
		DisplayName: u.DisplayName,
		AvatarURL:   u.AvatarURL,
		IsOnline:    u.IsOnline,
		LastSeenAt:  u.LastSeenAt,
		CreatedAt:   u.CreatedAt,
	}
}

// UpdateProfileInput defines the payload to update user profile
type UpdateProfileInput struct {
	DisplayName string `json:"display_name" binding:"max=100"`
	Username    string `json:"username" binding:"omitempty,min=3,max=50"`
}
