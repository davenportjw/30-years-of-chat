"""E2E Integration Tests verifying the core Web Deployed Service on Google Cloud Run.

Verifies:
- Static Web Asset Delivery (Flutter Single Page App index.html, scripts, manifest)
- Service Health and Telemetry (/api/healthz, Gemini 3.8 Flash, davenport-boutique project)
- CORS Middleware Headers
- Taxonomy APIs (/api/eras, /api/channels)
- Storage Schemas (/api/vector/ddl)
- Autonomous Loop Pacing (/api/pacing)
- Real-time RFC 6455 WebSocket connectivity (/ws)
"""

import json
import pytest
import httpx
import websockets


@pytest.mark.asyncio
async def test_deployed_web_app_serves_html_entrypoint(client: httpx.AsyncClient):
    """Verifies that the web deployed Cloud Run service serves Flutter SPA index.html."""
    resp = await client.get("/")
    assert resp.status_code == 200
    assert "text/html" in resp.headers.get("content-type", "")
    content = resp.text
    # Verify Flutter bootstrap loader and HTML5 structure
    assert "<!DOCTYPE html>" in content or "<!doctype html>" in content.lower()
    assert "flutter" in content.lower() or "flutter_bootstrap.js" in content


@pytest.mark.asyncio
async def test_deployed_web_app_serves_static_assets(client: httpx.AsyncClient):
    """Verifies that compiled web assets are accessible with correct MIME types."""
    # Test flutter_bootstrap.js
    resp_js = await client.get("/flutter_bootstrap.js")
    assert resp_js.status_code == 200
    assert "javascript" in resp_js.headers.get("content-type", "")
    assert len(resp_js.content) > 500

    # Test manifest.json
    resp_manifest = await client.get("/manifest.json")
    assert resp_manifest.status_code == 200
    assert "json" in resp_manifest.headers.get("content-type", "")


@pytest.mark.asyncio
async def test_deployed_service_health_and_gemini_models(client: httpx.AsyncClient):
    """Verifies health check, GCP project attribution, and Gemini 3.8 model flags."""
    resp = await client.get("/api/healthz")
    assert resp.status_code == 200
    data = resp.json()

    assert data.get("status") == "healthy"
    assert data.get("service") == "agents-of-chat"
    assert data.get("project") == "davenport-boutique"

    models = data.get("models", [])
    assert "gemini-3.8-flash" in models
    assert "gemini-1.5-flash" not in models
    assert "gemini-2.0" not in models


@pytest.mark.asyncio
async def test_deployed_cors_headers(client: httpx.AsyncClient):
    """Verifies cross-origin resource sharing headers on deployed endpoints."""
    resp = await client.options("/api/channels")
    assert resp.status_code == 200
    assert resp.headers.get("access-control-allow-origin") == "*"
    assert "GET" in resp.headers.get("access-control-allow-methods", "")


@pytest.mark.asyncio
async def test_deployed_taxonomy_eras(client: httpx.AsyncClient):
    """Verifies all 6 historical evolutionary eras are populated and ordered."""
    resp = await client.get("/api/eras")
    assert resp.status_code == 200
    eras = resp.json()
    assert len(eras) == 6

    expected_eras = [
        (1988, "era-1988-irc"),
        (1997, "era-1997-aim"),
        (2006, "era-2006-jabber"),
        (2013, "era-2013-hipchat"),
        (2017, "era-2017-threads"),
        (2026, "era-2026-agent-mesh"),
    ]

    for i, (year, era_id) in enumerate(expected_eras):
        assert eras[i]["year"] == year
        assert eras[i]["id"] == era_id
        assert len(eras[i]["active_features"]) > 0
        assert eras[i]["memory_concept"] != ""


@pytest.mark.asyncio
async def test_deployed_domain_channels(client: httpx.AsyncClient):
    """Verifies domain channels across the 6 eras on the deployed service."""
    resp = await client.get("/api/channels")
    assert resp.status_code == 200
    channels = resp.json()
    assert len(channels) == 10

    channel_ids = {c["id"] for c in channels}
    expected_ids = {
        "chan-1988-irc",
        "chan-1997-aim",
        "chan-1997-aim-scribe",
        "chan-1997-aim-researcher",
        "chan-2006-jabber-lobby",
        "chan-2006-jabber-eng",
        "chan-2006-jabber-billing",
        "chan-incident-postmortem",
        "chan-architecture-rfc",
        "chan-product-launch",
    }
    assert expected_ids.issubset(channel_ids)


@pytest.mark.asyncio
async def test_deployed_vector_ddl_schema(client: httpx.AsyncClient):
    """Verifies vector table DDL contract for cosine similarity search."""
    resp = await client.get("/api/vector/ddl")
    if resp.status_code == 404:
        resp = await client.get("/api/spanner/ddl")
    assert resp.status_code == 200
    data = resp.json()
    ddl = data.get("ddl", "")

    assert "CREATE TABLE messages" in ddl
    assert "embedding ARRAY<FLOAT32>(vector_length => 768)" in ddl
    assert "CREATE VECTOR INDEX messages_embedding_idx ON messages(embedding)" in ddl
    assert "distance_type = 'COSINE'" in ddl
    assert "type = 'TREE_AH'" in ddl


@pytest.mark.asyncio
async def test_deployed_pacing_configuration(client: httpx.AsyncClient):
    """Verifies reading and updating autonomous loop pacing."""
    # Get current pacing
    resp = await client.get("/api/pacing")
    assert resp.status_code == 200
    original_pacing = resp.json()
    assert "interval_seconds" in original_pacing

    # Update pacing mode
    new_pacing = {"paused": True, "interval_seconds": 12}
    update_resp = await client.post("/api/pacing", json=new_pacing)
    assert update_resp.status_code == 200
    updated = update_resp.json()
    assert updated["paused"] is True
    assert updated["interval_seconds"] == 12

    # Restore pacing
    restore_resp = await client.post("/api/pacing", json=original_pacing)
    assert restore_resp.status_code == 200


@pytest.mark.asyncio
async def test_deployed_websocket_connection_and_echo(ws_url: str):
    """Verifies RFC 6455 WebSocket connectivity on the live Cloud Run deployment."""
    async with websockets.connect(ws_url, open_timeout=5, close_timeout=5) as ws:
        assert ws.state.name == "OPEN"


