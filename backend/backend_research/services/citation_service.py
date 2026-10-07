"""
Citation service: extracts metadata from text/PDF/URL and formats
citations in APA 7, MLA 9, Chicago, IEEE, or Harvard.
"""

import os
import re
import json
import io
import xml.etree.ElementTree as ET

import httpx


# ============================================================
# LLM helper (Groq primary + Gemini fallback)
# ============================================================
async def _ask_gemini(prompt: str, json_mode: bool = False) -> str:
    from services.ai_service import _generate_with_fallback
    text = await _generate_with_fallback(prompt, json_mode=json_mode)
    text = (text or "").strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*|\s*```$", "", text, flags=re.MULTILINE)
    return text


# ============================================================
# PDF text extraction
# ============================================================
def extract_text_from_pdf(pdf_bytes: bytes, max_chars: int = 6000) -> str:
    """Extract text from a PDF using pypdf."""
    try:
        from pypdf import PdfReader
        reader = PdfReader(io.BytesIO(pdf_bytes))
        chunks = []
        for page in reader.pages[:5]:  # first 5 pages is plenty for metadata
            chunks.append(page.extract_text() or "")
            if sum(len(c) for c in chunks) >= max_chars:
                break
        return "\n".join(chunks)[:max_chars]
    except Exception as e:
        print(f"[Citation] PDF extract failed: {e}")
        return ""


# ============================================================
# arXiv API metadata extraction
# ============================================================
async def fetch_arxiv_metadata(arxiv_id: str) -> dict:
    """Fetch metadata directly from arXiv Export API for a given arXiv ID."""
    url = f"http://export.arxiv.org/api/query?id_list={arxiv_id}"
    print(f"[Citation] Fetching arXiv API: {url}")
    try:
        async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
            r = await client.get(url, headers={"User-Agent": "Mozilla/5.0"})
            print(f"[Citation] arXiv API status: {r.status_code}, preview: {r.text[:200]!r}")
            r.raise_for_status()
            xml_content = r.text

        root = ET.fromstring(xml_content)
        ns = {"atom": "http://www.w3.org/2005/Atom"}
        entry = root.find("atom:entry", ns)
        if entry is None:
            raise ValueError(f"No entry found in arXiv for ID {arxiv_id}")

        title_elem = entry.find("atom:title", ns)
        title = ""
        if title_elem is not None and title_elem.text:
            title = re.sub(r"\s+", " ", title_elem.text.strip().replace("\n", " "))

        authors = []
        for author_elem in entry.findall("atom:author", ns):
            name_elem = author_elem.find("atom:name", ns)
            if name_elem is not None and name_elem.text:
                authors.append(name_elem.text.strip())
        authors_str = ", ".join(authors)

        published_elem = entry.find("atom:published", ns)
        year = ""
        if published_elem is not None and published_elem.text:
            year = published_elem.text[:4]

        return {
            "title": title,
            "authors": authors_str,
            "year": year,
            "journal": f"arXiv preprint arXiv:{arxiv_id}",
            "publisher": "arXiv",
            "doi": f"10.48550/arXiv.{arxiv_id}",
            "url": f"https://arxiv.org/abs/{arxiv_id}",
        }
    except Exception as e:
        print(f"[Citation] arXiv API fetch failed: {e}")
        raise ValueError(f"Could not retrieve arXiv paper info: {e}")


# ============================================================
# URL text extraction
# ============================================================
async def extract_text_from_url(url: str, max_chars: int = 6000) -> str:
    """Fetch a URL and strip the HTML to plain text."""
    try:
        async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
            r = await client.get(url, headers={"User-Agent": "Mozilla/5.0"})
            print(f"[Citation] URL fetch status: {r.status_code}, preview: {r.text[:200]!r}")
            r.raise_for_status()
            html = r.text
    except Exception as e:
        print(f"[Citation] URL fetch failed: {e}")
        raise ValueError("Could not fetch page content. Try the manual entry tab.")

    # Strip scripts/styles
    html = re.sub(r"<script.*?</script>", " ", html, flags=re.DOTALL | re.IGNORECASE)
    html = re.sub(r"<style.*?</style>", " ", html, flags=re.DOTALL | re.IGNORECASE)
    # Strip tags
    text = re.sub(r"<[^>]+>", " ", html)
    # Collapse whitespace
    text = re.sub(r"\s+", " ", text).strip()
    if not text:
        raise ValueError("Could not fetch page content. Try the manual entry tab.")
    return text[:max_chars]


# ============================================================
# Metadata extraction (Gemini)
# ============================================================
_METADATA_PROMPT = """You are extracting bibliographic metadata from a document.

Return ONLY valid JSON with this shape:
{{
  "title": "...",
  "authors": "Author One, Author Two",
  "year": "2023",
  "journal": "Journal or conference name",
  "publisher": "Publisher if applicable",
  "doi": "10.xxxx/xxxxx or empty string",
  "url": "url or empty string"
}}

Rules:
- If a field is unknown, use an empty string ""
- Authors should be comma-separated, "Last, F. M." format
- Year must be a 4-digit string or ""

TEXT:
\"\"\"{text}\"\"\"
"""


async def extract_metadata(text: str) -> dict:
    if not text.strip():
        return {
            "title": "", "authors": "", "year": "",
            "journal": "", "publisher": "", "doi": "", "url": "",
        }
    prompt = _METADATA_PROMPT.format(text=text[:5000])
    try:
        raw = await _ask_gemini(prompt, json_mode=True)
        return json.loads(raw)
    except Exception as e:
        print(f"[Citation] metadata extraction failed: {e}")
        return {
            "title": "", "authors": "", "year": "",
            "journal": "", "publisher": "", "doi": "", "url": "",
        }


# ============================================================
# Citation formatting (Gemini)
# ============================================================
_STYLE_INSTRUCTIONS = {
    "APA 7":   "APA 7th edition. Author, A. A. (Year). Title. Journal, Volume(Issue), pages. DOI/URL",
    "MLA 9":   "MLA 9th edition. Author. \"Title.\" Journal, vol. X, no. Y, Year, pp. Z.",
    "Chicago": "Chicago 17th. Author. \"Title.\" Journal X, no. Y (Year): pages.",
    "IEEE":    "IEEE. [1] A. Author, \"Title,\" Journal, vol. X, no. Y, pp. Z, Year.",
    "Harvard": "Harvard. Author (Year) 'Title', Journal, vol. X, no. Y, pp. Z.",
}

_FORMAT_PROMPT = """You are a citation formatter. Produce a citation in the requested style.

Style: {style}
Rule: {rule}

Metadata:
- title: {title}
- authors: {authors}
- year: {year}
- journal: {journal}
- publisher: {publisher}
- doi: {doi}
- url: {url}

Return ONLY valid JSON with this shape:
{{
  "in_text": "short in-text citation like (Smith, 2023)",
  "reference_list": "full formatted reference"
}}

Rules:
- If metadata is missing, infer nothing — use available fields only
- Do not add quotes around the JSON output
"""


async def format_citation(metadata: dict, style: str) -> dict:
    title = (metadata.get("title") or "").strip()
    authors = (metadata.get("authors") or "").strip()
    if not title and not authors:
        raise ValueError("Could not extract citation metadata (title and authors are missing). Try the manual entry tab.")

    if style not in _STYLE_INSTRUCTIONS:
        style = "APA 7"

    prompt = _FORMAT_PROMPT.format(
        style=style,
        rule=_STYLE_INSTRUCTIONS[style],
        title=title,
        authors=authors,
        year=metadata.get("year", ""),
        journal=metadata.get("journal", ""),
        publisher=metadata.get("publisher", ""),
        doi=metadata.get("doi", ""),
        url=metadata.get("url", ""),
    )

    try:
        raw = await _ask_gemini(prompt, json_mode=True)
        return json.loads(raw)
    except Exception as e:
        print(f"[Citation] format failed: {e}")
        # Fallback — plain concatenation
        t = title or "Untitled"
        a = authors or "Unknown"
        y = metadata.get("year") or "n.d."
        return {
            "in_text": f"({a.split(',')[0]}, {y})",
            "reference_list": f"{a} ({y}). {t}.",
        }


# ============================================================
# Top-level: generate from any source
# ============================================================
async def generate(
    style: str,
    raw_text: str = "",
    url: str = "",
    metadata: dict | None = None,
) -> dict:
    """
    Build a citation from one of:
      - metadata (manual entry)   → skip extraction
      - url                       → fetch + extract + format (special arXiv handling)
      - raw_text                  → extract + format
    """
    if not metadata:
        arxiv_match = re.search(r"arxiv\.org/(?:abs|pdf)/([0-9]+\.[0-9]+(?:v[0-9]+)?|[a-zA-Z\-]+/[0-9]+)", url or "", re.IGNORECASE)
        if arxiv_match:
            arxiv_id = arxiv_match.group(1)
            metadata = await fetch_arxiv_metadata(arxiv_id)
        elif url and not raw_text:
            raw_text = await extract_text_from_url(url)
            metadata = await extract_metadata(raw_text)
            if url and not metadata.get("url"):
                metadata["url"] = url
        elif raw_text:
            metadata = await extract_metadata(raw_text)
            if url and not metadata.get("url"):
                metadata["url"] = url
        else:
            metadata = {}

    formatted = await format_citation(metadata, style)
    return {
        "metadata": metadata,
        "style": style,
        "in_text": formatted.get("in_text", ""),
        "reference_list": formatted.get("reference_list", ""),
    }
