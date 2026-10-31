package services

import (
	"encoding/json"
	"errors"
	"strings"

	"chat_go/backend/models"
	"chat_go/backend/repository"
)

type ChatService interface {
	SendMessage(senderID uint, senderUsername string, input models.SendMessageInput) (*models.MessageResponse, error)
	GetConversation(user1ID, user2ID uint, limit, offset int, before ...uint) ([]models.MessageResponse, error)
	GetConversations(userID uint) ([]models.ConversationItem, error)
	MarkAsRead(currentUserID, senderUserID uint) error
	GetUnreadCount(userID uint) (int64, error)
	GetMessageByID(messageID uint) (*models.Message, error)
	DeleteMessage(messageID, userID uint, forEveryone ...bool) error
	DeleteConversation(userID, partnerID uint, forEveryone bool) error
	ToggleReaction(messageID, userID uint, emoji string) (string, *models.Message, error)
	GetSharedMedia(user1ID, user2ID uint, mediaCategory string, limit, offset int) ([]models.MessageResponse, error)
}

type chatService struct {
	messageRepo repository.MessageRepository
	userRepo    repository.UserRepository
}

func NewChatService(messageRepo repository.MessageRepository, userRepo repository.UserRepository) ChatService {
	return &chatService{
		messageRepo: messageRepo,
		userRepo:    userRepo,
	}
}

func (s *chatService) SendMessage(senderID uint, senderUsername string, input models.SendMessageInput) (*models.MessageResponse, error) {
	if input.ReceiverID == 0 {
		return nil, errors.New("receiver_id is required")
	}
	if input.ReceiverID == senderID {
		return nil, errors.New("cannot send message to self")
	}

	// Idempotency check with client_message_id
	clientMessageID := strings.TrimSpace(input.ClientMessageID)
	if clientMessageID != "" {
		if existing, err := s.messageRepo.FindByClientMessageID(senderID, clientMessageID); err == nil && existing != nil {
			resp := existing.ToResponse(senderUsername)
			return &resp, nil
		}
	}

	content := strings.TrimSpace(input.Content)
	mediaType := strings.TrimSpace(input.MediaType)

	// Process attachments
	var attachments []models.MessageAttachment
	if len(input.Attachments) > 0 {
		attachments = make([]models.MessageAttachment, len(input.Attachments))
		allImagesOrVideos := true
		for i, att := range input.Attachments {
			aType := strings.TrimSpace(att.MediaType)
			if aType == "" {
				aType = "file"
			}
			if aType != "image" && aType != "photo" && aType != "video" {
				allImagesOrVideos = false
			}
			uploadStatus := strings.TrimSpace(att.UploadStatus)
			if uploadStatus == "" {
				uploadStatus = "completed"
			}
			attachments[i] = models.MessageAttachment{
				MediaType:    aType,
				MimeType:     strings.TrimSpace(att.MimeType),
				FileName:     strings.TrimSpace(att.FileName),
				SizeBytes:    att.SizeBytes,
				Width:        att.Width,
				Height:       att.Height,
				DurationMs:   att.DurationMs,
				StorageKey:   strings.TrimSpace(att.StorageKey),
				URL:          strings.TrimSpace(att.URL),
				UploadStatus: uploadStatus,
				SortOrder:    att.SortOrder,
			}
		}

		if mediaType == "" || mediaType == "text" {
			if len(attachments) > 1 {
				if allImagesOrVideos {
					mediaType = "album"
				} else {
					mediaType = "mixed"
				}
			} else {
				mediaType = attachments[0].MediaType
			}
		}

		if input.MediaURL == "" && len(attachments) > 0 {
			input.MediaURL = attachments[0].URL
		}
	}

	if mediaType == "" {
		mediaType = "text"
	}

	if content == "" && input.MediaURL == "" && len(attachments) == 0 {
		return nil, errors.New("message content or attachments required")
	}

	// Verify receiver exists
	receiver, err := s.userRepo.FindByID(input.ReceiverID)
	if err != nil || receiver == nil {
		return nil, errors.New("recipient not found")
	}

	status := strings.TrimSpace(input.Status)
	if status == "" {
		status = "sent"
	}

	msg := models.Message{
		SenderID:        senderID,
		ReceiverID:      &input.ReceiverID,
		ClientMessageID: clientMessageID,
		Content:         content,
		Status:          status,
		MediaType:       mediaType,
		MediaURL:        strings.TrimSpace(input.MediaURL),
		DurationMs:      input.DurationMs,
		Waveform:        strings.TrimSpace(input.Waveform),
		ForwardFrom:     strings.TrimSpace(input.ForwardFrom),
		IsRead:          false,
		Attachments:     attachments,
	}

	if err := s.messageRepo.Create(&msg); err != nil {
		return nil, err
	}

	senderAvatar := ""
	if s.userRepo != nil {
		if senderUser, err := s.userRepo.FindByID(senderID); err == nil && senderUser != nil {
			senderAvatar = senderUser.AvatarURL
		}
	}

	resp := msg.ToResponse(senderUsername, senderAvatar)
	return &resp, nil
}

func (s *chatService) GetConversation(user1ID, user2ID uint, limit, offset int, before ...uint) ([]models.MessageResponse, error) {
	messages, err := s.messageRepo.GetConversation(user1ID, user2ID, limit, offset, before...)
	if err != nil {
		return nil, err
	}

	result := make([]models.MessageResponse, len(messages))
	for i, m := range messages {
		senderName := ""
		senderAvatar := ""
		if m.Sender != nil {
			senderName = m.Sender.Username
			senderAvatar = m.Sender.AvatarURL
		}
		result[i] = m.ToResponse(senderName, senderAvatar)
	}

	return result, nil
}

func (s *chatService) GetConversations(userID uint) ([]models.ConversationItem, error) {
	return s.messageRepo.GetRecentConversations(userID)
}

func (s *chatService) MarkAsRead(currentUserID, senderUserID uint) error {
	return s.messageRepo.MarkMessagesAsRead(senderUserID, currentUserID)
}

func (s *chatService) GetUnreadCount(userID uint) (int64, error) {
	return s.messageRepo.GetUnreadCount(userID)
}

func (s *chatService) GetMessageByID(messageID uint) (*models.Message, error) {
	return s.messageRepo.GetMessageByID(messageID)
}

func (s *chatService) DeleteMessage(messageID, userID uint, forEveryone ...bool) error {
	return s.messageRepo.DeleteMessage(messageID, userID, forEveryone...)
}

func (s *chatService) DeleteConversation(userID, partnerID uint, forEveryone bool) error {
	return s.messageRepo.DeleteConversation(userID, partnerID, forEveryone)
}

func (s *chatService) ToggleReaction(messageID, userID uint, emoji string) (string, *models.Message, error) {
	emoji = strings.TrimSpace(emoji)
	if emoji == "" {
		return "", nil, errors.New("emoji cannot be empty")
	}

	msg, err := s.messageRepo.GetMessageByID(messageID)
	if err != nil {
		return "", nil, err
	}

	// Parse current reactions map e.g. {"❤️": [1, 2], "👍": [1]}
	reactionsMap := make(map[string][]uint)
	if msg.Reactions != "" {
		_ = json.Unmarshal([]byte(msg.Reactions), &reactionsMap)
	}

	// Check if user already reacted with this exact emoji
	alreadyHadThisEmoji := false
	if currentList, ok := reactionsMap[emoji]; ok {
		for _, uID := range currentList {
			if uID == userID {
				alreadyHadThisEmoji = true
				break
			}
		}
	}

	// Enforce ONE reaction per user: Remove userID from ALL emojis in reactionsMap
	for k, list := range reactionsMap {
		filtered := make([]uint, 0, len(list))
		for _, uID := range list {
			if uID != userID {
				filtered = append(filtered, uID)
			}
		}
		if len(filtered) == 0 {
			delete(reactionsMap, k)
		} else {
			reactionsMap[k] = filtered
		}
	}

	// If user did NOT already have this emoji, add it now (if they did, it toggles off)
	if !alreadyHadThisEmoji {
		reactionsMap[emoji] = append(reactionsMap[emoji], userID)
	}

	var updatedReactions string
	if len(reactionsMap) > 0 {
		bytes, err := json.Marshal(reactionsMap)
		if err == nil {
			updatedReactions = string(bytes)
		}
	} else {
		updatedReactions = "{}"
	}

	if err := s.messageRepo.UpdateReactions(messageID, updatedReactions); err != nil {
		return "", nil, err
	}

	msg.Reactions = updatedReactions
	return updatedReactions, msg, nil
}

func (s *chatService) GetSharedMedia(user1ID, user2ID uint, mediaCategory string, limit, offset int) ([]models.MessageResponse, error) {
	messages, err := s.messageRepo.GetSharedMedia(user1ID, user2ID, mediaCategory, limit, offset)
	if err != nil {
		return nil, err
	}

	result := make([]models.MessageResponse, len(messages))
	for i, m := range messages {
		senderName := ""
		senderAvatar := ""
		if m.Sender != nil {
			senderName = m.Sender.DisplayName
			if senderName == "" {
				senderName = m.Sender.Username
			}
			senderAvatar = m.Sender.AvatarURL
		}
		result[i] = m.ToResponse(senderName, senderAvatar)
	}

	return result, nil
}
