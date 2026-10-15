"""Gỡ `const` ở những biểu thức vừa bị chèn Ngu.d(...) vào.

    python tool/go_const.py            # chạy analyze rồi tự sửa, lặp tới khi sạch

Bọc chuỗi bằng Ngu.d() làm hỏng mọi `const` bao quanh: Dart không cho gọi hàm
trong biểu thức hằng. Analyzer chỉ đúng vị trí, nhưng cái `const` cần gỡ
thường nằm ở dòng khác — ví dụ `const Column(children: [...])` cách đó mười
dòng.

Không dùng cách "lùi lại tìm chữ const gần nhất": chữ gần nhất hay là của một
widget ANH EM (`const SizedBox(width: 8), Text(Ngu.d(...))`), gỡ nó thì lỗi
còn nguyên mà vòng lặp không bao giờ dừng. Thay vào đó lần ngược theo dấu
ngoặc chưa đóng để tìm đúng biểu thức BAO NGOÀI, rồi mới xét `const`.
"""

import io
import re
import subprocess
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

FLUTTER = r"C:\src\flutter\bin\flutter.bat"
# Dòng analyzer có dạng:
#   error - Methods can't be ... - lib\features\x.dart:29:6 - const_eval_method_invocation
# Bắt đúng phần đường dẫn sau dấu gạch CUỐI, không thì nuốt luôn câu mô tả.
LOI = re.compile(r"([^\s-]+\.dart):(\d+):(\d+)\s+-\s+const_eval_method_invocation")


def vi_tri(ma, dong, cot):
    """Đổi dòng:cột (đếm từ 1) sang offset."""
    cac_dong = ma.split("\n")
    return sum(len(d) + 1 for d in cac_dong[: dong - 1]) + (cot - 1)


def mo_bao_ngoai(ma, off):
    """Lần ngược từ `off`, trả về vị trí các dấu mở chưa đóng, trong ra ngoài."""
    ra = []
    do_sau = 0
    for i in range(off - 1, -1, -1):
        c = ma[i]
        if c in ")]}":
            do_sau += 1
        elif c in "([{":
            if do_sau == 0:
                ra.append(i)
            else:
                do_sau -= 1
    return ra


def go_const_bao_ngoai(ma, off):
    """Gỡ `const` của biểu thức bao ngoài gần nhất có `const`.

    Trả về mã mới, hoặc None nếu không tìm thấy gì để gỡ.
    """
    for j in mo_bao_ngoai(ma, off):
        # Trước dấu mở thường là tên lớp/hàm; `const` đứng trước cái tên ấy.
        # `const [` và `const {` thì không có tên nào ở giữa.
        ten = re.search(r"([A-Za-z_][\w.]*(?:<[^<>]*>)?)\s*$", ma[:j])
        truoc_ten = ten.start(1) if ten else j
        m = re.search(r"\bconst\s+$", ma[:truoc_ten])
        if m:
            return ma[: m.start()] + ma[truoc_ten:]
    return None


def go_boc(ma, off):
    """Gỡ `Ngu.d(...)` quanh vị trí `off`, trả chuỗi về nguyên trạng.

    Dùng cho bảng `static const ... = {...}`: ở đó không có `const` nào gỡ
    được mà vẫn giữ nghĩa, và quan trọng hơn — dịch ngay trong bảng là SAI.
    Bảng khởi tạo một lần lúc nạp lớp nên chữ sẽ đóng băng theo ngôn ngữ đang
    chọn lúc ấy, bấm đổi sang tiếng Anh không ăn thua. Những bảng này phải
    giữ tiếng Việt và dịch ở chỗ hiển thị.
    """
    bd = ma.rfind("Ngu.d(", 0, off + 1)
    if bd < 0:
        return None
    sau, i = 0, bd + len("Ngu.d(") - 1
    while i < len(ma):
        if ma[i] == "(":
            sau += 1
        elif ma[i] == ")":
            sau -= 1
            if sau == 0:
                break
        i += 1
    if i >= len(ma):
        return None
    ben_trong = ma[bd + len("Ngu.d(") : i]
    return ma[:bd] + ben_trong + ma[i + 1 :]


def mot_vong(duong_dan_loc):
    r = subprocess.run(
        [FLUTTER, "analyze", "--no-fatal-infos"] + duong_dan_loc,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    loi = {}
    for m in LOI.finditer(r.stdout or ""):
        tep, dong, cot = m.group(1), int(m.group(2)), int(m.group(3))
        loi.setdefault(tep, []).append((dong, cot))
    if not loi:
        return 0

    sua = 0
    for tep, cho in loi.items():
        ma = io.open(tep, encoding="utf-8").read()
        # Sửa từ dưới lên để offset phía trên không lệch.
        for dong, cot in sorted(cho, reverse=True):
            off = vi_tri(ma, dong, cot)
            moi = go_const_bao_ngoai(ma, off) or go_boc(ma, off)
            if moi:
                ma = moi
                sua += 1
        io.open(tep, "w", encoding="utf-8").write(ma)
    return sua


if __name__ == "__main__":
    muc = [a for a in sys.argv[1:] if not a.startswith("--")] or ["lib"]
    for vong in range(12):
        n = mot_vong(muc)
        print("vòng %d: gỡ %d chỗ" % (vong + 1, n))
        if n == 0:
            break
