"""Tính coverage dòng lệnh từ coverage/lcov.info; dưới ngưỡng thì thoát mã 1.

    python3 tool/kiem_coverage.py 80

Cùng cách SonarQube tính cho Dart (plugin sonar-flutter đọc đúng tệp này),
nên CI xanh ở đây nghĩa là Sonar cũng qua ngưỡng.
"""
import sys

# Windows mac dinh dung cp1252 cho stdout, va dong ket qua co chu "dong" kem
# dau. Khong dat lai encoding thi script chet bang UnicodeEncodeError NGAY SAU
# khi da tinh xong — tuc la mat ket qua vi mot ly do chang lien quan gi toi
# coverage. Tren CI (Ubuntu, UTF-8) khong dinh, nen loi nay chi lo ra o may dev,
# va lo ra dung luc nguoi ta muon xem con so truoc khi day code.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

nguong = float(sys.argv[1]) if len(sys.argv) > 1 else 80.0
tong = trung = 0
for dong in open("coverage/lcov.info", encoding="utf-8"):
    if dong.startswith("DA:"):
        tong += 1
        if int(dong.split(",")[1]) > 0:
            trung += 1
ti_le = 100 * trung / tong if tong else 0
print(f"Coverage: {trung}/{tong} dòng = {ti_le:.1f}% (ngưỡng {nguong:.0f}%)")
sys.exit(0 if ti_le >= nguong else 1)
