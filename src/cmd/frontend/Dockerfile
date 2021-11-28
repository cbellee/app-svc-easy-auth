FROM golang:1.16.4-alpine3.13 AS builder

# Ca-certificates is required to call HTTPS endpoints.
RUN apk update && apk add --no-cache git ca-certificates && update-ca-certificates

RUN mkdir /app
WORKDIR /app
COPY src/cmd/frontend/main.go /app
COPY src/cmd/frontend/go.mod /app
RUN CGO_ENABLED=0 go build -o /bin/server

FROM scratch
COPY --from=builder /bin/server /bin/server
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
ENTRYPOINT ["/bin/server"]