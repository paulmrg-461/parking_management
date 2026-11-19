from lpr_edge.postprocess import PlateRules, normalize


def test_strips_hyphen_and_spaces():
    assert normalize(" abc-123 ") == "ABC123"
    assert normalize("ABC 12 3") == "ABC123"


def test_empty_or_noise_is_dropped():
    assert normalize("") is None
    assert normalize("---") is None


def test_fold_confusables_only_when_pattern_then_matches():
    # O/0 and I/1 confusions land on the car layout.
    assert normalize("ABC1O2") == "ABC102"
    assert normalize("ABCI23") == "ABC123"
    # A real moto plate keeps its trailing letter.
    assert normalize("ABC12A") == "ABC12A"


def test_drops_non_matching():
    assert normalize("AB123") is None
    assert normalize("ABCD1234") is None


def test_accept_unmatched_flag():
    rules = PlateRules(accept_unmatched=True)
    assert normalize("AB123", rules) == "AB123"
    assert normalize("AB", rules) is None


def test_never_returns_chars_outside_A_Z_0_9():
    for raw in ["a-b_c 12", "ábc123", "ABC-12Z", "  ñ  "]:
        result = normalize(raw, PlateRules(accept_unmatched=True))
        assert result is None or all(c.isascii() and (c.isalnum()) for c in result)
