# Tự chạy FinAI Mobile sau cập nhật 25/10/2026

Agent chưa chạy app, SDK, test, build, Docker hoặc API trong lượt cập nhật. Lệnh bên dưới do người dùng tự thực hiện. SDK ghi trong phần lịch sử là thông tin lượt cũ, cần kiểm tra lại.

## 1. Backend đã có image phù hợp MVC

PowerShell cửa sổ 1:
```powershell
cd C:\Users\Dat\Documents\GitHub\KL
docker compose config --quiet
docker compose up -d --no-build backend mailpit
docker compose ps backend
```
Mở http://localhost:8000/docs và kiểm tra backend healthy; xác nhận có POST /api/v1/forecast/predict. Không in .env/token hoặc gửi mật khẩu lên chat. Lỗi mount models.py/import MVC/image thiếu thư viện cần Cả/Trí kiểm tra config và image; không build no-cache hoặc down -v để thử.

## 2. Kiểm tra source Flutter rồi chạy Android

PowerShell cửa sổ 2, chạy từng lệnh và xử lý lỗi trước bước kế tiếp:
```powershell
cd C:\Users\Dat\Documents\GitHub\khoaluan-cntt327-flutter
flutter --version
flutter pub get
flutter analyze
flutter test --concurrency=1
flutter emulators
```
Không cần dependency mới trong thay đổi này. Nếu SDK không tương thích pubspec, báo lại phiên bản/lỗi, không hạ SDK hay đổi lockfile tùy tiện. Có thể tự format các file vừa sửa bằng dart format trước analyze; agent chưa chạy formatter theo yêu cầu.

Ví dụ nếu danh sách có Pixel_6a:
```powershell
flutter emulators --launch Pixel_6a
flutter devices
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000
```
Thay tên emulator và ID bằng kết quả hiện tại. API_BASE_URL là origin, không thêm /api/v1. Emulator dùng 10.0.2.2; localhost trên Android là chính thiết bị. Nếu PowerShell không có flutter, tự kiểm tra đường dẫn SDK từng dùng và gọi:
```powershell
& 'D:\nam 3 HK2\LTDD\flutter\bin\flutter.bat' --version
```
Các lệnh flutter khác có thể dùng cùng tiền tố & và đường dẫn đó. Không tự đổi PATH hệ thống hoặc cài SDK.

Nếu màn hình đen do renderer, thử tùy SDK hỗ trợ:
```powershell
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000 --enable-software-rendering --no-enable-impeller
```
Không patch manifest release để tắt renderer toàn cục. Không clean/pub cache/Gradle cache mặc định vì sẽ tải lại.

## 3. Điện thoại thật
```powershell
ipconfig
flutter devices
flutter run -d YOUR_DEVICE_ID --dart-define=API_BASE_URL=http://YOUR_LAN_IP:8000
```
Thay ID/IP thật; máy và điện thoại cùng LAN, cổng 8000 được cho phép theo cấu hình của bạn. Agent không tự sửa firewall. Windows desktop có thể dùng localhost; Flutter web còn cần CORS backend phù hợp.

## 4. Demo kiểm tra

Login → Dữ liệu → upload CSV/XLSX nhỏ → detail/schema → chọn cột/câu hỏi tiếng Việt → phân tích → xem stdout/code/ảnh → Dự báo → chọn dataset/cột số/cột ngày/số kỳ → kết quả → logout → mở lại app. Với dataset missing, nút phân tích/dự báo phải bị khóa; khi file mất giữa chừng, download lỗi không POST AI. 403 thiếu quyền không làm logout; AUTH_008 token sai có logout. Không tạo bản ghi mất file bằng xóa dữ liệu thật; dùng test mock/checklist có kiểm soát.

Fixture synthetic: docs/testing/forecast_synthetic.csv. Mỗi dòng một tháng, target=revenue, date=month, model=linear_regression, horizon=3. Tổng revenue = 900, cost = 510, chênh lệch = 390; kỳ vọng forecast = 220, 240, 260 nếu giữ baseline hiện tại. Đây là test luồng, không chứng minh dự báo thật chính xác. Metrics backend hiện tính train/fitted, không phải tập kiểm tra; MAPE có actual = 0 cần đọc cảnh báo. Một lần phân tích AI thật tiêu tốn quota; các unit/widget mock không gọi AI.

Test live cũ `finai_live_test.dart` mặc định bị bỏ qua. Chỉ chạy khi người dùng chủ động đặt `FINAI_RUN_LIVE=1` và thông tin tài khoản test; lượt này có thể gọi Gemini và tốn quota. Không đặt mật khẩu/token trong source hoặc gửi lên chat.

## 5. APK khi cần
```powershell
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:8000
```
APK dự kiến build/app/outputs/flutter-apk/app-debug.apk; chưa tạo APK mới trong lượt này. Điện thoại thật phải build với IP LAN. Không commit APK/build/cache. HTTP local chỉ debug, release dùng HTTPS/signing phù hợp.

## Hướng dẫn lịch sử 24/10 — để tham khảo, ưu tiên phần cập nhật trên

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

## Chạy bằng Start Debugging của VS Code — 30/10/2026

Đã kiểm tra schema extension Dart Code 3.146.0 cài trên máy: `args` truyền vào chương trình, còn `toolArgs` truyền vào công cụ Flutter. Cấu hình `.vscode/launch.json` cũ đặt `--dart-define` ở `args`; đã chuyển sang `toolArgs` và khai báo `program: lib/main.dart` cho Android/Windows/Chrome.

1. Mở đúng thư mục gốc khoaluan-cntt327-flutter trong VS Code, có pubspec.yaml và lib/main.dart.
2. Dừng phiên debug cũ bằng Shift+F5. Giữ emulator và backend chạy.
3. Mở Run and Debug (Ctrl+Shift+D), chọn `FinAI (Android Emulator)` trong danh sách cấu hình.
4. Chọn thiết bị Android emulator ở thanh trạng thái rồi bấm F5. Android dùng API_BASE_URL=http://10.0.2.2:8000; Windows/Chrome dùng http://localhost:8000.
5. Cần khởi chạy lại đầy đủ để áp dụng dart-define; hot reload và nút Thử lại trong app không cập nhật giá trị cấu hình biên dịch.

Nếu vẫn báo URL không hợp lệ, kiểm tra đang chọn cấu hình FinAI của đúng thư mục Flutter; cấu hình workspace hoặc nút Run của Android Studio là luồng cấu hình riêng. Trong ảnh hỗ trợ, Android Studio chỉ đang hiển thị emulator.

Agent chỉ sửa/đọc cấu hình và kiểm tra cú pháp JSON; chưa chạy Flutter, build hoặc API để xác minh runtime trong lượt này.