package main

import (
	"encoding/json"
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
	countFlag := flag.Int("count", 1000, "Number of media and voice messages to seed")
	user1Flag := flag.Uint("user1", 1001, "First user ID (default 1001)")
	user2Flag := flag.Uint("user2", 2, "Second user ID (default 2)")
	flag.Parse()

	cfg := config.LoadConfig()
	db, err := database.ConnectDatabase(cfg)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	u1ID := *user1Flag
	u2ID := *user2Flag

	total := *countFlag
	log.Printf("Preparing to seed %d user image and voice messages between User %d and User %d...", total, u1ID, u2ID)

	// Authentic user uploaded images from Cloudflare R2
	realImages := []string{
		"http://localhost:8088/api/v1/media/file/chat/ccf94f45-4499-4dac-9299-d64afcdcb9f2.jpeg",
		"http://localhost:8088/api/v1/media/file/chat/01850544-2630-4acf-b0ea-d13f9f38572c.jpeg",
		"http://localhost:8088/api/v1/media/file/chat/c3abcb8d-df99-4881-a698-8fa020fce409.jpg",
		"http://localhost:8088/api/v1/media/file/chat/2b26136c-187e-45cd-93ad-1265a1337edd.jpg",
		"http://localhost:8088/api/v1/media/file/chat/2fbe9133-a882-4f28-b697-f86c423a77f2.tiff",
	}

	imageCaptions := []string{
		"Photo",
		"Here's the photo from earlier!",
		"Coffee break ☕️",
		"Working on the new design!",
		"Quick snap from today",
		"Photo",
		"Check this out!",
		"Photo",
	}

	// Authentic user recorded voice notes from Cloudflare R2
	realVoiceNotes := []string{
		"http://localhost:8088/api/v1/media/file/chat/ad0f6d58-54a6-4d0e-bd24-47f7736dc475.m4a",
		"http://localhost:8088/api/v1/media/file/chat/f500fd99-3cb2-4d1a-8a31-4a1de28eb69f.m4a",
		"http://localhost:8088/api/v1/media/file/chat/03474328-a147-42d9-8b9f-6e2b8351a59f.m4a",
		"http://localhost:8088/api/v1/media/file/chat/96c2e067-67ad-4c31-9f67-c67a2a6eab46.webm",
		"http://localhost:8088/api/v1/media/file/chat/6e2e2691-aab9-4b6b-928a-b133112e4e08.webm",
	}

	rnd := rand.New(rand.NewSource(time.Now().UnixNano()))

	// Spread messages chronologically over the past 30 days up to now
	startTime := time.Now().Add(-30 * 24 * time.Hour)
	interval := time.Now().Sub(startTime) / time.Duration(total+1)
	curTime := startTime

	messages := make([]models.Message, 0, total)

	for i := 1; i <= total; i++ {
		curTime = curTime.Add(interval + time.Duration(rnd.Intn(45))*time.Second)

		var senderID, receiverID uint
		if rnd.Float32() < 0.5 {
			senderID = u1ID
			receiverID = u2ID
		} else {
			senderID = u2ID
			receiverID = u1ID
		}

		isVoice := (i % 2 == 0) // 50% voice, 50% images

		var mediaType string
		var mediaURL string
		var content string
		var durationMs int
		var waveform string

		if isVoice {
			mediaType = "voice"
			mediaURL = realVoiceNotes[rnd.Intn(len(realVoiceNotes))]
			content = "Voice Message"
			durationMs = 1500 + rnd.Intn(10500) // 1.5s to 12s

			// Generate realistic 28-bar amplitude waveform
			bars := make([]float64, 28)
			for b := 0; b < 28; b++ {
				// Smooth bell curve with variation
				norm := 0.20 + 0.70*rnd.Float64()
				bars[b] = float64(int(norm*100)) / 100.0
			}
			wBytes, _ := json.Marshal(bars)
			waveform = string(wBytes)
		} else {
			mediaType = "image"
			mediaURL = realImages[rnd.Intn(len(realImages))]
			content = imageCaptions[rnd.Intn(len(imageCaptions))]
			durationMs = 0
			waveform = ""
		}

		isRead := true
		if total-i < 3 && senderID != u1ID {
			isRead = false
		}

		var readAt *time.Time
		if isRead {
			t := curTime.Add(time.Duration(rnd.Intn(120)) * time.Second)
			readAt = &t
		}

		// Occasional reaction
		reactions := ""
		if rnd.Float32() < 0.12 {
			emojis := []string{"❤️", "👍", "🔥", "😂", "🎉"}
			reactions = fmt.Sprintf(`{"%s":[%d]}`, emojis[rnd.Intn(len(emojis))], senderID)
		}

		msg := models.Message{
			SenderID:   senderID,
			ReceiverID: &receiverID,
			Content:    content,
			MediaType:  mediaType,
			MediaURL:   mediaURL,
			DurationMs: durationMs,
			Waveform:   waveform,
			Reactions:  reactions,
			IsRead:     isRead,
			ReadAt:     readAt,
			CreatedAt:  curTime,
			UpdatedAt:  curTime,
		}

		messages = append(messages, msg)
	}

	log.Printf("Inserting %d media messages in batches of 500...", len(messages))
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
		log.Printf("Inserted %d / %d media messages...", end, len(messages))
	}

	var imageCount int64
	var voiceCount int64
	db.Model(&models.Message{}).Where("media_type = 'image'").Count(&imageCount)
	db.Model(&models.Message{}).Where("media_type = 'voice'").Count(&voiceCount)

	log.Printf("Successfully seeded 1,000 real media messages! Total images in DB: %d, Total voice notes in DB: %d", imageCount, voiceCount)
}
