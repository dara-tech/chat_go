package models

import (
	"time"

	"gorm.io/gorm"
)

// Group represents a group chat conversation
type Group struct {
	ID          uint           `gorm:"primaryKey;autoIncrement" json:"id"`
	Name        string         `gorm:"type:varchar(128);not null" json:"name"`
	Description string         `gorm:"type:varchar(255)" json:"description"`
	AvatarURL   string         `gorm:"type:varchar(512)" json:"avatar_url"`
	CreatorID   uint           `gorm:"index;not null" json:"creator_id"`
	CreatedAt   time.Time      `gorm:"index" json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`

	Creator *User         `gorm:"foreignKey:CreatorID" json:"creator,omitempty"`
	Members []GroupMember `gorm:"foreignKey:GroupID;constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"members,omitempty"`
}

// GroupMember represents membership of a user in a group
type GroupMember struct {
	ID                uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	GroupID           uint      `gorm:"uniqueIndex:idx_group_user;not null" json:"group_id"`
	UserID            uint      `gorm:"uniqueIndex:idx_group_user;not null" json:"user_id"`
	Role              string    `gorm:"type:varchar(32);default:'member'" json:"role"` // 'admin', 'member'
	JoinedAt          time.Time  `json:"joined_at"`
	LastReadMessageID uint       `gorm:"default:0" json:"last_read_message_id"`
	LastReadAt        *time.Time `json:"last_read_at,omitempty"`

	User  *User  `gorm:"foreignKey:UserID" json:"user,omitempty"`
	Group *Group `gorm:"foreignKey:GroupID" json:"group,omitempty"`
}

// GroupMemberResponse represents member item formatted for client
type GroupMemberResponse struct {
	ID                uint         `json:"id"`
	GroupID           uint         `json:"group_id"`
	UserID            uint         `json:"user_id"`
	Role              string       `json:"role"`
	JoinedAt          time.Time    `json:"joined_at"`
	LastReadMessageID uint         `json:"last_read_message_id"`
	User              UserResponse `json:"user"`
}

// GroupResponse represents group chat details formatted for client
type GroupResponse struct {
	ID          uint                  `json:"id"`
	Name        string                `json:"name"`
	Description string                `json:"description"`
	AvatarURL   string                `json:"avatar_url"`
	CreatorID   uint                  `json:"creator_id"`
	MemberCount int                   `json:"member_count"`
	Members     []GroupMemberResponse `json:"members,omitempty"`
	LastMessage *MessageResponse      `json:"last_message,omitempty"`
	UnreadCount int                   `json:"unread_count"`
	CreatedAt   time.Time             `json:"created_at"`
	UpdatedAt   time.Time             `json:"updated_at"`
}

// CreateGroupInput defines input required to create a new group
type CreateGroupInput struct {
	Name        string   `json:"name" binding:"required"`
	Description string   `json:"description"`
	AvatarURL   string   `json:"avatar_url"`
	MemberIDs   []uint   `json:"member_ids"`
}

// UpdateGroupInput defines input for updating group details
type UpdateGroupInput struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	AvatarURL   string `json:"avatar_url"`
}

// AddMembersInput defines input for adding members to a group
type AddMembersInput struct {
	MemberIDs []uint `json:"member_ids" binding:"required"`
}
