// Dữ liệu mẫu đúng hình dạng JSON backend trả — lấy từ các DTO thật trong
// astro-tarot-web-be, không phải đoán.

final homNay = DateTime.now();

String iso(DateTime t) => t.toUtc().toIso8601String();

Map<String, dynamic> mauReader({
  String id = 'r1',
  String ten = 'Lan Hương',
  bool nhanLich = true,
  int soDanhGia = 12,
  int? gia15 = 100000,
  int? gia30 = 180000,
  int? gia60,
}) => {
  'id': id,
  'userId': 'u-$id',
  'username': 'lanhuong',
  'fullName': ten,
  'avatar': null,
  'bio': 'Đọc bài theo hướng chữa lành.',
  'specialties': ['Tarot', 'Chiêm tinh'],
  'yearsExperience': 5,
  'pricePer15m': gia15,
  'pricePer30m': gia30,
  'pricePer60m': gia60,
  'rating': 4.8,
  'totalReviews': soDanhGia,
  'isAvailable': nhanLich,
};

Map<String, dynamic> mauSlot(
  DateTime bd, {
  int phut = 30,
  String trang = 'FREE',
}) => {
  'startTime': iso(bd),
  'endTime': iso(bd.add(Duration(minutes: phut))),
  'price': 180000,
  'state': trang,
};

/// Lịch tháng: các ô truyền vào nằm ở hôm nay, ngày khác đóng.
Map<String, dynamic> mauLich({
  List<Map<String, dynamic>>? oHomNay,
  String kindHomNay = 'OPEN',
}) {
  final n = DateTime.now();
  final dau = DateTime(n.year, n.month, 1);
  final cuoi = DateTime(n.year, n.month + 1, 0);
  String khoa(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  final ngay = <Map<String, dynamic>>[];
  for (var d = dau; !d.isAfter(cuoi); d = d.add(const Duration(days: 1))) {
    final laHom = d.year == n.year && d.month == n.month && d.day == n.day;
    ngay.add({
      'date': khoa(d),
      'kind': laHom ? kindHomNay : 'CLOSED',
      'slots': laHom ? (oHomNay ?? []) : [],
    });
  }
  return {
    'year': n.year,
    'month': n.month,
    'durationMinutes': 30,
    'days': ngay,
  };
}

Map<String, dynamic> mauBooking({
  String id = 'b1',
  String trangThai = 'CONFIRMED',
  String traTien = 'UNPAID',
  bool daDanhGia = false,
  bool chatMo = true,
  DateTime? batDau,
  String? ghiChu,
}) {
  final bd = batDau ?? homNay.add(const Duration(days: 1));
  return {
    'id': id,
    'readerProfileId': 'r1',
    'readerUserId': 'u-r1',
    'readerName': 'Lan Hương',
    'readerAvatar': null,
    'customerId': 'u-USER',
    'customerName': 'Minh Anh',
    'customerAvatar': null,
    'startTime': iso(bd),
    'endTime': iso(bd.add(const Duration(minutes: 30))),
    'durationMinutes': 30,
    'totalAmount': 180000,
    'status': trangThai,
    'paymentStatus': traTien,
    'reviewed': daDanhGia,
    'chatOpen': chatMo,
    'cancelReason': null,
    'readerNote': ghiChu,
  };
}

Map<String, dynamic> mauSanPham({
  String id = 'p1',
  String slug = 'bo-bai-rider',
  String ten = 'Bộ bài Rider-Waite',
  bool coLink = true,
  bool dangBan = true,
}) => {
  'id': id,
  'name': ten,
  'slug': slug,
  'price': 250000,
  'compareAtPrice': 300000,
  'description': 'Bộ bài kinh điển cho người mới.',
  'imageUrl': '/products/rider.jpg',
  'imageIsIllustrative': true,
  'affiliateUrl': coLink ? 'https://shopee.vn/rider' : null,
  'affiliatePlatform': 'SHOPEE',
  'categoryName': 'Bộ bài',
  'categorySlug': 'bo-bai',
  'categoryId': 'c1',
  'clickCount': 42,
  'commissionPercent': 8.5,
  'featured': true,
  'active': dangBan,
};

Map<String, dynamic> mauTaiKhoan({
  String id = 't1',
  String vaiTro = 'USER',
  String trangThai = 'ACTIVE',
  bool suaDuoc = true,
  bool daXacMinh = true,
}) => {
  'id': id,
  'username': 'user$id',
  'email': '$id@mail.vn',
  'fullName': 'Người $id',
  'avatar': null,
  'role': vaiTro,
  'status': trangThai,
  'emailVerified': daXacMinh,
  'lastLoginAt': iso(homNay),
  'createdAt': iso(homNay.subtract(const Duration(days: 30))),
  'editable': suaDuoc,
};

Map<String, dynamic> mauChiTietTaiKhoan({
  String id = 't1',
  bool suaDuoc = true,
  bool daXacMinh = false,
  String trangThai = 'ACTIVE',
}) => {
  ...mauTaiKhoan(
    id: id,
    suaDuoc: suaDuoc,
    daXacMinh: daXacMinh,
    trangThai: trangThai,
  ),
  'phone': '0912345678',
  'gender': 'FEMALE',
  'city': 'Hà Nội',
  'address': '1 Tràng Tiền',
  'country': 'VN',
  'authProvider': 'LOCAL',
  'permissions': ['USER_BASIC', 'READER_APPLY'],
  'activeSessions': 2,
  'orderCount': 1,
  'totalSpent': 250000,
  'hasReaderProfile': true,
  'hasPendingReaderApplication': true,
};

Map<String, dynamic> mauThongKe() => {
  'users': {
    'total': 120,
    'byRole': {'USER': 100, 'STAFF': 12, 'MANAGER': 5, 'ADMIN': 3},
    'newLast7Days': 9,
  },
  'readers': {'pendingApplications': 2, 'activeProfiles': 10},
  'bookings': {
    'total': 80,
    'byStatus': {
      'PENDING': 4,
      'CONFIRMED': 10,
      'COMPLETED': 60,
      'CANCELLED': 6,
    },
  },
  'moderation': {'pendingReports': 1},
  'shop': {'activeProducts': 20, 'clicksLast30Days': 300, 'clicksTotal': 900},
  'ai': {
    'totalCalls': 50,
    'callsLast30Days': 20,
    'promptTokens': 1000,
    'completionTokens': 2000,
    'totalTokens': 3000,
    'tokensLast30Days': 1200,
    'estimatedCostUsd': 0.42,
    'tokensByModel': {'gemini-2.5-flash': 3000},
  },
  'revenue': {
    'grossRevenue': 10000000,
    'grossRevenueLast30Days': 2000000,
    'platformFeePercent': 20,
    'platformFee': 2000000,
    'readerShare': 8000000,
    'paidOut': 5000000,
    'pendingPayout': 1000000,
    'aiCostVnd': 100000,
    'netProfit': 1900000,
    'successfulPayments': 40,
    'pendingPayments': 2,
    'revenueByMonth': {'2026-08': 3000000, '2026-09': 7000000},
  },
  'traction': {
    'registeredUsers': 120,
    'successfulPayments': 40,
    'completedBookings': 60,
    'reviewsCount': 30,
    'feedbackCount': 21,
    'feedbackGoalMet': true,
    'affiliateClicks30d': 300,
    'marketingEventsLast30Days': {'cta_click': 10},
  },
};

Map<String, dynamic> mauHoSoSao({String id = 'h1', bool chinh = true}) => {
  'id': id,
  'title': 'Bản đồ sao của tôi',
  'targetName': 'Minh Anh',
  'birthDate': '2001-09-25',
  'birthTime': '07:30:00',
  'birthPlace': 'Hà Nội',
  'latitude': 21.0285,
  'longitude': 105.8542,
  'timezone': 'Asia/Ho_Chi_Minh',
  'profileType': 'SELF',
  'isPrimary': chinh,
};
