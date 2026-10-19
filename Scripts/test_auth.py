#!/usr/bin/env python3
"""Run auth ViewModel tests without changing the shared CareCall package.

Usage: python3 Scripts/test_auth.py [--filter TestName]
The temporary package compiles byte-identical app sources. No live SDK or server.
"""
import pathlib
import shutil
import subprocess
import sys
import tempfile

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
let package = Package(name: "ToDocAuthTests", platforms: [.macOS(.v14)], targets: [
    .target(name: "ToDocCoreErrors"),
    .target(name: "ToDocDomain", dependencies: ["ToDocCoreErrors"]),
    .target(name: "ToDocAuth", dependencies: ["ToDocDomain"]),
    .testTarget(name: "AuthViewModelTests", dependencies: ["ToDocAuth", "ToDocDomain"])
], swiftLanguageModes: [.v5])
''')
    result = subprocess.run(["swift", "test", "--package-path", str(package), *sys.argv[1:]])
    sys.exit(result.returncode)
