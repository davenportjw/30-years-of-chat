# Stage 1: Build the Go application
FROM golang:1.24-bookworm AS builder

WORKDIR /src
ENV GOTOOLCHAIN=auto
COPY go.mod ./
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -v -o /server .

# Stage 2: Minimal runtime image
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /server /app/server
COPY frontend/build/web /app/frontend/build/web

ENV PORT=8080
ENV STATIC_DIR=/app/frontend/build/web
EXPOSE 8080

ENTRYPOINT ["/app/server"]
