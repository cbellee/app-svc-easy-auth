package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
)

func main() {
	http.HandleFunc("/helloFrontend", callBackend)
	http.ListenAndServe(":80", nil)
}

func callBackend(w http.ResponseWriter, req *http.Request) {
	backendUri, ok := os.LookupEnv("BACKEND_URI")
	if !ok {
		backendUri = "https://localhost:80/helloBackend"
	}

	type responseJson struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
		ExpiresIn    string `json:"expires_in"`
		ExpiresOn    string `json:"expires_on"`
		NotBefore    string `json:"not_before"`
		Resource     string `json:"resource"`
		TokenType    string `json:"token_type"`
	}

	response := getAccessToken()
	responseBytes, err := ioutil.ReadAll(response.Body)
	if err != nil {
		log.Println("Error reading response body: ", err)
		return
	}

	var r responseJson
	err = json.Unmarshal(responseBytes, &r)
	if err != nil {
		log.Println("Error unmarshalling the response:", err)
		return
	}

	client := &http.Client{}
	request, _ := http.NewRequest("GET", backendUri, nil)
	header := fmt.Sprintf("Bearer %s", r.AccessToken)
	request.Header.Set("Authorization", header)

	response, err = client.Do(request)
	if err != nil {
		log.Println("Error calling backend uri:", err)
		return
	}

	log.Printf("response status Code: %d", response.StatusCode)

	if err != nil {
		log.Printf("error: %s", err.Error())
		w.Write([]byte(err.Error()))
		return
	}

	body, err := ioutil.ReadAll(response.Body)
	if err != nil {
		log.Printf("error: %s", err.Error())
		w.Write([]byte(err.Error()))
		return
	}

	log.Printf("body: %s", body)
	w.Write(body)
}

func getAccessToken() *http.Response {
	header := os.Getenv("IDENTITY_HEADER")
	endpoint := os.Getenv("IDENTITY_ENDPOINT")
	resourceId := os.Getenv("BACKEND_CLIENT_ID")
	apiVersion := "2019-08-01"

	miUri := fmt.Sprintf("%s?api-version=%s&resource=%s", endpoint, apiVersion, resourceId)
	log.Printf("MSI endpoint URI: %s", miUri)

	client := &http.Client{}
	request, _ := http.NewRequest("GET", miUri, nil)
	request.Header.Add("X-IDENTITY-HEADER", header)
	request.Header.Add("Metadata", "true")

	response, err := client.Do(request)
	if err != nil {
		log.Println("Error calling token endpoint: ", err)
		return nil
	}

	return response
}
