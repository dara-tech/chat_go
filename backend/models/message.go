package models

import (
	"time"

	"gorm.io/gorm"
)

// Message represents a direct 1-to-1 message between two users
type Message struct {
	ID              uint                `gorm:"primaryKey;autoIncrement" json:"id"`
	SenderID        uint                `gorm:"index;not null" json:"sender_id"`
	ReceiverID      *uint               `gorm:"index" json:"receiver_id,omitempty"`
	GroupID         *uint               `gorm:"index" json:"group_id,omitempty"`
	ClientMessageID string              `gorm:"type:varchar(64);index" json:"client_message_id,omitempty"`
	Content         string              `gorm:"type:text;not null" json:"content"`
	Status          string              `gorm:"type:varchar(32);default:'sent'" json:"status"` // pending, sent, delivered, read, failed
	MediaType       string              `gorm:"type:varchar(32);default:'text'" json:"media_type"` // text, image, audio, video, file, voice, mixed, album, location
	MediaURL        string              `gorm:"type:varchar(512)" json:"media_url,omitempty"`
	DurationMs      int                 `gorm:"default:0" json:"duration_ms,omitempty"`
	Waveform        string              `gorm:"type:text" json:"waveform,omitempty"`
	ForwardFrom     string              `gorm:"type:varchar(128)" json:"forward_from,omitempty"`
	Reactions       string              `gorm:"type:text" json:"reactions,omitempty"` // JSON string e.g. {"❤️":[1,2],"👍":[3]}
	IsRead          bool                `gorm:"index;default:false" json:"is_read"`
	ReadAt          *time.Time          `json:"read_at,omitempty"`
	CreatedAt       time.Time           `gorm:"index" json:"created_at"`
	UpdatedAt       time.Time           `json:"updated_at"`
	DeletedBySender bool                `gorm:"default:false" json:"deleted_by_sender"`
	DeletedByReceiver bool              `gorm:"default:false" json:"deleted_by_receiver"`
	DeletedAt       gorm.DeletedAt      `gorm:"index" json:"-"`

	// Relationships
	Sender      *User               `gorm:"foreignKey:SenderID" json:"sender,omitempty"`
	Receiver    *User               `gorm:"foreignKey:ReceiverID" json:"receiver,omitempty"`
	Group       *Group              `gorm:"foreignKey:GroupID" json:"group,omitempty"`
	Attachments []MessageAttachment `gorm:"foreignKey:MessageID;constraint:OnUpdate:CASCADE,OnDelete:CASCADE" json:"attachments,omitempty"`
}

// MessageAttachment represents an individual media attachment in a message
type MessageAttachment struct {
	ID           uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	MessageID    uint      `gorm:"index;not null" json:"message_id"`
	MediaType    string    `gorm:"type:varchar(32);not null" json:"media_type"` // image, video, audio, voice, document
	MimeType     string    `gorm:"type:varchar(128)" json:"mime_type"`
	FileName     string    `gorm:"type:varchar(255)" json:"file_name"`
	SizeBytes    int64     `gorm:"default:0" json:"size_bytes"`
	Width        int       `gorm:"default:0" json:"width,omitempty"`
	Height       int       `gorm:"default:0" json:"height,omitempty"`
	DurationMs   int       `gorm:"default:0" json:"duration_ms,omitempty"`
	StorageKey   string    `gorm:"type:varchar(512)" json:"storage_key,omitempty"`
	URL          string    `gorm:"type:varchar(512);not null" json:"url"`
	UploadStatus string    `gorm:"type:varchar(32);default:'completed'" json:"upload_status"` // pending, uploading, completed, failed
	SortOrder    int       `gorm:"default:0" json:"sort_order"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// AttachmentInput defines input parameters for creating an attachment
type AttachmentInput struct {
	MediaType    string `json:"media_type"` // image, video, audio, voice, document
	MimeType     string `json:"mime_type"`
	FileName     string `json:"file_name"`
	SizeBytes    int64  `json:"size_bytes"`
	Width        int    `json:"width,omitempty"`
	Height       int    `json:"height,omitempty"`
	DurationMs   int    `json:"duration_ms,omitempty"`
	StorageKey   string `json:"storage_key,omitempty"`
	URL          string `json:"url"`
	UploadStatus string `json:"upload_status,omitempty"`
	SortOrder    int    `json:"sort_order"`
}

// MessageAttachmentResponse is the client-facing format of an attachment
type MessageAttachmentResponse struct {
	ID           uint   `json:"id"`
	MessageID    uint   `json:"message_id"`
	MediaType    string `json:"media_type"`
	MimeType     string `json:"mime_type"`
	FileName     string `json:"file_name"`
	SizeBytes    int64  `json:"size_bytes"`
	Width        int    `json:"width,omitempty"`
	Height       int    `json:"height,omitempty"`
	DurationMs   int    `json:"duration_ms,omitempty"`
	StorageKey   string `json:"storage_key,omitempty"`
	URL          string `json:"url"`
	UploadStatus string `json:"upload_status"`
	SortOrder    int    `json:"sort_order"`
}

// SendMessageInput is the payload for sending a chat message
type SendMessageInput struct {
	ReceiverID      uint              `json:"receiver_id"`
	GroupID         *uint             `json:"group_id,omitempty"`
	ClientMessageID string            `json:"client_message_id,omitempty"`
	Content         string            `json:"content"`
	Status          string            `json:"status,omitempty"`
	MediaType       string            `json:"media_type"` // text, image, audio, video, file, voice, mixed, album, location
	MediaURL        string            `json:"media_url"`
	DurationMs      int               `json:"duration_ms,omitempty"`
	Waveform        string            `json:"waveform,omitempty"`
	ForwardFrom     string            `json:"forward_from,omitempty"`
	Attachments     []AttachmentInput `json:"attachments,omitempty"`
}

// ReadUser represents a user who read/seen a message
type ReadUser struct {
	UserID      uint       `json:"user_id"`
	Username    string     `json:"username"`
	DisplayName string     `json:"display_name,omitempty"`
	AvatarURL   string     `json:"avatar_url,omitempty"`
	ReadAt      *time.Time `json:"read_at,omitempty"`
}

// MessageResponse is the JSON response format for a message
type MessageResponse struct {
	ID              uint                        `json:"id"`
	SenderID        uint                        `json:"sender_id"`
	ReceiverID      uint                        `json:"receiver_id"`
	GroupID         *uint                       `json:"group_id,omitempty"`
	ClientMessageID string                      `json:"client_message_id,omitempty"`
	Username        string                      `json:"username,omitempty"`
	SenderAvatar    string                      `json:"sender_avatar,omitempty"`
	Content         string                      `json:"content"`
	Status          string                      `json:"status"`
	MediaType       string                      `json:"media_type"`
	MediaURL        string                      `json:"media_url,omitempty"`
	DurationMs      int                         `json:"duration_ms,omitempty"`
	Waveform        string                      `json:"waveform,omitempty"`
	ForwardFrom     string                      `json:"forward_from,omitempty"`
	Reactions       string                      `json:"reactions,omitempty"`
	IsRead          bool                        `json:"is_read"`
	ReadAt          *time.Time                  `json:"read_at,omitempty"`
	SeenCount       int                         `json:"seen_count"`
	SeenBy          []ReadUser                  `json:"seen_by,omitempty"`
	Attachments     []MessageAttachmentResponse `json:"attachments,omitempty"`
	Timestamp       time.Time                   `json:"timestamp"`
	CreatedAt       time.Time                   `json:"created_at"`
}

func (m *Message) ToResponse(senderUsername string, senderAvatar ...string) MessageResponse {
	avatar := ""
	if len(senderAvatar) > 0 {
		avatar = senderAvatar[0]
	} else if m.Sender != nil {
		avatar = m.Sender.AvatarURL
	}

	attachmentsResp := make([]MessageAttachmentResponse, len(m.Attachments))
	for i, att := range m.Attachments {
		attachmentsResp[i] = MessageAttachmentResponse{
			ID:           att.ID,
			MessageID:    att.MessageID,
			MediaType:    att.MediaType,
			MimeType:     att.MimeType,
			FileName:     att.FileName,
			SizeBytes:    att.SizeBytes,
			Width:        att.Width,
			Height:       att.Height,
			DurationMs:   att.DurationMs,
			StorageKey:   att.StorageKey,
			URL:          att.URL,
			UploadStatus: att.UploadStatus,
			SortOrder:    att.SortOrder,
		}
	}

	status := m.Status
	if status == "" {
		status = "sent"
	}

	var receiverID uint
	if m.ReceiverID != nil {
		receiverID = *m.ReceiverID
	}

	return MessageResponse{
		ID:              m.ID,
		SenderID:        m.SenderID,
		ReceiverID:      receiverID,
		GroupID:         m.GroupID,
		ClientMessageID: m.ClientMessageID,
		Username:        senderUsername,
		SenderAvatar:    avatar,
		Content:         m.Content,
		Status:          status,
		MediaType:       m.MediaType,
		MediaURL:        m.MediaURL,
		DurationMs:      m.DurationMs,
		Waveform:        m.Waveform,
		ForwardFrom:     m.ForwardFrom,
		Reactions:       m.Reactions,
		IsRead:          m.IsRead,
		ReadAt:          m.ReadAt,
		Attachments:     attachmentsResp,
		Timestamp:       m.CreatedAt,
		CreatedAt:       m.CreatedAt,
	}
}

// ConversationItem represents an entry in the user's active chat list
type ConversationItem struct {
	ConversationID string           `json:"conversation_id"`
	Name           string           `json:"name"`
	AvatarURL      string           `json:"avatar_url"`
	LastMessage    *MessageResponse `json:"last_message,omitempty"`
	LastMessageAt  *time.Time       `json:"last_message_at,omitempty"`
	LastMessageID  *uint            `json:"last_message_id,omitempty"`
	UnreadCount    int              `json:"unread_count"`
	IsPinned       bool             `json:"is_pinned"`
	IsMuted        bool             `json:"is_muted"`
	User           UserResponse     `json:"user"`
}

