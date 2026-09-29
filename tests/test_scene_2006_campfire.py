"""E2E Integration Tests for Scene 3 (2006 — Scoped Rooms & Context Fencing: Campfire & Jabber).

Architectural Invariants Verified on Deployed Cloud Run Service:
- Project-Scoped Multi-User Rooms (chan-2006-campfire-lobby, chan-2006-campfire-eng, chan-2006-campfire)
- Domain-Partitioned Memory Silos: Search Isolation & Context Fencing
- Role Quarantine Invariant: researcher-agent quarantined from confidential billing room
- Associative Bleed Prevention: Engineering room discussions do not bleed into billing room
"""

import asyncio
import json
import pytest
import httpx

LOBBY_CHANNEL = "chan-2006-campfire-lobby"
ENG_CHANNEL = "chan-2006-campfire-eng"
BILLING_CHANNEL = "chan-2006-campfire"
ERA_ID = "era-2006-campfire"


@pytest.mark.asyncio
async def test_scene_2006_room_scoping_and_role_fencing(client: httpx.AsyncClient):
    """Verifies room domain partitions and RBAC role allowances."""
    resp = await client.get("/api/channels")
    assert resp.status_code == 200
    channels = resp.json()

    campfire_channels = [c for c in channels if c.get("era_id") == ERA_ID]
    assert len(campfire_channels) == 3

    # Lobby room is open without restricted roles
    lobby = next(c for c in campfire_channels if c["id"] == LOBBY_CHANNEL)
    assert len(lobby.get("allowed_roles") or []) == 0 or "jason" in (lobby.get("allowed_roles") or [])
    assert lobby["retention_hours"] == 48

    # Engineering room allows engineering roster
    eng = next(c for c in campfire_channels if c["id"] == ENG_CHANNEL)
    assert set(eng.get("allowed_roles", [])) == {"lead-agent", "scribe-agent", "researcher-agent", "jason"}

    # Confidential billing room enforces RBAC quarantine
    billing = next(c for c in campfire_channels if c["id"] == BILLING_CHANNEL)
    assert set(billing.get("allowed_roles", [])) == {"lead-agent", "scribe-agent", "jason"}

    # Context Quarantine Invariant: researcher-agent is strictly excluded from billing
    assert "researcher-agent" not in billing.get("allowed_roles", [])


@pytest.mark.asyncio
async def test_scene_2006_context_fencing_associative_bleed_prevention(client: httpx.AsyncClient):
    """Verifies that operational discussions in engineering do not bleed into confidential billing."""
    # Step 1: Record initial message count in billing room
    initial_billing_resp = await client.get(f"/api/channels/{BILLING_CHANNEL}/messages")
    assert initial_billing_resp.status_code == 200
    initial_billing_messages = initial_billing_resp.json()
    initial_billing_count = len(initial_billing_messages)

    # Step 2: Ingest an engineering discussion into the engineering room
    eng_content = "Engineering Room Topic: Refactoring Flutter Web canvas renderer and WASM compilation"
    post_resp = await client.post(
        f"/api/channels/{ENG_CHANNEL}/messages",
        json={
            "content": eng_content,
            "sender_name": "Campfire Eng Lead",
        },
    )
    assert post_resp.status_code in [200, 201]

    # Step 3: Verify the message exists in engineering room
    eng_resp = await client.get(f"/api/channels/{ENG_CHANNEL}/messages")
    assert eng_resp.status_code == 200
    eng_messages = eng_resp.json()
    assert any(eng_content in m["content"] for m in eng_messages)

    # Step 4: Verify absolute context fencing: billing room count is unchanged and message is absent
    billing_resp = await client.get(f"/api/channels/{BILLING_CHANNEL}/messages")
    assert billing_resp.status_code == 200
    billing_messages = billing_resp.json()
    assert len(billing_messages) == initial_billing_count
    assert not any(eng_content in m["content"] for m in billing_messages)


@pytest.mark.asyncio
async def test_scene_2006_billing_room_confidential_system_prompt(client: httpx.AsyncClient):
    """Verifies that billing room system prompt enforces ledger consistency and domain boundaries."""
    resp = await client.get("/api/channels")
    assert resp.status_code == 200
    channels = resp.json()

    billing = next(c for c in channels if c["id"] == BILLING_CHANNEL)
    prompt = billing.get("system_prompt", "")
    assert "Apollo billing engineering" in prompt
    assert "ledger consistency" in prompt or "Reject out-of-domain" in prompt
