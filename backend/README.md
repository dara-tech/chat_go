# Real-Time Chat User Authentication (Go + MySQL)

A robust, production-ready User Authentication backend for a Real-Time Chat system built with **Go (Golang)**, **MySQL**, **JWT**, and **Gorilla WebSocket**.

---

## 🌟 Features

- **User Registration & Login**: Validated inputs, secure password hashing using `bcrypt`.
- **Dual JWT Token System**: Short-lived Access Tokens for API & WebSocket requests, and long-lived Refresh Tokens for rotation.
- **MySQL Integration**: Configured with connection pooling (`sql.DB`), connection lifetime management, and automatic schema migrations with `GORM`.
- **Real-Time Presence Tracking**: Automatically tracks `is_online` status and `last_seen_at` in MySQL when users connect or disconnect via WebSocket.
- **WebSocket Handshake Auth**: Supports both standard HTTP Bearer headers and URL query parameters (`?token=...`) required for browser WebSocket clients (`new WebSocket(...)`).
- **Real-Time WebSocket Hub**: Authenticated real-time message broadcasting and user presence events.
- **Modular Clean Architecture**: Handlers, Services, Repositories, Models, Middlewares, and Configuration.

---

## 📁 Project Architecture

```
backend/
├── cmd/
│   └── server/
│       └── main.go                 # Application bootstrap & dependency injection
├── config/
│   └── config.go                   # Loads .env configuration & system variables
├── database/
│   ├── database.go                 # MySQL connection pool & GORM auto-migration
│   └── migrations/
│       └── 001_init_schema.sql     # Pure SQL schema (optional manual execution)
├── handlers/
│   ├── auth_handler.go             # HTTP handlers for auth, profile, users, and WS
│   └── media_handler.go            # Cloudflare R2 media & avatar upload handlers
├── middleware/
│   ├── auth.go                     # JWT validation (Header & Query param token)
│   └── cors.go                     # Cross-Origin Resource Sharing configuration
├── models/
│   └── user.go                     # User database model and DTO structures
├── repository/
│   └── user_repository.go          # Database queries & persistence operations
├── routes/
│   └── routes.go                   # API routes definition
├── services/
│   ├── auth_service.go             # Business logic (registration, password check, presence)
│   ├── jwt_service.go              # Token generation and validation
│   └── r2_service.go               # Cloudflare R2 object storage service
├── websocket/
│   ├── client.go                   # WebSocket connection handler (Read/Write pumps)
│   └── hub.go                      # Multi-client hub & broadcast coordinator
├── .env.example                    # Sample environment variables
├── .env                            # Active environment configuration
└── go.mod                          # Go module dependencies
```

---

## ⚙️ Prerequisites & Setup

### 1. Ensure MySQL is Running
Make sure your local MySQL server is running (e.g., via Homebrew, macOS service, or standalone MySQL):

```bash
# If using Homebrew MySQL service on macOS:
brew services start mysql
```

Default credentials in `.env`:
- **Host**: `127.0.0.1`
- **Port**: `3306`
- **User**: `root`
- **Password**: *(empty by default, update in `.env` if your root user has a password)*
- **Database**: `chat_go_db` *(auto-created by the app on startup)*

### 2. Configure Environment (`.env`)
Check and modify `.env` if necessary:

```env
PORT=8080
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_mysql_password
DB_NAME=chat_go_db
JWT_SECRET=super-secret-chat-jwt-key-change-in-production
JWT_EXPIRATION_HOURS=24
REFRESH_EXPIRATION_DAYS=7
ALLOW_ORIGINS=*
```

---

## 🚀 Running the Server

Start the Go server:

```bash
go run cmd/server/main.go
```

The server will automatically:
1. Ensure the `chat_go_db` database exists in MySQL.
2. Auto-migrate the `users` table schema.
3. Start the WebSocket Hub.
4. Listen on `http://localhost:8080`.

---

## 📡 API Endpoints

### 1. Register User
- **Method**: `POST`
- **URL**: `/api/v1/auth/register`
- **Body**:
  ```json
  {
    "username": "alice",
    "email": "alice@example.com",
    "password": "Password123!",
    "display_name": "Alice Wonderland",
    "avatar_url": "https://example.com/avatar.png"
  }
  ```
- **Response** (`201 Created`):
  ```json
  {
    "message": "User registered successfully",
    "data": {
      "access_token": "eyJhbGciOi...",
      "refresh_token": "eyJhbGciOi...",
      "expires_in": 86400,
      "user": {
        "id": 1,
        "uuid": "4c9e8361-...",
        "username": "alice",
        "email": "alice@example.com",
        "display_name": "Alice Wonderland",
        "avatar_url": "https://example.com/avatar.png",
        "is_online": false,
        "last_seen_at": null,
        "created_at": "2026-10-24T23:00:00Z"
      }
    }
  }
  ```

### 2. Login User
- **Method**: `POST`
- **URL**: `/api/v1/auth/login`
- **Body**:
  ```json
  {
    "username_or_email": "alice",
    "password": "Password123!"
  }
  ```
- **Response** (`200 OK`):
  ```json
  {
    "message": "Login successful",
    "data": {
      "access_token": "eyJhbGciOi...",
      "refresh_token": "eyJhbGciOi...",
      "expires_in": 86400,
      "user": { ... }
    }
  }
  ```

### 3. Refresh Access Token
- **Method**: `POST`
- **URL**: `/api/v1/auth/refresh`
- **Body**:
  ```json
  {
    "refresh_token": "eyJhbGciOi..."
  }
  ```

### 4. Get Current User Profile (Protected)
- **Method**: `GET`
- **URL**: `/api/v1/auth/me`
- **Headers**:
  ```http
  Authorization: Bearer <ACCESS_TOKEN>
  ```

### 5. List Chat Users (Protected)
- **Method**: `GET`
- **URL**: `/api/v1/users?limit=20&offset=0`
- **Headers**:
  ```http
  Authorization: Bearer <ACCESS_TOKEN>
  ```
- Returns users list with `is_online` status for real-time presence indicators.

### 6. Upload Chat Media (Cloudflare R2) (Protected)
- **Method**: `POST`
- **URL**: `/api/v1/media/upload`
- **Headers**:
  ```http
  Authorization: Bearer <ACCESS_TOKEN>
  Content-Type: multipart/form-data
  ```
- **Form Data**:
  - `file`: (binary file, e.g. image, audio, video, document)
  - `folder`: (optional, e.g. `chat` or `attachments`)
- **Response** (`200 OK`):
  ```json
  {
    "message": "File uploaded successfully to Cloudflare R2",
    "data": {
      "url": "https://pub-xxxx.r2.dev/chat/550e8400-e29b-41d4-a716-446655440000.png",
      "key": "chat/550e8400-e29b-41d4-a716-446655440000.png",
      "filename": "screenshot.png",
      "content_type": "image/png",
      "size": 102400,
      "uploaded_at": "2026-10-25T03:30:00Z"
    }
  }
  ```

### 7. Upload & Update User Avatar (Cloudflare R2) (Protected)
- **Method**: `POST`
- **URL**: `/api/v1/users/avatar`
- **Headers**:
  ```http
  Authorization: Bearer <ACCESS_TOKEN>
  Content-Type: multipart/form-data
  ```
- **Form Data**:
  - `file`: (image file: `.jpg`, `.jpeg`, `.png`, `.webp`, `.gif`)
- **Action**: Uploads image to Cloudflare R2 and automatically updates `avatar_url` for the user in MySQL.

### 8. Real-Time Chat WebSocket Handshake
- **URL**: `ws://localhost:8088/api/v1/ws?token=<ACCESS_TOKEN>`
- Authenticates the user, flags `is_online = true` in MySQL, broadcasts presence event to online peers, and enables bidirectional real-time chat messages.
- On disconnect, flags `is_online = false` and updates `last_seen_at`.

---

## 🧪 Testing with cURL

### 1. Register a user
```bash
curl -X POST http://localhost:8088/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","email":"alice@example.com","password":"secretpassword","display_name":"Alice"}'
```

### 2. Login
```bash
curl -X POST http://localhost:8088/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username_or_email":"alice","password":"secretpassword"}'
```

### 3. Get Profile (Protected)
```bash
curl http://localhost:8088/api/v1/auth/me \
  -H "Authorization: Bearer <ACCESS_TOKEN>"
```

### 4. Connect to Real-time Chat WebSocket
Using any WebSocket CLI or client (e.g., `websocat` or Postman):
```bash
websocat "ws://localhost:8088/api/v1/ws?token=<ACCESS_TOKEN>"
```
