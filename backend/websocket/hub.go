package websocket

import (
	"encoding/json"
	"log"
	"sync"
	"time"
	"chat_go/backend/models"
	"chat_go/backend/services"
)

// Message represents real-time chat payload
type Message struct {
	ID              uint                              `json:"id,omitempty"`
	MessageID       uint                              `json:"message_id,omitempty"`
	ClientMessageID string                            `json:"client_message_id,omitempty"`
	Type            string                            `json:"type"` // e.g. "chat_message", "user_status", "read_receipt", "typing"
	SenderID        uint                              `json:"sender_id,omitempty"`
	ReceiverID      uint                              `json:"receiver_id,omitempty"`
	ReaderID        uint                              `json:"reader_id,omitempty"`
	Username        string                            `json:"username,omitempty"`
	SenderAvatar    string                            `json:"sender_avatar,omitempty"`
	Content         string                            `json:"content,omitempty"`
	Status          string                            `json:"status,omitempty"`
	MediaType       string                            `json:"media_type,omitempty"` // text, image, audio, video, file, voice, album, mixed
	MediaURL        string                            `json:"media_url,omitempty"`
	DurationMs      int                               `json:"duration_ms,omitempty"`
	Waveform        string                            `json:"waveform,omitempty"`
	ForwardFrom     string                            `json:"forward_from,omitempty"`
	Reactions       string                            `json:"reactions"`
	IsRead          bool                              `json:"is_read,omitempty"`
	IsTyping        bool                              `json:"is_typing"`
	Attachments     []models.MessageAttachmentResponse `json:"attachments,omitempty"`
	Payload         interface{}                       `json:"payload,omitempty"`
	GroupID         uint                              `json:"group_id,omitempty"`
	Timestamp       time.Time                         `json:"timestamp"`
}

// Hub maintains active authenticated clients and delivers messages (both 1-to-1, group, and broadcast)
type Hub struct {
	// Registered clients mapped by client pointer
	clients map[*Client]bool

	// User ID to active clients mapping (allows multiple tabs/devices per user)
	userClients map[uint]map[*Client]bool

	// Inbound messages from clients (buffered for high throughput)
	Broadcast chan Message

	// Register requests from clients
	Register chan *Client

	// Unregister requests from clients
	Unregister chan *Client

	// Auth, Chat, and Group services
	authService  services.AuthService
	chatService  services.ChatService
	groupService services.GroupService

	mu sync.RWMutex
}

func NewHub(authService services.AuthService, chatService services.ChatService) *Hub {
	return &Hub{
		Broadcast:   make(chan Message, 512),
		Register:    make(chan *Client, 128),
		Unregister:  make(chan *Client, 128),
		clients:     make(map[*Client]bool),
		userClients: make(map[uint]map[*Client]bool),
		authService: authService,
		chatService: chatService,
	}
}

func (h *Hub) SetGroupService(groupService services.GroupService) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.groupService = groupService
}

func (h *Hub) Run() {
	for {
		select {
		case client := <-h.Register:
			h.mu.Lock()
			h.clients[client] = true
			if h.userClients[client.UserID] == nil {
				h.userClients[client.UserID] = make(map[*Client]bool)
			}
			isFirstConnection := len(h.userClients[client.UserID]) == 0
			h.userClients[client.UserID][client] = true

			// Collect all currently connected user IDs
			var onlineUserIDs []uint
			for uid := range h.userClients {
				onlineUserIDs = append(onlineUserIDs, uid)
			}
			h.mu.Unlock()

			if isFirstConnection {
				// Mark user online in database
				if err := h.authService.UpdatePresence(client.UserID, true); err != nil {
					log.Printf("Error updating user %d to online: %v", client.UserID, err)
				}
				// Notify all active clients that this user is online
				h.BroadcastPresence(client.UserID, client.Username, true)
			}

			// Send connection ack and online users snapshot directly to the newly connected client
			ackBytes, _ := json.Marshal(Message{
				Type:     "connection_ack",
				Status:   "connected",
				SenderID: client.UserID,
				Username: client.Username,
				Payload: map[string]interface{}{
					"status":          "connected",
					"user_id":         client.UserID,
					"online_user_ids": onlineUserIDs,
				},
				Timestamp: time.Now(),
			})
			select {
			case client.Send <- ackBytes:
			default:
			}

			log.Printf("User %s (ID: %d) connected to WebSocket. Total active clients: %d", client.Username, client.UserID, len(h.clients))

		case client := <-h.Unregister:
			h.removeClient(client)

		case message := <-h.Broadcast:
			h.handleMessage(message)
		}
	}
}

func (h *Hub) removeClient(client *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if _, ok := h.clients[client]; ok {
		delete(h.clients, client)
		close(client.Send)

		if clientsForUser, exists := h.userClients[client.UserID]; exists {
			delete(clientsForUser, client)
			if len(clientsForUser) == 0 {
				delete(h.userClients, client.UserID)
				// No more active connections for this user -> mark offline
				go func(userID uint, username string) {
					if err := h.authService.UpdatePresence(userID, false); err != nil {
						log.Printf("Error updating user %d to offline: %v", userID, err)
					}
					h.BroadcastPresence(userID, username, false)
				}(client.UserID, client.Username)
			}
		}
		log.Printf("User %s (ID: %d) disconnected from WebSocket.", client.Username, client.UserID)
	}
}

func (h *Hub) handleMessage(message Message) {
	// 0. Typing Indicator Notification (direct 1-to-1, ephemeral without DB persistence)
	if message.Type == "typing" && message.ReceiverID > 0 {
		msgBytes, err := json.Marshal(message)
		if err != nil {
			return
		}

		var targetClients []*Client
		h.mu.RLock()
		if recipients, ok := h.userClients[message.ReceiverID]; ok {
			for c := range recipients {
				targetClients = append(targetClients, c)
			}
		}
		h.mu.RUnlock()

		for _, client := range targetClients {
			select {
			case client.Send <- msgBytes:
			case <-time.After(300 * time.Millisecond):
				go h.removeClient(client)
			}
		}
		return
	}

	// 0a. Group Chat Message / Group Typing / Group Reaction / Group Read
	if message.GroupID > 0 {
		if message.Type == "group_read" {
			if h.groupService != nil && message.SenderID > 0 {
				maxID, err := h.groupService.MarkGroupAsRead(message.GroupID, message.SenderID)
				if err == nil {
					message.MessageID = maxID
					message.ReaderID = message.SenderID
					payloadMap := map[string]interface{}{
						"group_id":       message.GroupID,
						"reader_id":      message.SenderID,
						"username":       message.Username,
						"avatar_url":     message.SenderAvatar,
						"max_message_id": maxID,
					}
					message.Payload = payloadMap
				}
			}
		} else if message.Type == "chat_message" || message.Type == "group_message" {
			message.Type = "group_message"
			if message.ID == 0 && h.groupService != nil {
				saved, err := h.groupService.SendGroupMessage(message.SenderID, message.Username, message.GroupID, models.SendMessageInput{
					ClientMessageID: message.ClientMessageID,
					Content:         message.Content,
					MediaType:       message.MediaType,
					MediaURL:        message.MediaURL,
					DurationMs:      message.DurationMs,
					Waveform:        message.Waveform,
					ForwardFrom:     message.ForwardFrom,
				})
				if err == nil && saved != nil {
					message.ID = saved.ID
					message.Timestamp = saved.CreatedAt
					message.Status = saved.Status
					message.SenderAvatar = saved.SenderAvatar
				} else if err != nil {
					log.Printf("Failed saving group message from %d to group %d: %v", message.SenderID, message.GroupID, err)
				}
			}
		}

		msgBytes, err := json.Marshal(message)
		if err != nil {
			return
		}

		var memberIDs []uint
		if h.groupService != nil {
			if mIDs, err := h.groupService.GetMemberIDs(message.GroupID); err == nil {
				memberIDs = mIDs
			}
		}

		var targetClients []*Client
		h.mu.RLock()
		for _, mID := range memberIDs {
			if (message.Type == "typing" || message.Type == "group_typing") && mID == message.SenderID {
				continue
			}
			if clients, ok := h.userClients[mID]; ok {
				for c := range clients {
					targetClients = append(targetClients, c)
				}
			}
		}
		h.mu.RUnlock()

		for _, client := range targetClients {
			select {
			case client.Send <- msgBytes:
			case <-time.After(500 * time.Millisecond):
				go h.removeClient(client)
			}
		}
		return
	}

	// 1. Direct 1-to-1 Chat Message
	if message.Type == "chat_message" && message.ReceiverID > 0 {
		// Persist message to database if not already persisted
		if message.ID == 0 && h.chatService != nil {
			saved, err := h.chatService.SendMessage(message.SenderID, message.Username, models.SendMessageInput{
				ReceiverID: message.ReceiverID,
				Content:    message.Content,
				MediaType:  message.MediaType,
				MediaURL:   message.MediaURL,
				ForwardFrom: message.ForwardFrom,
			})
			if err != nil {
				log.Printf("Failed saving message from %d to %d: %v", message.SenderID, message.ReceiverID, err)
				message.ID = saved.ID
				message.Timestamp = saved.CreatedAt
				message.IsRead = saved.IsRead
				message.ForwardFrom = saved.ForwardFrom
				if message.SenderAvatar == "" {
					message.SenderAvatar = saved.SenderAvatar
				}
			}
		}

		msgBytes, err := json.Marshal(message)
		if err != nil {
			return
		}

		// Snapshot target clients under read lock
		var targetClients []*Client
		h.mu.RLock()
		if recipients, ok := h.userClients[message.ReceiverID]; ok {
			for c := range recipients {
				targetClients = append(targetClients, c)
			}
		}
		if senders, ok := h.userClients[message.SenderID]; ok {
			for c := range senders {
				targetClients = append(targetClients, c)
			}
		}
		h.mu.RUnlock()

		// Deliver to target clients safely
		for _, client := range targetClients {
			select {
			case client.Send <- msgBytes:
			case <-time.After(500 * time.Millisecond):
				go h.removeClient(client)
			}
		}
		return
	}

	// 2. Read Receipt Notification (Sender is the reader, Receiver is the original sender)
	if message.Type == "read_receipt" && message.ReceiverID > 0 {
		if message.ReaderID == 0 {
			message.ReaderID = message.SenderID
		}
		if h.chatService != nil {
			_ = h.chatService.MarkAsRead(message.SenderID, message.ReceiverID)
		}

		msgBytes, err := json.Marshal(message)
		if err != nil {
			return
		}

		var targetClients []*Client
		h.mu.RLock()
		if recipients, ok := h.userClients[message.ReceiverID]; ok {
			for c := range recipients {
				targetClients = append(targetClients, c)
			}
		}
		if message.SenderID > 0 && message.SenderID != message.ReceiverID {
			if senders, ok := h.userClients[message.SenderID]; ok {
				for c := range senders {
					targetClients = append(targetClients, c)
				}
			}
		}
		h.mu.RUnlock()

		for _, client := range targetClients {
			select {
			case client.Send <- msgBytes:
			case <-time.After(500 * time.Millisecond):
				go h.removeClient(client)
			}
		}
		return
	}

	// 3. Message Reaction or Deletion Notification (target both SenderID and ReceiverID)
	if (message.Type == "message_reaction" || message.Type == "message_deleted") && (message.ReceiverID > 0 || message.SenderID > 0) {
		msgBytes, err := json.Marshal(message)
		if err != nil {
			return
		}

		var targetClients []*Client
		h.mu.RLock()
		if message.ReceiverID > 0 {
			if recipients, ok := h.userClients[message.ReceiverID]; ok {
				for c := range recipients {
					targetClients = append(targetClients, c)
				}
			}
		}
		if message.SenderID > 0 {
			if senders, ok := h.userClients[message.SenderID]; ok {
				for c := range senders {
					targetClients = append(targetClients, c)
				}
			}
		}
		h.mu.RUnlock()

		for _, client := range targetClients {
			select {
			case client.Send <- msgBytes:
			case <-time.After(500 * time.Millisecond):
				go h.removeClient(client)
			}
		}
		return
	}

	// 4. Community / Broadcast message
	msgBytes, err := json.Marshal(message)
	if err != nil {
		log.Printf("Error marshaling broadcast message: %v", err)
		return
	}

	var allClients []*Client
	h.mu.RLock()
	for client := range h.clients {
		allClients = append(allClients, client)
	}
	h.mu.RUnlock()

	for _, client := range allClients {
		select {
		case client.Send <- msgBytes:
		case <-time.After(500 * time.Millisecond):
			go h.removeClient(client)
		}
	}
}

func (h *Hub) BroadcastPresence(userID uint, username string, isOnline bool) {
	select {
	case h.Broadcast <- Message{
		Type:      "user_status",
		SenderID:  userID,
		Username:  username,
		Timestamp: time.Now(),
		Payload: map[string]interface{}{
			"user_id":   userID,
			"username":  username,
			"is_online": isOnline,
		},
	}:
	case <-time.After(500 * time.Millisecond):
	}
}
