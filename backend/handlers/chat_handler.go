package handlers

import (
	"net/http"
	"strconv"
	"time"

	"chat_go/backend/middleware"
	"chat_go/backend/models"
	"chat_go/backend/services"
	"chat_go/backend/websocket"

	"github.com/gin-gonic/gin"
)

type ChatHandler struct {
	chatService services.ChatService
	wsHub       *websocket.Hub
}

func NewChatHandler(chatService services.ChatService, wsHub *websocket.Hub) *ChatHandler {
	return &ChatHandler{
		chatService: chatService,
		wsHub:       wsHub,
	}
}

// GetConversations retrieves recent conversations for current user
// @Summary Get conversation list
// @Tags Chats
// @Security BearerAuth
// @Produce json
// @Success 200 {array} models.ConversationItem
func (h *ChatHandler) GetConversations(c *gin.Context) {
	userIDVal, exists := c.Get(middleware.ContextUserID)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	userID := userIDVal.(uint)
	conversations, err := h.chatService.GetConversations(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": conversations})
}

// GetMessages retrieves message history between current user and specified user
// @Summary Get message history
// @Tags Chats
// @Security BearerAuth
// @Produce json
// @Param userId path int true "User ID"
// @Param limit query int false "Limit"
// @Param offset query int false "Offset"
// @Success 200 {array} models.MessageResponse
func (h *ChatHandler) GetMessages(c *gin.Context) {
	userIDVal, exists := c.Get(middleware.ContextUserID)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	userID := userIDVal.(uint)
	partnerIDStr := c.Param("userId")
	partnerID, err := strconv.ParseUint(partnerIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user id"})
		return
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))
	before, _ := strconv.ParseUint(c.DefaultQuery("before", "0"), 10, 32)

	messages, err := h.chatService.GetConversation(userID, uint(partnerID), limit, offset, uint(before))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": messages})
}

// GetSharedMedia retrieves media, documents, and links between current user and partner
// @Summary Get shared media
// @Tags Chats
// @Security BearerAuth
// @Produce json
// @Param userId path int true "Partner User ID"
// @Param type query string false "Category (media, files, links)"
// @Success 200 {array} models.MessageResponse
func (h *ChatHandler) GetSharedMedia(c *gin.Context) {
	userIDVal, exists := c.Get(middleware.ContextUserID)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	userID := userIDVal.(uint)
	partnerIDStr := c.Param("userId")
	partnerID, err := strconv.ParseUint(partnerIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user id"})
		return
	}

	category := c.DefaultQuery("type", "all")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	items, err := h.chatService.GetSharedMedia(userID, uint(partnerID), category, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": items})
}

// SendMessage sends a 1-to-1 chat message via REST API
// @Summary Send chat message
// @Tags Chats
// @Security BearerAuth
// @Accept json
// @Produce json
// @Param body body models.SendMessageInput true "Message payload"
// @Success 201 {object} models.MessageResponse
func (h *ChatHandler) SendMessage(c *gin.Context) {
	userIDVal, exists := c.Get(middleware.ContextUserID)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	usernameVal, _ := c.Get(middleware.ContextUsername)
	username, _ := usernameVal.(string)

	var input models.SendMessageInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Validation error: " + err.Error()})
		return
	}

	userID := userIDVal.(uint)
	msg, err := h.chatService.SendMessage(userID, username, input)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Notify recipient via WebSocket
	if h.wsHub != nil {
		select {
		case h.wsHub.Broadcast <- websocket.Message{
			ID:              msg.ID,
			ClientMessageID: msg.ClientMessageID,
			Type:            "chat_message",
			SenderID:        userID,
			ReceiverID:      input.ReceiverID,
			Username:        username,
			SenderAvatar:    msg.SenderAvatar,
			Content:         msg.Content,
			Status:          msg.Status,
			MediaType:       msg.MediaType,
			MediaURL:        msg.MediaURL,
			DurationMs:      msg.DurationMs,
			Waveform:        msg.Waveform,
			ForwardFrom:     msg.ForwardFrom,
			IsRead:          false,
			Attachments:     msg.Attachments,
			Timestamp:       msg.CreatedAt,
		}:
		case <-time.After(1 * time.Second):
		}
	}

	c.JSON(http.StatusCreated, gin.H{"data": msg})
}

// MarkAsRead marks all incoming messages from partner as read
// @Summary Mark chat messages as read
// @Tags Chats
// @Security BearerAuth
// @Produce json
// @Param userId path int true "Sender User ID"
// @Success 200 {object} map[string]string
func (h *ChatHandler) MarkAsRead(c *gin.Context) {
	userIDVal, exists := c.Get(middleware.ContextUserID)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	userID := userIDVal.(uint)
	senderIDStr := c.Param("userId")
	senderID, err := strconv.ParseUint(senderIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user id"})
		return
	}

	if err := h.chatService.MarkAsRead(userID, uint(senderID)); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Notify original sender via WebSocket
	if h.wsHub != nil {
		select {
		case h.wsHub.Broadcast <- websocket.Message{
			Type:       "read_receipt",
			SenderID:   userID,
			ReceiverID: uint(senderID),
			ReaderID:   userID,
			Timestamp:  time.Now(),
		}:
		case <-time.After(500 * time.Millisecond):
		}
	}

	c.JSON(http.StatusOK, gin.H{"message": "Messages marked as read"})
}

// GetUnreadCount gets the total number of unread messages for the user
// @Summary Total unread messages
// @Tags Chats
// @Security BearerAuth
// @Produce json
// @Success 200 {object} map[string]int64
func (h *ChatHandler) GetUnreadCount(c *gin.Context) {
	userIDVal, exists := c.Get(middleware.ContextUserID)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	userID := userIDVal.(uint)
	count, err := h.chatService.GetUnreadCount(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"unread_count": count})
}

// DeleteMessage deletes a message by ID
// @Summary Delete chat message
// @Tags Chats
// @Security BearerAuth
// @Produce json
// @Param id path int true "Message ID"
// @Success 200 {object} map[string]interface{}
func (h *ChatHandler) DeleteMessage(c *gin.Context) {
	userIDVal, exists := c.Get(middleware.ContextUserID)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	userID := userIDVal.(uint)
	msgIDStr := c.Param("id")
	msgID, err := strconv.ParseUint(msgIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid message ID"})
		return
	}

	everyoneQuery := c.DefaultQuery("everyone", "false")
	forEveryone := everyoneQuery == "true" || everyoneQuery == "1"

	msg, err := h.chatService.GetMessageByID(uint(msgID))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Message not found"})
		return
	}
	isGroupMsg := msg.GroupID != nil && *msg.GroupID > 0
	if !isGroupMsg {
		if msg.SenderID != userID && (msg.ReceiverID == nil || *msg.ReceiverID != userID) {
			c.JSON(http.StatusForbidden, gin.H{"error": "You do not have permission to delete this message"})
			return
		}
	}

	// Only the sender can delete for everyone
	if forEveryone && msg.SenderID != userID {
		c.JSON(http.StatusForbidden, gin.H{"error": "Only the sender can delete this message for everyone"})
		return
	}

	if err := h.chatService.DeleteMessage(uint(msgID), userID, forEveryone); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Determine partner ID for socket broadcast
	var partnerID uint
	if msg.ReceiverID != nil {
		partnerID = *msg.ReceiverID
		if *msg.ReceiverID == userID {
			partnerID = msg.SenderID
		}
	}

	var groupID uint
	if isGroupMsg {
		groupID = *msg.GroupID
	}

	// Only broadcast to partner/group if deleted for everyone!
	if forEveryone && h.wsHub != nil {
		select {
		case h.wsHub.Broadcast <- websocket.Message{
			ID:         uint(msgID),
			MessageID:  uint(msgID),
			GroupID:    groupID,
			Type:       "message_deleted",
			SenderID:   userID,
			ReceiverID: partnerID,
			Timestamp:  time.Now(),
			Payload: map[string]interface{}{
				"message_id":   uint(msgID),
				"sender_id":    userID,
				"receiver_id":  partnerID,
				"group_id":     groupID,
				"for_everyone": true,
			},
		}:
		case <-time.After(1 * time.Second):
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"message":      "Message deleted successfully",
		"id":           msgID,
		"for_everyone": forEveryone,
	})
}

// DeleteConversation deletes all messages in a conversation
func (h *ChatHandler) DeleteConversation(c *gin.Context) {
	partnerIDStr := c.Param("userId")
	partnerID, err := strconv.ParseUint(partnerIDStr, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	userID := c.GetUint("userID")
	everyoneQuery := c.DefaultQuery("everyone", "false")
	forEveryone := everyoneQuery == "true" || everyoneQuery == "1"

	if err := h.chatService.DeleteConversation(userID, uint(partnerID), forEveryone); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// If deleted for everyone, broadcast WebSocket event
	if forEveryone && h.wsHub != nil {
		select {
		case h.wsHub.Broadcast <- websocket.Message{
			Type:       "conversation_deleted",
			SenderID:   userID,
			ReceiverID: uint(partnerID),
			Timestamp:  time.Now(),
			Payload: map[string]interface{}{
				"partner_id":   userID,
				"for_everyone": true,
			},
		}:
		case <-time.After(1 * time.Second):
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"message":      "Conversation deleted successfully",
		"partner_id":   partnerID,
		"for_everyone": forEveryone,
	})
}

// ReactMessageInput defines reaction payload
type ReactMessageInput struct {
	Emoji string `json:"emoji" binding:"required"`
}

// ReactMessage toggles an emoji reaction on a message
// @Summary React to message
// @Tags Chats
// @Security BearerAuth
// @Accept json
// @Produce json
// @Param id path int true "Message ID"
// @Param body body ReactMessageInput true "Reaction Emoji"
// @Success 200 {object} map[string]interface{}
func (h *ChatHandler) ReactMessage(c *gin.Context) {
	userIDVal, exists := c.Get(middleware.ContextUserID)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	userID := userIDVal.(uint)
	msgIDStr := c.Param("id")
	msgID, err := strconv.ParseUint(msgIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid message ID"})
		return
	}

	var input ReactMessageInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Emoji is required"})
		return
	}

	reactions, msg, err := h.chatService.ToggleReaction(uint(msgID), userID, input.Emoji)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Determine partner ID
	var partnerID uint
	if msg.ReceiverID != nil {
		partnerID = *msg.ReceiverID
		if *msg.ReceiverID == userID {
			partnerID = msg.SenderID
		}
	}

	var groupID uint
	if msg.GroupID != nil && *msg.GroupID > 0 {
		groupID = *msg.GroupID
	}

	// Notify via WebSocket
	if h.wsHub != nil {
		select {
		case h.wsHub.Broadcast <- websocket.Message{
			ID:         uint(msgID),
			MessageID:  uint(msgID),
			GroupID:    groupID,
			Type:       "message_reaction",
			SenderID:   userID,
			ReceiverID: partnerID,
			Reactions:  reactions,
			Timestamp:  time.Now(),
			Payload: map[string]interface{}{
				"message_id": uint(msgID),
				"reactions":  reactions,
				"emoji":      input.Emoji,
				"user_id":    userID,
				"group_id":   groupID,
			},
		}:
		case <-time.After(1 * time.Second):
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"message_id": msgID,
		"reactions":  reactions,
	})
}
