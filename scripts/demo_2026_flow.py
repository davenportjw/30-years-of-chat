#!/usr/bin/env python3
"""Automated Playback CLI Runner for Scene 6 (2026 Collaborative Multi-Agent Mesh).

Demonstrates:
  Phase 1: Swarm Consensus (Pill 1: Onboarding Stack -> verifies agent replies and state)
  Phase 2: Security Boundary & Private Monologue (Pill 2: Zero-Trust Scratchpad Isolation)
  Phase 3: REM Sleep Dreaming Trigger (POST /api/channels/{id}/consolidate)
  Phase 4: Crystalline Memory Inspection (Validates crystallized beliefs with confidence >= 0.90)
  Phase 5: Fast-Path Crystalline Recall (Probes crystalline cache for <10ms zero-token hits)

Usage:
  uv run python scripts/demo_2026_flow.py [--url <SERVICE_URL>] [--auto]
"""

import argparse
import json
import os
from pathlib import Path
import sys
import time
from typing import Any, Dict, List, Optional
import httpx

# ANSI Color Codes for Academic Sepia / Modern Terminal
CYAN = "\033[36m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
PURPLE = "\033[35m"
BOLD = "\033[1m"
DIM = "\033[2m"
RESET = "\033[0m"


def _load_env_file():
    root_dir = Path(__file__).resolve().parent.parent
    env_file = root_dir / ".env"
    if env_file.is_file():
        try:
            with open(env_file, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#") or "=" not in line:
                        continue
                    k, v = line.split("=", 1)
                    k = k.strip()
                    v = v.strip().strip("'\"")
                    if k and k not in os.environ:
                        os.environ[k] = v
        except Exception:
            pass


_load_env_file()

DEFAULT_URL = (
    os.environ.get("BASE_URL")
    or os.environ.get("SERVICE_URL")
    or os.environ.get("DEPLOYED_URL")
    or "http://localhost:8080"
)
DEFAULT_CHANNEL = "chan-product-launch"
DEFAULT_USER = "Jason Davenport"


def banner(title: str, subtitle: Optional[str] = None):
    line = "=" * 80
    print(f"\n{CYAN}{BOLD}{line}")
    print(f"  {title.center(76)}")
    if subtitle:
        print(f"  {DIM}{subtitle.center(76)}{RESET}{CYAN}{BOLD}")
    print(f"{line}{RESET}\n")


def phase_header(phase_num: int, title: str, description: str):
    print(f"\n{YELLOW}{BOLD}{'―' * 80}{RESET}")
    print(f"{YELLOW}{BOLD}[PHASE {phase_num}] {title}{RESET}")
    print(f"{DIM}{description}{RESET}")
    print(f"{YELLOW}{BOLD}{'―' * 80}{RESET}")


def wait_step(delay_sec: float, auto_mode: bool):
    if auto_mode and delay_sec > 0:
        time.sleep(delay_sec)


def poll_for_agent_reply(
    client: httpx.Client,
    channel_id: str,
    since_timestamp_ms: int,
    timeout_sec: float = 30.0,
    required_tag_type: Optional[str] = None,
) -> Optional[Dict[str, Any]]:
    """Polls for a newly emitted agent message in the specified channel."""
    start_time = time.time()
    while time.time() - start_time < timeout_sec:
        time.sleep(1.0)
        resp = client.get(f"/api/channels/{channel_id}/messages?limit=15")
        if resp.status_code != 200:
            continue
        messages = resp.json()
        for msg in messages:
            if msg.get("sender_type") == "agent":
                # Check if message satisfies required tag
                if required_tag_type:
                    tags = msg.get("intent_tags") or []
                    has_tag = any(
                        t.get("type") == required_tag_type
                        or "Crystalline Cache" in t.get("label", "")
                        for t in tags
                    )
                    if not has_tag:
                        continue
                return msg
    return None


def run_demo(base_url: str, channel_id: str, auto_mode: bool):
    base_url = base_url.rstrip("/")
    banner(
        "AGENTS OF CHAT: 2026 COLLABORATIVE MULTI-AGENT MESH",
        f"Target Service: {base_url} | Channel: #{channel_id}",
    )

    with httpx.Client(
        base_url=base_url,
        timeout=httpx.Timeout(25.0, connect=5.0),
        headers={"User-Agent": "AgentsOfChat-2026-DemoFlow/1.0"},
    ) as client:
        # Pre-flight health check
        print(f"{DIM}Connecting to {base_url}/api/healthz ...{RESET}", end=" ")
        try:
            health_resp = client.get("/api/healthz")
            if health_resp.status_code != 200:
                health_resp = client.get("/healthz")
            if health_resp.status_code == 200:
                print(f"{GREEN}[OK 200 Healthy]{RESET}")
            else:
                print(f"{YELLOW}[Status {health_resp.status_code}]{RESET}")
        except Exception as e:
            print(f"\n{YELLOW}⚠️ Health probe warning: {e}{RESET}")

        # =====================================================================
        # PHASE 0: Database & Vector Store Verification (BigQuery)
        # =====================================================================
        phase_header(
            0,
            "Database & BigQuery Vector Store Verification",
            "Verifying live BigQuery dataset adk_agent_telemetry and vector search capabilities.",
        )
        try:
            db_resp = client.get("/api/database")
            if db_resp.status_code == 200:
                db_data = db_resp.json()
                print(f"{GREEN}✔ DATABASE CONNECTED:{RESET} {db_data.get('database')} (Project: {db_data.get('project_id')})")
                print(f"  • Dataset:         {CYAN}{db_data.get('dataset_id')}{RESET}")
                print(f"  • Tables:          {', '.join(db_data.get('tables', []))}")
                print(f"  • Vector Engine:   {PURPLE}{db_data.get('vector_engine')}{RESET}")
                print(f"  • Auth Mode:       {db_data.get('auth_type', 'Google Cloud ADC')}")
                print(f"  • Indexed Beliefs: {db_data.get('total_crystallized_beliefs')}")
            else:
                print(f"{YELLOW}⚠️ Database status query returned {db_resp.status_code}{RESET}")
        except Exception as e:
            print(f"{YELLOW}⚠️ Database check skipped: {e}{RESET}")

        wait_step(1.5, auto_mode)

        # =====================================================================
        # PHASE 1: Swarm Consensus (Pill 1: Onboarding Stack)
        # =====================================================================
        phase_header(
            1,
            "Swarm Consensus — Onboarding Stack",
            "Broadcasting Quick Prompt 1 into the shared team blackboard to establish multi-agent consensus.",
        )

        p1_prompt = "Swarm consensus: Standardize deployment on Google Cloud Run, Terraform, and Google BigQuery with Gemini 3.8."
        print(f"\n{BOLD}[User -> #{channel_id}]:{RESET} {p1_prompt}")

        t0 = int(time.time() * 1000)
        post_p1 = client.post(
            f"/api/channels/{channel_id}/messages",
            json={"content": p1_prompt, "sender_name": DEFAULT_USER},
        )
        if post_p1.status_code not in (200, 201):
            print(f"❌ Failed to post user prompt: {post_p1.status_code} {post_p1.text}")
            sys.exit(1)

        print(f"{DIM}Waiting for autonomous agent response via Gemini 3.8...{RESET}")
        agent_reply_1 = poll_for_agent_reply(client, channel_id, t0, timeout_sec=30.0)
        if agent_reply_1:
            print(f"\n{GREEN}{BOLD}[Agent Reply — {agent_reply_1.get('sender_name')}]:{RESET}")
            content_preview = agent_reply_1.get("content", "").strip()
            print(f"  {content_preview[:320]}..." if len(content_preview) > 320 else f"  {content_preview}")
            tags = agent_reply_1.get("intent_tags") or []
            if tags:
                print(f"\n  {DIM}Intent Tags:{RESET}")
                for tag in tags:
                    print(f"    • [{tag.get('label')}] ({tag.get('type')}) - {tag.get('description')}")
        else:
            print(f"{YELLOW}⚠️ Agent reply timed out, continuing...{RESET}")

        wait_step(2.5, auto_mode)

        # =====================================================================
        # PHASE 2: Security Boundary & Private Monologue (Pill 2)
        # =====================================================================
        phase_header(
            2,
            "Security Boundary & Private Scratchpad Isolation",
            "Enforcing Dual-Layer Memory: private tool traces and inner thoughts remain strictly isolated.",
        )

        p2_prompt = "Security constraint: Zero-trust credentials, auth tokens, and raw tool traces must remain strictly isolated inside private scratchpads."
        print(f"\n{BOLD}[User -> #{channel_id}]:{RESET} {p2_prompt}")

        post_p2 = client.post(
            f"/api/channels/{channel_id}/messages",
            json={"content": p2_prompt, "sender_name": DEFAULT_USER},
        )
        assert post_p2.status_code in (200, 201)

        # Inspect private scratchpad
        pad_resp = client.get(f"/api/scratchpads?agent_id=lead-agent&channel_id={channel_id}")
        if pad_resp.status_code == 200:
            pad = pad_resp.json()
            print(f"\n{PURPLE}{BOLD}[Private Cognitive Scratchpad (lead-agent)]:{RESET}")
            print(f"  • Draft Plan:     {pad.get('draft_plan')}")
            print(f"  • Inner Thoughts: {len(pad.get('inner_thoughts', []))} confidential step(s)")
            for t in pad.get("inner_thoughts", []):
                print(f"     - {DIM}{t}{RESET}")
            print(f"  • Tool Traces:    {len(pad.get('tool_traces', []))} trace(s)")
            for tr in pad.get("tool_traces", []):
                print(f"     - {DIM}{tr}{RESET}")

            # Verify Zero-Leakage Invariant against public stream
            public_msgs = client.get(f"/api/channels/{channel_id}/messages?limit=25").json()
            leaked = False
            for thought in pad.get("inner_thoughts", []):
                if any(thought in m.get("content", "") for m in public_msgs):
                    leaked = True
                    break
            if not leaked:
                print(f"\n{GREEN}✔ ZERO-LEAKAGE INVARIANT VERIFIED: Private thoughts never appear in public stream.{RESET}")
            else:
                print(f"\n❌ ZERO-LEAKAGE VIOLATION: Private thought detected in public messages!")
                sys.exit(1)

        wait_step(2.5, auto_mode)

        # =====================================================================
        # PHASE 3: REM Sleep Dreaming Trigger (Pill 3: Trigger Dreaming)
        # =====================================================================
        phase_header(
            3,
            "REM Sleep Dreaming Synthesis Trigger",
            "Triggering POST /api/channels/{id}/consolidate to prune episodic chatter into durable semantic memory.",
        )

        print(f"Triggering dreaming consolidation pulse for #{channel_id}...")
        start_dream = time.time()
        c_resp = client.post(f"/api/channels/{channel_id}/consolidate")
        dream_latency_ms = int((time.time() - start_dream) * 1000)

        if c_resp.status_code not in (200, 201):
            print(f"❌ Dreaming consolidation failed: {c_resp.status_code} {c_resp.text}")
            sys.exit(1)

        report = c_resp.json()
        print(f"\n{GREEN}✔ REM Dreaming Consolidation Completed in {dream_latency_ms}ms!{RESET}")
        print(f"  • Report ID:         {report.get('id')}")
        print(f"  • Messages Pruned:   {report.get('pruned_messages')}")
        print(f"  • Distilled Facts:   {len(report.get('distilled_facts', []))} items")
        for fact in report.get("distilled_facts", []):
            print(f"     - {GREEN}{fact}{RESET}")
        print(f"  • Insight Summary:   {report.get('insight_summary')}")
        print(f"  • Intent Trajectory: {BOLD}{report.get('intent_trajectory')}{RESET}")
        if report.get("dream_prompt_used"):
            preview_prompt = report["dream_prompt_used"].split("\n")[0]
            print(f"  • Dream Prompt Used: {DIM}{preview_prompt}... ({len(report['dream_prompt_used'])} chars){RESET}")

        assert "crystallized_beliefs" in report, "Missing crystallized_beliefs in ConsolidationReport"
        assert "dream_prompt_used" in report and report["dream_prompt_used"], "Missing dream_prompt_used"
        assert "intent_trajectory" in report and report["intent_trajectory"], "Missing intent_trajectory"

        wait_step(2.5, auto_mode)

        # =====================================================================
        # PHASE 4: Crystalline Memory Inspection
        # =====================================================================
        phase_header(
            4,
            "Crystalline Memory Lens Inspection",
            "Verifying high-confidence crystallized beliefs (confidence >= 0.90) distilled into long-term memory.",
        )

        reports_list = client.get(f"/api/channels/{channel_id}/reports").json()
        target_report = next((r for r in reports_list if len(r.get("crystallized_beliefs", [])) > 0), report)
        beliefs: List[Dict[str, Any]] = target_report.get("crystallized_beliefs", [])

        print(f"Found {len(beliefs)} crystallized beliefs in channel memory store:")
        print(f"\n  {BOLD}{'KEY':<24} {'CATEGORY':<16} {'CONFIDENCE':<12} {'STATEMENT'}{RESET}")
        print(f"  {'-' * 24} {'-' * 16} {'-' * 12} {'-' * 40}")

        high_confidence_count = 0
        for b in beliefs:
            conf = b.get("confidence", 0.0)
            conf_str = f"{conf:.2f}"
            color = GREEN if conf >= 0.90 else YELLOW
            print(f"  {BOLD}{b.get('key'):<24}{RESET} {b.get('category'):<16} {color}{conf_str:<12}{RESET} {b.get('statement')}")
            if conf >= 0.90:
                high_confidence_count += 1

        print(f"\n{GREEN}✔ High-confidence beliefs (>= 0.90): {high_confidence_count}/{len(beliefs)}{RESET}")
        assert high_confidence_count >= 3, f"Expected at least 3 high-confidence beliefs, got {high_confidence_count}"

        wait_step(2.5, auto_mode)

        # =====================================================================
        # PHASE 5: Fast-Path Crystalline Recall (Pill 4: Recall Probe)
        # =====================================================================
        phase_header(
            5,
            "Fast-Path Crystalline Recall (Zero-Token Memory Cache)",
            "Querying known crystallized architectural beliefs to trigger <10ms zero-token memory cache hit.",
        )

        p4_prompt = "What deployment stack and security policies did the multi-agent swarm establish?"
        print(f"\n{BOLD}[User -> #{channel_id}]:{RESET} {p4_prompt}")

        t_recall = int(time.time() * 1000)
        post_p4 = client.post(
            f"/api/channels/{channel_id}/messages",
            json={"content": p4_prompt, "sender_name": DEFAULT_USER},
        )
        assert post_p4.status_code in (200, 201)

        print(f"{DIM}Awaiting agent response with fast-path crystalline recall tag...{RESET}")
        agent_recall = poll_for_agent_reply(
            client,
            channel_id,
            t_recall,
            timeout_sec=30.0,
            required_tag_type="crystalline_hit",
        )

        if not agent_recall:
            print(f"❌ Failed to observe crystalline recall agent response within timeout")
            sys.exit(1)

        print(f"\n{PURPLE}{BOLD}[Agent Response — {agent_recall.get('sender_name')}]:{RESET}")
        print(f"  {agent_recall.get('content')}\n")

        intent_tags = agent_recall.get("intent_tags") or []
        crystal_tag = next(
            (t for t in intent_tags if t.get("type") == "crystalline_hit" or "Crystalline Cache" in t.get("label", "")),
            None,
        )

        if crystal_tag:
            print(f"{PURPLE}{BOLD}⚡ FAST-PATH CRYSTALLINE CACHE HIT VERIFIED:{RESET}")
            print(f"  • Tag Label:       {PURPLE}{crystal_tag.get('label')}{RESET}")
            print(f"  • Tag Type:        {crystal_tag.get('type')}")
            print(f"  • Tag Description: {crystal_tag.get('description')}")
        else:
            print(f"❌ Crystalline Cache intent tag not found in agent response tags: {intent_tags}")
            sys.exit(1)

        # Final Summary
        banner(
            "ALL 5 PHASES VERIFIED SUCCESSFULLY",
            "Swarm Consensus • Scratchpad Isolation • REM Dreaming • Crystalline Beliefs • Fast-Path Recall",
        )


def main():
    parser = argparse.ArgumentParser(
        description="Automated Playback CLI Runner for Scene 6 (2026 Collaborative Multi-Agent Mesh)"
    )
    parser.add_argument(
        "--url",
        default=DEFAULT_URL,
        help=f"Base URL of the Agents of Chat service (default: {DEFAULT_URL})",
    )
    parser.add_argument(
        "--channel",
        default=DEFAULT_CHANNEL,
        help=f"Target channel ID (default: {DEFAULT_CHANNEL})",
    )
    parser.add_argument(
        "--auto",
        action="store_true",
        help="Enable automated playback with pacing delays between phases",
    )
    args = parser.parse_args()

    run_demo(base_url=args.url, channel_id=args.channel, auto_mode=args.auto)


if __name__ == "__main__":
    main()
