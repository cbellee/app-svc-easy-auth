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
	// function handler
	http.HandleFunc("/helloFrontend", callBackend)

	// start HTTP listener
	http.ListenAndServe(":80", nil)
}

func callBackend(w http.ResponseWriter, req *http.Request) {
	// 'BACKEND_URI' is set in the Bicep deployment as an app configuration environment variable
	backendUri, ok := os.LookupEnv("BACKEND_URI")
	if !ok {
		backendUri = "https://localhost:80/helloBackend"
	}

	// struct to store JSON response
	type responseJson struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
		ExpiresIn    string `json:"expires_in"`
		ExpiresOn    string `json:"expires_on"`
		NotBefore    string `json:"not_before"`
		Resource     string `json:"resource"`
		TokenType    string `json:"token_type"`
	}

	// get an access token from AAD for the backend app using the frontend's managed identity
	response := getAccessToken()
	responseBytes, err := ioutil.ReadAll(response.Body)
	if err != nil {
		log.Println("Error reading response body: ", err)
		return
	}

	// convert response to struct
	var r responseJson
	err = json.Unmarshal(responseBytes, &r)
	if err != nil {
		log.Println("Error unmarshalling the response:", err)
		return
	}

	// create http client & add 'Authorization' header containing access token
	client := &http.Client{}
	request, _ := http.NewRequest("GET", backendUri, nil)
	header := fmt.Sprintf("Bearer %s", r.AccessToken)
	request.Header.Set("Authorization", header)

	// execute http request to backend app
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

	// read http response
	if response.StatusCode == 200 {
		body, err := ioutil.ReadAll(response.Body)
		if err != nil {
			log.Printf("error: %s", err.Error())
			w.Write([]byte(err.Error()))
			return
		}
		log.Printf("body: %s", body)
		w.Write(body)
	} else {
		log.Printf("HTTP status code: %d \n HTTP Status: %s", response.StatusCode, response.Status)
	}
}

func getAccessToken() *http.Response {
	// 'IDENTITY_HEADER' & 'IDENTITY_ENDPOINT' are supplied to the app automatically when Managed Identity is enabled
	header := os.Getenv("IDENTITY_HEADER")
	endpoint := os.Getenv("IDENTITY_ENDPOINT")

	// 'BACKEND_CLIENT_ID' is created in Bicep deloyment as an App Service Configuration (environment variable)
	resourceId := os.Getenv("BACKEND_CLIENT_ID")
	apiVersion := "2019-08-01"

	// build a uri to the managed identity endpoint
	miUri := fmt.Sprintf("%s?api-version=%s&resource=%s", endpoint, apiVersion, resourceId)
	log.Printf("MSI endpoint URI: %s", miUri)

	// create http client & add headers
	client := &http.Client{}
	request, _ := http.NewRequest("GET", miUri, nil)
	request.Header.Add("X-IDENTITY-HEADER", header)
	request.Header.Add("Metadata", "true")

	// execute http request
	response, err := client.Do(request)
	if err != nil {
		log.Println("Error calling token endpoint: ", err)
		return nil
	}

	return response
}
