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
