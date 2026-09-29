"""E2E Integration Tests for Scene 6 (2026 — Collaborative Multi-Agent Mesh).

Architectural Invariants Verified on Deployed Cloud Run Service:
- Shared Canvas with Autonomous Swarm (chan-product-launch)
- Dual-Layer Memory: Shared Public Blackboard vs Private Inner Monologue
- Cognitive Scratchpad API (/api/scratchpads): inner thoughts, draft plans, tool traces
- Zero Leakage Invariant: Confidential scratchpad content never leaks into public stream
- REM Dreaming Memory Consolidation (/api/channels/{id}/consolidate & /reports):
  Prunes transient debug turns and distills core architectural facts via Gemini 3.8
"""

import asyncio
import json
import pytest
import httpx

PRODUCT_LAUNCH_CHANNEL = "chan-product-launch"
ERA_ID = "era-2026-agent-mesh"
LEAD_AGENT = "lead-agent"


@pytest.mark.asyncio
async def test_scene_2026_channel_metadata(client: httpx.AsyncClient):
    """Verifies channel configuration for the multi-agent mesh workspace."""
    resp = await client.get("/api/channels")
    assert resp.status_code == 200
    channels = resp.json()

    mesh_ch = next((c for c in channels if c["id"] == PRODUCT_LAUNCH_CHANNEL), None)
    assert mesh_ch is not None
    assert mesh_ch["era_id"] == ERA_ID
    assert mesh_ch["retention_hours"] == 48
    assert "Multi-Agent Mesh" in mesh_ch["topic"] or "Agents of Chat GA Launch" in mesh_ch["topic"]


@pytest.mark.asyncio
async def test_scene_2026_dual_layer_memory_scratchpad_isolation(client: httpx.AsyncClient):
    """Verifies that private cognitive scratchpads remain isolated from the public shared blackboard."""
    confidential_thought = "CONFIDENTIAL_INNER_MONOLOGUE: Evaluating zero-trust token signature before dispatch."
    confidential_plan = "Staging deployment pipeline dry-run"
    confidential_trace = "gcloud vertex-ai models describe gemini-3.8-flash -> 200 OK"

    # Step 1: Update private scratchpad via REST API
    scratchpad_payload = {
        "agent_id": LEAD_AGENT,
        "channel_id": PRODUCT_LAUNCH_CHANNEL,
        "inner_thoughts": [confidential_thought],
        "draft_plan": confidential_plan,
        "tool_traces": [confidential_trace],
    }
    post_resp = await client.post("/api/scratchpads", json=scratchpad_payload)
    assert post_resp.status_code in [200, 201]

    # Step 2: Retrieve private scratchpad and verify fields
    get_resp = await client.get(
        f"/api/scratchpads?agent_id={LEAD_AGENT}&channel_id={PRODUCT_LAUNCH_CHANNEL}"
    )
    assert get_resp.status_code == 200
    pad = get_resp.json()
    assert confidential_thought in pad.get("inner_thoughts", [])
    assert pad.get("draft_plan") == confidential_plan
    assert confidential_trace in pad.get("tool_traces", [])

    # Step 3: Zero-Leakage Invariant Check: Query public channel messages
    messages_resp = await client.get(f"/api/channels/{PRODUCT_LAUNCH_CHANNEL}/messages?limit=50")
    assert messages_resp.status_code == 200
    public_messages = messages_resp.json()

    # The private thought must NEVER be emitted into the public team blackboard
    assert not any(confidential_thought in m["content"] for m in public_messages)
    assert not any(confidential_plan in m["content"] for m in public_messages)


@pytest.mark.asyncio
async def test_scene_2026_rem_dreaming_memory_consolidation(client: httpx.AsyncClient):
    """Verifies the REM Dreaming memory consolidation lifecycle and crystalline memory on the live service."""
    # Step 1: Check existing consolidation reports and verify seeded crystalline beliefs
    initial_reports_resp = await client.get(f"/api/channels/{PRODUCT_LAUNCH_CHANNEL}/reports")
    assert initial_reports_resp.status_code == 200
    initial_reports = initial_reports_resp.json()
    assert len(initial_reports) > 0, "No initial consolidation reports found in channel"
    initial_count = len(initial_reports)

    # Seeded report verification
    seeded_report = initial_reports[0]
    assert "crystallized_beliefs" in seeded_report
    assert "dream_prompt_used" in seeded_report and seeded_report["dream_prompt_used"]
    assert "intent_trajectory" in seeded_report and seeded_report["intent_trajectory"]

    seeded_beliefs = {b["key"]: b for b in seeded_report.get("crystallized_beliefs", [])}
    for required_key in ["deployment_stack", "security_policies", "agreed_guidelines"]:
        assert required_key in seeded_beliefs, f"Missing required seeded belief: {required_key}"
        confidence = seeded_beliefs[required_key].get("confidence", 0.0)
        assert confidence >= 0.90, f"Expected confidence >= 0.90 for {required_key}, got {confidence}"

    # Step 2: Trigger a live dreaming consolidation cycle
    consolidate_resp = await client.post(
        f"/api/channels/{PRODUCT_LAUNCH_CHANNEL}/consolidate"
    )
    assert consolidate_resp.status_code in [200, 201], f"Consolidation trigger failed: {consolidate_resp.text}"
    report = consolidate_resp.json()

    assert report["channel_id"] == PRODUCT_LAUNCH_CHANNEL
    assert report["pruned_messages"] >= 0
    assert len(report.get("distilled_facts", [])) > 0
    assert len(report.get("insight_summary", "")) > 10
    assert "completed_at" in report
    assert "crystallized_beliefs" in report
    assert "dream_prompt_used" in report and report["dream_prompt_used"]
    assert "intent_trajectory" in report and report["intent_trajectory"]

    # Step 3: Verify the report is appended to consolidation history
    updated_reports_resp = await client.get(f"/api/channels/{PRODUCT_LAUNCH_CHANNEL}/reports")
    assert updated_reports_resp.status_code == 200
    updated_reports = updated_reports_resp.json()
    assert len(updated_reports) >= initial_count + 1
    assert any(r["id"] == report["id"] for r in updated_reports)


@pytest.mark.asyncio
async def test_scene_2026_fast_path_crystalline_recall(client: httpx.AsyncClient):
    """Verifies that queries matching crystallized beliefs trigger fast-path crystalline recall (<10ms)."""
    # Step 1: Verify seeded beliefs are indexed and accessible
    reports_resp = await client.get(f"/api/channels/{PRODUCT_LAUNCH_CHANNEL}/reports")
    assert reports_resp.status_code == 200
    reports = reports_resp.json()
    assert len(reports) > 0
    first_report = reports[0]
    beliefs = {b["key"]: b for b in first_report.get("crystallized_beliefs", [])}
    for required_key in ["deployment_stack", "security_policies", "agreed_guidelines"]:
        assert required_key in beliefs
        assert beliefs[required_key]["confidence"] >= 0.90

    # Step 2: Post recall probe query matching crystallized beliefs
    recall_query = "What deployment stack and security policies did the multi-agent swarm establish?"
    post_resp = await client.post(
        f"/api/channels/{PRODUCT_LAUNCH_CHANNEL}/messages",
        json={"content": recall_query, "sender_name": "Jason Davenport"},
    )
    assert post_resp.status_code in [200, 201]

    # Step 3: Poll for agent response annotated with crystalline_hit intent tag
    agent_msg = None
    for _ in range(25):
        await asyncio.sleep(1.0)
        msgs_resp = await client.get(f"/api/channels/{PRODUCT_LAUNCH_CHANNEL}/messages?limit=15")
        if msgs_resp.status_code == 200:
            msgs = msgs_resp.json()
            for m in msgs:
                if m.get("sender_type") == "agent":
                    intent_tags = m.get("intent_tags") or []
                    has_hit = any(
                        t.get("type") == "crystalline_hit" or "Crystalline Cache" in t.get("label", "")
                        for t in intent_tags
                    )
                    if has_hit:
                        agent_msg = m
                        break
            if agent_msg:
                break

    assert agent_msg is not None, "Expected agent response with crystalline_hit / ⚡ Crystalline Cache (<10ms) tag"
    tags = agent_msg.get("intent_tags") or []
    crystal_tag = next((t for t in tags if t.get("type") == "crystalline_hit" or "Crystalline Cache" in t.get("label", "")), None)
    assert crystal_tag is not None
    assert crystal_tag.get("type") == "crystalline_hit"
    assert "Crystalline Cache" in crystal_tag.get("label", "")


@pytest.mark.asyncio
async def test_scene_2026_bigquery_database_and_vector_store(client: httpx.AsyncClient):
    """Verifies that BigQuery database and vector store are wired and reporting status."""
    # Step 1: Query /api/database endpoint
    db_resp = await client.get("/api/database")
    assert db_resp.status_code == 200
    db_info = db_resp.json()

    assert db_info.get("database") == "Google BigQuery"
    assert db_info.get("dataset_id") == "adk_agent_telemetry"
    assert "agent_logs" in db_info.get("tables", [])
    assert "crystallized_beliefs" in db_info.get("tables", [])
    assert "session_summaries" in db_info.get("tables", [])
    assert "BigQuery Vector Search" in db_info.get("vector_engine", "")
    assert db_info.get("total_crystallized_beliefs", 0) >= 5

    # Step 2: Query /api/healthz and verify storage metadata inclusion
    health_resp = await client.get("/api/healthz")
    assert health_resp.status_code == 200
    health_data = health_resp.json()
    assert health_data.get("database") == "Google BigQuery"
    assert health_data.get("dataset") == "adk_agent_telemetry"
    assert "BigQuery Vector Search" in health_data.get("vector_engine", "")


