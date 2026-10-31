package services

import (
	"errors"
	"strings"
	"time"

	"chat_go/backend/models"
	"chat_go/backend/repository"
)

type GroupService interface {
	CreateGroup(creatorID uint, input models.CreateGroupInput) (*models.GroupResponse, error)
	GetUserGroups(userID uint) ([]models.GroupResponse, error)
	GetGroup(groupID, userID uint) (*models.GroupResponse, error)
	UpdateGroup(groupID, userID uint, input models.UpdateGroupInput) (*models.GroupResponse, error)
	AddMembers(groupID, userID uint, memberIDs []uint) error
	RemoveMember(groupID, requestingUserID, targetUserID uint) error
	GetGroupMessages(groupID, userID uint, limit, offset int, before ...uint) ([]models.MessageResponse, error)
	SendGroupMessage(senderID uint, senderUsername string, groupID uint, input models.SendMessageInput) (*models.MessageResponse, error)
	IsMember(groupID, userID uint) (bool, error)
	GetMemberIDs(groupID uint) ([]uint, error)
	MarkGroupAsRead(groupID, userID uint) (uint, error)
	GetMessageReaders(groupID, userID, messageID uint) ([]models.ReadUser, error)
}

type groupService struct {
	groupRepo   repository.GroupRepository
	messageRepo repository.MessageRepository
	userRepo    repository.UserRepository
}

func NewGroupService(groupRepo repository.GroupRepository, messageRepo repository.MessageRepository, userRepo repository.UserRepository) GroupService {
	return &groupService{
		groupRepo:   groupRepo,
		messageRepo: messageRepo,
		userRepo:    userRepo,
	}
}

func (s *groupService) CreateGroup(creatorID uint, input models.CreateGroupInput) (*models.GroupResponse, error) {
	name := strings.TrimSpace(input.Name)
	if name == "" {
		return nil, errors.New("group name is required")
	}

	group := &models.Group{
		Name:        name,
		Description: strings.TrimSpace(input.Description),
		AvatarURL:   strings.TrimSpace(input.AvatarURL),
		CreatorID:   creatorID,
	}

	if err := s.groupRepo.Create(group); err != nil {
		return nil, err
	}

	// Add creator as admin
	creatorMember := models.GroupMember{
		GroupID:  group.ID,
		UserID:   creatorID,
		Role:     "admin",
		JoinedAt: time.Now(),
	}
	_ = s.groupRepo.AddMember(&creatorMember)

	// Add other initial members
	memberMap := map[uint]bool{creatorID: true}
	var membersToAdd []models.GroupMember
	for _, mID := range input.MemberIDs {
		if mID > 0 && !memberMap[mID] {
			memberMap[mID] = true
			membersToAdd = append(membersToAdd, models.GroupMember{
				GroupID:  group.ID,
				UserID:   mID,
				Role:     "member",
				JoinedAt: time.Now(),
			})
		}
	}
	if len(membersToAdd) > 0 {
		_ = s.groupRepo.AddMembers(membersToAdd)
	}

	return s.GetGroup(group.ID, creatorID)
}

func (s *groupService) GetUserGroups(userID uint) ([]models.GroupResponse, error) {
	groups, err := s.groupRepo.FindUserGroups(userID)
	if err != nil {
		return nil, err
	}

	res := make([]models.GroupResponse, 0, len(groups))
	for _, g := range groups {
		resp := s.toGroupResponse(&g)
		lastMsg, _ := s.groupRepo.GetLastMessage(g.ID)
		if lastMsg != nil {
			var senderUsername string
			var senderAvatar string
			if lastMsg.Sender != nil {
				senderUsername = lastMsg.Sender.Username
				senderAvatar = lastMsg.Sender.AvatarURL
			}
			msgResp := lastMsg.ToResponse(senderUsername, senderAvatar)
			resp.LastMessage = &msgResp
		}
		unreadCount, _ := s.groupRepo.GetUnreadCount(g.ID, userID)
		resp.UnreadCount = unreadCount
		res = append(res, resp)
	}
	return res, nil
}

func (s *groupService) GetGroup(groupID, userID uint) (*models.GroupResponse, error) {
	isMember, err := s.groupRepo.IsMember(groupID, userID)
	if err != nil {
		return nil, err
	}
	if !isMember {
		return nil, errors.New("access denied: you are not a member of this group")
	}

	group, err := s.groupRepo.FindByID(groupID)
	if err != nil {
		return nil, err
	}
	if group == nil {
		return nil, errors.New("group not found")
	}

	resp := s.toGroupResponse(group)
	lastMsg, _ := s.groupRepo.GetLastMessage(group.ID)
	if lastMsg != nil {
		var senderUsername string
		var senderAvatar string
		if lastMsg.Sender != nil {
			senderUsername = lastMsg.Sender.Username
			senderAvatar = lastMsg.Sender.AvatarURL
		}
		msgResp := lastMsg.ToResponse(senderUsername, senderAvatar)
		resp.LastMessage = &msgResp
	}
	unreadCount, _ := s.groupRepo.GetUnreadCount(groupID, userID)
	resp.UnreadCount = unreadCount
	return &resp, nil
}

func (s *groupService) UpdateGroup(groupID, userID uint, input models.UpdateGroupInput) (*models.GroupResponse, error) {
	isMember, err := s.groupRepo.IsMember(groupID, userID)
	if err != nil {
		return nil, err
	}
	if !isMember {
		return nil, errors.New("access denied: not a member of this group")
	}

	group, err := s.groupRepo.FindByID(groupID)
	if err != nil || group == nil {
		return nil, errors.New("group not found")
	}

	if strings.TrimSpace(input.Name) != "" {
		group.Name = strings.TrimSpace(input.Name)
	}
	if input.Description != "" {
		group.Description = strings.TrimSpace(input.Description)
	}
	if input.AvatarURL != "" {
		group.AvatarURL = strings.TrimSpace(input.AvatarURL)
	}

	if err := s.groupRepo.Update(group); err != nil {
		return nil, err
	}

	return s.GetGroup(groupID, userID)
}

func (s *groupService) AddMembers(groupID, userID uint, memberIDs []uint) error {
	isMember, err := s.groupRepo.IsMember(groupID, userID)
	if err != nil || !isMember {
		return errors.New("access denied: only members can add other members")
	}

	existingMembers, err := s.groupRepo.GetMemberIDs(groupID)
	if err != nil {
		return err
	}

	existingMap := make(map[uint]bool)
	for _, id := range existingMembers {
		existingMap[id] = true
	}

	var newMembers []models.GroupMember
	now := time.Now()
	for _, mID := range memberIDs {
		if mID > 0 && !existingMap[mID] {
			existingMap[mID] = true
			newMembers = append(newMembers, models.GroupMember{
				GroupID:  groupID,
				UserID:   mID,
				Role:     "member",
				JoinedAt: now,
			})
		}
	}

	if len(newMembers) > 0 {
		return s.groupRepo.AddMembers(newMembers)
	}
	return nil
}

func (s *groupService) RemoveMember(groupID, requestingUserID, targetUserID uint) error {
	isMember, err := s.groupRepo.IsMember(groupID, requestingUserID)
	if err != nil || !isMember {
		return errors.New("access denied")
	}

	// User can leave the group (requestingUserID == targetUserID)
	// Or admin/creator can remove member
	if requestingUserID != targetUserID {
		group, err := s.groupRepo.FindByID(groupID)
		if err != nil || group == nil {
			return errors.New("group not found")
		}
		if group.CreatorID != requestingUserID {
			return errors.New("access denied: only group creator can remove members")
		}
	}

	return s.groupRepo.RemoveMember(groupID, targetUserID)
}

func (s *groupService) GetGroupMessages(groupID, userID uint, limit, offset int, before ...uint) ([]models.MessageResponse, error) {
	isMember, err := s.groupRepo.IsMember(groupID, userID)
	if err != nil || !isMember {
		return nil, errors.New("access denied: you are not a member of this group")
	}

	messages, err := s.groupRepo.GetGroupMessages(groupID, limit, offset, before...)
	if err != nil {
		return nil, err
	}

	members, _ := s.groupRepo.GetMembers(groupID)

	responses := make([]models.MessageResponse, len(messages))
	for i, msg := range messages {
		var senderUsername string
		var senderAvatar string
		if msg.Sender != nil {
			senderUsername = msg.Sender.Username
			senderAvatar = msg.Sender.AvatarURL
		}

		var seenUsers []models.ReadUser
		for _, m := range members {
			if m.UserID != msg.SenderID && m.LastReadMessageID >= msg.ID {
				username := ""
				displayName := ""
				avatar := ""
				if m.User != nil {
					username = m.User.Username
					displayName = m.User.DisplayName
					avatar = m.User.AvatarURL
				}
				seenUsers = append(seenUsers, models.ReadUser{
					UserID:      m.UserID,
					Username:    username,
					DisplayName: displayName,
					AvatarURL:   avatar,
					ReadAt:      m.LastReadAt,
				})
			}
		}

		resp := msg.ToResponse(senderUsername, senderAvatar)
		if len(seenUsers) > 0 {
			resp.IsRead = true
			resp.SeenCount = len(seenUsers)
			resp.SeenBy = seenUsers
		}
		responses[i] = resp
	}
	return responses, nil
}

func (s *groupService) SendGroupMessage(senderID uint, senderUsername string, groupID uint, input models.SendMessageInput) (*models.MessageResponse, error) {
	isMember, err := s.groupRepo.IsMember(groupID, senderID)
	if err != nil || !isMember {
		return nil, errors.New("access denied: you are not a member of this group")
	}

	clientMessageID := strings.TrimSpace(input.ClientMessageID)
	if clientMessageID != "" {
		if existing, err := s.messageRepo.FindByClientMessageID(senderID, clientMessageID); err == nil && existing != nil {
			resp := existing.ToResponse(senderUsername)
			return &resp, nil
		}
	}

	content := strings.TrimSpace(input.Content)
	mediaType := strings.TrimSpace(input.MediaType)

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

		if mediaType == "" {
			if len(attachments) > 1 && allImagesOrVideos {
				mediaType = "album"
			} else if len(attachments) == 1 {
				mediaType = attachments[0].MediaType
			} else {
				mediaType = "mixed"
			}
		}
	}

	if mediaType == "" {
		mediaType = "text"
	}
	if content == "" && len(attachments) == 0 && input.MediaURL == "" {
		return nil, errors.New("message cannot be empty")
	}

	status := strings.TrimSpace(input.Status)
	if status == "" {
		status = "sent"
	}

	var senderAvatar string
	if sender, err := s.userRepo.FindByID(senderID); err == nil && sender != nil {
		senderAvatar = sender.AvatarURL
	}

	msg := &models.Message{
		SenderID:        senderID,
		ReceiverID:      nil,
		GroupID:         &groupID,
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

	if err := s.messageRepo.Create(msg); err != nil {
		return nil, err
	}

	_, _ = s.groupRepo.MarkGroupAsRead(groupID, senderID)

	resp := msg.ToResponse(senderUsername, senderAvatar)
	return &resp, nil
}

func (s *groupService) IsMember(groupID, userID uint) (bool, error) {
	return s.groupRepo.IsMember(groupID, userID)
}

func (s *groupService) GetMemberIDs(groupID uint) ([]uint, error) {
	return s.groupRepo.GetMemberIDs(groupID)
}

func (s *groupService) MarkGroupAsRead(groupID, userID uint) (uint, error) {
	return s.groupRepo.MarkGroupAsRead(groupID, userID)
}

func (s *groupService) GetMessageReaders(groupID, userID, messageID uint) ([]models.ReadUser, error) {
	isMember, err := s.groupRepo.IsMember(groupID, userID)
	if err != nil || !isMember {
		return nil, errors.New("access denied: you are not a member of this group")
	}
	return s.groupRepo.GetMessageReaders(groupID, messageID)
}

func (s *groupService) toGroupResponse(g *models.Group) models.GroupResponse {
	memberResponses := make([]models.GroupMemberResponse, 0, len(g.Members))
	for _, m := range g.Members {
		var userResp models.UserResponse
		if m.User != nil {
			userResp = m.User.ToResponse()
		}
		memberResponses = append(memberResponses, models.GroupMemberResponse{
			ID:                m.ID,
			GroupID:           m.GroupID,
			UserID:            m.UserID,
			Role:              m.Role,
			JoinedAt:          m.JoinedAt,
			LastReadMessageID: m.LastReadMessageID,
			User:              userResp,
		})
	}

	return models.GroupResponse{
		ID:          g.ID,
		Name:        g.Name,
		Description: g.Description,
		AvatarURL:   g.AvatarURL,
		CreatorID:   g.CreatorID,
		MemberCount: len(g.Members),
		Members:     memberResponses,
		CreatedAt:   g.CreatedAt,
		UpdatedAt:   g.UpdatedAt,
	}
}
