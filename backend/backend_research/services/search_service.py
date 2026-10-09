"""
Literature search via Semantic Scholar's free Graph API.
Loads .env itself so it works regardless of import order.
"""

import os
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Optional

import httpx


# ============================================================
# Load .env before reading S2_API_KEY
# ============================================================
def _load_env():
    env_path = Path(__file__).resolve().parent.parent / ".env"
    if not env_path.exists():
        print(f"[S2] .env not found at {env_path}")
        return
    with open(env_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ[k.strip()] = v.strip()


_load_env()


S2_BASE = "https://api.semanticscholar.org/graph/v1/paper/search"
S2_FIELDS = "title,authors,year,abstract,url,citationCount,venue,externalIds"


# ============================================================
# Read key
# ============================================================
_api_key = os.getenv("S2_API_KEY")

if _api_key:
    print(f"[S2 DEBUG] S2_API_KEY = SET ({_api_key[:15]}...)")
else:
    print("[S2 DEBUG] S2_API_KEY = MISSING — running unauthenticated")

_headers = {"x-api-key": _api_key} if _api_key else {}
print(f"[S2 DEBUG] headers = {list(_headers.keys())}")


# ============================================================
# Search
# ============================================================
async def search_semantic_scholar(
    query: str,
    limit: int = 10,
    year_range: Optional[str] = None,
    discipline: Optional[str] = None,
) -> List[Dict]:
    """
    Search Semantic Scholar. Returns a normalized list of papers.
    year_range like '2015-2025' or None.
    """
    # Normalise human-readable date range values from the dropdown
    if year_range == "Last 5 years":
        year_range = f"{datetime.now().year - 5}-{datetime.now().year}"
    elif year_range in ("All time", "", None):
        year_range = None

    params = {
        "query": query,
        "limit": limit,
        "fields": S2_FIELDS,
    }
    if year_range:
        params["year"] = year_range

    # Use Semantic Scholar's proper fieldsOfStudy filter (not query keyword)
    _DISCIPLINE_MAP = {
        "medicine": "Medicine",
        "cs": "Computer Science",
        "engineering": "Engineering",
        "education": "Education",
    }
    if discipline and discipline.lower() not in ("all", ""):
        s2_field = _DISCIPLINE_MAP.get(discipline.lower())
        if s2_field:
            params["fieldsOfStudy"] = s2_field

    print(f"[S2 DEBUG] sending GET {S2_BASE}")
    print(f"[S2 DEBUG] params  = {params}")

    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            resp = await client.get(S2_BASE, params=params, headers=_headers)
    except httpx.TimeoutException:
        raise RuntimeError("Semantic Scholar request timed out — try again")
    except httpx.RequestError as e:
        raise RuntimeError(f"Semantic Scholar unreachable: {e}")

    print(f"[S2 DEBUG] status = {resp.status_code}")

    if resp.status_code == 429:
        raise RuntimeError("Semantic Scholar rate limit — try again in a minute")

    if resp.status_code >= 400:
        raise RuntimeError(
            f"Semantic Scholar error {resp.status_code}: {resp.text[:200]}"
        )

    data = resp.json()

    papers = []
    for p in data.get("data", []):
        authors_list = p.get("authors") or []
        authors = ", ".join(a.get("name", "") for a in authors_list[:3])
        if len(authors_list) > 3:
            authors += ", et al."

        papers.append({
            "id": p.get("paperId") or "",
            "title": p.get("title") or "Untitled",
            "authors": authors or "Unknown authors",
            "year": str(p.get("year") or ""),
            "abstract": (p.get("abstract") or "")[:1000],
            "url": p.get("url") or "",
            "citations": p.get("citationCount") or 0,
            "venue": p.get("venue") or "",
            "source": "Semantic Scholar",
        })

    print(f"[S2 DEBUG] parsed {len(papers)} papers")
    return papers