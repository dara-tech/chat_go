package main

import (
	"flag"
	"fmt"
	"log"
	"math/rand"
	"time"

	"chat_go/backend/config"
	"chat_go/backend/database"
	"chat_go/backend/models"
)

func main() {
	countFlag := flag.Int("count", 10000, "Number of messages to seed")
	user1Flag := flag.Uint("user1", 0, "First user ID (0 to auto-detect)")
	user2Flag := flag.Uint("user2", 0, "Second user ID (0 to auto-detect)")
	flag.Parse()

	cfg := config.LoadConfig()
	db, err := database.ConnectDatabase(cfg)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	var users []models.User
	if err := db.Order("id asc").Limit(20).Find(&users).Error; err != nil || len(users) < 2 {
		log.Fatalf("Need at least 2 users in database to seed conversation. Found: %d, err: %v", len(users), err)
	}

	u1ID := *user1Flag
	u2ID := *user2Flag

	if u1ID == 0 {
		u1ID = users[0].ID
	}
	if u2ID == 0 {
		u2ID = users[1].ID
	}

	var u1Name, u2Name string
	for _, u := range users {
		if u.ID == u1ID {
			u1Name = u.DisplayName
			if u1Name == "" {
				u1Name = u.Username
			}
		}
		if u.ID == u2ID {
			u2Name = u.DisplayName
			if u2Name == "" {
				u2Name = u.Username
			}
		}
	}

	total := *countFlag
	log.Printf("Preparing to seed %d messages between User %d (%s) and User %d (%s)...", total, u1ID, u1Name, u2ID, u2Name)

	sampleMessages := []string{
		"Hey there! How's your day going?",
		"Pretty good! Just refactoring the state management.",
		"Did you test the new Telegram-style reverse scroll?",
		"Yes! It feels super smooth, zero scroll jumping.",
		"What about cursor pagination with 'before' ID?",
		"It's working nicely! O(1) B-tree lookup on message ID.",
		"Awesome! Did you test with 10k messages?",
		"Doing that right now! Checking local-first cache too.",
		"Nice, local cache renders immediately in 0ms.",
		"Exactly, the app opens without any spinner.",
		"Did you push the latest commit?",
		"Yeah, just pushed it 5 minutes ago.",
		"Let me pull and check it out on my device.",
		"Cool, let me know if you run into any issues.",
		"Working like a charm! 🔥",
		"Are you free for a quick sync at 3 PM?",
		"Sure, let's jump on a quick call.",
		"I'll share the meeting link in a bit.",
		"Sounds like a plan!",
		"Did you see the new CartoDB dark map tiles?",
		"Yes, the dark mode styling matches the liquid theme perfectly.",
		"We should add voice messages next.",
		"Agreed, voice notes with waveform would be dope.",
		"Let's wrap up this milestone first though.",
		"Definitely. Performance first!",
		"What's your current RAM usage with 10,000 messages?",
		"Only a few megabytes because ListView.builder renders lazily!",
		"That's the beauty of lazy viewport rendering.",
		"No memory leaks at all.",
		"Great work team! 🚀",
		"Thanks, you too!",
		"Talk soon! 👋",
		"See ya!",
		"Check out this document when you get a chance.",
		"Will do 👍",
		"Everything looks solid on my end.",
		"Sweet, shipping to production soon!",
		"Let's gooo! 🎉",
		"Ok, I'm heading out for lunch.",
		"Enjoy! 🍜",
		"Back now! Let's continue.",
		"Just checked the server logs, WebSocket is holding steady.",
		"Nice! Low latency across the board.",
		"Catch you later tonight.",
		"Alright, peace out!",
	}

	rnd := rand.New(rand.NewSource(time.Now().UnixNano()))

	// Spread messages chronologically over the past 90 days up to now
	startTime := time.Now().Add(-90 * 24 * time.Hour)
	interval := time.Now().Sub(startTime) / time.Duration(total+1)

	messages := make([]models.Message, 0, total)
	curTime := startTime

	// Seed predominantly between u1 and u2 (e.g. 90%), and 10% with other contacts
	for i := 1; i <= total; i++ {
		curTime = curTime.Add(interval + time.Duration(rnd.Intn(60))*time.Second)

		var senderID, receiverID uint
		if i%10 == 0 && len(users) > 2 {
			// Random conversation with another user
			otherIdx := rnd.Intn(len(users))
			otherID := users[otherIdx].ID
			if otherID == u1ID {
				otherID = u2ID
			}
			if rnd.Float32() < 0.5 {
				senderID = u1ID
				receiverID = otherID
			} else {
				senderID = otherID
				receiverID = u1ID
			}
		} else {
			// Main conversation between u1 and u2
			if rnd.Float32() < 0.5 {
				senderID = u1ID
				receiverID = u2ID
			} else {
				senderID = u2ID
				receiverID = u1ID
			}
		}

		content := sampleMessages[rnd.Intn(len(sampleMessages))]
		if i%25 == 0 {
			content = fmt.Sprintf("Milestone message #%d: Performance benchmark test with high volume dataset.", i)
		}

		// Random read status (older are read, newest might be unread)
		isRead := true
		if total-i < 5 && senderID != u1ID {
			isRead = false
		}

		var readAt *time.Time
		if isRead {
			t := curTime.Add(time.Duration(rnd.Intn(300)) * time.Second)
			readAt = &t
		}

		// Occasional reaction
		reactions := ""
		if rnd.Float32() < 0.08 {
			emojis := []string{"❤️", "👍", "🔥", "🚀", "😂"}
			reactions = fmt.Sprintf(`{"%s":[%d]}`, emojis[rnd.Intn(len(emojis))], senderID)
		}

		msg := models.Message{
			SenderID:   senderID,
			ReceiverID: &receiverID,
			Content:    content,
			MediaType:  "text",
			Reactions:  reactions,
			IsRead:     isRead,
			ReadAt:     readAt,
			CreatedAt:  curTime,
			UpdatedAt:  curTime,
		}

		messages = append(messages, msg)
	}

	log.Printf("Inserting %d messages in batches of 500...", len(messages))
	const batchSize = 500
	for i := 0; i < len(messages); i += batchSize {
		end := i + batchSize
		if end > len(messages) {
			end = len(messages)
		}

		batch := messages[i:end]
		if err := db.CreateInBatches(batch, len(batch)).Error; err != nil {
			log.Fatalf("Failed inserting batch %d to %d: %v", i, end, err)
		}
		if (end%2000 == 0) || end == len(messages) {
			log.Printf("Inserted %d / %d messages...", end, len(messages))
		}
	}

	var totalMessages int64
	db.Model(&models.Message{}).Count(&totalMessages)
	log.Printf("Successfully seeded %d messages! Total messages in database now: %d", total, totalMessages)
}
