"""E2E Integration Tests for Scene 4 (2013 — The Searchable Vector Archive: Slack 1.0 & HipChat).

Architectural Invariants Verified on Deployed Cloud Run Service:
- Persistent Cloud Log (chan-incident-postmortem, 72h retention)
- Long-Term Memory (LTM): Spanner Vector Search (RAG) with embeddings
- Sensory Webhook Ingestion: POST /api/channels/{id}/events
- Vector Retrieval Intent Tags & Chronological Event Auditing
"""

import asyncio
import json
import pytest
import httpx

INCIDENT_CHANNEL = "chan-incident-postmortem"
ERA_ID = "era-2013-slack"


@pytest.mark.asyncio
async def test_scene_2013_channel_properties(client: httpx.AsyncClient):
    """Verifies that the incident channel is configured for persistent cloud logging."""
    resp = await client.get("/api/channels")
    assert resp.status_code == 200
    channels = resp.json()

    slack_ch = next((c for c in channels if c["id"] == INCIDENT_CHANNEL), None)
    assert slack_ch is not None
    assert slack_ch["era_id"] == ERA_ID
    assert slack_ch["retention_hours"] == 72
    assert "P0 Production Outage" in slack_ch["topic"]


@pytest.mark.asyncio
async def test_scene_2013_vector_embeddings_and_rag_grounding(client: httpx.AsyncClient):
    """Verifies that incident postmortem messages contain vector embeddings and RAG retrieval tags."""
    resp = await client.get(f"/api/channels/{INCIDENT_CHANNEL}/messages?limit=20")
    assert resp.status_code == 200
    messages = resp.json()
    assert len(messages) >= 5

    # Check for presence of vector embeddings in persistent cloud log
    embedded_messages = [m for m in messages if m.get("embedding") is not None and len(m["embedding"]) > 0]
    assert len(embedded_messages) >= 3, "Expected messages with vector embeddings"

    # Verify vector hit intent tags
    all_intent_labels = [
        tag["label"]
        for m in messages
        for tag in m.get("intent_tags", [])
    ]
    assert any("Vector Hit" in label for label in all_intent_labels), (
        f"Expected Spanner Vector Hit tag, found: {all_intent_labels}"
    )


@pytest.mark.asyncio
async def test_scene_2013_inbound_webhook_event_injection(client: httpx.AsyncClient):
    """Verifies sensory webhook ingestion via /api/channels/{id}/events."""
    event_title = "Cloud Monitoring Alert: Spanner Storage Lock Latency Spike"
    event_details = "p99 lock wait exceeded 250ms on shard 3 during schema compaction."

    # Step 1: Inject sensory event webhook
    inject_resp = await client.post(
        f"/api/channels/{INCIDENT_CHANNEL}/events",
        json={
            "title": event_title,
            "details": event_details,
        },
    )
    assert inject_resp.status_code in [200, 201]
    event_msg = inject_resp.json()

    assert event_msg["sender_id"] == "event-engine"
    assert event_msg["sender_name"] == "Scenario Event Engine"
    assert event_title in event_msg["content"]
    assert event_details in event_msg["content"]

    # Verify intent tag for audit trail
    tags = event_msg.get("intent_tags", [])
    assert any(tag.get("label") == "Event History: Live Injection" for tag in tags)

    # Step 2: Verify the injected event is persisted into the channel log
    stream_resp = await client.get(f"/api/channels/{INCIDENT_CHANNEL}/messages?limit=30")
    assert stream_resp.status_code == 200
    stream_messages = stream_resp.json()
    assert any(m["id"] == event_msg["id"] for m in stream_messages)
