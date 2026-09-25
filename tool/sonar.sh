#!/usr/bin/env bash
# Chạy toàn bộ chuỗi đo chất lượng rồi đẩy lên SonarQube.
#
#   SONAR_HOST_URL=http://localhost:9000 SONAR_TOKEN=... tool/sonar.sh
#
# Các bước:
#   1. Sinh test/coverage_helper_test.dart để coverage đếm cả tệp chưa có test
#      (không có bước này, `flutter test --coverage` chỉ đo tệp được test
#      import — số ra đẹp một cách giả tạo).
#   2. flutter test --coverage --machine → coverage/lcov.info + báo cáo test.
#   3. flutter analyze → đổi sang định dạng issue chung của Sonar.
#   4. sonar-scanner.
set -euo pipefail
cd "$(dirname "$0")/.."

tool/coverage_helper.sh
mkdir -p build/sonar
: > build/sonar/analyzer-empty.txt

flutter test --coverage --machine > build/sonar/tests.output

# `flutter analyze --no-fatal-infos` in dạng:  severity • message • file:line:col • rule
flutter analyze --no-fatal-infos --no-fatal-warnings 2>/dev/null \
  | python3 tool/analyzer_to_sonar.py > build/sonar/analyzer-issues.json || true

sonar-scanner \
  ${SONAR_HOST_URL:+-Dsonar.host.url=$SONAR_HOST_URL} \
  ${SONAR_TOKEN:+-Dsonar.token=$SONAR_TOKEN}
