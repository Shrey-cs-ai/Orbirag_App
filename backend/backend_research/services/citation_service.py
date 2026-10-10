"""
Citation service: extracts metadata from text/PDF/URL and formats
citations in APA 7, MLA 9, Chicago, IEEE, or Harvard.
"""

import os
import re
import json
import io
import xml.etree.ElementTree as ET
from typing import Optional

import httpx
from fastapi import HTTPException


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
# URL & Academic API helpers
# ============================================================
def _extract_doi_from_url(url: str) -> Optional[str]:
    """Extract a DOI from a URL like https://doi.org/10.1145/xxx or
    https://dl.acm.org/doi/10.1145/xxx"""
    m = re.search(r'10\.\d{4,9}/[-._;()/:A-Z0-9]+', url, re.IGNORECASE)
    if m:
        return m.group(0).rstrip(".,;/")
    return None


def _extract_arxiv_id(url: str) -> Optional[str]:
    """Extract arXiv ID from arxiv.org URLs."""
    # Match arxiv.org/abs/1706.03762 or arxiv.org/pdf/1706.03762.pdf
    m = re.search(r'arxiv\.org/(?:abs|pdf)/(\d{4}\.\d{4,5})', url, re.IGNORECASE)
    if not m:
        m = re.search(r'arxiv\.org/(?:abs|pdf)/([0-9]+\.[0-9]+(?:v[0-9]+)?|[a-zA-Z\-]+/[0-9]+)', url, re.IGNORECASE)
    return m.group(1) if m else None


async def _fetch_crossref_metadata(doi: str) -> dict:
    """Query Crossref for DOI metadata. Returns normalized dict."""
    try:
        async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
            r = await client.get(
                f"https://api.crossref.org/works/{doi}",
                headers={"User-Agent": "Orbirag/1.0 (mailto:admin@orbirag.local)"},
            )
            if r.status_code != 200:
                return {}
            data = r.json().get("message", {})

            # Authors
            authors_list = data.get("author", [])
            authors_parts = []
            for a in authors_list[:6]:
                family = a.get("family", "").strip()
                given = a.get("given", "").strip()
                if family and given:
                    authors_parts.append(f"{family}, {given[0]}.")
                elif family:
                    authors_parts.append(family)
                elif given:
                    authors_parts.append(given)
            authors = ", ".join(authors_parts)

            # Year
            year = ""
            date_parts = (
                data.get("published-print", {}).get("date-parts")
                or data.get("published-online", {}).get("date-parts")
                or data.get("issued", {}).get("date-parts")
            )
            if date_parts and date_parts[0]:
                year = str(date_parts[0][0])

            title_list = data.get("title") or [""]
            container_list = data.get("container-title") or [""]

            return {
                "title": title_list[0] if title_list else "",
                "authors": authors,
                "year": year,
                "journal": container_list[0] if container_list else "",
                "publisher": data.get("publisher", ""),
                "doi": doi,
                "url": f"https://doi.org/{doi}",
            }
    except Exception as e:
        print(f"[Citation] Crossref error for {doi}: {e}")
        return {}


async def _fetch_arxiv_metadata(arxiv_id: str) -> dict:
    """Query arXiv Export API for metadata."""
    try:
        async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
            r = await client.get(
                f"https://export.arxiv.org/api/query?id_list={arxiv_id}",
                headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"},
            )
            if r.status_code != 200:
                return {}
            root = ET.fromstring(r.text)
            ns = {'atom': 'http://www.w3.org/2005/Atom'}
            entry = root.find('atom:entry', ns)
            if entry is None:
                return {}

            title = (entry.findtext('atom:title', '', ns) or '').strip()
            title = re.sub(r'\s+', ' ', title)

            authors_parts = []
            for author in entry.findall('atom:author', ns)[:6]:
                name = (author.findtext('atom:name', '', ns) or '').strip()
                parts = name.split()
                if len(parts) >= 2:
                    authors_parts.append(f"{parts[-1]}, {parts[0][0]}.")
                elif name:
                    authors_parts.append(name)
            authors = ", ".join(authors_parts)

            published = entry.findtext('atom:published', '', ns)
            year = published[:4] if published else ""

            return {
                "title": title,
                "authors": authors,
                "year": year,
                "journal": "arXiv preprint",
                "publisher": "arXiv",
                "doi": f"10.48550/arXiv.{arxiv_id}",
                "url": f"https://arxiv.org/abs/{arxiv_id}",
            }
    except Exception as e:
        print(f"[Citation] arXiv error for {arxiv_id}: {e}")
        return {}

# Alias for backwards compatibility
fetch_arxiv_metadata = _fetch_arxiv_metadata


async def _fetch_html(url: str) -> str:
    """Fetch HTML with realistic browser headers."""
    try:
        async with httpx.AsyncClient(
            timeout=15.0,
            follow_redirects=True,
            headers={
                "User-Agent": (
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) "
                    "Chrome/120.0.0.0 Safari/537.36"
                ),
                "Accept": (
                    "text/html,application/xhtml+xml,application/xml;q=0.9,"
                    "image/webp,*/*;q=0.8"
                ),
                "Accept-Language": "en-US,en;q=0.9",
            },
        ) as client:
            r = await client.get(url)
            if r.status_code != 200:
                print(f"[Citation] fetch {url} -> {r.status_code}")
                return ""
            return r.text
    except Exception as e:
        print(f"[Citation] fetch error {url}: {e}")
        return ""


def _extract_metadata_from_html(html: str, url: str) -> dict:
    """Parse Dublin Core / OpenGraph / Highwire meta tags from HTML.
    These are used by ACM, Springer, IEEE, Elsevier, PubMed, etc."""
    def meta(name: str) -> str:
        # Match both name= and property= variants, order flexible
        for attr in ('name', 'property'):
            m = re.search(
                rf'<meta[^>]+{attr}=["\']{re.escape(name)}["\'][^>]+content=["\']([^"\']+)["\']',
                html, re.IGNORECASE
            )
            if not m:
                m = re.search(
                    rf'<meta[^>]+content=["\']([^"\']+)["\'][^>]+{attr}=["\']{re.escape(name)}["\']',
                    html, re.IGNORECASE
                )
            if m:
                return m.group(1).strip()
        return ""

    # Title — try Highwire then OpenGraph then Dublin Core
    title = (
        meta("citation_title")
        or meta("og:title")
        or meta("DC.Title")
        or meta("dc.title")
    )

    # Authors — citation_author appears multiple times
    author_matches = re.findall(
        r'<meta[^>]+name=["\']citation_author["\'][^>]+content=["\']([^"\']+)["\']',
        html, re.IGNORECASE
    )
    if not author_matches:
        author_matches = re.findall(
            r'<meta[^>]+property=["\']article:author["\'][^>]+content=["\']([^"\']+)["\']',
            html, re.IGNORECASE
        )
    authors = ", ".join(author_matches[:6])

    # Year
    date = meta("citation_publication_date") or meta("citation_date") or meta("DC.Date")
    year = date[:4] if date else ""

    # Journal / venue
    journal = (
        meta("citation_journal_title")
        or meta("citation_conference_title")
        or meta("citation_inbook_title")
        or meta("og:site_name")
    )

    # Publisher
    publisher = meta("citation_publisher") or meta("DC.Publisher")

    # DOI
    doi = meta("citation_doi") or meta("DC.Identifier")
    if doi.startswith("doi:"):
        doi = doi[4:]

    # If a bare URL was passed to a DOI resolver, pull the DOI from the URL
    if not doi:
        extracted = _extract_doi_from_url(url)
        if extracted:
            doi = extracted

    # Title cleanup
    title = re.sub(r'\s+', ' ', title).strip()

    return {
        "title": title,
        "authors": authors,
        "year": year,
        "journal": journal,
        "publisher": publisher,
        "doi": doi,
        "url": url,
    }


# ============================================================
# URL text extraction
# ============================================================
async def extract_text_from_url(url: str, max_chars: int = 6000) -> str:
    """Fetch a URL and strip the HTML to plain text."""
    html = await _fetch_html(url)
    if not html:
        return ""
    # Strip scripts and styles first
    html = re.sub(r"<script.*?</script>", " ", html, flags=re.DOTALL | re.IGNORECASE)
    html = re.sub(r"<style.*?</style>", " ", html, flags=re.DOTALL | re.IGNORECASE)
    # Keep meta tags content — extract them into readable text
    meta_text = " ".join(
        m for m in re.findall(r'<meta[^>]+content=["\']([^"\']+)["\']', html, re.IGNORECASE)
    )
    # Strip remaining tags
    body = re.sub(r"<[^>]+>", " ", html)
    text = (meta_text + " " + body)
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
    title = (metadata.get("title") or "").strip()
    authors = (metadata.get("authors") or "").strip()
    if not title and not authors:
        return {
            "in_text": "",
            "reference_list": "",
        }

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
      - url                       → smart URL pipeline (DOI/Crossref, arXiv, HTML meta, LLM fallback)
      - raw_text                  → extract + format
    """
    if metadata:
        formatted = await format_citation(metadata, style)
        return {
            "metadata": metadata,
            "style": style,
            "in_text": formatted.get("in_text", ""),
            "reference_list": formatted.get("reference_list", ""),
        }

    if raw_text:
        extracted = await extract_metadata(raw_text)
        if url and not extracted.get("url"):
            extracted["url"] = url
        formatted = await format_citation(extracted, style)
        return {
            "metadata": extracted,
            "style": style,
            "in_text": formatted.get("in_text", ""),
            "reference_list": formatted.get("reference_list", ""),
        }

    if url and not raw_text:
        # 1. DOI URL → query Crossref (most reliable)
        doi = _extract_doi_from_url(url)
        if doi:
            crossref_meta = await _fetch_crossref_metadata(doi)
            if crossref_meta and crossref_meta.get("title"):
                formatted = await format_citation(crossref_meta, style)
                return {
                    "metadata": crossref_meta,
                    "style": style,
                    "in_text": formatted.get("in_text", ""),
                    "reference_list": formatted.get("reference_list", ""),
                }

        # 2. arXiv URL → query arXiv Export API (already works)
        arxiv_id = _extract_arxiv_id(url)
        if arxiv_id:
            arxiv_meta = await _fetch_arxiv_metadata(arxiv_id)
            if arxiv_meta and arxiv_meta.get("title"):
                formatted = await format_citation(arxiv_meta, style)
                return {
                    "metadata": arxiv_meta,
                    "style": style,
                    "in_text": formatted.get("in_text", ""),
                    "reference_list": formatted.get("reference_list", ""),
                }

        # 3. Fall back to HTML scraping with proper headers
        html = await _fetch_html(url)
        if html:
            html_meta = _extract_metadata_from_html(html, url)
            if html_meta and html_meta.get("title"):
                formatted = await format_citation(html_meta, style)
                return {
                    "metadata": html_meta,
                    "style": style,
                    "in_text": formatted.get("in_text", ""),
                    "reference_list": formatted.get("reference_list", ""),
                }

        # 4. Last resort: pass whatever text we got to the LLM
        text = await extract_text_from_url(url)
        if text.strip():
            llm_meta = await extract_metadata(text)
            if url and not llm_meta.get("url"):
                llm_meta["url"] = url
            if llm_meta.get("title") or llm_meta.get("authors"):
                formatted = await format_citation(llm_meta, style)
                if formatted.get("in_text") or formatted.get("reference_list"):
                    return {
                        "metadata": llm_meta,
                        "style": style,
                        "in_text": formatted.get("in_text", ""),
                        "reference_list": formatted.get("reference_list", ""),
                    }

        # 5. Nothing worked → return an informative error
        raise HTTPException(
            status_code=422,
            detail=(
                "Could not extract metadata from this URL. "
                "The page may block automated access. "
                "Please use the 'Enter Manually' tab with the paper's title, "
                "authors, year, and journal."
            ),
        )

    raise HTTPException(status_code=400, detail="No source provided")
