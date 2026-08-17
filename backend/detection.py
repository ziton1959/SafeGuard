"""
SafeGuard - Layer 1 detection engine (rule-based).
Normalizes text (Arabizi -> Arabic, collapse repeats, strip noise)
then matches against an offensive-term wordlist.
This is the fast, offline baseline. Layer 2 (LLM) handles the rest.
"""

import re
import unicodedata
import os
import json
from dotenv import load_dotenv

load_dotenv()

# Configure Gemini (Layer 2). If no key, Layer 2 is skipped gracefully.
_GEMINI_READY = False
_gemini_client = None
try:
    from google import genai
    _key = os.getenv("GEMINI_API_KEY")
    if _key:
        _gemini_client = genai.Client(api_key=_key)
        _GEMINI_READY = True
except Exception as _e:
    _GEMINI_READY = False
# ------------------------------------------------------------------
# 1. ARABIZI NORMALIZATION MAP
# People write Arabic sounds with numbers/latin. Collapse them so
# "9a7ba", "9ahba", "qa7ba" all reduce toward one form.
# ------------------------------------------------------------------
ARABIZI_MAP = {
    "2": "ء",
    "3": "ع",
    "5": "خ",
    "6": "ط",
    "7": "ح",
    "8": "غ",
    "9": "ق",
}

# ------------------------------------------------------------------
# 2. WORDLIST
# Starter set. As a native speaker, EXPAND these lists.
# Store terms lowercase. Include both Arabic-script and Arabizi forms.
# severity: "high" = slur/sexual insult, "medium" = strong profanity,
#           "low" = mild.
# ------------------------------------------------------------------
OFFENSIVE_TERMS = {
    # --- Derja / Arabic script (high) ---
    "قحبة": "high",
    "عاهرة": "high",
    "زبي": "high",
    "نيك": "high",
    "منيك": "high",
    "طيز": "medium",
    "زوكة": "medium",
    "خرا": "low",
    "بهيم": "low",

    # --- Arabizi forms (high) ---
    "9a7ba": "high",
    "9ahba": "high",
    "9a7be": "high",
    "nik": "high",
    "mnik": "high",
    "zabi": "high",
    "3ahra": "high",

    # --- French (common in Tunisia) ---
    "pute": "high",
    "salope": "high",
    "connard": "medium",
    "merde": "low",
    "putain": "medium",

    # --- English ---
    "fuck": "medium",
    "bitch": "medium",
    "asshole": "medium",
    "shit": "low",
}

# Bullying / aggression signal words (second layer of meaning:
# not just profanity, but targeting a person). Expand these too.
BULLYING_TERMS = {
    "تموت", "اقتل روحك", "kill yourself", "kys",
    "loser", "ugly", "بهيم", "حقير", "t3ich wa7dek",
}


def normalize(text: str) -> str:
    """Reduce text to a canonical form to defeat simple evasions."""
    if not text:
        return ""
    # lowercase
    text = text.lower()
    # unicode normalize (strip accents variations)
    text = unicodedata.normalize("NFKC", text)
    # replace arabizi digits with arabic letters
    for digit, letter in ARABIZI_MAP.items():
        text = text.replace(digit, letter)
    # remove separators people insert: 9.a.7.b.a or 9_a_7_b_a or spaces inside
    text = re.sub(r"[._\-*]", "", text)
    # collapse 3+ repeated letters: "9a7baaaa" -> "9a7baa" -> handled below
    text = re.sub(r"(.)\1{2,}", r"\1", text)
    return text


def detect_language_layer1(text: str) -> dict:
    """
    Rule-based detection.
    Returns: { is_offensive, severity, matched_terms, is_bullying }
    """
    norm = normalize(text)
    # also keep a version with normalized wordlist for arabizi matches
    matched = []
    highest = None
    order = {"low": 1, "medium": 2, "high": 3}

    for term, sev in OFFENSIVE_TERMS.items():
        norm_term = normalize(term)
        if norm_term and norm_term in norm:
            matched.append(term)
            if highest is None or order[sev] > order[highest]:
                highest = sev

    # bullying check
    is_bullying = False
    for term in BULLYING_TERMS:
        if normalize(term) in norm:
            is_bullying = True
            break

    return {
        "is_offensive": len(matched) > 0,
        "severity": highest,          # None if clean
        "matched_terms": matched,
        "is_bullying": is_bullying,
    }

def detect_language_layer2(text: str) -> dict:
    """
    LLM interpretation layer. Catches what the wordlist misses:
    novel spellings, context, sarcasm, bullying without keywords.
    Understands Tunisian Derja + Arabizi + French code-switching.
    Returns: { is_offensive, severity, is_bullying, reason } or None if unavailable.
    """
    if not _GEMINI_READY or not text.strip():
        return None

    prompt = f"""You are a content-safety classifier for a child-protection app.
Analyze this message, which may be in Tunisian Derja, Arabizi (numbers as letters:
3=ع, 7=ح, 9=ق), Arabic, French, or English, possibly mixed.

Message: "{text}"

Decide if it is offensive/profane, and separately if it is bullying/harassment
directed at a person. Reply with ONLY a JSON object, no other text:
{{"is_offensive": true/false, "severity": "low"/"medium"/"high"/null, "is_bullying": true/false, "reason": "short explanation"}}"""

    try:
        response = _gemini_client.models.generate_content(
            model="gemini-3.6-flash",
            contents=prompt,
        )
        raw = response.text.strip()
        # strip markdown code fences if present
        raw = raw.replace("```json", "").replace("```", "").strip()
        data = json.loads(raw)
        return {
            "is_offensive": bool(data.get("is_offensive", False)),
            "severity": data.get("severity"),
            "is_bullying": bool(data.get("is_bullying", False)),
            "reason": data.get("reason", ""),
        }
    except Exception as e:
        # fail safe: if the LLM errors, don't crash detection
        return None


def detect_combined(text: str) -> dict:
    """
    Full engine: Layer 1 (fast, offline) always runs.
    Layer 2 (LLM) runs to catch what Layer 1 missed.
    Merges both - if either flags it, it's flagged (highest severity wins).
    """
    order = {"low": 1, "medium": 2, "high": 3}
    l1 = detect_language_layer1(text)

    result = {
        "is_offensive": l1["is_offensive"],
        "severity": l1["severity"],
        "is_bullying": l1["is_bullying"],
        "matched_terms": l1["matched_terms"],
        "source": "layer1",
    }

    # Run Layer 2 to catch subtle cases (or confirm)
    l2 = detect_language_layer2(text)
    if l2:
        # merge: offensive if either says so
        if l2["is_offensive"] and not result["is_offensive"]:
            result["is_offensive"] = True
            result["source"] = "layer2"
        if l2["is_bullying"]:
            result["is_bullying"] = True
        # take the higher severity between the two
        sevs = [s for s in [result["severity"], l2["severity"]] if s]
        if sevs:
            result["severity"] = max(sevs, key=lambda s: order.get(s, 0))
        result["layer2_reason"] = l2.get("reason", "")

    return result

# quick manual test when run directly:  python detection.py
if __name__ == "__main__":
    tests = [
        "salut ça va",              # clean
        "nti 9a7baaaa",             # layer 1 catches
        "ya weld el 7aram",         # derja insult layer 1 may miss
        "you're worthless, nobody likes you",  # bullying, no bad word
    ]
    for t in tests:
        print(t, "->", detect_combined(t))