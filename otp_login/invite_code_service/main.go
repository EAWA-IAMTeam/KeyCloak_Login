package main

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/joho/godotenv"
)

var aesKey []byte

func init() {
	// Load environment variables from the correct .env file location
	err := godotenv.Load("../scripts/.env") // Update path to point to scripts folder
	if err != nil {
		panic("Error loading .env file")
	}

	// Decode AES_KEY from Base64
	aesKeyDecoded, err := base64.StdEncoding.DecodeString(getEnv("AES_KEY", ""))
	if err != nil {
		panic("Invalid AES_KEY in .env file")
	}
	aesKey = aesKeyDecoded
}

func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}

// Encrypt static data
func encryptData(groupID, subgroupID string) (string, error) {
	expiration := time.Now().Add(24 * time.Hour).Unix()
	plainText := fmt.Sprintf("%s|%s|%d", groupID, subgroupID, expiration)

	block, err := aes.NewCipher(aesKey)
	if err != nil {
		return "", err
	}

	paddedText := pad([]byte(plainText), aes.BlockSize)
	cipherText := make([]byte, aes.BlockSize+len(paddedText))
	iv := cipherText[:aes.BlockSize]
	if _, err := io.ReadFull(rand.Reader, iv); err != nil {
		return "", err
	}

	mode := cipher.NewCBCEncrypter(block, iv)
	mode.CryptBlocks(cipherText[aes.BlockSize:], paddedText)

	return base64.StdEncoding.EncodeToString(cipherText), nil
}

// Decrypt static data
func decryptData(encryptedCode string) (string, string, error) {
	cipherText, err := base64.StdEncoding.DecodeString(encryptedCode)
	if err != nil {
		return "", "", err
	}

	block, err := aes.NewCipher(aesKey)
	if err != nil {
		return "", "", err
	}

	if len(cipherText) < aes.BlockSize {
		return "", "", errors.New("cipherText too short")
	}

	iv := cipherText[:aes.BlockSize]
	cipherText = cipherText[aes.BlockSize:]
	mode := cipher.NewCBCDecrypter(block, iv)

	paddedText := make([]byte, len(cipherText))
	mode.CryptBlocks(paddedText, cipherText)

	plainText, err := unpad(paddedText, aes.BlockSize)
	if err != nil {
		return "", "", err
	}

	parts := strings.Split(string(plainText), "|")
	if len(parts) != 3 {
		return "", "", errors.New("invalid data format")
	}

	groupID := parts[0]
	subgroupID := parts[1]
	expiration, err := strconv.ParseInt(parts[2], 10, 64)
	if err != nil || time.Now().Unix() > expiration {
		return "", "", errors.New("code expired or invalid")
	}

	return groupID, subgroupID, nil
}

func pad(data []byte, blockSize int) []byte {
	padding := blockSize - len(data)%blockSize
	padText := make([]byte, padding)
	for i := range padText {
		padText[i] = byte(padding)
	}
	return append(data, padText...)
}

func unpad(data []byte, blockSize int) ([]byte, error) {
	length := len(data)
	padding := int(data[length-1])
	if padding > blockSize || padding == 0 {
		return nil, errors.New("invalid padding")
	}
	return data[:length-padding], nil
}

func encryptHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Invalid request method", http.StatusMethodNotAllowed)
		return
	}

	groupID := r.FormValue("groupId")
	subgroupID := r.FormValue("subgroupId")
	if groupID == "" || subgroupID == "" {
		http.Error(w, "Missing parameters", http.StatusBadRequest)
		return
	}

	encrypted, err := encryptData(groupID, subgroupID)
	if err != nil {
		http.Error(w, "Encryption failed: "+err.Error(), http.StatusInternalServerError)
		return
	}

	fmt.Fprint(w, encrypted)
}

func verifyHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Invalid request method", http.StatusMethodNotAllowed)
		return
	}

	encryptedCode := r.FormValue("encryptedCode")
	groupID, subgroupID, err := decryptData(encryptedCode)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	response := map[string]string{
		"groupId":    groupID,
		"subgroupId": subgroupID,
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func main() {
	http.HandleFunc("/encrypt", encryptHandler)
	http.HandleFunc("/verify", verifyHandler)

	fmt.Println("Server running at http://localhost:3002")
	http.ListenAndServe(":3002", nil)
}
