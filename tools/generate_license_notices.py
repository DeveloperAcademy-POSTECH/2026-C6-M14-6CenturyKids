#!/usr/bin/env python3
"""Package.resolved에 고정된 SPM 패키지의 LICENSE·NOTICE 원문을 모아 앱 고지 파일 하나로 만든다.

패키지를 추가·업데이트하면 Xcode에서 패키지를 받은 뒤 다시 실행한다.
    python3 tools/generate_license_notices.py           # 고지 파일 다시 만들기
    python3 tools/generate_license_notices.py --check   # 고지 파일이 Package.resolved와 맞는지만 확인

패키지 원본은 Xcode DerivedData의 SourcePackages/checkouts에서 찾고, 각 원본이 Package.resolved의 리비전과 같은지 확인한다.
다른 위치를 쓰려면 --checkouts로 넘긴다.
"""
import argparse
import glob
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESOLVED = os.path.join(ROOT, "ToDoc.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved")
OUTPUT = os.path.join(ROOT, "ToDoc/Resources/Licenses/ThirdPartyNotices-Packages.txt")
LICENSE_FILE = re.compile(r"^(LICEN[CS]E|NOTICE|COPYING)", re.IGNORECASE)

# 고지하지 않는 패키지와 이유. 새 패키지는 기본으로 고지에 들어간다
EXCLUDED = {
    "swift-asn1": "iOS 앱에는 빌드되지 않는다 (swift-crypto가 Apple 플랫폼에서는 CryptoKit을 쓴다)",
}

# 패키지 맨 위 LICENSE 말고, 패키지 안에 함께 빌드되는 코드의 고지 (패키지 identity → [(이름, 경로)])
BUNDLED_INSIDE = {
    "supabase-swift": [
        ("SwiftPhoenixClient (supabase-swift Realtime)", "Sources/Realtime/Deprecated/Delegated.swift"),  # 라이선스는 파일 맨 위 주석
    ],
}


def read_notice(path):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    if path.endswith(".swift"):  # 맨 위 // 주석만
        lines = []
        for line in text.splitlines():
            if not line.startswith("//"):
                break
            lines.append(line.removeprefix("//").removeprefix(" "))
        text = "\n".join(lines)
    return text.strip()


def head_revision(path):
    try:
        return subprocess.run(["git", "-C", path, "rev-parse", "HEAD"], capture_output=True, text=True, check=True).stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None


def checkout_dirs(base):
    """identity(소문자) → 원본 폴더. 폴더 이름은 저장소 이름이라 대소문자가 identity와 다를 수 있다"""
    return {name.lower(): os.path.join(base, name) for name in os.listdir(base)}


def find_checkouts(pins, given):
    candidates = [given] if given else sorted(
        glob.glob(os.path.expanduser("~/Library/Developer/Xcode/DerivedData/ToDoc-*/SourcePackages/checkouts")),
        key=os.path.getmtime, reverse=True)
    for base in candidates:
        dirs = checkout_dirs(base)
        if all(head_revision(dirs.get(p["identity"], "")) == p["state"]["revision"] for p in pins):
            return dirs
    sys.exit("Package.resolved와 같은 리비전의 패키지 원본을 찾지 못했어요. Xcode에서 File > Packages > Resolve Package Versions 후 "
             "다시 실행하거나 --checkouts로 SourcePackages/checkouts 경로를 넘겨 주세요.")


def render(pins, dirs):
    sections = []  # (제목, 원문)
    components = []
    for pin in sorted(pins, key=lambda p: p["identity"]):
        identity, state = pin["identity"], pin["state"]
        if identity in EXCLUDED:
            continue
        version = state.get("version") or state["revision"][:7]
        components.append(f"- {identity} {version} — {pin['location'].removesuffix('.git')}")
        folder = dirs[identity]
        files = sorted(f for f in os.listdir(folder) if LICENSE_FILE.match(f) and os.path.isfile(os.path.join(folder, f)))
        if not files:
            sys.exit(f"{identity}: LICENSE 파일이 없어요. 고지 원문을 직접 확인해 주세요.")
        sections += [(f"{identity} {version} — {f}", read_notice(os.path.join(folder, f))) for f in files]
        for name, path in BUNDLED_INSIDE.get(identity, []):
            components.append(f"  - {name}")
            sections.append((f"{name} — {os.path.basename(path)}", read_notice(os.path.join(folder, path))))

    lines = [
        "Third-party notices: Swift packages",
        "이 파일은 tools/generate_license_notices.py로 만듭니다. 직접 고치지 마세요.",
        "Texts below are copied from each package's own LICENSE/NOTICE files at the versions pinned in Package.resolved.",
        "",
        "Components",
        "----------",
        *components,
    ]
    # 같은 원문(예: 저작권 줄까지 같은 Apache 2.0)은 한 번만 싣고 제목에 함께 쓰는 패키지를 모두 적는다
    merged = {}
    for title, text in sections:
        merged.setdefault(" ".join(text.split()), ([], text))[0].append(title)
    for titles, text in merged.values():
        lines += ["", "", "=" * 72, *titles, "=" * 72, "", text]
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkouts", help="SourcePackages/checkouts 경로 (기본: Xcode DerivedData에서 찾기)")
    parser.add_argument("--check", action="store_true", help="파일을 쓰지 않고 지금 파일과 같은지만 확인")
    args = parser.parse_args()

    with open(RESOLVED, encoding="utf-8") as f:
        pins = json.load(f)["pins"]
    text = render(pins, find_checkouts(pins, args.checkouts))

    if args.check:
        current = open(OUTPUT, encoding="utf-8").read() if os.path.exists(OUTPUT) else ""
        if current != text:
            sys.exit(f"{os.path.relpath(OUTPUT, ROOT)}가 Package.resolved와 달라요. 스크립트를 다시 실행해 주세요.")
        print("고지 파일이 최신이에요.")
        return
    with open(OUTPUT, "w", encoding="utf-8") as f:
        f.write(text)
    included = [p for p in pins if p["identity"] not in EXCLUDED]
    print(f"{os.path.relpath(OUTPUT, ROOT)}: 패키지 {len(included)}개 (제외: {', '.join(EXCLUDED)})")


if __name__ == "__main__":
    main()
