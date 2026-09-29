package storage

import (
	"fmt"
	"strings"
)

// SpannerDDL contains the production Cloud Spanner schema definitions,
// including tables and Spanner Vector Indexing for project davenport-boutique.
const SpannerDDL = `
CREATE TABLE channels (
    channel_id STRING(64) NOT NULL,
    name STRING(128) NOT NULL,
    topic STRING(512),
    description STRING(2048),
    system_prompt STRING(MAX),
    retention_hours INT64,
    created_at TIMESTAMP NOT NULL OPTIONS (allow_commit_timestamp = true)
) PRIMARY KEY (channel_id);

CREATE TABLE messages (
    message_id STRING(64) NOT NULL,
    channel_id STRING(64) NOT NULL,
    thread_id STRING(64),
    sender_type STRING(32) NOT NULL,
    sender_id STRING(64) NOT NULL,
    sender_name STRING(128) NOT NULL,
    avatar_url STRING(512),
    content STRING(MAX) NOT NULL,
    token_count INT64 NOT NULL,
    embedding ARRAY<FLOAT32>(vector_length => 768),
    metadata_json JSON,
    created_at TIMESTAMP NOT NULL OPTIONS (allow_commit_timestamp = true)
) PRIMARY KEY (channel_id, message_id);

CREATE INDEX messages_by_thread ON messages(thread_id, created_at)
WHERE thread_id IS NOT NULL;

CREATE VECTOR INDEX messages_embedding_idx ON messages(embedding)
WHERE embedding IS NOT NULL
OPTIONS (distance_type = 'COSINE', type = 'TREE_AH');

CREATE TABLE summaries (
    summary_id STRING(64) NOT NULL,
    channel_id STRING(64) NOT NULL,
    thread_id STRING(64),
    covered_start_message_id STRING(64) NOT NULL,
    covered_end_message_id STRING(64) NOT NULL,
    condensed_state STRING(MAX) NOT NULL,
    original_tokens INT64 NOT NULL,
    compacted_tokens INT64 NOT NULL,
    compression_ratio FLOAT64 NOT NULL,
    created_at TIMESTAMP NOT NULL OPTIONS (allow_commit_timestamp = true)
) PRIMARY KEY (channel_id, summary_id);
`

// BuildSpannerVectorSearchQuery generates an optimized Spanner SQL query utilizing
// Spanner's native VECTOR_SEARCH or COSINE_DISTANCE function for K-NN retrieval.
func BuildSpannerVectorSearchQuery(channelID string, vectorLength int, topK int) string {
	var whereClauses []string
	whereClauses = append(whereClauses, "embedding IS NOT NULL")
	if channelID != "" {
		whereClauses = append(whereClauses, fmt.Sprintf("channel_id = '%s'", channelID))
	}

	whereSQL := strings.Join(whereClauses, " AND ")

	return fmt.Sprintf(`
SELECT 
    message_id, channel_id, thread_id, sender_type, sender_id, sender_name,
    avatar_url, content, token_count, metadata_json, created_at,
    COSINE_DISTANCE(embedding, @queryEmbedding) AS distance
FROM messages
WHERE %s
ORDER BY distance ASC
LIMIT %d;
`, whereSQL, topK)
}
