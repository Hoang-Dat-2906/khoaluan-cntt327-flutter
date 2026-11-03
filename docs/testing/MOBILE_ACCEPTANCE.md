# Nghiệm thu Flutter cập nhật 25/10/2026

Mọi kiểm tra bản mới: **Chưa chạy — theo yêu cầu người dùng**. Không sử dụng log pass cũ để nghiệm thu bản này.

| ID | Bước tự kiểm tra | Mong đợi | Thực tế | Trạng thái |
|---|---|---|---|---|
| M01 | flutter analyze; flutter test --concurrency=1 | Phân tích tĩnh và unit/widget không lỗi | Chưa có kết quả | Chưa chạy |
| M02 | Login đúng/sai; mở lại app; logout | Token secure, lỗi đúng ngữ cảnh, không mock | Chưa có kết quả | Chưa chạy |
| M03 | Lỗi AUTH_008/403 và DATASET_002/403 bằng test mock | Chỉ lỗi token xóa phiên | Chưa có kết quả | Chưa chạy |
| M04 | List/detail schema null/malformed/Unnamed, refresh | Có cảnh báo, không nhận định dữ liệu sạch | Chưa có kết quả | Chưa chạy |
| M05 | Dataset thiếu file, lỗi DATASET_003 khi download | Có thông báo tải lại; không POST AI | Chưa có kết quả | Chưa chạy |
| M06 | Upload CSV/XLSX, hủy picker, lỗi quyền đọc, file lớn | Chọn đúng file; refresh; không tự gọi AI | Chưa có kết quả | Chưa chạy |
| M07 | Chọn cột/query, một lượt AI nhỏ | Gửi đúng scope; stdout/ảnh/code nhận thật | Chưa có kết quả | Chưa chạy |
| M08 | HTTP200 idle/error/blocked và ảnh hỏng | Không success giả; lỗi ảnh có placeholder | Chưa có kết quả | Chưa chạy |
| M09 | Forecast fixture 6 tháng, target revenue, date month, horizon 3 | 220/240/260 với baseline hiện tại; metrics nhãn train/fitted | Chưa có kết quả | Chưa chạy |
| M10 | MAPE null/actual = 0, response không hữu hạn, timeout POST | Không đổi null thành0; cảnh báo; không retry tự động | Chưa có kết quả | Chưa chạy |
| M11 | Logout/đổi user khi request chưa xong | Không lộ kết quả/cache phiên trước | Chưa có kết quả | Chưa chạy |
| M12 | Android 360–412dp, bàn phím, ảnh zoom; build debug | Không tràn; thao tác được; APK build được | Chưa có kết quả | Chưa chạy |

Test source mới: test/mobile_mvc_forecast_test.dart, test/mobile_mvc_widget_test.dart và bổ sung test/session_test.dart. Mock HTTP/picker/token tách runtime; không gọi Gemini trong các test này. Với test live lịch sử, chỉ bật riêng có chủ đích vì phát sinh quota và tạo/xóa dataset synthetic.

Bằng chứng mới khi người dùng thực hiện: lưu ảnh/log đã che credential vào docs/evidence/mobile/. Chưa tạo ảnh/log/APK mới trong lượt sửa. History mobile chưa làm. P0/P1 còn chờ chạy analyze/test/build và nghiệm thu thiết bị.

## Checklist lịch sử — không thay kết quả bản mới

# Nghiệm thu FinAI Mobile

Các trạng thái dưới đây sẽ được cập nhật theo lệnh và bằng chứng thực tế. Test HTTP mock kiểm tra hành vi client; không thay thế kiểm tra backend thật hoặc thao tác Android.

| Nhóm | Ca kiểm tra | Bằng chứng dự kiến | Trạng thái |
|---|---|---|---|
| Auth | Form encoding, users/me, role, lưu/xóa token | test/session_test.dart | Pass với TokenStore test |
| Phiên | Restore success/401/mạng, logout khi login đang chạy | test/session_test.dart | Pass |
| Contract | Dataset envelope/schema null hoặc malformed, Unnamed | test/finai_contract_test.dart | Pass |
| Phân tích | Download→multipart, 404 không POST, cột rỗng/comma | test/finai_contract_test.dart | Pass |
| API | Timeout, không retry POST, giới hạn response, 401 phiên cũ | test/finai_contract_test.dart | Pass |
| Kết quả | 200/error/idle/blocked/mâu thuẫn và Base64 lỗi | test/finai_contract_test.dart | Pass |
| Ảnh | Chặn URL khác origin để không lộ token | test/finai_contract_test.dart | Pass |
| UI | Login 360dp, validate và lỗi thực thi không hiện success | test/finai_widget_test.dart | Pass |
| UI | Dataset user thật qua HTTP mock, logout về login | test/finai_widget_test.dart | Pass với HTTP mock |
| Backend live | Login, upload 3 dòng, detail, tổng revenue=60, ảnh và cleanup | test/finai_live_test.dart; api-smoke.log | Pass qua Dart client trên Windows |
| Native Android | Cài/chạy app, login, dataset, result, restore/logout | docs/evidence/mobile/ | Chưa kiểm tra |
| P1 picker | Chọn CSV/Excel, hủy chọn, file lớn, upload và refresh | Kiểm thử thiết bị | Chưa kiểm tra |
| Quyền hai user | Dữ liệu user A không xuất hiện cho user B | Kiểm thử backend hai tài khoản | Chưa kiểm tra |
| Forecast | Dữ liệu thật/metrics/biểu đồ | Chờ API backend | Bị chặn |
| Release | HTTPS, signing và icon/applicationId phát hành | Ngoài APK debug demo | Chưa kiểm tra |

Không có ảnh “trước tùy biến” được chụp trong lượt này. Mọi ảnh/log bổ sung phải là kết quả thực và được che token/mật khẩu.


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
