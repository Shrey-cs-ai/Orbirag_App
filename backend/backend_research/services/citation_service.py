"""
Citation service: extracts metadata from text/PDF/URL and formats
citations in APA 7, MLA 9, Chicago, IEEE, or Harvard.
"""

import os
import re
import json
import io

import httpx


# ============================================================
# Gemini helper
# ============================================================
def _gemini_model():
    import google.generativeai as genai
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise RuntimeError("GEMINI_API_KEY not set")
    genai.configure(api_key=api_key)
    return genai.GenerativeModel("gemini-3.8-flash")


async def _ask_gemini(prompt: str, json_mode: bool = False) -> str:
    model = _gemini_model()
    cfg = {"temperature": 0.2}
    if json_mode:
        cfg["response_mime_type"] = "application/json"
    response = model.generate_content(prompt, generation_config=cfg)
    text = response.text.strip()
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
# URL text extraction
# ============================================================
async def extract_text_from_url(url: str, max_chars: int = 6000) -> str:
    """Fetch a URL and strip the HTML to plain text."""
    try:
        async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
            r = await client.get(url, headers={"User-Agent": "Mozilla/5.0"})
            r.raise_for_status()
            html = r.text
    except Exception as e:
        print(f"[Citation] URL fetch failed: {e}")
        return ""

    # Strip scripts/styles
    html = re.sub(r"<script.*?</script>", " ", html, flags=re.DOTALL | re.IGNORECASE)
    html = re.sub(r"<style.*?</style>", " ", html, flags=re.DOTALL | re.IGNORECASE)
    # Strip tags
    text = re.sub(r"<[^>]+>", " ", html)
    # Collapse whitespace
    text = re.sub(r"\s+", " ", text).strip()
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
    if style not in _STYLE_INSTRUCTIONS:
        style = "APA 7"

    prompt = _FORMAT_PROMPT.format(
        style=style,
        rule=_STYLE_INSTRUCTIONS[style],
        title=metadata.get("title", ""),
        authors=metadata.get("authors", ""),
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
        title = metadata.get("title") or "Untitled"
        authors = metadata.get("authors") or "Unknown"
        year = metadata.get("year") or "n.d."
        return {
            "in_text": f"({authors.split(',')[0]}, {year})",
            "reference_list": f"{authors} ({year}). {title}.",
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
      - url                       → fetch + extract + format
      - raw_text                  → extract + format
    """
    if not metadata:
        # Fetch text if URL given
        if url and not raw_text:
            raw_text = await extract_text_from_url(url)

        # Extract metadata from text
        metadata = await extract_metadata(raw_text)
        if url and not metadata.get("url"):
            metadata["url"] = url

    formatted = await format_citation(metadata, style)
    return {
        "metadata": metadata,
        "style": style,
        "in_text": formatted.get("in_text", ""),
        "reference_list": formatted.get("reference_list", ""),
    }


