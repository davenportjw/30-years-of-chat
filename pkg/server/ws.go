package server

import (
	"bufio"
	"crypto/sha1"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"sync"
)

const wsGUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

// WSMessage represents a real-time event sent across the WebSocket.
type WSMessage struct {
	Type    string      `json:"type"`
	Payload interface{} `json:"payload"`
}

// Client represents a connected WebSocket peer (e.g. Flutter Web UI).
type Client struct {
	conn net.Conn
	bufr *bufio.Reader
	hub  *WSHub
	send chan []byte
}

// WSHub manages active WebSocket clients and broadcasts.
type WSHub struct {
	mu         sync.RWMutex
	clients    map[*Client]bool
	broadcast  chan []byte
	register   chan *Client
	unregister chan *Client
	stopCh     chan struct{}
}

// NewWSHub creates an active WebSocket Hub.
func NewWSHub() *WSHub {
	return &WSHub{
		clients:    make(map[*Client]bool),
		broadcast:  make(chan []byte, 256),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		stopCh:     make(chan struct{}),
	}
}

// Run begins the hub event loop.
func (h *WSHub) Run() {
	for {
		select {
		case <-h.stopCh:
			return
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client] = true
			h.mu.Unlock()
		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)
				client.conn.Close()
			}
			h.mu.Unlock()
		case message := <-h.broadcast:
			h.mu.RLock()
			for client := range h.clients {
				select {
				case client.send <- message:
				default:
					close(client.send)
					delete(h.clients, client)
					client.conn.Close()
				}
			}
			h.mu.RUnlock()
		}
	}
}

// BroadcastEvent publishes an event to all connected clients.
func (h *WSHub) BroadcastEvent(eventType string, payload interface{}) {
	msg := WSMessage{
		Type:    eventType,
		Payload: payload,
	}
	data, err := json.Marshal(msg)
	if err == nil {
		h.broadcast <- data
	}
}

// Upgrade upgrades an incoming HTTP request to an RFC 6455 WebSocket connection.
func (h *WSHub) Upgrade(w http.ResponseWriter, r *http.Request) (*Client, error) {
	if !strings.EqualFold(r.Header.Get("Upgrade"), "websocket") {
		return nil, fmt.Errorf("missing websocket upgrade header")
	}

	key := r.Header.Get("Sec-WebSocket-Key")
	if key == "" {
		return nil, fmt.Errorf("missing Sec-WebSocket-Key")
	}

	// Compute Sec-WebSocket-Accept
	hKey := sha1.New()
	hKey.Write([]byte(key + wsGUID))
	accept := base64.StdEncoding.EncodeToString(hKey.Sum(nil))

	hijacker, ok := w.(http.Hijacker)
	if !ok {
		return nil, fmt.Errorf("webserver doesn't support hijacking")
	}

	conn, bufrw, err := hijacker.Hijack()
	if err != nil {
		return nil, fmt.Errorf("hijack failed: %w", err)
	}

	// Write handshake response
	res := fmt.Sprintf("HTTP/1.1 101 Switching Protocols\r\n"+
		"Upgrade: websocket\r\n"+
		"Connection: Upgrade\r\n"+
		"Sec-WebSocket-Accept: %s\r\n\r\n", accept)
	if _, err := conn.Write([]byte(res)); err != nil {
		conn.Close()
		return nil, err
	}

	client := &Client{
		conn: conn,
		bufr: bufrw.Reader,
		hub:  h,
		send: make(chan []byte, 128),
	}

	h.register <- client

	// Start pump routines
	go client.writePump()
	go client.readPump()

	return client, nil
}

func (c *Client) writePump() {
	for msg := range c.send {
		frame := encodeTextFrame(msg)
		if _, err := c.conn.Write(frame); err != nil {
			break
		}
	}
}

func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
	}()

	for {
		_, _, err := readFrame(c.bufr)
		if err != nil {
			break
		}
	}
}

// encodeTextFrame wraps bytes in an RFC 6455 unmasked text frame.
func encodeTextFrame(payload []byte) []byte {
	length := len(payload)
	var header []byte

	if length <= 125 {
		header = []byte{0x81, byte(length)}
	} else if length <= 65535 {
		header = []byte{0x81, 126, 0, 0}
		binary.BigEndian.PutUint16(header[2:], uint16(length))
	} else {
		header = make([]byte, 10)
		header[0] = 0x81
		header[1] = 127
		binary.BigEndian.PutUint64(header[2:], uint64(length))
	}

	return append(header, payload...)
}

// readFrame reads an RFC 6455 client frame (unmasks masked client frames).
func readFrame(r *bufio.Reader) (byte, []byte, error) {
	b1, err := r.ReadByte()
	if err != nil {
		return 0, nil, err
	}
	b2, err := r.ReadByte()
	if err != nil {
		return 0, nil, err
	}

	opcode := b1 & 0x0F
	masked := (b2 & 0x80) != 0
	payloadLen := int64(b2 & 0x7F)

	if payloadLen == 126 {
		var l uint16
		if err := binary.Read(r, binary.BigEndian, &l); err != nil {
			return 0, nil, err
		}
		payloadLen = int64(l)
	} else if payloadLen == 127 {
		var l uint64
		if err := binary.Read(r, binary.BigEndian, &l); err != nil {
			return 0, nil, err
		}
		payloadLen = int64(l)
	}

	var mask [4]byte
	if masked {
		if _, err := io.ReadFull(r, mask[:]); err != nil {
			return 0, nil, err
		}
	}

	payload := make([]byte, payloadLen)
	if _, err := io.ReadFull(r, payload); err != nil {
		return 0, nil, err
	}

	if masked {
		for i := int64(0); i < payloadLen; i++ {
			payload[i] ^= mask[i%4]
		}
	}

	return opcode, payload, nil
}
