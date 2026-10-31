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

type GroupHandler struct {
	groupService services.GroupService
	wsHub        *websocket.Hub
}

func NewGroupHandler(groupService services.GroupService, wsHub *websocket.Hub) *GroupHandler {
	return &GroupHandler{
		groupService: groupService,
		wsHub:        wsHub,
	}
}

// CreateGroup creates a new group chat
// @Summary Create group
// @Tags Groups
// @Security BearerAuth
// @Accept json
// @Produce json
// @Param body body models.CreateGroupInput true "Create Group Body"
// @Success 201 {object} models.GroupResponse
func (h *GroupHandler) CreateGroup(c *gin.Context) {
	userIDVal, exists := c.Get(middleware.ContextUserID)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(uint)

	var input models.CreateGroupInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	group, err := h.groupService.CreateGroup(userID, input)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"data": group})
}

// GetGroups retrieves all groups the authenticated user belongs to
// @Summary Get user groups
// @Tags Groups
// @Security BearerAuth
// @Produce json
// @Success 200 {array} models.GroupResponse
func (h *GroupHandler) GetGroups(c *gin.Context) {
	userIDVal, exists := c.Get(middleware.ContextUserID)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(uint)

	groups, err := h.groupService.GetUserGroups(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": groups})
}

// GetGroup retrieves group details by ID
// @Summary Get group details
// @Tags Groups
// @Security BearerAuth
// @Produce json
// @Param groupId path int true "Group ID"
// @Success 200 {object} models.GroupResponse
func (h *GroupHandler) GetGroup(c *gin.Context) {
	userIDVal, exists := c.Get(middleware.ContextUserID)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(uint)

	groupIDStr := c.Param("groupId")
	groupID, err := strconv.ParseUint(groupIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid group ID"})
		return
	}

	group, err := h.groupService.GetGroup(uint(groupID), userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": group})
}

// UpdateGroup updates group metadata
// @Summary Update group
// @Tags Groups
// @Security BearerAuth
// @Accept json
// @Produce json
// @Param groupId path int true "Group ID"
// @Param body body models.UpdateGroupInput true "Update Group Body"
// @Success 200 {object} models.GroupResponse
func (h *GroupHandler) UpdateGroup(c *gin.Context) {
	userIDVal, exists := c.Get(middleware.ContextUserID)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(uint)

	groupIDStr := c.Param("groupId")
	groupID, err := strconv.ParseUint(groupIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid group ID"})
		return
	}

	var input models.UpdateGroupInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	group, err := h.groupService.UpdateGroup(uint(groupID), userID, input)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": group})
}

// AddMembers adds users to the group
// @Summary Add members to group
// @Tags Groups
// @Security BearerAuth
// @Accept json
// @Produce json
// @Param groupId path int true "Group ID"
// @Param body body models.AddMembersInput true "Member IDs"
// @Success 200 {object} map[string]string
func (h *GroupHandler) AddMembers(c *gin.Context) {
	userIDVal, exists := c.Get(middleware.ContextUserID)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(uint)

	groupIDStr := c.Param("groupId")
	groupID, err := strconv.ParseUint(groupIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid group ID"})
		return
	}

	var input models.AddMembersInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := h.groupService.AddMembers(uint(groupID), userID, input.MemberIDs); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Members added successfully"})
}

// RemoveMember removes a user from the group (admin or self)
// @Summary Remove member from group
// @Tags Groups
// @Security BearerAuth
// @Produce json
// @Param groupId path int true "Group ID"
// @Param userId path int true "User ID to remove"
// @Success 200 {object} map[string]string
func (h *GroupHandler) RemoveMember(c *gin.Context) {
	userIDVal, exists := c.Get(middleware.ContextUserID)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	requestingUserID := userIDVal.(uint)

	groupIDStr := c.Param("groupId")
	groupID, err := strconv.ParseUint(groupIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid group ID"})
		return
	}

	targetUserIDStr := c.Param("userId")
	targetUserID, err := strconv.ParseUint(targetUserIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid target user ID"})
		return
	}

	if err := h.groupService.RemoveMember(uint(groupID), requestingUserID, uint(targetUserID)); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Member removed successfully"})
}

// LeaveGroup leaves the group
// @Summary Leave group
// @Tags Groups
// @Security BearerAuth
// @Produce json
// @Param groupId path int true "Group ID"
// @Success 200 {object} map[string]string
func (h *GroupHandler) LeaveGroup(c *gin.Context) {
	userIDVal, exists := c.Get(middleware.ContextUserID)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(uint)

	groupIDStr := c.Param("groupId")
	groupID, err := strconv.ParseUint(groupIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid group ID"})
		return
	}

	if err := h.groupService.RemoveMember(uint(groupID), userID, userID); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Left group successfully"})
}

// GetGroupMessages returns message history for a group
// @Summary Get group messages
// @Tags Groups
// @Security BearerAuth
// @Produce json
// @Param groupId path int true "Group ID"
// @Param limit query int false "Limit"
// @Param offset query int false "Offset"
// @Param before query int false "Before message ID"
// @Success 200 {array} models.MessageResponse
func (h *GroupHandler) GetGroupMessages(c *gin.Context) {
	userIDVal, exists := c.Get(middleware.ContextUserID)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(uint)

	groupIDStr := c.Param("groupId")
	groupID, err := strconv.ParseUint(groupIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid group ID"})
		return
	}

	limit := 50
	if lStr := c.Query("limit"); lStr != "" {
		if l, err := strconv.Atoi(lStr); err == nil && l > 0 && l <= 100 {
			limit = l
		}
	}

	offset := 0
	if oStr := c.Query("offset"); oStr != "" {
		if o, err := strconv.Atoi(oStr); err == nil && o >= 0 {
			offset = o
		}
	}

	var before []uint
	if beforeStr := c.Query("before"); beforeStr != "" {
		if bID, err := strconv.ParseUint(beforeStr, 10, 32); err == nil && bID > 0 {
			before = append(before, uint(bID))
		}
	}

	messages, err := h.groupService.GetGroupMessages(uint(groupID), userID, limit, offset, before...)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": messages})
}

// SendGroupMessage sends a message to a group
// @Summary Send message to group
// @Tags Groups
// @Security BearerAuth
// @Accept json
// @Produce json
// @Param groupId path int true "Group ID"
// @Param body body models.SendMessageInput true "Message payload"
// @Success 201 {object} models.MessageResponse
func (h *GroupHandler) SendGroupMessage(c *gin.Context) {
	userIDVal, exists := c.Get(middleware.ContextUserID)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(uint)

	usernameVal, _ := c.Get(middleware.ContextUsername)
	username, _ := usernameVal.(string)

	groupIDStr := c.Param("groupId")
	groupID64, err := strconv.ParseUint(groupIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid group ID"})
		return
	}
	groupID := uint(groupID64)

	var input models.SendMessageInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	input.GroupID = &groupID

	msg, err := h.groupService.SendGroupMessage(userID, username, groupID, input)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Broadcast to WebSocket hub
	if h.wsHub != nil {
		h.wsHub.Broadcast <- websocket.Message{
			ID:              msg.ID,
			ClientMessageID: msg.ClientMessageID,
			Type:            "group_message",
			SenderID:        msg.SenderID,
			GroupID:         groupID,
			Username:        msg.Username,
			SenderAvatar:    msg.SenderAvatar,
			Content:         msg.Content,
			Status:          msg.Status,
			MediaType:       msg.MediaType,
			MediaURL:        msg.MediaURL,
			DurationMs:      msg.DurationMs,
			Waveform:        msg.Waveform,
			ForwardFrom:     msg.ForwardFrom,
			Reactions:       msg.Reactions,
			Attachments:     msg.Attachments,
			Timestamp:       msg.CreatedAt,
		}
	}

	c.JSON(http.StatusCreated, gin.H{"data": msg})
}

// MarkGroupAsRead marks all messages in a group as read for the current user
// @Summary Mark group as read
// @Tags Groups
// @Security BearerAuth
// @Produce json
// @Param groupId path int true "Group ID"
// @Success 200 {object} map[string]interface{}
func (h *GroupHandler) MarkGroupAsRead(c *gin.Context) {
	userIDVal, exists := c.Get(middleware.ContextUserID)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(uint)

	groupIDStr := c.Param("groupId")
	groupID, err := strconv.ParseUint(groupIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid group ID"})
		return
	}

	maxID, err := h.groupService.MarkGroupAsRead(uint(groupID), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Broadcast group_read to group members via WebSocket
	if h.wsHub != nil {
		h.wsHub.Broadcast <- websocket.Message{
			Type:      "group_read",
			GroupID:   uint(groupID),
			SenderID:  userID,
			ReaderID:  userID,
			MessageID: maxID,
			Timestamp: time.Now(),
			Payload: map[string]interface{}{
				"group_id":       uint(groupID),
				"reader_id":      userID,
				"max_message_id": maxID,
			},
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"message":        "Group marked as read",
		"group_id":       groupID,
		"max_message_id": maxID,
	})
}

// GetMessageReaders returns the list of members who read a specific message
func (h *GroupHandler) GetMessageReaders(c *gin.Context) {
	userIDVal, exists := c.Get(middleware.ContextUserID)
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(uint)

	groupIDStr := c.Param("groupId")
	groupID, err := strconv.ParseUint(groupIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid group ID"})
		return
	}

	messageIDStr := c.Param("messageId")
	messageID, err := strconv.ParseUint(messageIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid message ID"})
		return
	}

	readers, err := h.groupService.GetMessageReaders(uint(groupID), userID, uint(messageID))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"data":  readers,
		"count": len(readers),
	})
}
