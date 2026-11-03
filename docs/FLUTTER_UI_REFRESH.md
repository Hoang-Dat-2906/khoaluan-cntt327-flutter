# Cập nhật giao diện FinAI Mobile ngày 31/10/2026

Phạm vi: thay đổi giao diện Flutter trên nền luồng nghiệp vụ hiện có. Không sửa backend, auth/network/parser, API, SDK, dependency, Gradle hoặc dữ liệu người dùng. Các thay đổi chưa commit trước đó được giữ lại.

## Thiết kế

- Nền sáng xanh nhẹ, màu chính xanh dương, phối tím ở phần giới thiệu và xanh ngọc ở dữ liệu. Giao diện tối có nền, chữ và bề mặt riêng.
- Thanh ứng dụng có biểu tượng FinAI; bốn mục điều hướng có icon được chọn rõ ràng. Nội dung giới hạn chiều rộng 860 dp trên cửa sổ lớn.
- Đăng nhập: nền chuyển sắc, form dạng thẻ, icon email/mật khẩu, khoảng cách chạm lớn, cuộn khi bàn phím mở. Không thêm đăng nhập giả hoặc chức năng chưa có.
- Tổng quan: lời chào, phần giới thiệu, số tệp từ API, tệp hiện có và lối tắt phân tích/dự báo. Không tạo KPI tài chính hay biểu đồ mẫu.
- Dữ liệu: nút upload, giới hạn file, thẻ tệp dễ đọc, trạng thái lưu trữ, chi tiết số dòng/cột và schema. Thiếu file vẫn khóa thao tác như trước.
- Phân tích: nhóm chọn cột và câu hỏi theo bước, kết quả tách số liệu/ảnh/mã kỹ thuật; stdout và Python cuộn ngang để giữ cấu trúc bảng. Không đổi cách quyết định thành công/thất bại.
- Dự báo: nhóm chọn dữ liệu và mô hình, chỉ số trong các thẻ, bảng tương lai cuộn ngang và giữ cảnh báo train/fitted/MAPE.
- Cài đặt: thông tin tài khoản, giao diện tối, kết nối máy chủ và đăng xuất được nhóm riêng; giữ nguồn Kite/MIT.

## File

`lib/shared/widgets/finai_design.dart`: bảng màu, Material theme và các thành phần giao diện dùng chung.
`lib/app.dart`: áp dụng Material theme bên trong ShadApp hiện có.
`lib/shared/layout/finai_shell.dart`: shell, trạng thái kiểm tra phiên và cài đặt.
`lib/features/auth/auth_screens.dart`: giao diện đăng nhập.
`lib/features/datasets/dataset_screens.dart`: tổng quan, danh sách, chi tiết, thẻ tệp dùng chung.
`lib/features/analysis/analysis_screen.dart`: form và kết quả.
`lib/features/forecast/forecast_screen.dart`: form và kết quả.

## Trạng thái kiểm tra

Chưa chạy Flutter/Dart formatter, analyze, test, build, emulator, Docker hoặc API theo yêu cầu người dùng trước đó. Chưa chụp giao diện chạy thật. Kết quả 68 test đạt của phiên bản trước không xác nhận thay đổi UI lần này. Không tạo APK/ảnh/log giả và không gọi Gemini.

Người dùng tự chạy trong repository Flutter:

```powershell
flutter analyze
flutter test --concurrency=1
```

Sau đó chạy cấu hình F5 `FinAI (Android Emulator)` hoặc lệnh:

```powershell
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Thay ID bằng thiết bị hiện có. Backend cần hoạt động. Nếu app đang chạy, hot restart bằng R trong terminal Flutter; không nhấn nút phân tích chỉ để xem màu giao diện vì đó là yêu cầu AI thật.

Kiểm tra ở 360/412 dp và cỡ chữ lớn: đăng nhập/bàn phím, tên tệp dài, missing dataset, chọn cột tên dài, câu hỏi nhiều dòng, số liệu cuộn ngang, chart zoom, forecast dropdown/bảng/metrics, dark mode, logout. Giữ nguyên những kiểm tra nghiệp vụ đang có; không xóa assertion overflow để che lỗi.


## Bổ sung khi rà mã

Thêm nút quay lại ở trang chi tiết/form và mở biểu đồ toàn màn hình, hỗ trợ pinch zoom; không gọi lại API để mở ảnh đã nhận. Giới hạn chiều rộng tên chip, nhãn trạng thái và bảng/mã cuộn ngang.
Đã viết thêm test widget: tên tệp dài với theme sáng/tối ở 360 dp; form đăng nhập cuộn khi bàn phím mở và chữ 130%. Những test này chưa chạy.
