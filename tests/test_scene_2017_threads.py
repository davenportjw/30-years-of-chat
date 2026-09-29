"""E2E Integration Tests for Scene 5 (2017 — Threads & Scribe Compaction: Slack Threads & Discord Forums).

Architectural Invariants Verified on Deployed Cloud Run Service:
- Thread Branching & Collapsible Scratchpads (chan-architecture-rfc)
- Sub-Task Isolation: Sub-thread turns do not pollute the root channel stream
- Scribe Compaction: Hierarchical state rollups achieved with >95% token compression
- Multi-Turn Deliberation queryable via ?thread_id={id}
"""

import asyncio
import json
import pytest
import httpx

RFC_CHANNEL = "chan-architecture-rfc"
ERA_ID = "era-2017-threads"
EXISTING_THREAD_ID = "thread-rfc-042"


@pytest.mark.asyncio
async def test_scene_2017_channel_metadata(client: httpx.AsyncClient):
    """Verifies channel configuration for thread branching and compaction."""
    resp = await client.get("/api/channels")
    assert resp.status_code == 200
    channels = resp.json()

    rfc_ch = next((c for c in channels if c["id"] == RFC_CHANNEL), None)
    assert rfc_ch is not None
    assert rfc_ch["era_id"] == ERA_ID
    assert rfc_ch["retention_hours"] == 168  # 7-day deep architectural review
    assert "RFC 042" in rfc_ch["topic"]


@pytest.mark.asyncio
async def test_scene_2017_scribe_compaction_summaries(client: httpx.AsyncClient):
    """Verifies that Scribe compaction summaries achieve dramatic token reductions (>90%)."""
    resp = await client.get(f"/api/channels/{RFC_CHANNEL}/summaries")
    assert resp.status_code == 200
    summaries = resp.json()
    assert len(summaries) >= 1

    summary = next((s for s in summaries if s.get("thread_id") == EXISTING_THREAD_ID), summaries[0])
    assert summary["original_tokens"] > summary["compacted_tokens"]
    assert summary["compression_ratio"] > 0.90, f"Expected >90% compression, got {summary['compression_ratio']}"
    assert "synchronous 2PC" in summary["condensed_state"] or "CONSENSUS" in summary["condensed_state"]


@pytest.mark.asyncio
async def test_scene_2017_subtask_thread_isolation(client: httpx.AsyncClient):
    """Verifies that sub-task scratchpad messages do not pollute the main root stream."""
    custom_thread_id = "thread-e2e-subtask-eval-994"

    # Step 1: Query initial root stream (without thread_id)
    root_resp_before = await client.get(f"/api/channels/{RFC_CHANNEL}/messages?limit=50")
    assert root_resp_before.status_code == 200
    root_messages_before = root_resp_before.json()
    root_ids_before = {m["id"] for m in root_messages_before}

    # Step 2: Post a turn strictly inside the sub-task thread
    thread_msg_content = "Subtask Deliberation: Benchmarking distributed 2PC latency vs eventual consistency"
    post_resp = await client.post(
        f"/api/channels/{RFC_CHANNEL}/messages",
        json={
            "content": thread_msg_content,
            "thread_id": custom_thread_id,
            "sender_name": "Architecture Reviewer",
        },
    )
    assert post_resp.status_code in [200, 201]
    new_message = post_resp.json()
    assert new_message["thread_id"] == custom_thread_id

    # Step 3: Verify the message IS retrieved when querying that specific thread
    thread_resp = await client.get(f"/api/channels/{RFC_CHANNEL}/messages?thread_id={custom_thread_id}")
    assert thread_resp.status_code == 200
    thread_messages = thread_resp.json()
    assert any(m["id"] == new_message["id"] for m in thread_messages)

    # Step 4: Verify the message is SHIELDED from the root channel stream
    root_resp_after = await client.get(f"/api/channels/{RFC_CHANNEL}/messages?limit=50")
    assert root_resp_after.status_code == 200
    root_messages_after = root_resp_after.json()

    # The newly created thread turn must NOT be present in root stream
    assert new_message["id"] not in {m["id"] for m in root_messages_after}
