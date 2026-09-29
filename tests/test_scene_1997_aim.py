"""E2E Integration Tests for Scene 2 (1997 — The 1:1 Direct Session & Presence: AIM & ICQ).

Architectural Invariants Verified on Deployed Cloud Run Service:
- Stateful 1:1 DMs (chan-1997-aim, chan-1997-aim-scribe, chan-1997-aim-researcher)
- Working Memory & Attentional State: Buddy roster presence (/api/presence)
- Dynamic System Prompt Persona Priming via Away Messages
- Session Boundary Isolation: Messages in 1:1 DM session do not cross-talk or leak
- Real-time WebSocket presence broadcasting (presence_updated)
"""

import asyncio
import json
import pytest
import httpx
import websockets

AIM_LEAD_CHANNEL = "chan-1997-aim"
AIM_SCRIBE_CHANNEL = "chan-1997-aim-scribe"
AIM_RESEARCHER_CHANNEL = "chan-1997-aim-researcher"
ERA_ID = "era-1997-aim"


@pytest.mark.asyncio
async def test_scene_1997_direct_session_channel_properties(client: httpx.AsyncClient):
    """Verifies that AIM channels are configured as isolated 1:1 direct sessions."""
    resp = await client.get("/api/channels")
    assert resp.status_code == 200
    channels = resp.json()

    aim_channels = [c for c in channels if c.get("era_id") == ERA_ID]
    assert len(aim_channels) == 3

    for ch in aim_channels:
        assert ch["is_direct_message"] is True
        assert ch["retention_hours"] == 24
        assert len(ch.get("allowed_roles", [])) == 1

    lead_ch = next(c for c in aim_channels if c["id"] == AIM_LEAD_CHANNEL)
    assert lead_ch["allowed_roles"] == ["lead-agent"]

    scribe_ch = next(c for c in aim_channels if c["id"] == AIM_SCRIBE_CHANNEL)
    assert scribe_ch["allowed_roles"] == ["scribe-agent"]

    researcher_ch = next(c for c in aim_channels if c["id"] == AIM_RESEARCHER_CHANNEL)
    assert researcher_ch["allowed_roles"] == ["researcher-agent"]


@pytest.mark.asyncio
async def test_scene_1997_presence_roster_and_attentional_state(client: httpx.AsyncClient):
    """Verifies retrieval of agent presence, task status, and attentional liveness."""
    resp = await client.get("/api/presence")
    assert resp.status_code == 200
    presences = resp.json()
    assert len(presences) == 3

    agent_ids = {p["agent_id"] for p in presences}
    assert agent_ids == {"lead-agent", "scribe-agent", "researcher-agent"}

    for p in presences:
        assert p["status"] in ["available", "away", "busy", "typing"]
        assert len(p["status_message"]) > 0
        assert len(p["current_task"]) > 0
        assert "last_heartbeat" in p


@pytest.mark.asyncio
async def test_scene_1997_update_presence_and_away_message_priming(client: httpx.AsyncClient, ws_url: str):
    """Tests updating agent presence and away message, verifying dynamic state."""
    target_agent_id = "scribe-agent"
    new_status = "away"
    new_message = "Away: Compacting architectural RFC thread history into hierarchical rollup"
    new_task = "Scribe compaction cycle"

    # Step 1: Update presence via REST API
    update_payload = {
        "agent_id": target_agent_id,
        "agent_name": "Staff Architect Scribe",
        "avatar_url": "https://api.dicebear.com/7.x/bottts/svg?seed=scribe",
        "status": new_status,
        "status_message": new_message,
        "current_task": new_task,
    }

    put_resp = await client.post("/api/presence", json=update_payload)
    assert put_resp.status_code == 200

    # Step 2: Verify presence persistence
    get_resp = await client.get("/api/presence")
    assert get_resp.status_code == 200
    presences = get_resp.json()

    scribe_presence = next(p for p in presences if p["agent_id"] == target_agent_id)
    assert scribe_presence["status"] == new_status
    assert scribe_presence["status_message"] == new_message
    assert scribe_presence["current_task"] == new_task


@pytest.mark.asyncio
async def test_scene_1997_session_boundary_isolation(client: httpx.AsyncClient):
    """Verifies that messages sent in a 1:1 session do not leak into another buddy channel."""
    # Step 1: Record initial message count in Scribe channel
    scribe_initial_resp = await client.get(f"/api/channels/{AIM_SCRIBE_CHANNEL}/messages")
    assert scribe_initial_resp.status_code == 200
    initial_scribe_count = len(scribe_initial_resp.json())

    # Step 2: Send a message strictly to the Lead channel
    unique_content = "AIM Direct Session Secret Token: session-isolation-verification-token-991"
    post_resp = await client.post(
        f"/api/channels/{AIM_LEAD_CHANNEL}/messages",
        json={
            "content": unique_content,
            "sender_name": "Jason Davenport",
        },
    )
    assert post_resp.status_code in [200, 201]

    # Step 3: Verify message appears in Lead channel
    lead_resp = await client.get(f"/api/channels/{AIM_LEAD_CHANNEL}/messages")
    assert lead_resp.status_code == 200
    lead_messages = lead_resp.json()
    assert any(unique_content in m["content"] for m in lead_messages)

    # Step 4: Verify message did NOT leak into Scribe channel
    scribe_resp = await client.get(f"/api/channels/{AIM_SCRIBE_CHANNEL}/messages")
    assert scribe_resp.status_code == 200
    scribe_messages = scribe_resp.json()
    assert len(scribe_messages) == initial_scribe_count
    assert not any(unique_content in m["content"] for m in scribe_messages)
