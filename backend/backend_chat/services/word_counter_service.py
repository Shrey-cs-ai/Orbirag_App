import re

def count_words(text: str) -> int:
    if not text.strip():
        return 0
    return len([w for w in re.split(r'\s+', text.strip()) if w])

def count_characters(text: str) -> int:
    return len(text)

def count_sentences(text: str) -> int:
    if not text.strip():
        return 0
    # Split on . ! ? followed by space or end of string
    matches = re.findall(r'[^.!?]+[.!?]+', text)
    if not matches:
        return 1 if text.strip() else 0
    # Check trailing text without terminator
    last_match_end = text.rfind(matches[-1]) + len(matches[-1])
    trailing = text[last_match_end:].strip()
    return len(matches) + (1 if trailing else 0)

def build_stats(text: str) -> dict:
    return {
        "words": count_words(text),
        "characters": count_characters(text),
        "sentences": count_sentences(text),
    }