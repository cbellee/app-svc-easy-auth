package main

import (
	"fmt"
	"net/http"
	"os"
)

func helloBackend(w http.ResponseWriter, req *http.Request) {
	host := os.Getenv("WEBSITE_HOSTNAME")
	respStr := fmt.Sprintf("hello from backend website: %s", host)
	w.Write([]byte(respStr))
}

func main() {
	http.HandleFunc("/helloBackend", helloBackend)
	http.ListenAndServe(":80", nil)
}