//code: encrypted AES key, 
//aes_key: AES-encrypted data that contains the group ID, subgroup ID, OTP, and expiration time

package main

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"
	"context"
	mrand "math/rand"
	"sync"
)

var (
	ctx              = context.Background()
	aesKey           []byte // AES Key will be generated dynamically
	rsaPrivateKey    *rsa.PrivateKey
	rsaPublicKey     *rsa.PublicKey
	cache            sync.Map // In-memory cache
)

// Generate a random 32-byte AES key
func generateAESKey() ([]byte, error) {
	key := make([]byte, 32) // AES-256 requires a 32-byte key
	_, err := rand.Read(key) // Use crypto/rand for secure random data
	if err != nil {
		return nil, err
	}
	return key, nil
}

// Encrypt the given data using AES
func encryptAES(data string) (string, error) {
	block, err := aes.NewCipher(aesKey)
	if err != nil {
		return "", err
	}

	plaintext := []byte(data)
	ciphertext := make([]byte, aes.BlockSize+len(plaintext))
	iv := ciphertext[:aes.BlockSize] // Initialization vector

	// Generate a random IV using crypto/rand
	_, err = rand.Read(iv)
	if err != nil {
		return "", err
	}

	// Encrypt the data using CFB mode
	stream := cipher.NewCFBEncrypter(block, iv)
	stream.XORKeyStream(ciphertext[aes.BlockSize:], plaintext)

	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

// Decrypt the given AES encrypted data
func decryptAES(encryptedData string) (string, error) {
	block, err := aes.NewCipher(aesKey)
	if err != nil {
		return "", err
	}

	ciphertext, err := base64.StdEncoding.DecodeString(encryptedData)
	if err != nil {
		return "", err
	}

	iv := ciphertext[:aes.BlockSize] // Extract the IV from the ciphertext
	plaintext := make([]byte, len(ciphertext)-aes.BlockSize)

	// Decrypt the data using CFB mode
	stream := cipher.NewCFBDecrypter(block, iv)
	stream.XORKeyStream(plaintext, ciphertext[aes.BlockSize:])

	return string(plaintext), nil
}

// RSA encrypt the AES key
func encryptRSA(data []byte, publicKey *rsa.PublicKey) (string, error) {
	encryptedData, err := rsa.EncryptOAEP(sha256.New(), rand.Reader, publicKey, data, nil)
	if err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(encryptedData), nil
}

// RSA decrypt the AES key
func decryptRSA(encryptedData string, privateKey *rsa.PrivateKey) ([]byte, error) {
	ciphertext, err := base64.StdEncoding.DecodeString(encryptedData)
	if err != nil {
		return nil, err
	}
	decryptedData, err := rsa.DecryptOAEP(sha256.New(), rand.Reader, privateKey, ciphertext, nil)
	if err != nil {
		return nil, err
	}
	return decryptedData, nil
}

// Struct to hold the invitation code details
type InvitationCode struct {
	GroupID       string `json:"group_id"`
	SubgroupID    string `json:"subgroup_id"`
	OTP           string `json:"otp"`
	ExpirationTime int64  `json:"expiration_time"`
}

// Generate a random OTP (non-cryptographic)
func generateOTP() string {
	otp := ""
	for i := 0; i < 6; i++ {
		digit := mrand.Intn(10) // Using mrand.Intn() to generate a random digit
		otp += fmt.Sprintf("%d", digit)
	}
	return otp
}

// Create an invitation code and store it in memory (cache)
func createInvitationCode(groupID, subgroupID, otp string, expirationTime int64) (string, string, error) {
	// Format: groupID|subgroupID|OTP|expirationTime
	data := fmt.Sprintf("%s|%s|%s|%d", groupID, subgroupID, otp, expirationTime)

	// Encrypt the data using AES
	encryptedData, err := encryptAES(data)
	if err != nil {
		return "", "", err
	}

	// Encrypt the AES key using RSA
	encryptedAESKey, err := encryptRSA(aesKey, rsaPublicKey)
	if err != nil {
		return "", "", err
	}

	// Store the encrypted data in memory (in-memory cache)
	cache.Store(encryptedAESKey, encryptedData)

	return encryptedAESKey, encryptedData, nil
}

// Validate the invitation code by decrypting and checking expiration
func validateInvitationCode(code string) (bool, string, string, error) {
	// Retrieve encrypted AES key and encrypted data from cache
	encryptedData, ok := cache.Load(code)
	if !ok {
		return false, "", "", fmt.Errorf("code not found")
	}

	// Decrypt the AES key using RSA
	decryptedAESKey, err := decryptRSA(code, rsaPrivateKey)
	if err != nil {
		return false, "", "", err
	}
	aesKey = decryptedAESKey

	// Decrypt the data using AES
	decryptedData, err := decryptAES(encryptedData.(string))
	if err != nil {
		return false, "", "", err
	}

	// Extract and validate data
	var groupID, subgroupID, otp string
	var expiration int64
	_, err = fmt.Sscanf(decryptedData, "%s|%s|%s|%d", &groupID, &subgroupID, &otp, &expiration)
	if err != nil {
		return false, "", "", err
	}

	// Check if the code has expired
	if time.Now().Unix() > expiration {
		return false, "", "", fmt.Errorf("code expired")
	}

	// Delete the code from cache after use
	cache.Delete(code)

	return true, groupID, subgroupID, nil
}

// HTTP handler for generating the invitation code
func generateInvitationCodeHandler(w http.ResponseWriter, r *http.Request) {
	groupID := r.URL.Query().Get("group_id")
	subgroupID := r.URL.Query().Get("subgroup_id")

	if groupID == "" || subgroupID == "" {
		http.Error(w, "GroupID and SubgroupID are required", http.StatusBadRequest)
		return
	}

	otp := generateOTP()
	expirationTime := time.Now().Add(24 * time.Hour).Unix() // 24 hours from now

	// Generate and encrypt the invitation code
	encryptedAESKey, encryptedData, err := createInvitationCode(groupID, subgroupID, otp, expirationTime)
	if err != nil {
		http.Error(w, "Failed to generate invitation code", http.StatusInternalServerError)
		return
	}

	// Respond with the generated code
	response := struct {
		Code   string `json:"code"`
		AESKey string `json:"aes_key"`
	}{Code: encryptedAESKey, AESKey: encryptedData}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(response); err != nil {
		http.Error(w, "Failed to generate response", http.StatusInternalServerError)
	}
}

// HTTP handler for validating the invitation code
func validateInvitationCodeHandler(w http.ResponseWriter, r *http.Request) {
	code := r.URL.Query().Get("code")
	if code == "" {
		http.Error(w, "Code is required", http.StatusBadRequest)
		return
	}

	valid, groupID, subgroupID, err := validateInvitationCode(code)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if !valid {
		http.Error(w, "Invalid invitation code", http.StatusBadRequest)
		return
	}

	// Respond with the group and subgroup IDs
	response := struct {
		GroupID    string `json:"group_id"`
		SubgroupID string `json:"subgroup_id"`
	}{
		GroupID:    groupID,
		SubgroupID: subgroupID,
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(response); err != nil {
		http.Error(w, "Failed to generate response", http.StatusInternalServerError)
	}
}

// Main function to initialize the server
func main() {
	// Generate a random AES key when the server starts
	var err error
	aesKey, err = generateAESKey()
	if err != nil {
		log.Fatalf("Error generating AES key: %v", err)
	}
	log.Println("AES Key generated successfully")

	// RSA key generation (for encryption/decryption example purposes)
	// Generate RSA keys (private and public)
	rsaPrivateKey, rsaPublicKey, err = generateRSAKeys()
	if err != nil {
		log.Fatalf("Error generating RSA keys: %v", err)
	}

	http.HandleFunc("/generate-invitation-code", generateInvitationCodeHandler)
	http.HandleFunc("/validate-invitation-code", validateInvitationCodeHandler)

	// Start the server on port 3002
	fmt.Println("Server running on http://localhost:3002")
	log.Fatal(http.ListenAndServe(":3002", nil))
}

// Generate RSA private and public keys
func generateRSAKeys() (*rsa.PrivateKey, *rsa.PublicKey, error) {
	privKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		return nil, nil, err
	}
	pubKey := &privKey.PublicKey
	return privKey, pubKey, nil
}

// package main

// import (
// 	"crypto/aes"
// 	"crypto/cipher"
// 	"crypto/rand"
// 	"crypto/rsa"
// 	"crypto/sha256"
// 	"encoding/base64"
// 	"encoding/json"
// 	"fmt"
// 	"log"
// 	mrand "math/rand"
// 	"net/http"
// 	"sync"
// 	"time"
// )

// var (
// 	// Global variables
// 	aesKey           []byte            // AES Key for encryption
// 	rsaPrivateKey    *rsa.PrivateKey   // RSA Private Key for decryption
// 	rsaPublicKey     *rsa.PublicKey    // RSA Public Key for encryption
// 	cache            sync.Map          // In-memory cache to store encrypted data
// )

// // Generate a random 32-byte AES key
// func generateAESKey() ([]byte, error) {
// 	key := make([]byte, 32) // AES-256 requires a 32-byte key
// 	_, err := rand.Read(key) // Use crypto/rand for secure random data
// 	if err != nil {
// 		return nil, err
// 	}
// 	return key, nil
// }

// // Encrypt the given data using AES
// func encryptAES(data string) (string, error) {
// 	block, err := aes.NewCipher(aesKey)
// 	if err != nil {
// 		return "", err
// 	}

// 	plaintext := []byte(data)
// 	ciphertext := make([]byte, aes.BlockSize+len(plaintext))
// 	iv := ciphertext[:aes.BlockSize] // Initialization vector

// 	// Generate a random IV using crypto/rand
// 	_, err = rand.Read(iv)
// 	if err != nil {
// 		return "", err
// 	}

// 	// Encrypt the data using CFB mode
// 	stream := cipher.NewCFBEncrypter(block, iv)
// 	stream.XORKeyStream(ciphertext[aes.BlockSize:], plaintext)

// 	return base64.StdEncoding.EncodeToString(ciphertext), nil
// }

// // Decrypt the given AES encrypted data
// func decryptAES(encryptedData string) (string, error) {
// 	block, err := aes.NewCipher(aesKey)
// 	if err != nil {
// 		return "", err
// 	}

// 	ciphertext, err := base64.StdEncoding.DecodeString(encryptedData)
// 	if err != nil {
// 		return "", err
// 	}

// 	iv := ciphertext[:aes.BlockSize] // Extract the IV from the ciphertext
// 	plaintext := make([]byte, len(ciphertext)-aes.BlockSize)

// 	// Decrypt the data using CFB mode
// 	stream := cipher.NewCFBDecrypter(block, iv)
// 	stream.XORKeyStream(plaintext, ciphertext[aes.BlockSize:])

// 	return string(plaintext), nil
// }

// // RSA encrypt the AES key
// func encryptRSA(data []byte, publicKey *rsa.PublicKey) (string, error) {
// 	encryptedData, err := rsa.EncryptOAEP(sha256.New(), rand.Reader, publicKey, data, nil)
// 	if err != nil {
// 		return "", err
// 	}
// 	return base64.StdEncoding.EncodeToString(encryptedData), nil
// }

// // RSA decrypt the AES key
// func decryptRSA(encryptedData string, privateKey *rsa.PrivateKey) ([]byte, error) {
// 	ciphertext, err := base64.StdEncoding.DecodeString(encryptedData)
// 	if err != nil {
// 		return nil, err
// 	}
// 	decryptedData, err := rsa.DecryptOAEP(sha256.New(), rand.Reader, privateKey, ciphertext, nil)
// 	if err != nil {
// 		return nil, err
// 	}
// 	return decryptedData, nil
// }

// // Function to generate RSA keys (for testing purposes)
// func generateRSAKeys() (*rsa.PrivateKey, *rsa.PublicKey, error) {
// 	privateKey, err := rsa.GenerateKey(rand.Reader, 2048)
// 	if err != nil {
// 		return nil, nil, err
// 	}
// 	publicKey := &privateKey.PublicKey
// 	return privateKey, publicKey, nil
// }

// // Struct to hold the invitation code details
// type InvitationCode struct {
// 	GroupID       string `json:"group_id"`
// 	SubgroupID    string `json:"subgroup_id"`
// 	OTP           string `json:"otp"`
// 	ExpirationTime int64  `json:"expiration_time"`
// }

// // Generate a random OTP (non-cryptographic)
// func generateOTP() string {
// 	otp := ""
// 	for i := 0; i < 6; i++ {
// 		digit := mrand.Intn(10) // Using rand.Intn() to generate a random digit
// 		otp += fmt.Sprintf("%d", digit)
// 	}
// 	return otp
// }

// // Create an invitation code and store it in memory (cache)
// func createInvitationCode(groupID, subgroupID, otp string, expirationTime int64) (string, string, error) {
// 	// Format: groupID|subgroupID|OTP|expirationTime
// 	data := fmt.Sprintf("%s|%s|%s|%d", groupID, subgroupID, otp, expirationTime)

// 	// Encrypt the data using AES
// 	encryptedData, err := encryptAES(data)
// 	if err != nil {
// 		return "", "", err
// 	}

// 	// Encrypt the AES key using RSA
// 	encryptedAESKey, err := encryptRSA(aesKey, rsaPublicKey)
// 	if err != nil {
// 		return "", "", err
// 	}

// 	// Store the encrypted data in memory (in-memory cache)
// 	cache.Store(encryptedAESKey, encryptedData)

// 	return encryptedAESKey, encryptedData, nil
// }

// // Validate the invitation code by decrypting and checking expiration
// func validateInvitationCode(code string) (bool, string, string, error) {
// 	// Retrieve encrypted data from cache using the code
// 	encryptedData, ok := cache.Load(code)
// 	if !ok {
// 		return false, "", "", fmt.Errorf("invitation code not found")
// 	}

// 	// Decrypt the AES key using RSA
// 	decryptedAESKey, err := decryptRSA(code, rsaPrivateKey)
// 	if err != nil {
// 		return false, "", "", fmt.Errorf("failed to decrypt AES key: %v", err)
// 	}
// 	aesKey = decryptedAESKey

// 	// Decrypt the invitation data using AES
// 	decryptedData, err := decryptAES(encryptedData.(string))
// 	if err != nil {
// 		return false, "", "", fmt.Errorf("failed to decrypt invitation code: %v", err)
// 	}

// 	// Extract the groupID, subgroupID, OTP, and expiration time from the decrypted data
// 	var groupID, subgroupID, otp string
// 	var expiration int64
// 	_, err = fmt.Sscanf(decryptedData, "%s|%s|%s|%d", &groupID, &subgroupID, &otp, &expiration)
// 	if err != nil {
// 		return false, "", "", fmt.Errorf("failed to parse decrypted data: %v", err)
// 	}

// 	// Check if the invitation code has expired
// 	if time.Now().Unix() > expiration {
// 		return false, "", "", fmt.Errorf("invitation code expired")
// 	}

// 	// Return success with the group and subgroup IDs
// 	return true, groupID, subgroupID, nil
// }

// // HTTP handler for creating an invitation code
// func createInvitationCodeHandler(w http.ResponseWriter, r *http.Request) {
// 	// Hardcoded for testing purposes
// 	groupID := "group1"
// 	subgroupID := "subgroupA"
// 	otp := generateOTP()
// 	expirationTime := time.Now().Add(24 * time.Hour).Unix() // Set expiry to 24 hours from now

// 	// Create the invitation code
// 	encryptedKey, encryptedData, err := createInvitationCode(groupID, subgroupID, otp, expirationTime)
// 	if err != nil {
// 		http.Error(w, fmt.Sprintf("Failed to create invitation code: %v", err), http.StatusInternalServerError)
// 		return
// 	}

// 	// Respond with the encrypted invitation code and data
// 	response := struct {
// 		EncryptedKey  string `json:"encrypted_key"`
// 		EncryptedData string `json:"encrypted_data"`
// 	}{
// 		EncryptedKey:  encryptedKey,
// 		EncryptedData: encryptedData,
// 	}

// 	w.Header().Set("Content-Type", "application/json")
// 	if err := json.NewEncoder(w).Encode(response); err != nil {
// 		http.Error(w, fmt.Sprintf("Failed to encode response: %v", err), http.StatusInternalServerError)
// 	}
// }

// // HTTP handler for validating an invitation code
// func validateInvitationCodeHandler(w http.ResponseWriter, r *http.Request) {
// 	// Example invitation code for testing purposes
// 	invitationCode := "example_code"

// 	// Validate the invitation code
// 	valid, groupID, subgroupID, err := validateInvitationCode(invitationCode)
// 	if err != nil {
// 		http.Error(w, fmt.Sprintf("Failed to validate invitation code: %v", err), http.StatusBadRequest)
// 		return
// 	}

// 	// Respond with validation result
// 	response := struct {
// 		Valid        bool   `json:"valid"`
// 		GroupID      string `json:"group_id"`
// 		SubgroupID   string `json:"subgroup_id"`
// 	}{
// 		Valid:      valid,
// 		GroupID:    groupID,
// 		SubgroupID: subgroupID,
// 	}

// 	w.Header().Set("Content-Type", "application/json")
// 	if err := json.NewEncoder(w).Encode(response); err != nil {
// 		http.Error(w, fmt.Sprintf("Failed to encode response: %v", err), http.StatusInternalServerError)
// 	}
// }

// func main() {
// 	// Generate AES key
// 	var err error
// 	aesKey, err = generateAESKey()
// 	if err != nil {
// 		log.Fatal("Failed to generate AES key:", err)
// 	}

// 	// Generate RSA keys for testing purposes
// 	rsaPrivateKey, rsaPublicKey, err = generateRSAKeys()
// 	if err != nil {
// 		log.Fatal("Failed to generate RSA keys:", err)
// 	}

// 	// Register HTTP handlers
// 	http.HandleFunc("/create_invitation_code", createInvitationCodeHandler)
// 	http.HandleFunc("/validate_invitation_code", validateInvitationCodeHandler)

// 	// Start HTTP server
// 	log.Println("Starting server on :3002...")
// 	log.Fatal(http.ListenAndServe(":3002", nil))
// }
