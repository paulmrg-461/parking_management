"""Plate normalisation before anything leaves the edge box.

The server re-validates everything; this module exists so a camera never
sends obvious OCR noise and so a single confusable character does not lose a
real read. It never returns a character outside ``A-Z0-9``.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

DEFAULT_PATTERNS = (
    r"^[A-Z]{3}[0-9]{3}$",      # cars
    r"^[A-Z]{3}[0-9]{2}[A-Z]$",  # motorcycles
)

LETTER_FOLD = {"0": "O", "1": "I", "8": "B", "5": "S", "2": "Z", "6": "G"}
DIGIT_FOLD = {value: key for key, value in LETTER_FOLD.items()}
CLEAN = re.compile(r"[^A-Z0-9]")
ACCEPT = re.compile(r"^[A-Z0-9]{4,10}$")
GROUP = re.compile(r"\[([A-Z0-9])-([A-Z0-9])\]\{(\d+)\}")


@dataclass(frozen=True)
class PlateRules:
    patterns: tuple[str, ...] = DEFAULT_PATTERNS
    fold_confusables: bool = True
    accept_unmatched: bool = False


def normalize(raw: str | None, rules: PlateRules | None = None) -> str | None:
    """Uppercase, strip everything outside ``A-Z0-9`` and apply the rules."""
    rules = rules or PlateRules()
    text = CLEAN.sub("", (raw or "").upper())
    if text == "":
        return None
    if any(re.match(pattern, text) for pattern in rules.patterns):
        return text
    if rules.fold_confusables:
        folded = _fold(text, rules.patterns)
        if folded is not None:
            return folded
    if rules.accept_unmatched and ACCEPT.match(text):
        return text
    return None


def _fold(text: str, patterns: tuple[str, ...]) -> str | None:
    """Positional confusable fold, using the class layout of a same-length
    pattern. Returns the folded plate only when it matches that pattern."""
    for pattern in patterns:
        mask = _layout(pattern)
        if mask is None or len(mask) != len(text):
            continue
        folded = "".join(
            (LETTER_FOLD.get(char, char) if kind == "L" else DIGIT_FOLD.get(char, char))
            for char, kind in zip(text, mask)
        )
        if re.match(pattern, folded) and re.match(r"^[A-Z0-9]+$", folded):
            return folded
    return None


def _layout(pattern: str) -> list[str] | None:
    """Turn the small regex dialect of the config into a letter/digit mask."""
    body = pattern.removeprefix("^").removesuffix("$")
    mask: list[str] = []
    position = 0
    for match in GROUP.finditer(body):
        if match.start() != position:
            return None
        low, high, count = match.group(1), match.group(2), int(match.group(3))
        if (low, high) == ("A", "Z"):
            mask.extend(["L"] * count)
        elif (low, high) == ("0", "9"):
            mask.extend(["D"] * count)
        else:
            return None
        position = match.end()
    return mask if position == len(body) else None
