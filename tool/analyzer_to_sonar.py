"""Đổi đầu ra `flutter analyze` sang định dạng issue chung của SonarQube.

Dòng vào có dạng:
    info • Message • lib/a.dart:12:5 • rule_name

Ra định dạng mới (có khối "rules"), để Sonar không cảnh báo định dạng cũ
sắp bị bỏ:
https://docs.sonarsource.com/sonarqube-community-build/analyzing-source-code/importing-external-issues/generic-issue-import-format/
"""
import json
import re
import sys

# mức của analyzer → (thuộc tính clean code, chất lượng phần mềm, mức ảnh hưởng)
MUC = {
    "error": ("LOGICAL", "RELIABILITY", "HIGH"),
    "warning": ("LOGICAL", "MAINTAINABILITY", "MEDIUM"),
    "info": ("CONVENTIONAL", "MAINTAINABILITY", "LOW"),
}
DONG = re.compile(
    r"^\s*(error|warning|info)\s+•\s+(.+?)\s+•\s+(.+?):(\d+):(\d+)\s+•\s+(\S+)\s*$"
)

rules = {}
issues = []
for line in sys.stdin:
    m = DONG.match(line)
    if not m:
        continue
    muc, msg, path, row, _col, rule = m.groups()
    thuoc_tinh, chat_luong, anh_huong = MUC[muc]
    rules.setdefault(rule, {
        "id": rule,
        "name": rule,
        "engineId": "dart-analyzer",
        "cleanCodeAttribute": thuoc_tinh,
        "impacts": [{"softwareQuality": chat_luong, "severity": anh_huong}],
    })
    issues.append({
        "ruleId": rule,
        "effortMinutes": 5,
        "primaryLocation": {
            "message": msg,
            "filePath": path,
            "textRange": {"startLine": int(row)},
        },
    })

json.dump({"rules": list(rules.values()), "issues": issues}, sys.stdout,
          ensure_ascii=False, indent=1)
