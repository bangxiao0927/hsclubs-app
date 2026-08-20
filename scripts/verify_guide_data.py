#!/usr/bin/env python3
"""Compare the guide payload with each real school's authoritative summary API."""

from __future__ import annotations

import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone


GUIDE_URL = "https://hsclubs.net/api/schools"


def load_json(url: str) -> object:
    request = urllib.request.Request(url, headers={"Accept": "application/json"})
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.load(response)


def load_summary(site_url: str) -> dict[str, object]:
    summary = load_json(f"{site_url.rstrip('/')}/api/summary")
    if not isinstance(summary, dict):
        raise ValueError("summary endpoint did not return an object")
    return summary


def parse_instant(value: object) -> datetime | None:
    if value is None:
        return None
    if not isinstance(value, str):
        raise ValueError("timestamp is not a string")
    return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)


def main() -> int:
    payload = load_json(GUIDE_URL)
    if not isinstance(payload, dict) or not isinstance(payload.get("schools"), list):
        raise ValueError("guide endpoint returned an unexpected payload")

    failed = False
    for school in payload["schools"]:
        name = school.get("schoolName") or school.get("slug") or "Unknown school"
        if school.get("demo"):
            print(f"SKIP {name}: demo summaries intentionally use saved data")
            continue
        if school.get("status") == "no-data":
            print(f"SKIP {name}: guide reports no published data")
            continue

        site_url = str(school.get("siteUrl", ""))
        parsed_site_url = urllib.parse.urlparse(site_url)
        expected_host = str(school.get("host", ""))
        if (
            parsed_site_url.scheme != "https"
            or not expected_host
            or parsed_site_url.netloc.casefold() != expected_host.casefold()
        ):
            print(f"FAIL {name}: siteUrl is not the expected HTTPS origin")
            failed = True
            continue

        try:
            summary = load_summary(site_url)
        except (KeyError, OSError, ValueError, urllib.error.HTTPError) as error:
            print(f"FAIL {name}: cannot read school data ({error})")
            failed = True
            continue

        guide_categories = {
            str(category["name"]): int(category["count"])
            for category in school.get("categories", [])
        }
        summary_categories = {
            str(category): int(count)
            for category, count in dict(summary.get("categories", {})).items()
        }
        mismatches: list[str] = []
        for guide_key, summary_key in (
            ("schoolName", "schoolName"),
            ("clubCount", "clubCount"),
            ("address", "address"),
        ):
            if school.get(guide_key) != summary.get(summary_key):
                mismatches.append(
                    f"{guide_key} guide={school.get(guide_key)!r} "
                    f"school={summary.get(summary_key)!r}"
                )
        try:
            if parse_instant(school.get("publishedAt")) != parse_instant(
                summary.get("lastUpdatedAt")
            ):
                mismatches.append(
                    f"publishedAt guide={school.get('publishedAt')!r} "
                    f"school={summary.get('lastUpdatedAt')!r}"
                )
        except ValueError as error:
            mismatches.append(f"publishedAt is invalid ({error})")
        if school.get("slug") != summary.get("slug"):
            mismatches.append(
                f"slug guide={school.get('slug')!r} school={summary.get('slug')!r}"
            )
        if guide_categories != summary_categories:
            mismatches.append(
                f"categories guide={guide_categories!r} school={summary_categories!r}"
            )

        if mismatches:
            print(f"FAIL {name}: {'; '.join(mismatches)}")
            failed = True
        else:
            print(
                f"PASS {name}: {summary.get('clubCount')} clubs across "
                f"{len(summary_categories)} categories"
            )

    return 1 if failed else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"FAIL guide: {error}")
        sys.exit(1)
