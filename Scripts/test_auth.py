#!/usr/bin/env python3
"""Run auth ViewModel tests without changing the shared CareCall package.

Usage: python3 Scripts/test_auth.py [--filter TestName]
Add --auth-sdk-path /path/to/supabase-swift to run SDK error mapping tests.
The temporary package compiles byte-identical app sources. No server requests.
"""
import argparse
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser(add_help=False)
parser.add_argument("--auth-sdk-path", type=pathlib.Path)
options, swift_args = parser.parse_known_args()
sdk_dependency = ""
auth_product = ""
if options.auth_sdk_path:
    sdk = options.auth_sdk_path.resolve(strict=True)
    if not (sdk / "Sources/Auth/AuthError.swift").is_file():
        parser.error("--auth-sdk-path must point to a supabase-swift checkout")
    sdk_dependency = f'.package(path: {json.dumps(str(sdk), ensure_ascii=False)})'
    auth_product = ', .product(name: "Auth", package: ' + json.dumps(sdk.name, ensure_ascii=False) + ')'
repo = pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="todoc-auth-tests-") as directory:
    package = pathlib.Path(directory)

    def copy(source, destination):
        source, destination = repo / source, package / destination
        destination.parent.mkdir(parents=True, exist_ok=True)
        if source.is_dir():
            shutil.copytree(source, destination)
        else:
            shutil.copy2(source, destination)

    copy("ToDoc/Core/Errors", "Sources/ToDocCoreErrors")
    copy("ToDoc/Domain", "Sources/ToDocDomain")
    for area in ["Auth/Presentation", "Auth/ViewModels", "Onboarding/ViewModels"]:
        copy("ToDoc/Features/" + area, "Sources/ToDocAuth/" + area)
    for name in ["Auth", "User", "Patient", "Doctor", "Hospital"]:
        filename = name + "Repository.swift"
        copy("ToDoc/Data/Repositories/Protocols/" + filename,
             "Sources/ToDocAuth/Repositories/" + filename)
    copy("Tests/AuthViewModelTests", "Tests/AuthViewModelTests")
    (package / "Package.swift").write_text('''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "ToDocAuthTests", platforms: [.macOS(.v14)], dependencies: [SDK_DEPENDENCY], targets: [
    .target(name: "ToDocCoreErrors"),
    .target(name: "ToDocDomain", dependencies: ["ToDocCoreErrors"]),
    .target(name: "ToDocAuth", dependencies: ["ToDocDomain"AUTH_PRODUCT]),
    .testTarget(name: "AuthViewModelTests", dependencies: ["ToDocAuth", "ToDocDomain"AUTH_PRODUCT])
], swiftLanguageModes: [.v5])
'''.replace('SDK_DEPENDENCY', sdk_dependency).replace('AUTH_PRODUCT', auth_product))
    result = subprocess.run(["swift", "test", "--package-path", str(package), *swift_args])
    sys.exit(result.returncode)
