#!/usr/bin/env python3
"""Guard active patient views against reintroducing local palette/font renderers.

Run from any directory: python3 Scripts/check_design_system.py [--output report.json]
Home, Records and DeferredViews remain on hold. Geometry/artwork dimensions are not tokens.
"""
import argparse
import json
from pathlib import Path
import re
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
# These are native platform presentations, not custom-designed text.
native_fonts = {'ToDoc/Features/Settings/Views/NotificationSettingsView.swift': {'.font(.caption)'}}
rows, errors = [], []
for path in sorted((root / 'ToDoc/Features').rglob('*.swift')):
    if 'Views' not in path.parts:
        continue
    rel = str(path.relative_to(root))
    text = path.read_text()
    feature = path.relative_to(root).parts[2]
    # Home View/VM is explicitly reserved for a separate PR after #107 merges.
    deferred = feature in {'Home', 'Records'} or 'DeferredViews' in path.parts
    findings = []
    for line_no, line in enumerate(text.splitlines(), 1):
        code = line.split('//', 1)[0]
        if re.search(r'\bColor\s*\(', code):
            findings.append((line_no, 'raw-color', line.strip()))
        if re.search(r'\.font\(\.custom|UIFont\(|AppTypography\.Style\.\w+\.font\(', code):
            findings.append((line_no, 'local-font', line.strip()))
        if re.search(r'struct \w+TextStyle\s*:\s*ViewModifier', code):
            findings.append((line_no, 'local-font-renderer', line.strip()))
        # System font calls on SF Symbols remain intentional geometry; native Form is explicit.
        if re.search(r'\.font\(\.(?:body|headline|footnote|caption|title\d?)\)', code):
            if not any(allowed in code for allowed in native_fonts.get(rel, set())):
                findings.append((line_no, 'native-text-font', line.strip()))
    rows.append({'path': rel, 'feature': feature, 'status': 'deferred' if deferred else ('fail' if findings else 'pass'), 'findings': findings})
    if not deferred:
        errors.extend(f'{rel}:{line}: {kind}: {code}' for line, kind, code in findings)
report = {'active_files': sum(r['status'] != 'deferred' for r in rows), 'deferred_files': sum(r['status'] == 'deferred' for r in rows), 'violations': len(errors), 'views': rows,
          'exceptions': {'native_form': list(native_fonts), 'symbols': 'SF Symbol system font sizes are icon geometry', 'artwork': 'Illustration/body hit-region/gauge coordinates stay local', 'scope': 'This source guard complements rendered UI review; it does not prove visual identity.'}}
if args.output:
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2))
print(f"{'FAIL' if errors else 'PASS'}: {report['active_files']} active view files, {report['deferred_files']} deferred files, {len(errors)} violations")
for error in errors:
    print(error)
sys.exit(bool(errors))
