# Cập nhật Flutter theo mục V — 25/10/2026

> Cập nhật source 25/10/2026: chưa chạy app/test/build theo yêu cầu người dùng. Kết quả kiểm thử 24/10 bên dưới là bằng chứng lịch sử, không chứng minh phiên bản vừa sửa đã pass.

Đã đối chiếu source backend MVC hiện tại tại KL và phân công/đề cương trong prompt. Chỉ sửa Flutter; không sửa backend, .env, dependency/lockfile, Gradle hoặc Git. Checkout lúc bắt đầu sạch, nhánh feature/mobile-finai-shell-dat theo dõi origin/codex/finai-mobile-muc-v. Không đổi nhánh hoặc commit/push.

| Mục | Phần source đã có và thay đổi lần này | Trạng thái nghiệm thu bản mới |
|---|---|---|
| DAT-M01 shell | Giữ FinAI/auth guard; thêm route và navigation Dự báo; giữ MIT/Kite | Chưa chạy |
| DAT-M02 ApiClient | Parser mã lỗi MVC, giới hạn error body 16 KiB, allowlist thông báo, JSON riêng form, timeout riêng; không retry POST | Chưa chạy |
| DAT-M03 auth | AUTH_008/403 hết token; dataset 403 không logout; giữ generation guard, chặn side effect lỗi về muộn sau timeout | Chưa chạy |
| DAT-M04 dataset | file_available nullable/storage_status, khóa file missing/error/processing/unavailable; unknown vẫn báo chưa xác nhận, backend kiểm tra khi dùng | Chưa chạy |
| DAT-M05 analysis | Không POST khi file bị chặn/download fail; idle không báo thành công; cho refresh trạng thái; giữ code/stdout/ảnh có giới hạn | Chưa chạy |
| DAT-M06 Android/test | Giữ INTERNET/debug HTTP và cấu hình Gradle; thêm test source MVC/forecast/widget/session | Chưa chạy analyze/test/build/thiết bị |
| P1 upload | Giữ upload thật; tách DatasetFilePicker injectable, đọc stream có giới hạn bộ nhớ; viết test hủy/lỗi chọn file | Chưa chạy native picker |
| P1 forecast | Model/repository/form/result mới; JSON API; PNG backend, MAE/RMSE/MAPE/R², bảng future, actual/fitted và cảnh báo giới hạn | Chưa chạy API/runtime |
| History mobile | Không triển khai; ngoài ưu tiên lượt này | Chưa làm |

File chính: lib/core/network/api_client.dart; lib/core/auth/session.dart; lib/core/router/app_router.dart; lib/shared/layout/finai_shell.dart; lib/features/datasets/*; lib/features/analysis/*; lib/features/forecast/*; test/mobile_mvc_forecast_test.dart; test/mobile_mvc_widget_test.dart; test/session_test.dart.

Các kết quả forecast chỉ lưu trong State của route, không có cache lâu dài. Request cũ bị kiểm tra generation và dataset/request revision; router auth guard bỏ màn hình riêng khi logout. Không có lượt Gemini/API live, không tải SDK/package, không tạo APK hoặc ảnh/log mới. Test source đã viết chưa được runner xác nhận; P0/P1 chưa nghiệm thu toàn bộ. Hướng dẫn tự chạy: docs/FLUTTER_RUN_GUIDE.md; checklist: docs/testing/MOBILE_ACCEPTANCE.md; phụ thuộc: docs/BACKEND_DEPENDENCIES_FOR_MOBILE.md.

Cả review P0: mã lỗi, token và multipart/storage. Trí review P1: request/response forecast, nhãn metrics và kỳ/đơn vị. Đề xuất nhóm commit: auth/network; dataset/analysis; forecast; test/docs theo các nhánh trong Word. Không tự tách commit hoặc rewrite lịch sử.

## Bản báo cáo lịch sử 24/10 — giữ để đối soát

# Báo cáo triển khai mục V FinAI Mobile

Ngày bắt đầu đối chiếu 24/10/2026. Phạm vi là repository Flutter; backend KL chỉ được đọc contract và kiểm thử API, không sửa mã nguồn hoặc .env Web. Trước triển khai repository sạch trên nhánh dev; thay đổi hiện ở codex/finai-mobile-muc-v, chưa commit/push.

## Thay đổi theo mục V

| Hạng mục | Nội dung thực hiện | Giới hạn cần theo dõi |
|---|---|---|
| P0 Nhận diện/shell | FinAI Mobile; navigation Tổng quan/Dữ liệu/Cài đặt; chỉ route auth, dataset, analysis và settings | Giữ source template cũ nhưng không expose route. Logo dùng icon auto_graph và theme xanh; chưa có bộ icon phát hành riêng. |
| P0 Auth/API | Form URL encoded, users/me, secure storage, restore/guard, 401 theo generation, logout/cache theo phiên | Lưu token native cần kiểm tra trên emulator/APK. URL lấy dart-define; thiếu URL báo cấu hình, không đoán localhost. |
| P0 Dataset | Parse data/count và schema string/object/list/null; list/detail/refresh/pagination; cảnh báo Unnamed | Chất lượng/schema là metadata đã lưu; chưa tự nhận diện bảng Excel thay backend. |
| P0 Analysis | Download file có token rồi multipart; giới hạn dung lượng; không POST lại tự động | API dataset_id chưa có. Contract cũ không hỗ trợ chọn cột tên chứa dấu phẩy. |
| P0 Kết quả | stdout/code/ảnh Base64 hoặc cùng origin; error có chi tiết; security/execution tách riêng | UI không kiểm chứng mọi phép tính Gemini; đã có cảnh báo. Không có history bền vững. |
| P1 Upload | File picker CSV/XLSX/XLS, tối đa 15 MB, refresh và detail sau upload | Cần kiểm tra native picker trên emulator/thiết bị; test API upload không chứng minh picker. |
| P1 Forecast | Chưa triển khai, không đưa vào navigation | Thông tin lịch sử 24/10, đã lỗi thời: source backend 25/10 hiện có forecast/predict; xem cập nhật bên trên. |

## File chính

lib/core/network/api_client.dart; lib/core/auth/session.dart và token_store.dart; lib/core/router/app_router.dart; lib/features/auth/auth_screens.dart; lib/features/datasets/*; lib/features/analysis/*; lib/shared/layout/finai_shell.dart; lib/app.dart; lib/core/theme/app_theme.dart; pubspec.yaml và pubspec.lock; Android manifests và gradle.properties.

Session cũ đăng nhập giả theo email/KITE_DEMO đã được thay. Các test session mock cũ đã được viết lại cho HTTP contract thật với HTTP giả lập chỉ trong test. Không có key Gemini trong Flutter. Secure storage và file_picker được resolve bằng SDK cài sẵn; không hạ SDK. Gradle hiện giới hạn heap 1536 MB và một worker, không parallel, không giữ daemon sau build; HeapBaseMinAddress=4G theo chẩn đoán native memory. Không thay đổi pagefile/cấu hình Windows.

## Kiểm chứng

flutter analyze: No issues found. flutter test --concurrency=1: 48 pass, 1 live test skip theo thiết kế. Lỗi schema type inference và retry bootstrap ở lượt đầu đã sửa; kết quả này dùng lượt rerun. Log: docs/evidence/mobile/analyze.log và tests.log.

Live smoke riêng pass login/users-me, dataset list, upload/detail CSV giả lập 3 dòng, download/multipart/Gemini/sandbox, tổng revenue=60, execution success, security passed, nhận bytes ảnh và cleanup đúng dataset test. Log docs/evidence/mobile/api-smoke.log không chứa credential/token. Đây là Dart client trên Windows với backend thật, chưa thay thế thao tác native Android.

Build đầu thất bại khi tải artifact Gradle do thiếu tài nguyên hệ thống. Android doctor còn cảnh báo một số license. Emulator Pixel_6a đã khởi chạy thành emulator-5554, Android 16/API36; trạng thái cài/chạy app phải ghi theo bằng chứng thực tế sau build.

Chưa kết luận P0 hoàn thành chỉ từ code hoặc HTTP 200. Phần kiểm thử thiết bị, upload picker, sai mật khẩu, restore/logout và kết quả ảnh cần đánh dấu riêng theo bằng chứng.

## Git và kiểm tra chéo

Không commit, push, merge hoặc tạo PR. Thay đổi được chuẩn bị để Cả/Trí review. Nhóm công việc mapping: shell → feature/mobile-finai-shell-dat; auth → feature/mobile-auth-api-dat; dataset/analysis → feature/mobile-datasets-analysis-dat; test → test/mobile-e2e-tri; forecast chưa có thay đổi.

Cả cần kiểm tra tương thích multipart/status, quyền dataset và thay adapter khi analysis/run có thật. Trí cần kiểm tra metrics/forecast contract sau khi triển khai backend; không suy ra dữ liệu tháng từ quý/năm để hiển thị dự báo.


## Kết quả người dùng cung cấp và sửa tiếp ngày 25/10/2026

Người dùng đã chạy Flutter 3.47.5/Dart 3.13.4 và pub get thành công.
Kết quả analyze trước bản sửa tiếp: 6 info, 1 warning (7 issues).
Kết quả test trước bản sửa tiếp: 67 pass, 1 skip, 1 fail. Test fail là
`missing dataset disables analysis and forecast at 360dp`: RenderFlex tràn phải 6 px.
Đây là kết quả người dùng gửi, agent không tự chạy lệnh để xác nhận.

Đã sửa thứ tự import, thêm block cho if, chỉ định kiểu collection trong test;
giới hạn nhãn nút phân tích bằng Flexible trong Row của button để có thể xuống dòng.
Bản sửa tiếp chưa chạy lại. Giữ assertion bắt overflow và kiểm tra hai nút bị khóa.
Người dùng cần chạy lại `flutter analyze` và `flutter test --concurrency=1`.
Emulator Pixel_6a đã có trong danh sách nhưng chưa xuất hiện trong flutter devices
ở log được cung cấp; cần launch emulator rồi lấy ID thực tế trước flutter run.

### Kết quả chạy lại do người dùng cung cấp ngày 25/10/2026

`flutter test --concurrency=1`: 68 test đạt, 1 test bỏ qua; tất cả test được thực thi đã đạt. Test tràn giao diện 360 dp đã đạt ở lần này.
`flutter analyze`: còn 1 info về block if tại forecast_screen.dart:87. Đã bổ sung block cho các nhánh catch/finally tương ứng; thay đổi cú pháp này chưa chạy analyze lại.
Nguồn xác nhận là log người dùng gửi, agent không tự chạy SDK/test/build. Kết quả này không xác nhận app đã chạy trên Android hoặc API live đã hoạt động.

## Giao diện 31/10/2026 — chưa chạy kiểm tra

Xem docs/FLUTTER_UI_REFRESH.md. Cập nhật giao diện toàn bộ các màn hình nghiệp vụ, giữ API và trạng thái thực thi. Không áp dụng kết quả 68 test của bản cũ cho bản UI mới.
