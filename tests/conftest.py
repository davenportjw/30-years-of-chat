"""Pytest configuration and fixtures for Agents of Chat E2E Integration Tests.

Targets the live web-deployed version of Agents of Chat on Google Cloud Run or a local instance:
- Configured via .env or BASE_URL / SERVICE_URL environment variables
- Fallback: http://localhost:8080
"""

import os
from pathlib import Path
import pytest
import pytest_asyncio
import httpx
import websockets


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


def get_base_url() -> str:
    url = (
        os.environ.get("BASE_URL")
        or os.environ.get("SERVICE_URL")
        or os.environ.get("DEPLOYED_URL")
        or os.environ.get("WEB_DEPLOYED_URL")
        or "http://localhost:8080"
    )
    return url.rstrip("/")


def get_ws_url(base_url: str) -> str:
    if base_url.startswith("https://"):
        return base_url.replace("https://", "wss://") + "/ws"
    elif base_url.startswith("http://"):
        return base_url.replace("http://", "ws://") + "/ws"
    return f"wss://{base_url}/ws"


@pytest.fixture(scope="session")
def base_url() -> str:
    return get_base_url()


@pytest.fixture(scope="session")
def ws_url(base_url: str) -> str:
    return get_ws_url(base_url)


@pytest_asyncio.fixture(scope="function")
async def client(base_url: str):
    """Function-scoped HTTP client ensuring clean event-loop isolation."""
    async with httpx.AsyncClient(
        base_url=base_url,
        timeout=httpx.Timeout(60.0, connect=10.0),
        headers={"User-Agent": "AgentsOfChat-E2E-Integration-Test/1.0"},
    ) as c:
        yield c


@pytest_asyncio.fixture(autouse=True)
async def ensure_clean_state_after_test(base_url: str):
    """Runs tests and ensures teardown clean state per resource lifecycle invariants."""
    yield
    # Post-test cleanup: ensure pristine seed state
    try:
        async with httpx.AsyncClient(base_url=base_url, timeout=10.0) as c:
            await c.post("/api/seed")
    except Exception:
        pass
