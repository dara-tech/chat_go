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

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

func main() {
	targetCount := flag.Int("count", 1000, "Number of users to seed")
	flag.Parse()

	log.Printf("Starting user seeder for target %d users...", *targetCount)

	cfg := config.LoadConfig()
	db, err := database.ConnectDatabase(cfg)
	if err != nil {
		log.Fatalf("Database connection failed: %v", err)
	}

	var existingCount int64
	db.Model(&models.User{}).Count(&existingCount)
	log.Printf("Current users count in database: %d", existingCount)

	needed := *targetCount - int(existingCount)
	if needed <= 0 {
		log.Printf("Database already has %d users (target %d). No new users needed.", existingCount, *targetCount)
		return
	}

	log.Printf("Seeding %d new users into chat_go_db...", needed)

	// Hash password once to ensure high performance
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte("password123"), bcrypt.DefaultCost)
	if err != nil {
		log.Fatalf("Password hashing failed: %v", err)
	}

	firstNames := []string{
		"Sovandara", "Chantha", "Visal", "Sreymom", "Kosal", "Dany", "Bopha", "Vireak",
		"Rath", "Sokha", "Chann", "Kalyan", "Rithy", "Piseth", "Kolab", "Theara",
		"Samnang", "Vannak", "Sinath", "Neary", "Ratanak", "Serey", "Malis", "Bunthan",
		"Alex", "Sophia", "David", "Emma", "Lucas", "Olivia", "James", "Isabella",
		"Ethan", "Ava", "Liam", "Mia", "Daniel", "Chloe", "Ryan", "Grace",
		"Leo", "Lily", "Kevin", "Sarah", "Jason", "Anna", "Eric", "Zoe",
		"Marcus", "Elena", "Nathan", "Aria", "Victor", "Clara", "Adrian", "Maya",
		"Kenji", "Hana", "Minho", "Jiwoo", "Wei", "Mei", "Hiroshi", "Yuki",
	}

	lastNames := []string{
		"Cheol", "Keo", "Seng", "Pich", "Heng", "Meas", "Chhun", "Long",
		"Vann", "Ouk", "Som", "Chhay", "Nuon", "Thorn", "Khin", "Kong",
		"Smith", "Johnson", "Lee", "Kim", "Watson", "Davis", "Miller", "Wilson",
		"Taylor", "Anderson", "Thomas", "Moore", "Martin", "Jackson", "White", "Harris",
		"Clark", "Lewis", "Robinson", "Walker", "Hall", "Allen", "Young", "King",
		"Wright", "Lopez", "Hill", "Scott", "Green", "Adams", "Baker", "Gonzalez",
		"Nelson", "Carter", "Mitchell", "Perez", "Roberts", "Turner", "Phillips", "Campbell",
	}

	roles := []string{
		"dev", "design", "cloud", "ai", "go", "flutter", "react", "sec",
		"pm", "qa", "lead", "code", "ops", "data", "web", "sys",
	}

	rnd := rand.New(rand.NewSource(time.Now().UnixNano()))
	users := make([]models.User, 0, needed)

	now := time.Now()

	for i := 1; i <= needed; i++ {
		fn := firstNames[rnd.Intn(len(firstNames))]
		ln := lastNames[rnd.Intn(len(lastNames))]
		role := roles[rnd.Intn(len(roles))]

		displayName := fmt.Sprintf("%s %s", fn, ln)
		uniqueID := int(existingCount) + i
		username := fmt.Sprintf("%s_%s_%d", fn, role, uniqueID)
		email := fmt.Sprintf("%s.%s%d@chatgo.app", fn, ln, uniqueID)

		isOnline := rnd.Float32() < 0.28 // 28% online
		var lastSeen *time.Time
		if !isOnline {
			hoursAgo := rnd.Intn(72) + 1
			minsAgo := rnd.Intn(60)
			t := now.Add(-time.Duration(hoursAgo)*time.Hour - time.Duration(minsAgo)*time.Minute)
			lastSeen = &t
		} else {
			lastSeen = &now
		}

		createdAt := now.Add(-time.Duration(rnd.Intn(365*24)) * time.Hour)

		avatarURL := fmt.Sprintf("https://ui-avatars.com/api/?name=%s+%s&background=2563EB&color=fff&size=128", fn, ln)

		user := models.User{
			UUID:         uuid.NewString(),
			Username:     username,
			Email:        email,
			PasswordHash: string(hashedPassword),
			DisplayName:  displayName,
			AvatarURL:    avatarURL,
			IsOnline:     isOnline,
			LastSeenAt:   lastSeen,
			CreatedAt:    createdAt,
			UpdatedAt:    now,
		}

		users = append(users, user)
	}

	// Insert in batches of 200
	const batchSize = 200
	for i := 0; i < len(users); i += batchSize {
		end := i + batchSize
		if end > len(users) {
			end = len(users)
		}

		batch := users[i:end]
		if err := db.CreateInBatches(batch, len(batch)).Error; err != nil {
			log.Fatalf("Failed inserting batch %d to %d: %v", i, end, err)
		}
		log.Printf("Inserted batch: %d / %d users...", end, len(users))
	}

	var finalCount int64
	db.Model(&models.User{}).Count(&finalCount)
	log.Printf("Successfully seeded users! Total users in database now: %d", finalCount)
}
