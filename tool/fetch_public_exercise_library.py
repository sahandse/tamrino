from __future__ import annotations

import hashlib
import json
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/data/free_exercises.json"

SOURCE_REPO = "yuhonas/free-exercise-db"
SOURCE_COMMIT = "f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5"
SOURCE_BLOB_SHA1 = "37beaac6031b34f7a7322b3150d201182c49a71b"
SOURCE_URL = (
    "https://raw.githubusercontent.com/"
    f"{SOURCE_REPO}/{SOURCE_COMMIT}/dist/exercises.json"
)


def git_blob_sha1(data: bytes) -> str:
    header = f"blob {len(data)}\0".encode("utf-8")
    return hashlib.sha1(header + data).hexdigest()


def normalize(item: dict) -> dict | None:
    name = str(item.get("name") or "").strip()
    if not name:
        return None

    primary = item.get("primaryMuscles") or []
    muscle = str(primary[0]).strip() if primary else None
    equipment = item.get("equipment")
    equipment = str(equipment).strip() if equipment else None
    category = str(item.get("category") or "strength").strip().lower()

    if category in {"cardio"}:
        tracking_type = "cardio"
        exercise_mode = "reps"
    elif category in {"stretching"}:
        tracking_type = "timed"
        exercise_mode = "timed"
    else:
        tracking_type = "strength"
        exercise_mode = "reps"

    normalized = {
        "id": str(item.get("id") or name).strip(),
        "name": name,
        "muscle_group": muscle,
        "equipment": equipment,
        "category": category,
        "tracking_type": tracking_type,
        "exercise_mode": exercise_mode,
        "is_bodyweight": 1 if (equipment or "").lower() in {"body only", "bodyweight"} else 0,
    }
    return normalized


def main() -> None:
    with urllib.request.urlopen(SOURCE_URL, timeout=60) as response:
        raw = response.read()

    actual_sha = git_blob_sha1(raw)
    if actual_sha != SOURCE_BLOB_SHA1:
        raise RuntimeError(
            f"Pinned exercise dataset checksum mismatch: {actual_sha} != {SOURCE_BLOB_SHA1}"
        )

    source = json.loads(raw.decode("utf-8"))
    exercises = []
    for item in source:
        if isinstance(item, dict):
            normalized = normalize(item)
            if normalized:
                exercises.append(normalized)

    exercises.sort(key=lambda item: item["name"].casefold())
    payload = {
        "source": SOURCE_REPO,
        "source_commit": SOURCE_COMMIT,
        "license": "Unlicense / Public Domain",
        "contains_media": False,
        "contains_instructions": False,
        "exercises": exercises,
    }

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(
        json.dumps(payload, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    print(f"Wrote {len(exercises)} public exercise metadata rows to {OUTPUT}")


if __name__ == "__main__":
    main()
