package repository

import (
	"errors"
	"time"

	"chat_go/backend/models"

	"gorm.io/gorm"
)

type UserRepository interface {
	Create(user *models.User) error
	FindByID(id uint) (*models.User, error)
	FindByUUID(uuid string) (*models.User, error)
	FindByUsername(username string) (*models.User, error)
	FindByEmail(email string) (*models.User, error)
	FindByUsernameOrEmail(identifier string) (*models.User, error)
	UpdateOnlineStatus(id uint, isOnline bool) error
	UpdateAvatar(id uint, avatarURL string) error
	UpdateProfile(id uint, displayName string, username string) error
	ListUsers(limit, offset int, search string) ([]models.User, error)
}

type userRepository struct {
	db *gorm.DB
}

func NewUserRepository(db *gorm.DB) UserRepository {
	return &userRepository{db: db}
}

func (r *userRepository) Create(user *models.User) error {
	return r.db.Create(user).Error
}

func (r *userRepository) FindByID(id uint) (*models.User, error) {
	var user models.User
	if err := r.db.First(&user, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &user, nil
}

func (r *userRepository) FindByUUID(uuid string) (*models.User, error) {
	var user models.User
	if err := r.db.Where("uuid = ?", uuid).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &user, nil
}

func (r *userRepository) FindByUsername(username string) (*models.User, error) {
	var user models.User
	if err := r.db.Where("username = ?", username).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &user, nil
}

func (r *userRepository) FindByEmail(email string) (*models.User, error) {
	var user models.User
	if err := r.db.Where("email = ?", email).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &user, nil
}

func (r *userRepository) FindByUsernameOrEmail(identifier string) (*models.User, error) {
	var user models.User
	if err := r.db.Where("username = ? OR email = ?", identifier, identifier).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &user, nil
}

func (r *userRepository) UpdateOnlineStatus(id uint, isOnline bool) error {
	now := time.Now()
	return r.db.Model(&models.User{}).Where("id = ?", id).Updates(map[string]interface{}{
		"is_online":    isOnline,
		"last_seen_at": &now,
	}).Error
}

func (r *userRepository) UpdateAvatar(id uint, avatarURL string) error {
	return r.db.Model(&models.User{}).Where("id = ?", id).Update("avatar_url", avatarURL).Error
}

func (r *userRepository) UpdateProfile(id uint, displayName string, username string) error {
	updates := map[string]interface{}{}
	if displayName != "" {
		updates["display_name"] = displayName
	}
	if username != "" {
		updates["username"] = username
	}
	if len(updates) == 0 {
		return nil
	}
	return r.db.Model(&models.User{}).Where("id = ?", id).Updates(updates).Error
}

func (r *userRepository) ListUsers(limit, offset int, search string) ([]models.User, error) {
	var users []models.User
	query := r.db.Model(&models.User{})
	if search != "" {
		s := "%" + search + "%"
		query = query.Where("username LIKE ? OR display_name LIKE ? OR email LIKE ?", s, s, s)
	}
	err := query.Limit(limit).Offset(offset).Order("is_online desc, created_at desc").Find(&users).Error
	return users, err
}
