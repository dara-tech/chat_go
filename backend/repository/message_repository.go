package repository

import (
	"fmt"
	"time"

	"chat_go/backend/models"

	"gorm.io/gorm"
)

type MessageRepository interface {
	Create(message *models.Message) error
	GetConversation(user1ID, user2ID uint, limit, offset int, before ...uint) ([]models.Message, error)
	MarkMessagesAsRead(senderID, receiverID uint) error
	GetRecentConversations(userID uint) ([]models.ConversationItem, error)
	GetUnreadCount(userID uint) (int64, error)
	GetMessageByID(messageID uint) (*models.Message, error)
	FindByClientMessageID(senderID uint, clientMessageID string) (*models.Message, error)
	DeleteMessage(messageID, userID uint, forEveryone ...bool) error
	DeleteConversation(userID, partnerID uint, forEveryone bool) error
	UpdateReactions(messageID uint, reactions string) error
	GetSharedMedia(user1ID, user2ID uint, mediaCategory string, limit, offset int) ([]models.Message, error)
}

type messageRepository struct {
	db *gorm.DB
}

func NewMessageRepository(db *gorm.DB) MessageRepository {
	return &messageRepository{db: db}
}

func (r *messageRepository) Create(message *models.Message) error {
	return r.db.Create(message).Error
}

func (r *messageRepository) GetConversation(user1ID, user2ID uint, limit, offset int, before ...uint) ([]models.Message, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	if offset < 0 {
		offset = 0
	}

	query := r.db.
		Preload("Sender").
		Preload("Receiver").
		Preload("Attachments", func(db *gorm.DB) *gorm.DB {
			return db.Order("message_attachments.sort_order asc, message_attachments.id asc")
		}).
		Where("((sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)) AND deleted_at IS NULL", user1ID, user2ID, user2ID, user1ID).
		Where("NOT (sender_id = ? AND deleted_by_sender = true)", user1ID).
		Where("NOT (receiver_id = ? AND deleted_by_receiver = true)", user1ID)

	if len(before) > 0 && before[0] > 0 {
		query = query.Where("id < ?", before[0])
	}

	var messages []models.Message
	err := query.
		Order("id desc").
		Limit(limit).
		Offset(offset).
		Find(&messages).Error

	if err != nil {
		return nil, err
	}

	// Reverse so messages are in ascending chronological order for client display
	for i, j := 0, len(messages)-1; i < j; i, j = i+1, j-1 {
		messages[i], messages[j] = messages[j], messages[i]
	}

	return messages, nil
}

func (r *messageRepository) MarkMessagesAsRead(senderID, receiverID uint) error {
	now := time.Now()
	return r.db.Model(&models.Message{}).
		Where("sender_id = ? AND receiver_id = ? AND is_read = false", senderID, receiverID).
		Updates(map[string]interface{}{
			"is_read": true,
			"read_at": &now,
		}).Error
}

func (r *messageRepository) GetUnreadCount(userID uint) (int64, error) {
	var count int64
	err := r.db.Model(&models.Message{}).
		Where("receiver_id = ? AND is_read = false", userID).
		Count(&count).Error
	return count, err
}

func (r *messageRepository) GetRecentConversations(userID uint) ([]models.ConversationItem, error) {
	// Find all distinct counterpart IDs
	type ChatPartner struct {
		PartnerID uint `gorm:"column:partner_id"`
		MaxID     uint `gorm:"column:max_id"`
	}

	var partners []ChatPartner
	rawQuery := `
		SELECT 
			CASE WHEN sender_id = ? THEN receiver_id ELSE sender_id END AS partner_id,
			MAX(id) AS max_id
		FROM messages
		WHERE (sender_id = ? OR receiver_id = ?) 
		  AND deleted_at IS NULL
		  AND NOT (sender_id = ? AND deleted_by_sender = true)
		  AND NOT (receiver_id = ? AND deleted_by_receiver = true)
		GROUP BY partner_id
		ORDER BY max_id DESC
		LIMIT 50
	`
	if err := r.db.Raw(rawQuery, userID, userID, userID, userID, userID).Scan(&partners).Error; err != nil {
		return nil, err
	}

	var conversations []models.ConversationItem
	for _, p := range partners {
		// Fetch partner user details
		var partner models.User
		if err := r.db.First(&partner, p.PartnerID).Error; err != nil {
			continue
		}

		// Fetch last message strictly by newest id where deleted_at IS NULL
		var lastMsg models.Message
		err := r.db.
			Preload("Sender").
			Preload("Attachments", func(db *gorm.DB) *gorm.DB {
				return db.Order("message_attachments.sort_order asc, message_attachments.id asc")
			}).
			Where("((sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)) AND deleted_at IS NULL",
				userID, p.PartnerID, p.PartnerID, userID).
			Where("NOT (sender_id = ? AND deleted_by_sender = true)", userID).
			Where("NOT (receiver_id = ? AND deleted_by_receiver = true)", userID).
			Order("id desc").
			Take(&lastMsg).Error

		if err != nil {
			// All messages in this conversation were deleted
			continue
		}

		senderUsername := partner.Username
		if lastMsg.SenderID == userID {
			senderUsername = "You"
		}
		resp := lastMsg.ToResponse(senderUsername)

		// Count unread from this partner
		var unread int64
		_ = r.db.Model(&models.Message{}).
			Where("sender_id = ? AND receiver_id = ? AND is_read = false AND deleted_at IS NULL", p.PartnerID, userID).
			Count(&unread)

		var lastMessageAt *time.Time
		var lastMessageID *uint
		if lastMsg.ID != 0 {
			lastMessageAt = &lastMsg.CreatedAt
			lastMessageID = &lastMsg.ID
		}

		name := partner.DisplayName
		if name == "" {
			name = partner.Username
		}

		conversations = append(conversations, models.ConversationItem{
			ConversationID: fmt.Sprintf("chat_%d", partner.ID),
			Name:           name,
			AvatarURL:      partner.AvatarURL,
			LastMessage:    &resp,
			LastMessageAt:  lastMessageAt,
			LastMessageID:  lastMessageID,
			UnreadCount:    int(unread),
			IsPinned:       false,
			IsMuted:        false,
			User:           partner.ToResponse(),
		})
	}

	return conversations, nil
}

func (r *messageRepository) GetMessageByID(messageID uint) (*models.Message, error) {
	var msg models.Message
	err := r.db.
		Preload("Sender").
		Preload("Receiver").
		Preload("Attachments", func(db *gorm.DB) *gorm.DB {
			return db.Order("message_attachments.sort_order asc, message_attachments.id asc")
		}).
		First(&msg, messageID).Error
	return &msg, err
}

func (r *messageRepository) FindByClientMessageID(senderID uint, clientMessageID string) (*models.Message, error) {
	if clientMessageID == "" {
		return nil, gorm.ErrRecordNotFound
	}
	var msg models.Message
	err := r.db.
		Preload("Sender").
		Preload("Receiver").
		Preload("Attachments", func(db *gorm.DB) *gorm.DB {
			return db.Order("message_attachments.sort_order asc, message_attachments.id asc")
		}).
		Where("sender_id = ? AND client_message_id = ? AND deleted_at IS NULL", senderID, clientMessageID).
		First(&msg).Error
	return &msg, err
}

func (r *messageRepository) DeleteMessage(messageID, userID uint, forEveryone ...bool) error {
	isEveryone := len(forEveryone) > 0 && forEveryone[0]
	if isEveryone {
		return r.db.Where("id = ? AND sender_id = ?", messageID, userID).
			Delete(&models.Message{}).Error
	}

	var msg models.Message
	if err := r.db.Where("id = ?", messageID).First(&msg).Error; err != nil {
		return err
	}

	updates := map[string]interface{}{}
	if msg.SenderID == userID {
		updates["deleted_by_sender"] = true
	}
	if msg.ReceiverID != nil && *msg.ReceiverID == userID {
		updates["deleted_by_receiver"] = true
	}

	// If both users deleted for themselves (direct chat), soft-delete the row entirely
	if (msg.SenderID == userID && msg.DeletedByReceiver) || (msg.ReceiverID != nil && *msg.ReceiverID == userID && msg.DeletedBySender) {
		return r.db.Delete(&msg).Error
	}

	return r.db.Model(&msg).Updates(updates).Error
}

func (r *messageRepository) DeleteConversation(userID, partnerID uint, forEveryone bool) error {
	if forEveryone {
		return r.db.Where("((sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)) AND deleted_at IS NULL",
			userID, partnerID, partnerID, userID).
			Delete(&models.Message{}).Error
	}

	// Delete for me only:
	// Messages where I am the sender: set deleted_by_sender = true
	if err := r.db.Model(&models.Message{}).
		Where("sender_id = ? AND receiver_id = ? AND deleted_at IS NULL", userID, partnerID).
		Update("deleted_by_sender", true).Error; err != nil {
		return err
	}
	// Messages where I am the receiver: set deleted_by_receiver = true
	if err := r.db.Model(&models.Message{}).
		Where("receiver_id = ? AND sender_id = ? AND deleted_at IS NULL", userID, partnerID).
		Update("deleted_by_receiver", true).Error; err != nil {
		return err
	}

	// Soft-delete any messages where both deleted_by_sender and deleted_by_receiver are now true
	return r.db.Where("((sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)) AND deleted_by_sender = true AND deleted_by_receiver = true",
		userID, partnerID, partnerID, userID).
		Delete(&models.Message{}).Error
}

func (r *messageRepository) UpdateReactions(messageID uint, reactions string) error {
	return r.db.Model(&models.Message{}).Where("id = ?", messageID).Update("reactions", reactions).Error
}

func (r *messageRepository) GetSharedMedia(user1ID, user2ID uint, mediaCategory string, limit, offset int) ([]models.Message, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	if offset < 0 {
		offset = 0
	}

	query := r.db.
		Preload("Sender").
		Preload("Receiver").
		Preload("Attachments", func(db *gorm.DB) *gorm.DB {
			return db.Order("message_attachments.sort_order asc, message_attachments.id asc")
		}).
		Where("((sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)) AND deleted_at IS NULL", user1ID, user2ID, user2ID, user1ID).
		Where("NOT (sender_id = ? AND deleted_by_sender = true)", user1ID).
		Where("NOT (receiver_id = ? AND deleted_by_receiver = true)", user1ID)

	switch mediaCategory {
	case "media":
		query = query.Where("(media_type IN ('image', 'photo', 'video', 'album') OR EXISTS (SELECT 1 FROM message_attachments a WHERE a.message_id = messages.id AND a.media_type IN ('image', 'video')))")
	case "files":
		query = query.Where("(media_type IN ('file', 'audio', 'voice', 'document') OR EXISTS (SELECT 1 FROM message_attachments a WHERE a.message_id = messages.id AND a.media_type IN ('document', 'file', 'audio', 'voice')))")
	case "links":
		query = query.Where("(content LIKE '%http://%' OR content LIKE '%https://%') AND content NOT LIKE '%flutter.dev%' AND content NOT LIKE '%carto.com%' AND content NOT LIKE '%gin-gonic.com%'")
	default:
		query = query.Where("((media_type != 'text' AND media_url != '') OR EXISTS (SELECT 1 FROM message_attachments a WHERE a.message_id = messages.id) OR content LIKE '%http://%' OR content LIKE '%https://%')")
	}

	var messages []models.Message
	err := query.Order("id desc").Limit(limit).Offset(offset).Find(&messages).Error
	return messages, err
}
