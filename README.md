# Agents of Chat: 30 Years of Chat & Agent Memory Evolution

An interactive, live multi-agent workspace illustrating the 30-year evolution of chat applications (1988–2026) and how each milestone maps directly to modern AI agent cognitive memory architectures.

- **Cognitive Models**: `gemini-3.8-flash` via Google Cloud Vertex AI (Application Default Credentials)
- **Runtime Target**: Google Cloud Run & Local Go HTTP Server
- **Design System**: Academic Sepia 3-Panel Studio & Authentic Historical Viewports
- **Standalone Memory Engine**: For a dedicated memory engine implementing offline REM dream synthesis and cognitive memory consolidation that you can download and try, explore [electric-sheep](https://github.com/jasondavenport/electric-sheep).

---

## Interactive Era-Transforming Interface

A persistent top navigation header (`TopEraBar`) features a **Top-Left Era Dropdown** and **Stepper Buttons (`< Prev Era`, `Next Era >`)**. Selecting an era dynamically morphs the entire interface into the authentic visual style and cognitive memory paradigm of that era:

1. **1988 — The Ephemeral Buffer (IRC & Unix talk)**:
   - **Visuals**: Fullscreen green-on-black phosphor CRT terminal (`#33FF33` on `#0A0D0A`) with scanlines and bottom `> _` command prompt. No sidebars, drawers, or distraction.
   - **Concept**: Short-Term Memory (STM) & FIFO Eviction Ring Buffer.
   - **Mechanisms**: Volatile RAM limits (5 turns); older turns are dropped when capacity is reached (the *Amnesia Trap* with live eviction banners).
2. **1997 — The 1:1 Direct Session & Presence (AIM & ICQ)**:
   - **Visuals**: Classic Windows 95/98 beveled window chrome, navy title bar, AIM Buddy List with active agent contacts, and sunken direct chat log.
   - **Concept**: Working Memory & Attentional State.
   - **Mechanisms**: 1:1 conversation isolation; agent buddy presence (`available`, `away`, `typing`) controls attentional liveness; away messages prime agent persona and system prompts.
3. **2006 — Scoped Rooms & Context Fencing (Campfire & Jabber)**:
   - **Visuals**: 37signals Web 2.0 clean cream aesthetic, room tabs (`#general-lobby`, `#engineering`, `#billing-confidential`), sound effect toggle, and yellow message fade.
   - **Concept**: Search Isolation & Role-Based Context Fencing.
   - **Mechanisms**: Domain-partitioned rooms with role quarantine prevent prompt contamination and associative bleed between projects via `CONTEXT QUARANTINE WARNING` cards.
4. **2013 — The Searchable Vector Archive (Slack 1.0 & HipChat)**:
   - **Visuals**: Classic aubergine sidebar (`#4A154B`), clean white transcript, and top universal search bar.
   - **Concept**: Long-Term Memory (LTM) & Vector Search RAG.
   - **Mechanisms**: Append-only persistent cloud history; agents perform exact cosine vector similarity retrieval on historical ADRs and incidents with real cosine distance metrics.
5. **2017 — Threads & Scribe Compaction (Slack Threads & Discord Forums)**:
   - **Visuals**: Modern dark Slack workspace with collapsible 430px right-hand Thread Scratchpad.
   - **Concept**: Sub-Task Scratchpads & Hierarchical State Compaction.
   - **Mechanisms**: Sub-task scratchpads isolate complex investigations; a Scribe agent compresses resolved discussions into a dense state rollup (-96% token footprint).
6. **2026 — Collaborative Multi-Agent Mesh (Agents of Chat Swarm)**:
   - **Visuals**: Academic Sepia 3-panel workspace: Left Multi-Agent Swarm Roster with real-time presence, Center stream with compact Intent Pills and Progressive Quick Action Chips, and Right 5-tab Memory Lens Drawer.
   - **Concept**: Dual-Layer Memory, REM Dream Synthesis & Crystalline Recall.
   - **Mechanisms**: Team blackboard for public collaboration alongside confidential private agent scratchpads (inner monologue, draft plans, raw tool traces); background Dreaming passes prune conversational chatter, trace intent trajectories, and crystallize durable architectural facts into a fast-path cache (<10ms) backed by BigQuery.

---

## System Architecture & Data Flow

```mermaid
flowchart TD
  subgraph Ingress["1. Ingress & Triggers"]
    UI["Web Client / Chat UI"] -->|HTTP POST /messages| API["Go HTTP API Gateway (:8080)"]
    Webhooks["Inbound Sensor / Alert Webhooks"] -->|HTTP POST /events| API
    CronTicker["Autonomous Pacer (1.5s - 12s)"] -->|Tick Trigger| API
  end

  subgraph WorkingMemory["2. In-Memory Working State (RAM)"]
    API -->|Route by Era & Channel| Store["MemoryStore (Thread-Safe Mutex)"]
    Store -->|Era 1988: 5-Turn Max| RingBuf["FIFO Ring Buffer\n(Oldest turn dropped -> Amnesia Event)"]
    Store -->|Era 1997: 1:1 DMs| DMContext["Isolated Session Context\n(Peer crosstalk blocked)"]
    Store -->|Era 2006: Room Scopes| RoomRBAC["Scoped Room Buffer\n(Role firewall check)"]
    Store -->|Era 2017: Sub-Tasks| ThreadBuf["Child Thread Scratchpad\n(Root context shielded)"]
    Store -->|Era 2026: Blackboard| TeamStream["Shared Team Blackboard"]
    Store -->|Era 2026: Agent Monologue| Scratchpad["Private Agent Scratchpad\n(Zero-Leakage confidential)"]
  end

  subgraph LLMInference["3. LLM Inference & Generation"]
    TeamStream & Scratchpad -->|Assembled Prompt (ADC Auth)| VertexAI["Google Cloud Vertex AI\n(gemini-3.8-flash)"]
    VertexAI -->|Generated Message + Intent Tags| TeamStream
    TeamStream -->|Broadcast Events| WSHub["WebSocket Event Fanout Hub"]
    WSHub -->|Live Streaming Telemetry| UI
  end

  subgraph TelemetryStorage["4. Real-Time Telemetry Persistence"]
    API & Store -->|Async REST Streaming| BQLogs[("BigQuery: agent_logs\nadk_agent_telemetry")]
  end

  subgraph OfflineDreaming["5. Offline Consolidation & Recall"]
    UI & API -->|POST /consolidate| DreamPass["REM Sleep Dreaming Engine\n(Gemini 3.8 Flash)"]
    TeamStream -->|Prune Noise & Extract Invariants| DreamPass
    DreamPass -->|Session Summaries| BQSummary[("BigQuery: session_summaries")]
    DreamPass -->|768-d Vector Embeddings| BQBeliefs[("BigQuery: crystallized_beliefs\n(Cosine Distance)")]
    BQBeliefs -->|Distilled Beliefs| Cache["In-Memory Crystalline Cache\n(Key-indexed, <10ms lookup)"]
    Cache -->|<10ms Fast-Path Zero-Token Recall| TeamStream
  end
```

---

## Configuration & Environment Variables

Deployment endpoints, cloud project identifiers, and runtime secrets are stored in a local `.env` file and strictly **excluded from git** via `.gitignore`.

1. Copy the template to create your local `.env`:
   ```bash
   cp .env.example .env
   ```

2. Configure your environment variables:
   ```env
   # Google Cloud Platform & Vertex AI
   GCP_PROJECT=your-gcp-project-id
   GCP_REGION=us-central1
   GCP_LOCATION=global
   GEMINI_MODEL=gemini-3.8-flash

   # Cloud Run Deployed Service URL (populate after deployment)
   SERVICE_URL=https://agents-of-chat-YOUR_PROJECT_NUMBER.us-central1.run.app

   # Base URL for E2E tests and CLI playback runner
   # Set to $SERVICE_URL for testing against Cloud Run, or http://localhost:8080 for local testing
   BASE_URL=http://localhost:8080

   # Local Server Settings
   PORT=8080
   STATIC_DIR=frontend/build/web
   ```

---

## Deployment Guide (Google Cloud Run)

Follow these steps to build and deploy `agents-of-chat` to Google Cloud Run.

### Prerequisites

- [Google Cloud SDK (`gcloud`)](https://cloud.google.com/sdk/docs/install) installed and configured
- Application Default Credentials (ADC) configured:
  ```bash
  gcloud auth login
  gcloud auth application-default login
  ```
- [Go 1.24+](https://go.dev/)
- [Flutter SDK](https://flutter.dev/) (for compiling the web frontend)
- [Python 3.11+ & uv](https://docs.astral.sh/uv/) (for running integration tests and the playback CLI runner)

### Step 1: Set Active GCP Project

```bash
export GCP_PROJECT="your-gcp-project-id"
export GCP_REGION="us-central1"

gcloud config set project ${GCP_PROJECT}
```

Ensure required Google Cloud APIs are enabled:
```bash
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  aiplatform.googleapis.com \
  bigquery.googleapis.com
```

### Step 2: Build the Flutter Web Frontend

Compile the Flutter Web client into static release assets:
```bash
cd frontend
flutter pub get
flutter build web --release
cd ..
```
The compiled SPA bundle will be placed in `frontend/build/web`.

### Step 3: Deploy to Cloud Run

Deploy directly from source using Google Cloud Build and Cloud Run:
```bash
gcloud run deploy agents-of-chat \
  --source . \
  --project ${GCP_PROJECT} \
  --region ${GCP_REGION} \
  --allow-unauthenticated \
  --set-env-vars GCP_PROJECT=${GCP_PROJECT},GCP_LOCATION=global,GEMINI_MODEL=gemini-3.8-flash
```

Upon successful deployment, `gcloud` outputs your Service URL:
```text
Service URL: https://agents-of-chat-<hash>-<region>.a.run.app
```

### Step 4: Update Your `.env` File

Add your live Cloud Run URL to `.env`:
```bash
# Update SERVICE_URL and BASE_URL in your local .env
echo "SERVICE_URL=https://agents-of-chat-<hash>-<region>.a.run.app" >> .env
echo "BASE_URL=https://agents-of-chat-<hash>-<region>.a.run.app" >> .env
```

### Step 5: Verify Live Deployment

Send a live HTTP probe to verify health and schema integrity:
```bash
# Verify service health
curl -s "${SERVICE_URL}/healthz"

# Query active memory eras
curl -s "${SERVICE_URL}/api/eras" | jq .
```

---

## Local Development

You can run both the Go backend API and Flutter Web client locally:

```bash
# 1. Build the Flutter Web frontend
cd frontend && flutter build web --release && cd ..

# 2. Run the Go server locally (defaults to port 8080)
go run main.go

# 3. Access in browser
open http://localhost:8080
```

---

## 2026 Interactive Guided Tour & Quick Action Prompts

The 2026 Collaborative Multi-Agent Mesh workspace includes an automated 5-step interactive tour and progressive quick action scenario pills to demonstrate the complete cognitive memory lifecycle:

### Progressive Quick Action Scenario Pills
- **Pill 1 (1. Onboarding Stack)**: `Swarm consensus: Standardize deployment on Google Cloud Run, Terraform, and Google BigQuery with Gemini 3.8.`
  - Ingests human commander direction into the shared public blackboard; triggers Lead Coordinator and swarm consensus response.
- **Pill 2 (2. Security Boundary)**: `Security constraint: Zero-trust credentials, auth tokens, and raw tool traces must remain strictly isolated inside private scratchpads.`
  - Enforces the **Zero-Leakage Invariant**: tool traces and inner thoughts remain confidential in `/api/scratchpads` and never leak into the team stream.
- **Pill 3 (3. Trigger Dreaming)**: `POST /api/channels/chan-product-launch/consolidate`
  - Executes an offline REM Sleep Dreaming synthesis cycle via Vertex AI Gemini 3.8, pruning transient turns and distilling high-confidence crystallized beliefs.
- **Pill 4 (4. Recall Probe)**: `What deployment stack and security policies did the multi-agent swarm establish?`
  - Probes the **⚡ Crystalline Cache (<10ms)** (`crystalline_hit`), retrieving distilled consensus instantly with zero token regeneration.

### Automated Playback CLI Runner

The CLI playback runner runs all 5 phases against local or deployed Cloud Run instances:

```bash
# Run against target resolved automatically from .env or environment
uv run python scripts/demo_2026_flow.py

# Run with automated presentation pacing delays
uv run python scripts/demo_2026_flow.py --auto

# Explicitly override the target URL
uv run python scripts/demo_2026_flow.py --url https://your-deployed-service.run.app --auto
```

---

## Verification & Testing

```bash
# 1. Run all backend unit and boundary isolation tests (Go)
go test -v ./...

# 2. Run End-to-End integration tests against the live Cloud Run deployment or local server (Python with uv)
# Automatically uses BASE_URL / SERVICE_URL from .env if present
uv run pytest -v

# Run E2E tests for a specific scene
uv run pytest tests/test_scene_1988_irc.py -v          # Scene 1: FIFO Eviction & Amnesia Trap
uv run pytest tests/test_scene_1997_aim.py -v          # Scene 2: 1:1 Session Isolation & Presence
uv run pytest tests/test_scene_2006_campfire.py -v     # Scene 3: Scoped Rooms & Context Fencing
uv run pytest tests/test_scene_2013_slack.py -v        # Scene 4: Vector Search RAG & Webhooks
uv run pytest tests/test_scene_2017_threads.py -v      # Scene 5: Sub-task Threads & Compaction
uv run pytest tests/test_scene_2026_agent_mesh.py -v   # Scene 6: Dual-Layer Memory, Dreaming & Crystalline Recall
uv run pytest tests/test_web_deployment.py -v          # Web Core: Assets, CORS, Schemas, WS

# Override target URL for a specific test run
BASE_URL="http://localhost:8080" uv run pytest -v
```

---

## Technical Stack

- **Backend**: Go 1.24 (`pkg/storage`, `pkg/agent`, `pkg/server`)
- **LLM Engine**: Google Cloud Vertex AI / Gemini 3.8 Flash (`gemini-3.8-flash`) via Application Default Credentials (ADC)
- **Frontend**: Flutter Web with Sepia Academic Design System and 6 historical Era Viewports
- **Persistence & Vector Search**: Google BigQuery (`adk_agent_telemetry`), in-memory thread-safe cache
- **Deployment**: Google Cloud Run (containerized, stateless autoscaling)

---

## License

This project is licensed under the Apache License, Version 2.0. See the [LICENSE](LICENSE) file for details.
