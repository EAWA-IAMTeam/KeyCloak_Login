package main

import (
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"os"

	"github.com/joho/godotenv"
)

func generateRandomBytes(size int) string {
	bytes := make([]byte, size)
	_, err := rand.Read(bytes)
	if err != nil {
		panic("Error generating random bytes")
	}
	return base64.StdEncoding.EncodeToString(bytes)
}

func main() {
	key := generateRandomBytes(32) // 256-bit key
	iv := generateRandomBytes(16)  // 128-bit IV

	envFile := ".env"

	// Load existing .env file
	err := godotenv.Load(envFile)
	if err != nil {
		fmt.Println("No .env file found. A new one will be created.")
	}

	envMap := map[string]string{
		"AES_KEY": key,
		"AES_IV":  iv,
	}

	// Save AES key and IV to .env
	for k, v := range envMap {
		err := os.Setenv(k, v)
		if err != nil {
			panic(err)
		}
	}

	// Write to the .env file
	file, err := os.OpenFile(envFile, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0644)
	if err != nil {
		panic(err)
	}
	defer file.Close()

	for k, v := range envMap {
		_, _ = file.WriteString(fmt.Sprintf("%s=%s\n", k, v))
	}

	fmt.Printf("AES Key and IV saved to %s\n", envFile)
}
