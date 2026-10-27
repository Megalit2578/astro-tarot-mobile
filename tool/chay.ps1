# Chạy app bằng một lệnh.
#
#   .\tool\chay.ps1          -> trỏ về backend chạy ở máy
#   .\tool\chay.ps1 -That    -> trỏ về production
#
# ---------------------------------------------------------------------------
# Vì sao có file này
# ---------------------------------------------------------------------------
#
# `flutter run` trần sẽ báo "No supported devices connected" khi chưa có máy
# ảo nào bật, rồi liệt kê Chrome, Edge và Windows như thể đó là lựa chọn —
# nhưng dự án chỉ có thư mục android và ios nên không dựng được cho chúng.
# Thông báo ấy dễ làm người ta đi chạy `flutter create .` để "thêm hỗ trợ",
# và thế là sinh ra web/ với windows/ cho một dự án cố ý chỉ làm di động.
#
# Thêm nữa, trỏ về backend ở máy thì phải nhớ hai biến, và nhớ rằng cả hai
# đều là 10.0.2.2 chứ không phải localhost — trong máy ảo Android, localhost
# là chính máy ảo đó.
#
# Script này gộp cả ba việc: bật máy ảo nếu chưa có, chờ nó khởi động xong,
# rồi chạy với đúng bộ biến.

param(
    # Trỏ về production thay vì backend ở máy.
    [switch]$That,

    # Dùng máy ảo khác thay vì cái đầu tiên tìm thấy.
    [string]$MayAo = "",

    # Cài lên MỌI máy ảo đang bật, để đăng nhập mỗi máy một vai trò.
    #
    # Token nằm trong Keystore của Android, khoá theo package name, nên một
    # bản cài chỉ giữ được một phiên — đăng nhập vai trò khác là đè mất phiên
    # cũ. Muốn thấy khách đặt lịch rồi Reader nhận ở màn bên cạnh thì phải có
    # hai bản cài, tức hai máy.
    #
    # Dựng MỘT lần rồi cài bản apk ấy lên từng máy, thay vì `flutter run` ba
    # lần — mỗi lần chạy là một lượt dựng lại từ đầu, và mỗi lượt giữ một cửa
    # sổ terminal.
    [switch]$MoiMay,

    # Bật và chạy cùng lúc 4 máy ảo cho 4 vai trò: User, Staff, Manager, Admin.
    # Script tự bật đủ 4 máy ảo nếu chưa có, chờ khởi động, cài app, và tự động
    # đăng nhập đúng vai trò và mở đúng khu vực làm việc của vai trò đó.
    [switch]$BonRole,

    # Chỉ xếp lại 4 cửa sổ máy ảo thành một hàng, không dựng lại apk.
    [switch]$Xem
)

# ---------------------------------------------------------------------------
# Vi sao luon truyen -gpu host khi bat may ao
# ---------------------------------------------------------------------------
# Bon AVD cua may nay tung co hw.gpu.enabled=no trong config.ini. Voi cau hinh
# ay, emulator VAN chay va adb VAN thay thiet bi — nhung no khong dung duoc
# cua so nao. Hau qua: `flutter run` bao thanh cong, app da cai va dang chay,
# ma khong co man hinh nao hien len. Khong co dong loi nao noi ra dieu do.
#
# Co dinh -gpu o day de script khong phu thuoc vao config.ini: nguoi khac
# clone ve, hoac AVD duoc tao lai, thi van co cua so.
$CoGpu = @('-gpu', 'host')

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

# ---------------------------------------------------------------------------
# Tìm adb
# ---------------------------------------------------------------------------
# Không dựa vào PATH: trên máy này adb không nằm trong PATH, và một script
# chết vì "không tìm thấy adb" thì chẳng nói được gì về chỗ cần sửa.
$adb = $null
foreach ($d in @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, "$env:LOCALAPPDATA\Android\Sdk", "$env:USERPROFILE\Android\Sdk")) {
    if ($d -and (Test-Path "$d\platform-tools\adb.exe")) { $adb = "$d\platform-tools\adb.exe"; break }
}
if (-not $adb) { $adb = (Get-Command adb -ErrorAction SilentlyContinue).Source }
if (-not $adb) {
    Write-Host "Khong tim thay adb. Cai Android SDK Platform-Tools, hoac dat ANDROID_HOME." -ForegroundColor Red
    exit 1
}

function CoMay {
    # Dòng đầu là tiêu đề "List of devices attached", bỏ. Chỉ tính dòng có
    # trạng thái "device" — "offline" hay "unauthorized" thì flutter cũng
    # không dùng được.
    $out = & $adb devices 2>$null | Select-Object -Skip 1
    return [bool]($out | Where-Object { $_ -match '\sdevice\s*$' })
}

# ---------------------------------------------------------------------------
# Xep cua so may ao thanh mot hang
# ---------------------------------------------------------------------------
# Vi sao can: bon may ao deu mo cua so o CUNG mot toa do mac dinh, nen chung
# chong len nhau va chi thay duoc cai tren cung. Day cung la ly do script
# truoc phai muon scrcpy — nhung scrcpy chi de xem, con cua so that thi bam
# duoc, keo tha duoc, va khong ton them mot tien trinh nao.
Add-Type -Name XepCuaSo -Namespace Win32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc f, IntPtr l);
public delegate bool EnumWindowsProc(IntPtr h, IntPtr l);
[DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int ht, bool rp);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
'@ -ErrorAction SilentlyContinue

function XepCuaSoMayAo($thuTuAvd) {
    Add-Type -AssemblyName System.Windows.Forms
    $man = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea

    $thay = @{}
    $cb = [Win32.XepCuaSo+EnumWindowsProc]{
        param($h, $l)
        if ([Win32.XepCuaSo]::IsWindowVisible($h)) {
            $sb = New-Object System.Text.StringBuilder 512
            [void][Win32.XepCuaSo]::GetWindowText($h, $sb, 512)
            if ($sb.ToString() -match '^Android Emulator - (\S+?):') { $thay[$Matches[1]] = $h }
        }
        return $true
    }
    [void][Win32.XepCuaSo]::EnumWindows($cb, [IntPtr]::Zero)

    if ($thay.Count -eq 0) {
        Write-Host "Khong thay cua so may ao nao de xep." -ForegroundColor Yellow
        Write-Host "Thuong la do AVD dat hw.gpu.enabled=no — xem ghi chu o dau file." -ForegroundColor Yellow
        return
    }

    $rong = [int]($man.Width / [Math]::Max(1, $thuTuAvd.Count))
    $x = $man.X
    foreach ($a in $thuTuAvd) {
        $h = $thay[$a]
        if ($h) {
            [void][Win32.XepCuaSo]::ShowWindow($h, 9)   # SW_RESTORE: cua so co the dang thu nho
            [void][Win32.XepCuaSo]::MoveWindow($h, $x, $man.Y, ($rong - 1), $man.Height, $true)
        }
        $x += $rong
    }
    Write-Host "Da xep $($thay.Count) cua so may ao thanh mot hang." -ForegroundColor Green
}

function LayTenAvd($ser) {
    $raw = & $adb -s $ser emu avd name 2>$null
    if (-not $raw) { return "" }
    $firstLine = ($raw -split '\r?\n')[0].Trim()
    if ($firstLine -match '^([a-zA-Z0-9_]+)') {
        return $Matches[1]
    }
    return ""
}

# ---------------------------------------------------------------------------
# Chi xep lai 4 cua so may ao
# ---------------------------------------------------------------------------
if ($Xem) {
    Write-Host "=== XEP 4 CUA SO MAY AO THANH MOT HANG ===" -ForegroundColor Cyan
    $dangChay = & $adb devices 2>$null | Select-Object -Skip 1 | Where-Object { $_ -match '\sdevice\s*$' } | ForEach-Object { ($_ -split '\s+')[0] }
    $avdChay = @{}
    foreach ($d in $dangChay) {
        $tenAvd = LayTenAvd $d
        if ($tenAvd) { $avdChay[$tenAvd] = $d }
    }
    XepCuaSoMayAo @('quantri', 'reader', 'chay', 'Pixel_API_36')
    exit 0
}

# ---------------------------------------------------------------------------
# Bốn vai trò: User, Staff, Manager, Admin chạy cùng lúc
# ---------------------------------------------------------------------------
if ($BonRole) {
    Write-Host "=== CHAY 4 MAY AO CHO 4 VAI TRO (USER, STAFF, MANAGER, ADMIN) ===" -ForegroundColor Cyan

    $roles = @(
        [PSCustomObject]@{ Role = "ADMIN";   Avd = "quantri";      Email = "megalit2578@gmail.com";     MatKhau = "12345678"; KhuVuc = "Khu quan tri" },
        [PSCustomObject]@{ Role = "STAFF";   Avd = "reader";       Email = "tranduydatqtdl@gmail.com";  MatKhau = "12345678"; KhuVuc = "Ban lam viec" },
        [PSCustomObject]@{ Role = "MANAGER"; Avd = "chay";         Email = "tranduydatquahay@gmail.com"; MatKhau = "12345678"; KhuVuc = "Khu quan ly" },
        [PSCustomObject]@{ Role = "USER";    Avd = "Pixel_API_36"; Email = "alloffdenchi13@gmail.com";  MatKhau = "12345678"; KhuVuc = "Trang chu (Tarot AI)" }
    )

    # Tim emulator.exe
    $emu = $null
    foreach ($d in @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, "$env:LOCALAPPDATA\Android\Sdk", "$env:USERPROFILE\Android\Sdk")) {
        if ($d -and (Test-Path "$d\emulator\emulator.exe")) { $emu = "$d\emulator\emulator.exe"; break }
    }
    if (-not $emu) { $emu = (Get-Command emulator -ErrorAction SilentlyContinue).Source }

    # Kiem tra cac may dang chay va avd name
    $dangChay = & $adb devices 2>$null | Select-Object -Skip 1 | Where-Object { $_ -match '\sdevice\s*$' } | ForEach-Object { ($_ -split '\s+')[0] }
    $avdChay = @{}
    foreach ($d in $dangChay) {
        $tenAvd = LayTenAvd $d
        if ($tenAvd) { $avdChay[$tenAvd] = $d }
    }

    # Bat cac may ao con thieu
    foreach ($r in $roles) {
        if (-not $avdChay.ContainsKey($r.Avd)) {
            Write-Host "Bat may ao $($r.Avd) ($($r.Role))..." -ForegroundColor Cyan
            if ($emu) {
                Start-Process -FilePath $emu -ArgumentList (@("-avd", $r.Avd) + $CoGpu)
            } else {
                flutter emulators --launch $r.Avd | Out-Null
            }
            Start-Sleep -Seconds 4
        }
    }

    # Cho tat ca 4 may boot completed
    Write-Host "Cho tat ca 4 may ao khoi dong xong..." -ForegroundColor Cyan
    $han = (Get-Date).AddMinutes(3)
    while ((Get-Date) -lt $han) {
        $dangChay = & $adb devices 2>$null | Select-Object -Skip 1 | Where-Object { $_ -match '\sdevice\s*$' } | ForEach-Object { ($_ -split '\s+')[0] }
        $avdChay = @{}
        foreach ($d in $dangChay) {
            $boot = (& $adb -s $d shell getprop sys.boot_completed 2>$null) -replace '\s', ''
            if ($boot -eq '1') {
                $tenAvd = LayTenAvd $d
                if ($tenAvd) { $avdChay[$tenAvd] = $d }
            }
        }
        $du4 = $true
        foreach ($r in $roles) {
            if (-not $avdChay.ContainsKey($r.Avd)) { $du4 = $false; break }
        }
        if ($du4) { break }
        Start-Sleep -Seconds 3
    }

    # Dung APK mot lan
    $dinhNghia = if ($That) { @() } else { @('--dart-define-from-file=dart_defines/may.json') }
    $dich = if ($That) { 'production' } else { '10.0.2.2:8080' }
    Write-Host "Dung apk mot lan (tro ve $dich)..." -ForegroundColor Cyan
    flutter build apk --debug @dinhNghia
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $apk = 'build/app/outputs/flutter-apk/app-debug.apk'

    # Cai dat va dang nhap tung may
    foreach ($r in $roles) {
        $dev = $avdChay[$r.Avd]
        if (-not $dev) {
            Write-Host "Khong tim thay thiet bi cho $($r.Avd)" -ForegroundColor Yellow
            continue
        }
        Write-Host "Cai dat va dang nhap vai tro [$($r.Role)] len $dev ($($r.Avd))..." -ForegroundColor Cyan
        & $adb -s $dev install -r -d $apk | Select-Object -Last 1

        # Xoa phien cu: token nam trong Keystore, khoa theo ten goi, nen mot
        # ban cai chi giu duoc MOT phien. Khong xoa thi may nay van la vai tro
        # cua lan chay truoc.
        & $adb -s $dev shell pm clear com.astrotarot.astrotarot_mobile 2>$null | Out-Null

        # Mo app KEM bo dang nhap, de chinh app tu dang nhap.
        #
        # Ban truoc go ho bang `input tap` theo toa do co dinh (540 611, 540
        # 790...). Cach ay hong bat cu khi nao bo cuc xe dich, do phan giai
        # khac di, hay ban phim mo cham hon nua giay — va khi hong thi no go
        # email vao cho trong chu khong bao gi ca. Rieng Pixel_API_36 phai co
        # mot bo toa do rieng chi vi man hinh cao hon.
        #
        # Gio chuyen email/mat khau qua intent extras: app doc chung o
        # `lib/core/auth/tu_dong_dang_nhap.dart` va tu goi dangNhap(). Chi
        # chay o ban go loi — chan hai lop, mot o Dart (kDebugMode) va mot o
        # MainActivity.kt (BuildConfig.DEBUG).
        & $adb -s $dev shell am start `
            -n com.astrotarot.astrotarot_mobile/.MainActivity `
            -e email $r.Email -e matKhau $r.MatKhau 2>$null | Out-Null
    }

    Write-Host ""
    Write-Host "==========================================================================" -ForegroundColor Green
    Write-Host "DA KHOI CHAY VA DANG NHAP THANH CONG CA 4 VAI TRO TREN 4 MAY AO:" -ForegroundColor Green
    Write-Host "==========================================================================" -ForegroundColor Green
    $roles | ForEach-Object {
        $dev = $avdChay[$_.Avd]
        Write-Host "[$($_.Role)]" -ForegroundColor Yellow -NoNewline
        Write-Host " $($_.Avd) ($dev)" -ForegroundColor Cyan
        Write-Host "  - Email:    $($_.Email)"
        Write-Host "  - Mat khau: $($_.MatKhau)"
        Write-Host "  - Man hinh: $($_.KhuVuc)"
        Write-Host ""
    }

    # Xep cua so that cua may ao thanh mot hang. Khong goi scrcpy nua: cua so
    # that thi bam duoc, keo tha duoc, va khong ton them bon tien trinh.
    XepCuaSoMayAo ($roles | ForEach-Object { $_.Avd })
    exit 0
}

# ---------------------------------------------------------------------------
# Bật máy ảo nếu chưa có thiết bị nào
# ---------------------------------------------------------------------------
if (CoMay) {
    Write-Host "Da co thiet bi, khong can bat may ao." -ForegroundColor DarkGray
} else {
    if (-not $MayAo) {
        # Lấy id của máy ảo android đầu tiên trong danh sách.
        #
        # Dò theo chữ 'android' ở cuối dòng chứ KHÔNG theo dấu chấm tròn ngăn
        # cột. Bản đầu khớp theo ký tự ấy, mà powershell.exe 5.1 đọc file .ps1
        # không BOM theo bảng mã ANSI nên ký tự ngoài ASCII hỏng — script báo
        # "chưa có máy ảo" trong khi máy ảo vẫn nằm đó.
        #
        # Lỗi không lộ ra lần chạy đầu vì lúc ấy đã có sẵn thiết bị, nên cả
        # nhánh này chưa từng chạy.
        #
        # Dòng tiêu đề kết thúc bằng 'Platform' nên không dính.
        $dong = flutter emulators 2>$null |
                Where-Object { $_ -match 'android\s*$' } |
                Select-Object -First 1
        if ($dong) { $MayAo = ($dong -split '\s+')[0].Trim() }
    }
    if (-not $MayAo) {
        Write-Host "Chua co may ao nao. Tao mot cai:" -ForegroundColor Red
        Write-Host "  flutter emulators --create --name Pixel_API_36"
        exit 1
    }

    Write-Host "Bat may ao $MayAo ..." -ForegroundColor Cyan
    flutter emulators --launch $MayAo | Out-Null

    # Chờ tới khi Android báo đã khởi động xong. `adb wait-for-device` chỉ
    # chờ tới lúc adb nối được, mà lúc đó hệ điều hành còn đang lên — cài app
    # vào đúng quãng ấy thì hỏng giữa chừng. sys.boot_completed mới là mốc
    # thật.
    & $adb wait-for-device
    Write-Host "Cho Android khoi dong xong..." -ForegroundColor Cyan
    $han = (Get-Date).AddMinutes(3)
    while ((Get-Date) -lt $han) {
        $xong = (& $adb shell getprop sys.boot_completed 2>$null) -replace '\s', ''
        if ($xong -eq '1') { break }
        Start-Sleep -Seconds 2
    }
    if ((Get-Date) -ge $han) {
        Write-Host "May ao qua 3 phut van chua khoi dong xong. Thu chay lai." -ForegroundColor Red
        exit 1
    }
}

# ---------------------------------------------------------------------------
# Nhiều máy: dựng một lần, cài lên tất cả
# ---------------------------------------------------------------------------
if ($MoiMay) {
    # Chỉ lấy máy ở trạng thái 'device'. Máy vừa bật còn 'offline' — cài vào
    # đúng quãng ấy thì hỏng giữa chừng, và thông báo lỗi của adb không nói
    # ra là vì máy chưa boot xong.
    $may = & $adb devices 2>$null |
           Select-Object -Skip 1 |
           Where-Object { $_ -match '\sdevice\s*$' } |
           ForEach-Object { ($_ -split '\s+')[0] }

    if (-not $may) {
        Write-Host "Khong co may nao san sang. Bat may ao roi cho no boot xong da." -ForegroundColor Red
        exit 1
    }

    $dinhNghia = if ($That) { @() } else { @('--dart-define-from-file=dart_defines/may.json') }
    $dich = if ($That) { 'production' } else { '10.0.2.2:8080' }
    Write-Host "Dung apk mot lan (tro ve $dich)..." -ForegroundColor Cyan
    flutter build apk --debug @dinhNghia
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $apk = 'build/app/outputs/flutter-apk/app-debug.apk'
    foreach ($m in $may) {
        Write-Host "Cai len $m ..." -ForegroundColor Cyan
        & $adb -s $m install -r $apk | Select-Object -Last 1
        # Mở luôn, đỡ phải tự tìm icon trên từng máy.
        & $adb -s $m shell monkey -p com.astrotarot.astrotarot_mobile `
            -c android.intent.category.LAUNCHER 1 2>$null | Out-Null
    }

    Write-Host ""
    Write-Host "Xong $($may.Count) may. Moi may dang nhap mot vai tro khac nhau." -ForegroundColor Green
    Write-Host "Doi role trong DB xong phai DANG XUAT roi dang nhap lai: quyen nam trong token." -ForegroundColor Yellow
    exit 0
}

# ---------------------------------------------------------------------------
# Chạy
# ---------------------------------------------------------------------------
if ($That) {
    Write-Host "Chay voi backend THAT (production)." -ForegroundColor Yellow
    flutter run
} else {
    Write-Host "Chay voi backend o MAY (10.0.2.2:8080)." -ForegroundColor Green
    Write-Host "Nho bat backend va web truoc, xem deploy/CHAY-O-MAY.md ben repo backend." -ForegroundColor DarkGray
    flutter run --dart-define-from-file=dart_defines/may.json
}
