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
    [string]$MayAo = ""
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
        $dong = flutter emulators 2>$null | Where-Object { $_ -match '•\s*android\s*$' } | Select-Object -First 1
        if ($dong) { $MayAo = ($dong -split '•')[0].Trim() }
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
