#!/usr/bin/env python3
"""Independent exact reporting oracle. JSON stdin only; no files or network.

Operands are supplied by the authentic-candidate test after canonical hydration.
Python Fraction provides a separate arbitrary-precision implementation from the
app's Swift digit arithmetic. This script is a validation tool, not an app input.
"""
import json
import sys
from fractions import Fraction


def verify(data):
    rates = {k: Fraction(v) for k, v in data["rates"].items()}
    # Express one native unit in QAR; division gives all six directed paths.
    base = {"QAR": Fraction(1), "INR": 1 / rates["INR"], "USD": 1 / rates["USD"]}
    inputs = {row["id"]: row for row in data["inputs"]}
    for target in data["targets"]:
        contributions = {row["id"]: row for row in target["contributions"]}
        assert contributions.keys() == inputs.keys(), "Contribution membership differs"
        total = Fraction(0)
        for key, source in inputs.items():
            actual = contributions[key]
            if source["value"] is None:
                assert actual["numerator"] is None, "Unknown source became a value"
                continue
            expected = Fraction(source["value"]) * base[source["currency"]] / base[target["currency"]]
            assert Fraction(actual["numerator"]) / Fraction(actual["denominator"]) == expected, "Contribution differs"
            total += expected
        assert Fraction(target["numerator"]) / Fraction(target["denominator"]) == total, "Exact aggregate differs"
        magnitude = abs(total)
        rounded = (2 * magnitude.numerator + magnitude.denominator) // (2 * magnitude.denominator)
        rounded = -rounded if total < 0 else rounded
        assert target["rounded"] == str(rounded), "Final whole-money rounding differs"
        for chart in target.get("charts", []):
            observed = []
            for row in chart["rows"]:
                observed.extend(row["ids"])
                known = [inputs[key] for key in row["ids"] if inputs[key]["value"] is not None]
                if not known:
                    assert row["numerator"] is None, "Unavailable chart row became zero"
                    continue
                expected = sum((Fraction(item["value"]) * base[item["currency"]] / base[target["currency"]]
                                for item in known), Fraction(0))
                assert Fraction(row["numerator"]) / Fraction(row["denominator"]) == expected, "Chart aggregate differs"
            expected_ids = {key for key in inputs if chart["scope"] == "Assets and liabilities" or key.startswith("holding:")}
            assert len(observed) == len(set(observed)), "Chart double-counts a position"
            assert set(observed) == expected_ids, "Chart and drill-down membership differ"
    return {"targets": len(data["targets"]), "components": len(inputs), "result": "PASS"}


if __name__ == "__main__":
    print(json.dumps(verify(json.load(sys.stdin))))
