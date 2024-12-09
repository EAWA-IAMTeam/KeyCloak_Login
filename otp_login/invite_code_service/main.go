package main

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"
	"log"

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

// 1. LOGIN_PAGE.DART
func exchangeGoogleToken(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Invalid request method", http.StatusMethodNotAllowed)
		return
	}

	// Parse the incoming request to get the Google access token
	var requestData struct {
		GoogleAccessToken string `json:"googleAccessToken"`
	}
	if err := json.NewDecoder(r.Body).Decode(&requestData); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Prepare the data for the token exchange request to Keycloak
	data := url.Values{
		"grant_type":     {"urn:ietf:params:oauth:grant-type:token-exchange"},
		"subject_token":  {requestData.GoogleAccessToken},
		"client_id":      {"frontend-login"},
		"client_secret":  {os.Getenv("KEYCLOAK_CLIENT_SECRET")},
		"subject_issuer": {"google"},
	}

	// Exchange token with Keycloak
	keycloakUrl := os.Getenv("KEYCLOAK_URL")
	resp, err := http.PostForm(keycloakUrl, data)
	if err != nil || resp.StatusCode != http.StatusOK {
		http.Error(w, "Failed to exchange Google token", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	var keycloakTokens map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&keycloakTokens); err != nil {
		http.Error(w, "Error decoding Keycloak response", http.StatusInternalServerError)
		return
	}

	// Respond with the Keycloak tokens
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(keycloakTokens)
}

// 2. HOME_PAGE.DART
// Handles Keycloak logout
func handleLogout(w http.ResponseWriter, r *http.Request) {
	// Check for the required fields in the request
	clientID := os.Getenv("KEYCLOAK_CLIENT_ID")         // Example: "frontend-login"
	clientSecret := os.Getenv("KEYCLOAK_CLIENT_SECRET") // Example: "0SSZj01TDs7812fLBxgwTKPA74ghnLQM"
	refreshToken := r.URL.Query().Get("refresh_token")

	if refreshToken == "" {
		http.Error(w, "Missing refresh token", http.StatusBadRequest)
		return
	}

	// Keycloak logout endpoint
	keycloakURL := os.Getenv("KEYCLOAK_HOST_URL") // Example: "http://localhost:8080"
	if keycloakURL == "" {
		http.Error(w, "Keycloak URL not configured", http.StatusInternalServerError)
		return
	}
	logoutEndpoint := fmt.Sprintf("%s/protocol/openid-connect/logout", keycloakURL)

	// Prepare the request payload
	data := url.Values{}
	data.Set("client_id", clientID)
	data.Set("client_secret", clientSecret)
	data.Set("refresh_token", refreshToken)

	// Make POST request to Keycloak
	req, err := http.NewRequest("POST", logoutEndpoint, bytes.NewBufferString(data.Encode()))
	if err != nil {
		http.Error(w, "Failed to create request", http.StatusInternalServerError)
		return
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		http.Error(w, "Failed to communicate with Keycloak", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	// Handle non-200 responses from Keycloak
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		http.Error(w, fmt.Sprintf("Keycloak returned status: %d, body: %s", resp.StatusCode, string(body)), resp.StatusCode)
		return
	}

	// Return success response
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("User logged out successfully"))
}

// Handles the token refresh request
func handleRefreshToken(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Invalid request method", http.StatusMethodNotAllowed)
		return
	}

	// Parse request body to get the refresh token
	var requestData struct {
		RefreshToken string `json:"refreshToken"`
	}

	if err := json.NewDecoder(r.Body).Decode(&requestData); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Keycloak token refresh URL
	keycloakURL := fmt.Sprintf("%s/realms/G-SSO-Connect/protocol/openid-connect/token", os.Getenv("KEYCLOAK_HOST_URL"))

	// Prepare request to refresh token
	resp, err := http.PostForm(keycloakURL, map[string][]string{
		"client_id":     {"frontend-login"},
		"client_secret": {os.Getenv("KEYCLOAK_CLIENT_SECRET")},
		"grant_type":    {"refresh_token"},
		"refresh_token": {requestData.RefreshToken},
	})

	if err != nil || resp.StatusCode != http.StatusOK {
		http.Error(w, "Failed to refresh token", http.StatusInternalServerError)
		return
	}

	// Read response body to extract the new access token
	body, _ := io.ReadAll(resp.Body)
	var tokenResponse map[string]interface{}
	if err := json.Unmarshal(body, &tokenResponse); err != nil {
		http.Error(w, "Failed to parse token response", http.StatusInternalServerError)
		return
	}

	// Send the new access token in the response
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"access_token": tokenResponse["access_token"].(string),
	})
}

// 3.SELECT_COMPANY.DART
// GetClientAccessToken retrieves an access token using the client_credentials grant type
func GetClientAccessToken(w http.ResponseWriter, r *http.Request) {
	// Load Keycloak configuration from environment variables
	clientID := os.Getenv("KEYCLOAK_CLIENT_ID") // Example: "frontend-login"
	clientSecret := os.Getenv("KEYCLOAK_CLIENT_SECRET") // Example: "0SSZj01TDs7812fLBxgwTKPA74ghnLQM"
	keycloakURL := os.Getenv("KEYCLOAK_HOST_URL")       // Example: "http://localhost:8080"

	if clientID == "" || clientSecret == "" || keycloakURL == "" {
		http.Error(w, "Keycloak configuration is missing", http.StatusInternalServerError)
		return
	}

	// Keycloak token endpoint
	tokenEndpoint := fmt.Sprintf("%s/realms/G-SSO-Connect/protocol/openid-connect/token", keycloakURL)

	// Prepare the request payload
	data := url.Values{}
	data.Set("client_id", clientID)
	data.Set("client_secret", clientSecret)
	data.Set("grant_type", "client_credentials")

	// Make POST request to Keycloak
	req, err := http.NewRequest("POST", tokenEndpoint, bytes.NewBufferString(data.Encode()))
	if err != nil {
		http.Error(w, "Failed to create request", http.StatusInternalServerError)
		return
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		http.Error(w, "Failed to communicate with Keycloak", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	// Handle non-200 responses from Keycloak
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		http.Error(w, fmt.Sprintf("Keycloak returned status: %d, body: %s", resp.StatusCode, string(body)), resp.StatusCode)
		return
	}

	// Read and return the response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		http.Error(w, "Failed to read response from Keycloak", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(body)
}

func getUserGroupsHandler(w http.ResponseWriter, r *http.Request) {
	userId := r.URL.Query().Get("userId")
	if r.Method != http.MethodPost {
		http.Error(w, "Invalid request method", http.StatusMethodNotAllowed)
		return
	}

	// Extract Keycloak Access Token from Authorization header
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" || len(authHeader) < 8 {
		http.Error(w, "Missing or invalid Authorization header", http.StatusBadRequest)
		return
	}
	keycloakAccessToken := authHeader[7:]

	// Use Keycloak admin client to fetch groups
	client := &http.Client{}
	req, err := http.NewRequest("GET", fmt.Sprintf("%s/users/%s/groups", os.Getenv("KEYCLOAK_BASE_URL"), userId), nil)
	if err != nil {
		http.Error(w, "Failed to create request", http.StatusInternalServerError)
		return
	}

	req.Header.Set("Authorization", "Bearer "+keycloakAccessToken)
	resp, err := client.Do(req)
	if err != nil || resp.StatusCode != http.StatusOK {
		http.Error(w, "Failed to fetch groups from Keycloak", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	// Decode the response from Keycloak
	var groups []map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&groups); err != nil {
		http.Error(w, "Failed to parse Keycloak response", http.StatusInternalServerError)
		return
	}

	// Prepare response in list format
	type Group struct {
		ID       string `json:"id"`
		Name     string `json:"name"`
		ParentID string `json:"parentId,omitempty"`
	}
	var groupList []Group

	for _, group := range groups {
		groupObj := Group{
			ID:   group["id"].(string),
			Name: group["name"].(string),
		}
		if parentID, ok := group["parentId"].(string); ok {
			groupObj.ParentID = parentID
		}
		groupList = append(groupList, groupObj)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(groupList)
}

func GetGroupDetails(w http.ResponseWriter, r *http.Request) {
	// Extract parameters from request
	parentID := r.URL.Query().Get("parentId")
	if parentID == "" {
		http.Error(w, "Missing parentId parameter", http.StatusBadRequest)
		return
	}

	clientToken := r.Header.Get("Authorization")
	if clientToken == "" {
		http.Error(w, "Missing Authorization header", http.StatusUnauthorized)
		return
	}

	// Keycloak URL from environment variables
	keycloakURL := os.Getenv("KEYCLOAK_BASE_URL")
	if keycloakURL == "" {
		http.Error(w, "Keycloak URL not configured", http.StatusInternalServerError)
		return
	}

	// Construct Keycloak group URL
	url := fmt.Sprintf("%s/groups/%s", keycloakURL, parentID)

	// Make a GET request to Keycloak
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		http.Error(w, "Failed to create request", http.StatusInternalServerError)
		return
	}
	req.Header.Set("Authorization", clientToken)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		http.Error(w, "Failed to communicate with Keycloak", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	// Handle non-200 responses
	if resp.StatusCode != http.StatusOK {
		http.Error(w, fmt.Sprintf("Keycloak returned status: %d", resp.StatusCode), resp.StatusCode)
		return
	}

	// Read and forward the response
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		http.Error(w, "Failed to read Keycloak response", http.StatusInternalServerError)
		return
	}

	var groupDetails interface{}
	if err := json.Unmarshal(body, &groupDetails); err != nil {
		http.Error(w, "Failed to parse Keycloak response", http.StatusInternalServerError)
		return
	}

	// Respond with group details
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(groupDetails)
}

// 4. SELECT_COMPANYFORUSER
func GetAllGroups(w http.ResponseWriter, r *http.Request) {
	// Extract the Authorization header
	clientToken := r.Header.Get("Authorization")
	if clientToken == "" {
		http.Error(w, "Missing Authorization header", http.StatusUnauthorized)
		return
	}

	// Keycloak URL from environment variables
	keycloakURL := os.Getenv("KEYCLOAK_BASE_URL")
	if keycloakURL == "" {
		http.Error(w, "Keycloak URL not configured", http.StatusInternalServerError)
		return
	}

	// Construct Keycloak groups URL
	url := fmt.Sprintf("%s/groups", keycloakURL)

	// Make a GET request to Keycloak
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		http.Error(w, "Failed to create request", http.StatusInternalServerError)
		return
	}
	req.Header.Set("Authorization", clientToken)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		http.Error(w, "Failed to communicate with Keycloak", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	// Handle non-200 responses
	if resp.StatusCode != http.StatusOK {
		http.Error(w, fmt.Sprintf("Keycloak returned status: %d", resp.StatusCode), resp.StatusCode)
		return
	}

	// Read and forward the response
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		http.Error(w, "Failed to read Keycloak response", http.StatusInternalServerError)
		return
	}

	var groups interface{}
	if err := json.Unmarshal(body, &groups); err != nil {
		http.Error(w, "Failed to parse Keycloak response", http.StatusInternalServerError)
		return
	}

	// Respond with group details
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(groups)
}

func GetChildGroups(w http.ResponseWriter, r *http.Request) {
	// Extract the Authorization header
	clientToken := r.Header.Get("Authorization")
	if clientToken == "" {
		http.Error(w, "Missing Authorization header", http.StatusUnauthorized)
		return
	}

	// Get the parent group ID from the query parameters
	parentGroupID := r.URL.Query().Get("parentGroupId")
	if parentGroupID == "" {
		http.Error(w, "Missing parentGroupId parameter", http.StatusBadRequest)
		return
	}

	// Keycloak URL from environment variables
	keycloakURL := os.Getenv("KEYCLOAK_BASE_URL")
	if keycloakURL == "" {
		http.Error(w, "Keycloak URL not configured", http.StatusInternalServerError)
		return
	}

	// Construct Keycloak endpoint for child groups
	url := fmt.Sprintf("%s/groups/%s/children", keycloakURL, parentGroupID)

	// Make a GET request to Keycloak
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		http.Error(w, "Failed to create request", http.StatusInternalServerError)
		return
	}
	req.Header.Set("Authorization", clientToken)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		http.Error(w, "Failed to communicate with Keycloak", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	// Handle non-200 responses
	if resp.StatusCode != http.StatusOK {
		http.Error(w, fmt.Sprintf("Keycloak returned status: %d", resp.StatusCode), resp.StatusCode)
		return
	}

	// Read and forward the response
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		http.Error(w, "Failed to read Keycloak response", http.StatusInternalServerError)
		return
	}

	var childGroups interface{}
	if err := json.Unmarshal(body, &childGroups); err != nil {
		http.Error(w, "Failed to parse Keycloak response", http.StatusInternalServerError)
		return
	}

	// Respond with child group details
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(childGroups)
}

func CreateChildGroups(w http.ResponseWriter, r *http.Request) {
	// Validate HTTP method
	if r.Method != http.MethodPost {
		http.Error(w, "Invalid request method", http.StatusMethodNotAllowed)
		return
	}

	// Extract Authorization header
	clientToken := r.Header.Get("Authorization")
	if clientToken == "" {
		http.Error(w, "Missing Authorization header", http.StatusUnauthorized)
		return
	}

	// Extract parentGroupId from query parameters
	parentGroupID := r.URL.Query().Get("parentGroupId")
	if parentGroupID == "" {
		http.Error(w, "Missing parentGroupId parameter", http.StatusBadRequest)
		return
	}

	// Parse request body to extract child group name
	var requestBody struct {
		Name string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&requestBody); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Construct Keycloak URL
	keycloakURL := os.Getenv("KEYCLOAK_BASE_URL")
	if keycloakURL == "" {
		http.Error(w, "Keycloak URL not configured", http.StatusInternalServerError)
		return
	}
	url := fmt.Sprintf("%s/groups/%s/children", keycloakURL, parentGroupID)

	// Prepare request to Keycloak
	childGroupData := map[string]string{"name": requestBody.Name}
	requestBodyBytes, _ := json.Marshal(childGroupData)

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(requestBodyBytes))
	if err != nil {
		http.Error(w, "Failed to create request", http.StatusInternalServerError)
		return
	}
	req.Header.Set("Authorization", clientToken)
	req.Header.Set("Content-Type", "application/json")

	// Send request to Keycloak
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		http.Error(w, "Failed to communicate with Keycloak", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	// Check for successful response
	if resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		log.Printf("Keycloak error: Status %d, Body: %s", resp.StatusCode, string(body))
		http.Error(w, fmt.Sprintf("Keycloak error: %s", string(body)), resp.StatusCode)
		return
	}

	// Parse response from Keycloak
	var keycloakResponse map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&keycloakResponse); err != nil {
		http.Error(w, "Failed to parse Keycloak response", http.StatusInternalServerError)
		return
	}

	// Respond with the created child group details
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(keycloakResponse)
}


// 5. CREATE_COMPANY.DART

func CreateGroup(w http.ResponseWriter, r *http.Request) {
	// Ensure the request method is POST
	if r.Method != http.MethodPost {
		http.Error(w, "Invalid request method", http.StatusMethodNotAllowed)
		return
	}

	// Extract the Authorization header
	clientToken := r.Header.Get("Authorization")
	if clientToken == "" {
		http.Error(w, "Missing Authorization header", http.StatusUnauthorized)
		return
	}

	// Parse the request body
	var requestBody struct {
		Name string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&requestBody); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Validate group name
	if requestBody.Name == "" {
		http.Error(w, "Group name is required", http.StatusBadRequest)
		return
	}

	// Keycloak URL from environment variables
	keycloakURL := os.Getenv("KEYCLOAK_BASE_URL")
	if keycloakURL == "" {
		http.Error(w, "Keycloak URL not configured", http.StatusInternalServerError)
		return
	}

	// Construct the Keycloak group creation URL
	url := fmt.Sprintf("%s/groups", keycloakURL)

	// Create the request payload for Keycloak
	keycloakPayload := map[string]string{"name": requestBody.Name}
	payload, err := json.Marshal(keycloakPayload)
	if err != nil {
		http.Error(w, "Failed to encode request body", http.StatusInternalServerError)
		return
	}

	// Make a POST request to Keycloak
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(payload))
	if err != nil {
		http.Error(w, "Failed to create request", http.StatusInternalServerError)
		return
	}
	req.Header.Set("Authorization", clientToken)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		http.Error(w, "Failed to communicate with Keycloak", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	// Handle non-201 responses from Keycloak
	if resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		http.Error(w, fmt.Sprintf("Keycloak returned status: %d, body: %s", resp.StatusCode, string(body)), resp.StatusCode)
		return
	}

	// Respond with success
	w.WriteHeader(http.StatusCreated)
	w.Write([]byte(`{"message": "Group created successfully"}`))
}

// AddUserToSubgroup adds a user to a specific subgroup in Keycloak
func AddUserToSubgroup(w http.ResponseWriter, r *http.Request) {
	// Extract Authorization header
	clientToken := r.Header.Get("Authorization")
	if clientToken == "" {
		http.Error(w, "Missing Authorization header", http.StatusUnauthorized)
		return
	}

	// Parse userId and subgroupId from query parameters
	userID := r.URL.Query().Get("userId")
	subgroupID := r.URL.Query().Get("subgroupId")
	if userID == "" || subgroupID == "" {
		http.Error(w, "Missing userId or subgroupId parameter", http.StatusBadRequest)
		return
	}

	// Keycloak URL from environment variables
	keycloakURL := os.Getenv("KEYCLOAK_BASE_URL")
	if keycloakURL == "" {
		http.Error(w, "Keycloak URL not configured", http.StatusInternalServerError)
		return
	}

	// Keycloak endpoint URL
	url := fmt.Sprintf("%s/users/%s/groups/%s", keycloakURL, userID, subgroupID)

	// Create request body
	requestBody := []map[string]string{
		{"id": userID},
	}
	body, err := json.Marshal(requestBody)
	if err != nil {
		http.Error(w, "Failed to encode request body", http.StatusInternalServerError)
		return
	}

	// Make PUT request to Keycloak
	req, err := http.NewRequest("PUT", url, bytes.NewBuffer(body))
	if err != nil {
		http.Error(w, "Failed to create request", http.StatusInternalServerError)
		return
	}
	req.Header.Set("Authorization", clientToken)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		http.Error(w, "Failed to communicate with Keycloak", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	// Handle non-204 responses from Keycloak
	if resp.StatusCode != http.StatusNoContent {
		body, _ := io.ReadAll(resp.Body)
		http.Error(w, fmt.Sprintf("Keycloak returned status: %d, body: %s", resp.StatusCode, string(body)), resp.StatusCode)
		return
	}

	// Respond with success
	w.WriteHeader(http.StatusNoContent)
}

// GetKeycloakClient fetches client details from Keycloak based on the clientId
func GetKeycloakClient(w http.ResponseWriter, r *http.Request) {
	// Extract Authorization header
	clientToken := r.Header.Get("Authorization")
	if clientToken == "" {
		http.Error(w, "Missing Authorization header", http.StatusUnauthorized)
		return
	}

	// Parse clientId from query parameters
	clientID := r.URL.Query().Get("clientId")
	if clientID == "" {
		http.Error(w, "Missing clientId parameter", http.StatusBadRequest)
		return
	}

	// Keycloak URL from environment variables
	keycloakURL := os.Getenv("KEYCLOAK_BASE_URL")
	if keycloakURL == "" {
		http.Error(w, "Keycloak URL not configured", http.StatusInternalServerError)
		return
	}

	// Construct Keycloak endpoint URL
	url := fmt.Sprintf("%s/clients?clientId=%s", keycloakURL, clientID)

	// Make GET request to Keycloak
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		http.Error(w, "Failed to create request", http.StatusInternalServerError)
		return
	}
	req.Header.Set("Authorization", clientToken)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		http.Error(w, "Failed to communicate with Keycloak", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	// Handle non-200 responses from Keycloak
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		http.Error(w, fmt.Sprintf("Keycloak returned status: %d, body: %s", resp.StatusCode, string(body)), resp.StatusCode)
		return
	}

	// Read and forward response from Keycloak
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		http.Error(w, "Failed to read response from Keycloak", http.StatusInternalServerError)
		return
	}

	// Return the response from Keycloak to the client
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(body)
}

// GetClientRole fetches details of a specific role for a client in Keycloak
func GetClientRole(w http.ResponseWriter, r *http.Request) {
	// Extract Authorization header
	clientToken := r.Header.Get("Authorization")
	if clientToken == "" {
		http.Error(w, "Missing Authorization header", http.StatusUnauthorized)
		return
	}

	// Extract clientInternalId and clientRole from query parameters
	clientInternalID := r.URL.Query().Get("clientInternalId")
	clientRole := r.URL.Query().Get("clientRole")
	if clientInternalID == "" || clientRole == "" {
		http.Error(w, "Missing clientInternalId or clientRole parameter", http.StatusBadRequest)
		return
	}

	// Keycloak URL from environment variables
	keycloakURL := os.Getenv("KEYCLOAK_BASE_URL")
	if keycloakURL == "" {
		http.Error(w, "Keycloak URL not configured", http.StatusInternalServerError)
		return
	}

	// Construct Keycloak endpoint URL
	url := fmt.Sprintf("%s/clients/%s/roles/%s", keycloakURL, clientInternalID, clientRole)

	// Make GET request to Keycloak
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		http.Error(w, "Failed to create request", http.StatusInternalServerError)
		return
	}
	req.Header.Set("Authorization", clientToken)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		http.Error(w, "Failed to communicate with Keycloak", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	// Handle non-200 responses from Keycloak
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		http.Error(w, fmt.Sprintf("Keycloak returned status: %d, body: %s", resp.StatusCode, string(body)), resp.StatusCode)
		return
	}

	// Read and forward response from Keycloak
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		http.Error(w, "Failed to read response from Keycloak", http.StatusInternalServerError)
		return
	}

	// Return the response from Keycloak to the client
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(body)
}

// AssignRoleToGroup assigns a client role to a Keycloak group
func AssignRoleToGroup(w http.ResponseWriter, r *http.Request) {
	// Extract Authorization header
	clientToken := r.Header.Get("Authorization")
	if clientToken == "" {
		http.Error(w, "Missing Authorization header", http.StatusUnauthorized)
		return
	}

	// Extract groupId and clientInternalId from query parameters
	groupID := r.URL.Query().Get("groupId")
	clientInternalID := r.URL.Query().Get("clientInternalId")
	if groupID == "" || clientInternalID == "" {
		http.Error(w, "Missing groupId or clientInternalId parameter", http.StatusBadRequest)
		return
	}

	// Parse role details from the request body
	var roles []map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&roles); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Keycloak URL from environment variables
	keycloakURL := os.Getenv("KEYCLOAK_BASE_URL")
	if keycloakURL == "" {
		http.Error(w, "Keycloak URL not configured", http.StatusInternalServerError)
		return
	}

	// Construct Keycloak endpoint URL
	url := fmt.Sprintf("%s/groups/%s/role-mappings/clients/%s", keycloakURL, groupID, clientInternalID)

	// Convert roles to JSON
	payload, err := json.Marshal(roles)
	if err != nil {
		http.Error(w, "Failed to encode role data", http.StatusInternalServerError)
		return
	}

	// Make POST request to Keycloak
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(payload))
	if err != nil {
		http.Error(w, "Failed to create request", http.StatusInternalServerError)
		return
	}
	req.Header.Set("Authorization", clientToken)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		http.Error(w, "Failed to communicate with Keycloak", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	// Handle non-200 responses from Keycloak
	if resp.StatusCode != http.StatusNoContent {
		body, _ := io.ReadAll(resp.Body)
		http.Error(w, fmt.Sprintf("Keycloak returned status: %d, body: %s", resp.StatusCode, string(body)), resp.StatusCode)
		return
	}

	// Return success response
	w.WriteHeader(http.StatusNoContent)
}

//6. INVITE_USER.DART & 7. JOIN_COMPANY.DART

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
	http.HandleFunc("/exchange-google-token", exchangeGoogleToken) 	// /protocol/openid-connect/token

	http.HandleFunc("/logout", handleLogout)              			// /protocol/openid-connect/logout
	http.HandleFunc("/refresh-token", handleRefreshToken) 			// /protocol/openid-connect/token

	http.HandleFunc("/api/token", GetClientAccessToken)      		// /protocol/openid-connect/token
	http.HandleFunc("/api/usergroups", getUserGroupsHandler) 		// /users/$userId/groups
	http.HandleFunc("/api/group-details", GetGroupDetails)  		// /groups/$parentId

	http.HandleFunc("/api/groups", GetAllGroups)        	 		// /groups (GET)
	http.HandleFunc("/api/creategroups", CreateGroup)    	 		// /groups (POST)
	http.HandleFunc("/api/childgroups", GetChildGroups) 	 		// /groups/$parentGroupId/children (GET)
	http.HandleFunc("/api/createsubgroups", CreateChildGroups) 	    // /groups/$parentGroupId/children (POST)

	http.HandleFunc("/api/adduser", AddUserToSubgroup)              // /users/$userId/groups/$subgroupId
	http.HandleFunc("/api/get-client", GetKeycloakClient)           // /clients?clientId=$clientId
	http.HandleFunc("/api/get-client-role", GetClientRole)          // /clients/$clientInternalId/roles/$clientRole
	http.HandleFunc("/api/assign-role-to-group", AssignRoleToGroup) // /groups/$groupId/role-mappings/clients/$clientInternalId

	http.HandleFunc("/encrypt", encryptHandler)
	http.HandleFunc("/verify", verifyHandler)

	fmt.Println("Server running at http://localhost:3002")
	http.ListenAndServe(":3002", nil)
}
