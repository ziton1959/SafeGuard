"""
SafeGuard - Layer 1 detection engine (rule-based).
Normalizes text (Arabizi -> Arabic, collapse repeats, strip noise)
then matches against an offensive-term wordlist.
This is the fast, offline baseline. Layer 2 (LLM) handles the rest.
"""

import re
import unicodedata

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


# quick manual test when run directly:  python detection.py
if __name__ == "__main__":
    tests = [
        "salut ça va",
        "ya 9a7ba",
        "nti 9a7baaaa",
        "9.a.7.b.a",
        "you are a loser, kys",
        "خرا عليك",
    ]
    for t in tests:
        print(t, "->", detect_language_layer1(t))