#!/usr/bin/env python3
"""Static guard for the offline booth target; not a packet-capture test."""
from pathlib import Path
import plistlib
import re
import sys

root = Path(__file__).resolve().parents[1]
failures = []

def require(ok, message):
    if not ok:
        failures.append(message)

project = (root / 'ToDoc.xcodeproj/project.pbxproj').read_text()
for marker in ('XCRemoteSwiftPackageReference', 'Supabase;', 'KakaoSDK', 'AmplitudeSwift'):
    require(marker not in project, f'External build dependency remains: {marker}')

require(not re.search(r'baseConfigurationReference[^;]*Secrets', project), 'Secret build configuration remains')

for path in (root / 'ToDoc').rglob('*.swift'):
    source = path.read_text()
    for marker in ('URLSession', 'URLRequest', 'SupabaseClient', 'downloadAndInstall', 'registerForRemoteNotifications', 'SFSafariViewController'):
        require(marker not in source, f'{path.relative_to(root)}: {marker}')

container = (root / 'ToDoc/Core/Dependency/DependencyContainer.swift').read_text()
for marker in ('LocalPainRepository', 'LocalSymptomRepository', 'LocalPrevisitRepository', 'LocalAuthRepository', 'OfflineCareCallAnalyzer'):
    require(marker in container, f'Offline dependency missing: {marker}')
require('Supabase' not in container, 'Remote repository remains in dependency container')

for path in (root / 'ToDoc').rglob('*.plist'):
    with path.open('rb') as stream:
        settings = plistlib.load(stream)
    require('remote-notification' not in settings.get('UIBackgroundModes', []), f'{path.name}: remote background mode')
    require(not any(re.search(r'SUPABASE|KAKAO|AMPLITUDE', key, re.I) for key in settings), f'{path.name}: remote SDK key')

with (root / 'ToDoc/ToDoc.entitlements').open('rb') as stream:
    entitlements = plistlib.load(stream)
for key in ('aps-environment', 'com.apple.developer.applesignin', 'com.apple.developer.icloud-container-identifiers'):
    require(key not in entitlements, f'Network entitlement remains: {key}')

if failures:
    print('\n'.join(f'FAIL: {message}' for message in failures))
    sys.exit(1)
print('PASS: no external SDK packages, direct HTTP/asset downloads, remote push entitlements; offline repositories and analyzer are wired.')
