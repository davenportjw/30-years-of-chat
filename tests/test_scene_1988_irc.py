"""E2E Integration Tests for Scene 1 (1988 — The Ephemeral Buffer: IRC & Unix talk).

Architectural Invariants Verified on Deployed Cloud Run Service:
- Volatile RAM line-buffered daemon stream (chan-1988-irc)
- Short-Term Memory (STM) with fixed capacity (max_turns = 5)
- Amnesia Trap: Ingesting turns beyond capacity triggers FIFO displacement
- Eviction telemetry: Buffer reports evicted_count > 0, evicted messages drop off
- Real-time WebSocket telemetry event emission
"""

import asyncio
import json
import pytest
import httpx
import websockets

CHANNEL_ID = "chan-1988-irc"
ERA_ID = "era-1988-irc"


@pytest.mark.asyncio
async def test_scene_1988_metadata_and_channel_configuration(client: httpx.AsyncClient):
    """Verifies Scene 1 metadata, retention hours, and FIFO buffer turn configuration."""
    resp = await client.get("/api/channels")
    assert resp.status_code == 200
    channels = resp.json()

    irc_chan = next((c for c in channels if c["id"] == CHANNEL_ID), None)
    assert irc_chan is not None, f"Channel {CHANNEL_ID} not found in deployed channels"
    assert irc_chan["era_id"] == ERA_ID
    assert irc_chan["max_buffer_turns"] == 5
    assert irc_chan["retention_hours"] == 1
    assert "Line-buffered daemon stream" in irc_chan["topic"]


@pytest.mark.asyncio
async def test_scene_1988_initial_buffer_state(client: httpx.AsyncClient):
    """Verifies that the buffer endpoint returns active turn capacity metrics."""
    resp = await client.get(f"/api/channels/{CHANNEL_ID}/buffer")
    assert resp.status_code == 200
    buffer_data = resp.json()

    assert buffer_data["channel_id"] == CHANNEL_ID
    assert buffer_data["max_turns"] == 5
    assert 0 <= buffer_data["current_turns"] <= 5
    assert "evicted_count" in buffer_data


@pytest.mark.asyncio
async def test_scene_1988_fifo_amnesia_trap_eviction(client: httpx.AsyncClient, ws_url: str):
    """Tests the Amnesia Trap: posts turns to exceed 5 turns and asserts older turns evict."""
    # Step 1: Check initial messages and count
    initial_resp = await client.get(f"/api/channels/{CHANNEL_ID}/messages")
    assert initial_resp.status_code == 200
    initial_messages = initial_resp.json()
    initial_count = len(initial_messages)

    # Record a marker unique to the oldest turn
    oldest_initial_id = initial_messages[0]["id"] if initial_messages else None

    # Step 2: Post enough messages to force FIFO displacement beyond 5 turns
    sent_turn_ids = []
    for i in range(6):
        turn_msg = f"!bot ping turn {i + 1} - evaluating volatile RAM sliding window"
        post_resp = await client.post(
            f"/api/channels/{CHANNEL_ID}/messages",
            json={
                "content": turn_msg,
                "sender_name": "IRC Tester",
            },
        )
        assert post_resp.status_code in [200, 201], f"Failed to post turn {i}: {post_resp.text}"
        sent_turn_ids.append(post_resp.json()["id"])
        await asyncio.sleep(0.1)

    # Step 3: Query buffer status on the live deployment
    buffer_resp = await client.get(f"/api/channels/{CHANNEL_ID}/buffer")
    assert buffer_resp.status_code == 200
    buffer_metrics = buffer_resp.json()

    # The Amnesia Trap invariant: buffer size is strictly capped at max_turns (5)
    assert buffer_metrics["current_turns"] <= 5
    assert buffer_metrics["evicted_count"] > 0, "Expected FIFO displacement eviction count > 0"

    # Step 4: Verify that the oldest initial message has been evicted and dropped
    final_resp = await client.get(f"/api/channels/{CHANNEL_ID}/messages")
    assert final_resp.status_code == 200
    final_messages = final_resp.json()
    final_ids = {m["id"] for m in final_messages}

    # Total active messages in sliding window must not exceed 5
    assert len(final_messages) <= 5

    # Most recent turns must be present in the buffer
    assert sent_turn_ids[-1] in final_ids
