#!/usr/bin/env bash
# Sinh test/coverage_helper_test.dart: import mọi tệp trong lib/ để coverage
# tính cả những tệp chưa test nào chạm tới. Tệp sinh ra nằm trong .gitignore.
set -euo pipefail
cd "$(dirname "$0")/.."
{
  echo "// Tệp sinh tự động bởi tool/coverage_helper.sh — đừng sửa tay."
  echo "// ignore_for_file: unused_import, directives_ordering"
  find lib -name '*.dart' ! -name '*.g.dart' | LC_ALL=C sort \
    | sed "s#^lib/#import 'package:astrotarot_mobile/#; s#\$#';#"
  echo "void main() {}"
} > test/coverage_helper_test.dart
