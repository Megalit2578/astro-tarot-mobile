"""Bọc chuỗi tiếng Việt trong một tệp Dart bằng Ngu.d(...).

    python tool/boc_ban_dich.py lib/features/home/home_screen.dart
    python tool/boc_ban_dich.py --thu lib/...        # chỉ in ra, không ghi

Làm tay hơn một nghìn chuỗi thì không xong, nên bọc bằng máy rồi để
`flutter analyze` bắt lỗi. Script cố ý KHÔNG tự xoá `const`: chỗ nào hỏng thì
analyzer chỉ đúng dòng, sửa tay chắc hơn đoán.

Script bỏ qua:
  • chuỗi đã bọc rồi
  • chuỗi trong bình luận
  • chuỗi nội suy (có $) — bọc vào là tra từ điển bằng câu đã ghép, không khớp
  • chuỗi chỉ gồm ký hiệu hoặc quá ngắn
"""

import io
import re
import sys

# Console Windows mac dinh cp1252, in chu co dau la vo.
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

DAU = "àáâãèéêìíòóôõùúýăđĩũơưạảấầẩậắằẵặẹẻẽếềểệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹ"
CO_DAU = re.compile("[" + DAU + DAU.upper() + "]")

# Chuỗi đứng sau những chữ này là khoá máy, không phải chữ cho người đọc.
BO_QUA_TRUOC = re.compile(r"(key|name|id|path|route|url|package|import|export)\s*:\s*$", re.I)


def bo_binh_luan_giu_vi_tri(ma):
    """Thay bình luận bằng dấu cách, giữ nguyên độ dài để offset không lệch."""
    ra = list(ma)
    for m in re.finditer(r"/\*[\s\S]*?\*/", ma):
        for i in range(m.start(), m.end()):
            if ra[i] != "\n":
                ra[i] = " "
    for m in re.finditer(r"(?m)(^|[^:])//.*$", ma):
        for i in range(m.start(1) + len(m.group(1)), m.end()):
            if ra[i] != "\n":
                ra[i] = " "
    return "".join(ra)


def boc(duong_dan, chi_thu=False):
    goc = io.open(duong_dan, encoding="utf-8").read()
    sach = bo_binh_luan_giu_vi_tri(goc)

    # Quét chuỗi bằng máy trạng thái, KHÔNG bằng regex.
    #
    # Regex `'[^']*'` cắt nhầm ở ranh giới nội suy. Với
    #
    #     '${d.lyDo ?? 'Không có lý do.'} Bấm để sửa.'
    #
    # nó coi `'} Bấm để sửa.'` là một chuỗi riêng và chèn Ngu.d( vào giữa,
    # làm hỏng hẳn dòng mã. Phải nhảy qua cả cụm `${...}` — kể cả chuỗi lồng
    # bên trong nó — mới biết chuỗi ngoài kết thúc ở đâu.
    def quet(ma):
        ra, i, n = [], 0, len(ma)
        while i < n:
            if ma[i] != "'":
                i += 1
                continue
            bd = i
            i += 1
            noi_suy = False
            while i < n and ma[i] != "'":
                if ma[i] == "\\":
                    i += 2
                    continue
                if ma[i] == "$" and i + 1 < n and ma[i + 1] == "{":
                    noi_suy = True
                    sau = 0
                    i += 1
                    while i < n:
                        if ma[i] == "{":
                            sau += 1
                        elif ma[i] == "}":
                            sau -= 1
                            if sau == 0:
                                break
                        elif ma[i] == "'":
                            i += 1
                            while i < n and ma[i] != "'":
                                i += 2 if ma[i] == "\\" else 1
                        i += 1
                elif ma[i] == "$":
                    noi_suy = True
                i += 1
            if i >= n:
                break
            ra.append((bd, i + 1, ma[bd + 1 : i], noi_suy))
            i += 1
        return ra

    # Gộp các literal liền nhau TRƯỚC khi bọc.
    #
    # Dart nối tự động hai chuỗi chỉ cách nhau khoảng trắng:
    #
    #     'Có bản đồ sao thì lời giải bám vào '
    #     'chính bạn, thay vì trả lời chung chung.'
    #
    # Bọc riêng từng mảnh thì vừa sai nghĩa (tra từ điển bằng nửa câu) vừa
    # hỏng cú pháp — hai lời gọi Ngu.d() cạnh nhau không tự nối. Nên gom cả
    # cụm thành một chuỗi rồi mới bọc.
    tho = quet(sach)
    cum = []
    i = 0
    while i < len(tho):
        j = i
        while j + 1 < len(tho) and sach[tho[j][1] : tho[j + 1][0]].strip() == "":
            j += 1
        cum.append(
            (
                tho[i][0],
                tho[j][1],
                "".join(t[2] for t in tho[i : j + 1]),
                any(t[3] for t in tho[i : j + 1]),
            )
        )
        i = j + 1

    sua = []
    for bd, kt, cau, noi_suy in cum:
        if not CO_DAU.search(cau):
            continue
        # Chuỗi nội suy thì bỏ: khoá tra sẽ là câu đã ghép giá trị vào, không
        # bao giờ khớp từ điển. Những câu ấy phải tách tay.
        if len(cau) < 2 or noi_suy:
            continue
        truoc = sach[max(0, bd - 40) : bd]
        if truoc.rstrip().endswith("Ngu.d("):
            continue
        if BO_QUA_TRUOC.search(truoc):
            continue
        sua.append((bd, kt, cau))

    if not sua:
        print("khong co gi de boc")
        return 0

    ra = goc
    for bd, kt, cau in reversed(sua):
        # Viết lại cả cụm thành MỘT literal; giữ nguyên escape vốn có.
        ra = ra[:bd] + "Ngu.d('" + cau + "')" + ra[kt:]

    if chi_thu:
        for _, _, cau in sua:
            print(" ", cau)
    else:
        io.open(duong_dan, "w", encoding="utf-8").write(ra)
    return len(sua)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    thu = "--thu" in sys.argv
    tong = 0
    for d in args:
        n = boc(d, thu)
        tong += n
        print("%4d  %s" % (n, d))
    print("tong:", tong)
