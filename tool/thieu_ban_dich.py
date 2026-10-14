"""Liệt kê những chuỗi tiếng Việt CHƯA dịch sang tiếng Anh.

    python tool/thieu_ban_dich.py          # tóm tắt + 40 chuỗi gặp nhiều nhất
    python tool/thieu_ban_dich.py --het    # in hết
    python tool/thieu_ban_dich.py --tep    # gom theo tệp, để biết dịch tệp nào trước

Vì sao cần: từ điển tra theo chính câu tiếng Việt nên chuỗi thiếu KHÔNG gây
lỗi gì — nó lặng lẽ hiện tiếng Việt giữa màn tiếng Anh. Tiện lúc dịch dần,
nhưng có nghĩa là mắt thường không soát nổi. Script này là cách duy nhất biết
còn thiếu bao nhiêu.
"""

import io
import os
import re
import sys

GOC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(GOC, "lib")
TU_DIEN = os.path.join(LIB, "core", "tu_dien_en.dart")

DAU = "àáâãèéêìíòóôõùúýăđĩũơưạảấầẩậắằẵặẹẻẽếềểệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹ"
CO_DAU = re.compile("[" + DAU + DAU.upper() + "]")

BO_QUA = ("tu_dien_en.dart",)


def bo_binh_luan(ma):
    """Mã nguồn này bình luận bằng tiếng Việt rất nhiều.

    Không bỏ thì script báo hàng nghìn "chuỗi thiếu" toàn là câu giải thích,
    lẫn mất chuỗi thật.
    """
    ma = re.sub(r"/\*[\s\S]*?\*/", "", ma)
    return re.sub(r"(^|[^:])//.*$", r"\1", ma, flags=re.M)


def doc_khoa_tu_dien():
    tho = io.open(TU_DIEN, encoding="utf-8").read()
    return set(
        m.group(1).replace("\\'", "'")
        for m in re.finditer(r"^\s*'((?:[^'\\]|\\.)*)'\s*:", tho, re.M)
    )


def main():
    da_dich = doc_khoa_tu_dien()
    dem = {}
    tong_boc = 0

    for thu_muc, _, ten_tep in os.walk(LIB):
        for ten in ten_tep:
            if not ten.endswith(".dart") or ten in BO_QUA:
                continue
            d = os.path.join(thu_muc, ten)
            ma = bo_binh_luan(io.open(d, encoding="utf-8").read())
            nhan = os.path.relpath(d, GOC).replace("\\", "/")

            for m in re.finditer(r"Ngu\.d\(\s*'((?:[^'\\]|\\.)*)'\s*\)", ma):
                cau = m.group(1).replace("\\'", "'")
                nonlocal_tong(cau, nhan, da_dich, dem)

            for m in re.finditer(r"'((?:[^'\\\n]|\\.){2,120})'", ma):
                cau = m.group(1)
                if not CO_DAU.search(cau):
                    continue
                if "Ngu.d('" + cau + "')" in ma:
                    continue
                ghi(dem, cau, nhan, chua_boc=True)

            tong_boc += len(re.findall(r"Ngu\.d\(", ma))

    tat_ca = sorted(dem.items(), key=lambda kv: -kv[1]["so_lan"])
    chua_boc = [x for x in tat_ca if x[1]["chua_boc"]]
    thieu_dich = [x for x in tat_ca if not x[1]["chua_boc"]]

    out = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    print("Đã bọc Ngu.d(): %d lượt" % tong_boc, file=out)
    print("Đã có bản dịch: %d câu" % len(da_dich), file=out)
    print("Bọc rồi nhưng CHƯA dịch: %d câu" % len(thieu_dich), file=out)
    print("Chuỗi tiếng Việt CHƯA bọc: %d câu\n" % len(chua_boc), file=out)

    if "--tep" in sys.argv:
        theo_tep = {}
        for _, v in chua_boc:
            for f in v["tep"]:
                theo_tep[f] = theo_tep.get(f, 0) + 1
        for f, n in sorted(theo_tep.items(), key=lambda kv: -kv[1]):
            print("%4d %s" % (n, f), file=out)
    else:
        het = "--het" in sys.argv
        for ds, nhan in ((thieu_dich, "Bọc rồi nhưng thiếu bản dịch"), (chua_boc, "Chưa bọc")):
            if not ds:
                continue
            print("--- %s ---" % nhan, file=out)
            for cau, v in (ds if het else ds[:40]):
                print("%3d %r" % (v["so_lan"], cau), file=out)
            if not het and len(ds) > 40:
                print("    … còn %d câu" % (len(ds) - 40), file=out)
            print(file=out)
    out.flush()


def ghi(dem, cau, tep, chua_boc=False):
    cu = dem.setdefault(cau, {"so_lan": 0, "tep": set(), "chua_boc": False})
    cu["so_lan"] += 1
    cu["tep"].add(tep)
    cu["chua_boc"] = cu["chua_boc"] or chua_boc


def nonlocal_tong(cau, nhan, da_dich, dem):
    if cau in da_dich:
        return
    ghi(dem, cau, nhan)


if __name__ == "__main__":
    main()
