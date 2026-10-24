# Chạy FinAI Mobile

Mở terminal trong repository khoaluan-cntt327-flutter. SDK đã kiểm tra: Flutter 3.47.5, Dart 3.13.4. Ứng dụng vẫn giữ tên package Dart kite để dùng thư viện Kite sẵn có; tên hiển thị là FinAI Mobile.

## Android emulator

Khởi động Docker backend tại repository KL trước. Backend phải nhận kết nối trên cổng 8000 và đăng nhập được từ web.

```powershell
flutter pub get
flutter emulators --launch Pixel_6a
flutter devices
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Nếu thiết bị có ID khác, dùng ID từ flutter devices. 10.0.2.2 trỏ về máy Windows trong Android Emulator; localhost trên Android trỏ về chính điện thoại/emulator.

## Thiết bị thật

Cùng Wi-Fi với máy chạy Docker, bật USB debugging và xác nhận thiết bị. Lấy IP LAN Windows bằng ipconfig rồi dùng origin tương ứng, ví dụ:

```powershell
flutter run -d YOUR_DEVICE_ID --dart-define=API_BASE_URL=http://YOUR_LAN_IP:8000
```

Hai placeholder YOUR_DEVICE_ID/YOUR_LAN_IP phải thay bằng giá trị thực tế. Không đưa mật khẩu hoặc API key vào dart-define. Không đổi DATABASE_URL sang IP điện thoại. Với Windows Flutter desktop, origin có thể dùng http://localhost:8000. Flutter web còn phụ thuộc CORS của backend; mobile native không dùng chính sách CORS của trình duyệt.

## Build và kiểm thử

```powershell
flutter analyze
flutter test --concurrency=1
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

APK debug dự kiến: build/app/outputs/flutter-apk/app-debug.apk. Không commit APK/build/cache. APK build dùng URL compile-time nên đổi từ emulator sang LAN cần build lại. HTTP được cho phép ở manifest debug để demo local; release không được bật cleartext diện rộng. Bản release cần HTTPS và signing config riêng; không coi debug APK là bản phát hành production.

Nếu Android doctor báo license chưa được chấp nhận, chạy flutter doctor --android-licenses và tự đọc/chấp nhận các điều khoản phù hợp. Agent không xác nhận thay người dùng. Gradle giới hạn heap 1536 MB và một worker, không giữ daemon sau build; nếu thiếu tài nguyên, đóng ứng dụng không cần thiết theo lựa chọn người dùng và thử lại. Không xóa volume PostgreSQL để sửa lỗi build Flutter.

## Smoke test backend thật có một lượt Gemini

File test/finai_live_test.dart mặc định bị skip nếu không có FINAI_TEST_EMAIL/FINAI_TEST_PASSWORD trong environment của tiến trình. Đặt hai biến này bằng tài khoản demo của bạn trong terminal, không ghi giá trị vào file hoặc Git, rồi chạy:

```powershell
$env:API_BASE_URL = 'http://localhost:8000'
flutter test test/finai_live_test.dart --reporter expanded
```

Test tạo một CSV giả lập 3 dòng, xác minh tổng revenue=60, thực thi thành công và có ảnh. Test xóa đúng dataset vừa tạo ở finally. Không chạy trong unit test mặc định và không lặp lại chỉ để lấy ảnh đẹp. Nếu backend lỗi, đọc báo cáo thay vì tăng số lượt Gemini tự động.

## Demo thao tác

1. Nhập tài khoản đã được cấp trên Web; app không điền sẵn mật khẩu.
2. Mở Dữ liệu, tải CSV/XLSX/XLS tối đa 15 MB nếu cần. Hủy chọn file không làm thay đổi dữ liệu.
3. Mở detail, xem schema và cảnh báo. Chọn Phân tích, cột và câu hỏi tiếng Việt.
4. Chờ server; đọc số liệu, execution/security riêng; mở mã Python khi cần. Kiểm tra đơn vị/kỳ và đối chiếu nguồn trước khi dùng kết luận.
5. Đăng xuất ở Cài đặt; token và phiên cache bị xóa. Khởi động lại app kiểm tra restore hoặc login phù hợp.

App không lưu lịch sử phân tích lâu dài ở thiết bị; rời màn hình kết quả có thể cần gửi lại để phân tích lần nữa. Không bấm lại nếu server vẫn đang xử lý request trước.
