#!/bin/sh
# #39의 공통 테스트 패키지 병합 전에도 알림 계약을 독립 실행합니다.
set -eu
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/todoc-notification-tests.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
mkdir -p "$test_dir/Sources/ToDocDomain" "$test_dir/Tests"
cp -R "$repo_root/ToDoc/Domain/Notification/" "$test_dir/Sources/ToDocDomain/"
cp "$repo_root/Tests/DomainTests/NotificationTypeTests.swift" "$test_dir/Tests/"
cat > "$test_dir/Package.swift" <<'PACKAGE'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "NotificationContracts",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ToDocDomain"),
        .testTarget(name: "DomainTests", dependencies: ["ToDocDomain"], path: "Tests")
    ],
    swiftLanguageModes: [.v5]
)
PACKAGE
swift test --package-path "$test_dir"
