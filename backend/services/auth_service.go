package services

import (
	"errors"
	"fmt"
	"strings"
	"chat_go/backend/models"
	"chat_go/backend/repository"
	"golang.org/x/crypto/bcrypt"
)

var (
	ErrUserAlreadyExists = errors.New("username or email is already taken")
	ErrInvalidCredentials = errors.New("invalid username/email or password")
	ErrUserNotFound      = errors.New("user not found")
)

type AuthService interface {
	Register(input models.RegisterInput) (*models.AuthResponse, error)
	Login(input models.LoginInput) (*models.AuthResponse, error)
	RefreshToken(refreshToken string) (*models.AuthResponse, error)
	GetProfile(userID uint) (*models.UserResponse, error)
	UpdatePresence(userID uint, isOnline bool) error
	UpdateAvatar(id uint, avatarURL string) error
	UpdateProfile(id uint, input models.UpdateProfileInput) (*models.UserResponse, error)
	ListUsers(limit, offset int, search string) ([]models.UserResponse, error)
}

type authService struct {
	userRepo   repository.UserRepository
	jwtService JWTService
}

func NewAuthService(userRepo repository.UserRepository, jwtService JWTService) AuthService {
	return &authService{
		userRepo:   userRepo,
		jwtService: jwtService,
	}
}

func (s *authService) Register(input models.RegisterInput) (*models.AuthResponse, error) {
	// Normalize strings
	username := strings.ToLower(strings.TrimSpace(input.Username))
	email := strings.ToLower(strings.TrimSpace(input.Email))

	// Check if username or email exists
	existingUser, err := s.userRepo.FindByUsernameOrEmail(username)
	if err != nil {
		return nil, fmt.Errorf("failed checking existing user: %w", err)
	}
	if existingUser != nil {
		return nil, ErrUserAlreadyExists
	}

	existingEmail, err := s.userRepo.FindByEmail(email)
	if err != nil {
		return nil, fmt.Errorf("failed checking existing email: %w", err)
	}
	if existingEmail != nil {
		return nil, ErrUserAlreadyExists
	}

	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(input.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, fmt.Errorf("failed to hash password: %w", err)
	}

	displayName := input.DisplayName
	if displayName == "" {
		displayName = input.Username
	}

	newUser := &models.User{
		Username:     username,
		Email:        email,
		PasswordHash: string(hashedPassword),
		DisplayName:  displayName,
		AvatarURL:    input.AvatarURL,
		IsOnline:     false,
	}

	if err := s.userRepo.Create(newUser); err != nil {
		return nil, fmt.Errorf("failed to create user: %w", err)
	}

	// Generate JWT tokens
	accessToken, refreshToken, expiresIn, err := s.jwtService.GenerateTokenPair(newUser)
	if err != nil {
		return nil, fmt.Errorf("failed generating tokens: %w", err)
	}

	return &models.AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    expiresIn,
		User:         newUser.ToResponse(),
	}, nil
}

func (s *authService) Login(input models.LoginInput) (*models.AuthResponse, error) {
	identifier := strings.ToLower(strings.TrimSpace(input.UsernameOrEmail))

	user, err := s.userRepo.FindByUsernameOrEmail(identifier)
	if err != nil {
		return nil, fmt.Errorf("database error: %w", err)
	}
	if user == nil {
		return nil, ErrInvalidCredentials
	}

	// Verify password
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(input.Password)); err != nil {
		return nil, ErrInvalidCredentials
	}

	// Generate JWT tokens
	accessToken, refreshToken, expiresIn, err := s.jwtService.GenerateTokenPair(user)
	if err != nil {
		return nil, fmt.Errorf("failed generating tokens: %w", err)
	}

	return &models.AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    expiresIn,
		User:         user.ToResponse(),
	}, nil
}

func (s *authService) RefreshToken(tokenString string) (*models.AuthResponse, error) {
	claims, err := s.jwtService.ValidateRefreshToken(tokenString)
	if err != nil {
		return nil, err
	}

	user, err := s.userRepo.FindByID(claims.UserID)
	if err != nil {
		return nil, fmt.Errorf("database error: %w", err)
	}
	if user == nil {
		return nil, ErrUserNotFound
	}

	accessToken, refreshToken, expiresIn, err := s.jwtService.GenerateTokenPair(user)
	if err != nil {
		return nil, fmt.Errorf("failed generating tokens: %w", err)
	}

	return &models.AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    expiresIn,
		User:         user.ToResponse(),
	}, nil
}

func (s *authService) GetProfile(userID uint) (*models.UserResponse, error) {
	user, err := s.userRepo.FindByID(userID)
	if err != nil {
		return nil, fmt.Errorf("database error: %w", err)
	}
	if user == nil {
		return nil, ErrUserNotFound
	}

	resp := user.ToResponse()
	return &resp, nil
}

func (s *authService) UpdatePresence(userID uint, isOnline bool) error {
	return s.userRepo.UpdateOnlineStatus(userID, isOnline)
}

func (s *authService) UpdateAvatar(userID uint, avatarURL string) error {
	return s.userRepo.UpdateAvatar(userID, avatarURL)
}

func (s *authService) ListUsers(limit, offset int, search string) ([]models.UserResponse, error) {
	if limit <= 0 || limit > 1000 {
		limit = 100
	}
	if offset < 0 {
		offset = 0
	}

	users, err := s.userRepo.ListUsers(limit, offset, search)
	if err != nil {
		return nil, fmt.Errorf("database error: %w", err)
	}

	result := make([]models.UserResponse, len(users))
	for i, u := range users {
		result[i] = u.ToResponse()
	}
	return result, nil
}

func (s *authService) UpdateProfile(id uint, input models.UpdateProfileInput) (*models.UserResponse, error) {
	if input.Username != "" {
		normalized := strings.ToLower(strings.TrimSpace(input.Username))
		existing, err := s.userRepo.FindByUsername(normalized)
		if err != nil {
			return nil, err
		}
		if existing != nil && existing.ID != id {
			return nil, ErrUserAlreadyExists
		}
		input.Username = normalized
	}

	if err := s.userRepo.UpdateProfile(id, strings.TrimSpace(input.DisplayName), input.Username); err != nil {
		return nil, fmt.Errorf("failed updating profile: %w", err)
	}

	user, err := s.userRepo.FindByID(id)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, ErrUserNotFound
	}

	resp := user.ToResponse()
	return &resp, nil
}
