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
    [switch]$MoiMay
)

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
