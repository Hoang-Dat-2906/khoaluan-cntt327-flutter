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
| P1 Forecast | Chưa triển khai, không đưa vào navigation | Backend chưa có forecast/predict. Chờ Trí cung cấp contract và kết quả thật. |

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
