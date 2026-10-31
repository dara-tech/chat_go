package services

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"mime/multipart"
	"os"
	"path/filepath"
	"strings"
	"time"

	"chat_go/backend/config"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/google/uuid"
)

var (
	ErrR2NotConfigured = errors.New("cloudflare R2 is not configured in environment variables")
	ErrInvalidFileType = errors.New("unsupported file type")
	ErrFileTooLarge    = errors.New("file exceeds maximum allowed size (50MB)")
)

const maxFileSize = 50 * 1024 * 1024 // 50MB

// MediaResponse represents the metadata of an uploaded file
type MediaResponse struct {
	URL         string    `json:"url"`
	Key         string    `json:"key"`
	Filename    string    `json:"filename"`
	ContentType string    `json:"content_type"`
	Size        int64     `json:"size"`
	UploadedAt  time.Time `json:"uploaded_at"`
}

type R2Service interface {
	UploadFile(ctx context.Context, fileHeader *multipart.FileHeader, folder string) (*MediaResponse, error)
	GetFile(ctx context.Context, key string) (io.ReadCloser, string, error)
	GetFileWithRange(ctx context.Context, key string, rangeHeader string) (io.ReadCloser, string, int64, string, error)
	DeleteFile(ctx context.Context, key string) error
	IsConfigured() bool
}

type r2Service struct {
	s3Client   *s3.Client
	bucketName string
	publicURL  string
	cacheDir   string
	configured bool
}

func NewR2Service(cfg *config.Config) R2Service {
	cacheDir := "./media_cache"
	_ = os.MkdirAll(cacheDir, 0755)

	if cfg.R2AccountID == "" || cfg.R2AccessKeyID == "" || cfg.R2SecretAccessKey == "" || cfg.R2BucketName == "" {
		return &r2Service{configured: false, cacheDir: cacheDir}
	}

	endpoint := fmt.Sprintf("https://%s.r2.cloudflarestorage.com", cfg.R2AccountID)

	s3Client := s3.New(s3.Options{
		Region:       "auto",
		BaseEndpoint: aws.String(endpoint),
		Credentials:  credentials.NewStaticCredentialsProvider(cfg.R2AccessKeyID, cfg.R2SecretAccessKey, ""),
	})

	publicURL := strings.TrimRight(cfg.R2PublicURL, "/")
	if publicURL == "" {
		publicURL = fmt.Sprintf("https://pub-%s.r2.dev", cfg.R2BucketName)
	}

	return &r2Service{
		s3Client:   s3Client,
		bucketName: cfg.R2BucketName,
		publicURL:  publicURL,
		cacheDir:   cacheDir,
		configured: true,
	}
}

func (s *r2Service) IsConfigured() bool {
	return s.configured
}

func (s *r2Service) guessContentType(key string) string {
	ext := strings.ToLower(filepath.Ext(key))
	switch ext {
	case ".jpg", ".jpeg":
		return "image/jpeg"
	case ".png":
		return "image/png"
	case ".webp":
		return "image/webp"
	case ".gif":
		return "image/gif"
	case ".m4a":
		return "audio/mp4"
	case ".mp3":
		return "audio/mpeg"
	case ".webm":
		return "audio/webm"
	case ".ogg":
		return "audio/ogg"
	case ".wav":
		return "audio/wav"
	case ".aac":
		return "audio/aac"
	case ".mp4":
		return "video/mp4"
	case ".mov":
		return "video/quicktime"
	case ".pdf":
		return "application/pdf"
	case ".doc", ".docx":
		return "application/msword"
	case ".xls", ".xlsx":
		return "application/vnd.ms-excel"
	case ".ppt", ".pptx":
		return "application/vnd.ms-powerpoint"
	case ".zip":
		return "application/zip"
	case ".rar":
		return "application/x-rar-compressed"
	case ".csv":
		return "text/csv"
	case ".txt":
		return "text/plain"
	default:
		return "application/octet-stream"
	}
}

// UploadFile streams a multipart file directly to Cloudflare R2 and caches it locally
func (s *r2Service) UploadFile(ctx context.Context, fileHeader *multipart.FileHeader, folder string) (*MediaResponse, error) {
	if !s.configured {
		return nil, ErrR2NotConfigured
	}

	if fileHeader.Size > maxFileSize {
		return nil, ErrFileTooLarge
	}

	srcFile, err := fileHeader.Open()
	if err != nil {
		return nil, fmt.Errorf("failed opening uploaded file: %w", err)
	}
	defer srcFile.Close()

	fileBytes, err := io.ReadAll(srcFile)
	if err != nil {
		return nil, fmt.Errorf("failed reading uploaded file: %w", err)
	}

	ext := strings.ToLower(filepath.Ext(fileHeader.Filename))
	if ext == "" {
		ext = ".jpg"
	}
	contentType := fileHeader.Header.Get("Content-Type")
	if contentType == "" || contentType == "application/octet-stream" {
		contentType = s.guessContentType(ext)
	}

	// Sanitize folder path
	folder = strings.Trim(folder, "/")
	if folder == "" {
		folder = "uploads"
	}

	// Unique file key to prevent collision
	objectKey := fmt.Sprintf("%s/%s%s", folder, uuid.NewString(), ext)

	// Save to local cache immediately for blazing fast 1ms retrieval
	localPath := filepath.Join(s.cacheDir, objectKey)
	if err := os.MkdirAll(filepath.Dir(localPath), 0755); err == nil {
		_ = os.WriteFile(localPath, fileBytes, 0644)
	}

	// PutObject to Cloudflare R2
	_, err = s.s3Client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(s.bucketName),
		Key:         aws.String(objectKey),
		Body:        bytes.NewReader(fileBytes),
		ContentType: aws.String(contentType),
	})
	if err != nil {
		return nil, fmt.Errorf("failed uploading to Cloudflare R2: %w", err)
	}

	publicURL := fmt.Sprintf("%s/%s", s.publicURL, objectKey)

	return &MediaResponse{
		URL:         publicURL,
		Key:         objectKey,
		Filename:    fileHeader.Filename,
		ContentType: contentType,
		Size:        int64(len(fileBytes)),
		UploadedAt:  time.Now(),
	}, nil
}

// GetFile retrieves an object from Cloudflare R2 or local cache
func (s *r2Service) GetFile(ctx context.Context, key string) (io.ReadCloser, string, error) {
	body, contentType, _, _, err := s.GetFileWithRange(ctx, key, "")
	return body, contentType, err
}

// GetFileWithRange retrieves an object or partial byte range from local cache or Cloudflare R2
func (s *r2Service) GetFileWithRange(ctx context.Context, key string, rangeHeader string) (io.ReadCloser, string, int64, string, error) {
	// 1. Check local cache first for instant 1ms response
	localPath := filepath.Join(s.cacheDir, key)
	if fi, err := os.Stat(localPath); err == nil && !fi.IsDir() {
		f, err := os.Open(localPath)
		if err == nil {
			contentType := s.guessContentType(key)
			return f, contentType, fi.Size(), "", nil
		}
	}

	if !s.configured {
		return nil, "", 0, "", ErrR2NotConfigured
	}

	input := &s3.GetObjectInput{
		Bucket: aws.String(s.bucketName),
		Key:    aws.String(key),
	}
	if rangeHeader != "" {
		input.Range = aws.String(rangeHeader)
	}

	resp, err := s.s3Client.GetObject(ctx, input)
	if err != nil {
		return nil, "", 0, "", fmt.Errorf("failed fetching from R2: %w", err)
	}

	contentType := "application/octet-stream"
	if resp.ContentType != nil && *resp.ContentType != "" && *resp.ContentType != "application/octet-stream" {
		contentType = *resp.ContentType
	} else {
		contentType = s.guessContentType(key)
	}

	contentLength := int64(-1)
	if resp.ContentLength != nil {
		contentLength = *resp.ContentLength
	}

	contentRange := ""
	if resp.ContentRange != nil {
		contentRange = *resp.ContentRange
	}

	// Cache to disk if full file response
	if rangeHeader == "" {
		bodyBytes, err := io.ReadAll(resp.Body)
		_ = resp.Body.Close()
		if err == nil {
			_ = os.MkdirAll(filepath.Dir(localPath), 0755)
			_ = os.WriteFile(localPath, bodyBytes, 0644)
			return io.NopCloser(bytes.NewReader(bodyBytes)), contentType, int64(len(bodyBytes)), contentRange, nil
		}
	}

	return resp.Body, contentType, contentLength, contentRange, nil
}

// DeleteFile removes an object from Cloudflare R2
func (s *r2Service) DeleteFile(ctx context.Context, key string) error {
	if !s.configured {
		return ErrR2NotConfigured
	}

	_, err := s.s3Client.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(s.bucketName),
		Key:    aws.String(key),
	})
	return err
}
