package repository

import (
	"errors"
	"time"

	"chat_go/backend/models"
	"gorm.io/gorm"
)

type GroupRepository interface {
	Create(group *models.Group) error
	FindByID(id uint) (*models.Group, error)
	FindUserGroups(userID uint) ([]models.Group, error)
	AddMember(member *models.GroupMember) error
	AddMembers(members []models.GroupMember) error
	RemoveMember(groupID, userID uint) error
	IsMember(groupID, userID uint) (bool, error)
	GetMemberIDs(groupID uint) ([]uint, error)
	GetMembers(groupID uint) ([]models.GroupMember, error)
	Update(group *models.Group) error
	Delete(id uint) error
	GetGroupMessages(groupID uint, limit, offset int, before ...uint) ([]models.Message, error)
	GetLastMessage(groupID uint) (*models.Message, error)
	GetUnreadCount(groupID, userID uint) (int, error)
	MarkGroupAsRead(groupID, userID uint) (uint, error)
	GetMessageReaders(groupID, messageID uint) ([]models.ReadUser, error)
}

type groupRepository struct {
	db *gorm.DB
}

func NewGroupRepository(db *gorm.DB) GroupRepository {
	return &groupRepository{db: db}
}

func (r *groupRepository) Create(group *models.Group) error {
	return r.db.Create(group).Error
}

func (r *groupRepository) FindByID(id uint) (*models.Group, error) {
	var group models.Group
	err := r.db.Preload("Creator").
		Preload("Members.User").
		First(&group, id).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &group, nil
}

func (r *groupRepository) FindUserGroups(userID uint) ([]models.Group, error) {
	var groups []models.Group
	err := r.db.Table("groups").
		Joins("JOIN group_members ON group_members.group_id = groups.id").
		Where("group_members.user_id = ? AND groups.deleted_at IS NULL", userID).
		Preload("Creator").
		Preload("Members.User").
		Order("groups.updated_at DESC").
		Find(&groups).Error
	return groups, err
}

func (r *groupRepository) AddMember(member *models.GroupMember) error {
	if member.JoinedAt.IsZero() {
		member.JoinedAt = time.Now()
	}
	return r.db.Create(member).Error
}

func (r *groupRepository) AddMembers(members []models.GroupMember) error {
	if len(members) == 0 {
		return nil
	}
	now := time.Now()
	for i := range members {
		if members[i].JoinedAt.IsZero() {
			members[i].JoinedAt = now
		}
	}
	return r.db.Create(&members).Error
}

func (r *groupRepository) RemoveMember(groupID, userID uint) error {
	return r.db.Where("group_id = ? AND user_id = ?", groupID, userID).
		Delete(&models.GroupMember{}).Error
}

func (r *groupRepository) IsMember(groupID, userID uint) (bool, error) {
	var count int64
	err := r.db.Model(&models.GroupMember{}).
		Where("group_id = ? AND user_id = ?", groupID, userID).
		Count(&count).Error
	return count > 0, err
}

func (r *groupRepository) GetMemberIDs(groupID uint) ([]uint, error) {
	var ids []uint
	err := r.db.Model(&models.GroupMember{}).
		Where("group_id = ?", groupID).
		Pluck("user_id", &ids).Error
	return ids, err
}

func (r *groupRepository) GetMembers(groupID uint) ([]models.GroupMember, error) {
	var members []models.GroupMember
	err := r.db.Preload("User").
		Where("group_id = ?", groupID).
		Order("joined_at ASC").
		Find(&members).Error
	return members, err
}

func (r *groupRepository) Update(group *models.Group) error {
	return r.db.Save(group).Error
}

func (r *groupRepository) Delete(id uint) error {
	return r.db.Delete(&models.Group{}, id).Error
}

func (r *groupRepository) GetGroupMessages(groupID uint, limit, offset int, before ...uint) ([]models.Message, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 100 {
		limit = 100
	}

	query := r.db.Model(&models.Message{}).
		Preload("Sender").
		Preload("Attachments", func(db *gorm.DB) *gorm.DB {
			return db.Order("sort_order ASC")
		}).
		Where("group_id = ?", groupID)

	if len(before) > 0 && before[0] > 0 {
		query = query.Where("id < ?", before[0])
	}

	var messages []models.Message
	err := query.Order("created_at DESC").
		Limit(limit).
		Offset(offset).
		Find(&messages).Error

	return messages, err
}

func (r *groupRepository) GetLastMessage(groupID uint) (*models.Message, error) {
	var msg models.Message
	err := r.db.Preload("Sender").
		Preload("Attachments").
		Where("group_id = ?", groupID).
		Order("created_at DESC").
		First(&msg).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &msg, nil
}

func (r *groupRepository) GetUnreadCount(groupID, userID uint) (int, error) {
	var member models.GroupMember
	if err := r.db.Where("group_id = ? AND user_id = ?", groupID, userID).First(&member).Error; err != nil {
		return 0, nil
	}

	var count int64
	err := r.db.Model(&models.Message{}).
		Where("group_id = ? AND id > ? AND sender_id != ? AND deleted_at IS NULL", groupID, member.LastReadMessageID, userID).
		Count(&count).Error

	return int(count), err
}

func (r *groupRepository) MarkGroupAsRead(groupID, userID uint) (uint, error) {
	var maxID uint
	r.db.Model(&models.Message{}).
		Where("group_id = ? AND deleted_at IS NULL", groupID).
		Select("COALESCE(MAX(id), 0)").
		Scan(&maxID)

	now := time.Now()
	err := r.db.Model(&models.GroupMember{}).
		Where("group_id = ? AND user_id = ?", groupID, userID).
		Updates(map[string]interface{}{
			"last_read_message_id": maxID,
			"last_read_at":         now,
		}).Error

	return maxID, err
}

func (r *groupRepository) GetMessageReaders(groupID, messageID uint) ([]models.ReadUser, error) {
	var msg models.Message
	if err := r.db.Where("id = ? AND group_id = ?", messageID, groupID).First(&msg).Error; err != nil {
		return nil, err
	}

	var members []models.GroupMember
	err := r.db.Preload("User").
		Where("group_id = ? AND user_id != ? AND last_read_message_id >= ?", groupID, msg.SenderID, messageID).
		Order("last_read_at DESC, id ASC").
		Find(&members).Error
	if err != nil {
		return nil, err
	}

	readers := make([]models.ReadUser, len(members))
	for i, m := range members {
		username := ""
		displayName := ""
		avatar := ""
		if m.User != nil {
			username = m.User.Username
			displayName = m.User.DisplayName
			avatar = m.User.AvatarURL
		}
		readers[i] = models.ReadUser{
			UserID:      m.UserID,
			Username:    username,
			DisplayName: displayName,
			AvatarURL:   avatar,
			ReadAt:      m.LastReadAt,
		}
	}
	return readers, nil
}
