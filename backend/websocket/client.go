package websocket

import (
	"encoding/json"
	"log"
	"net/http"
	"time"
	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

const (
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = (pongWait * 9) / 10
	maxMessageSize = 512 * 1024 // 512 KB
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		// Allow any origin for WebSocket handshake (or restrict per config)
		return true
	},
}

// Client represents a single authenticated WebSocket connection
type Client struct {
	Hub       *Hub
	Conn      *websocket.Conn
	Send      chan []byte
	UserID    uint
	UUID      string
	Username  string
	AvatarURL string
}

func (c *Client) ReadPump() {
	defer func() {
		c.Hub.Unregister <- c
		c.Conn.Close()
	}()

	c.Conn.SetReadLimit(maxMessageSize)
	c.Conn.SetReadDeadline(time.Now().Add(pongWait))
	c.Conn.SetPongHandler(func(string) error {
		c.Conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, messageData, err := c.Conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("WebSocket read error: %v", err)
			}
			break
		}

		var incoming Message
		if err := json.Unmarshal(messageData, &incoming); err != nil {
			var rawMap map[string]interface{}
			if err2 := json.Unmarshal(messageData, &rawMap); err2 == nil {
				msgType, _ := rawMap["type"].(string)
				incoming.Type = msgType
				if c, ok := rawMap["content"].(string); ok {
					incoming.Content = c
				}
				if r, ok := rawMap["receiver_id"].(float64); ok {
					incoming.ReceiverID = uint(r)
				}
				if g, ok := rawMap["group_id"].(float64); ok {
					incoming.GroupID = uint(g)
				}
				if mt, ok := rawMap["media_type"].(string); ok {
					incoming.MediaType = mt
				}
				if mu, ok := rawMap["media_url"].(string); ok {
					incoming.MediaURL = mu
				}
				if cid, ok := rawMap["client_message_id"].(string); ok {
					incoming.ClientMessageID = cid
				}
				if isTyping, ok := rawMap["is_typing"].(bool); ok {
					incoming.IsTyping = isTyping
				}
				incoming.Timestamp = time.Now()
			} else {
				trimmed := string(messageData)
				if len(trimmed) > 0 && (trimmed[0] == '{' || trimmed[0] == '[') {
					log.Printf("Ignoring malformed JSON message from %s: %v", c.Username, err)
					continue
				}
				incoming = Message{
					Type:      "chat_message",
					Content:   string(messageData),
					Timestamp: time.Now(),
				}
			}
		}

		if incoming.Type == "ping" {
			pongBytes, _ := json.Marshal(map[string]interface{}{
				"type":      "pong",
				"timestamp": time.Now(),
			})
			select {
			case c.Send <- pongBytes:
			default:
			}
			continue
		}

		// Ensure sender info is firmly stamped from authenticated session
		incoming.SenderID = c.UserID
		incoming.Username = c.Username
		if incoming.SenderAvatar == "" {
			incoming.SenderAvatar = c.AvatarURL
		}
		incoming.Timestamp = time.Now()

		c.Hub.Broadcast <- incoming
	}
}

func (c *Client) WritePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.Conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.Send:
			c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				// Hub closed the channel
				c.Conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			if err := c.Conn.WriteMessage(websocket.TextMessage, message); err != nil {
				return
			}

		case <-ticker.C:
			c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// ServeWs upgrades HTTP request to authenticated WebSocket connection
func ServeWs(hub *Hub, c *gin.Context) {
	// User credentials were authenticated by middleware
	userIDVal, _ := c.Get("userID")
	userUUIDVal, _ := c.Get("userUUID")
	usernameVal, _ := c.Get("username")

	userID, ok := userIDVal.(uint)
	if !ok || userID == 0 {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized WebSocket connection"})
		return
	}

	userUUID, _ := userUUIDVal.(string)
	username, _ := usernameVal.(string)

	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("WebSocket upgrade failed: %v", err)
		return
	}

	var avatarURL string
	if hub.authService != nil {
		if profile, err := hub.authService.GetProfile(userID); err == nil && profile != nil {
			avatarURL = profile.AvatarURL
		}
	}

	client := &Client{
		Hub:       hub,
		Conn:      conn,
		Send:      make(chan []byte, 256),
		UserID:    userID,
		UUID:      userUUID,
		Username:  username,
		AvatarURL: avatarURL,
	}

	client.Hub.Register <- client

	// Start read and write pumps in separate goroutines
	go client.WritePump()
	go client.ReadPump()
}
