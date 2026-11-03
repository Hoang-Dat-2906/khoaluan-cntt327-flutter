# Đối chiếu backend và mobile ngày 03/11/2026

Đối chiếu source backend trong repository KL; chưa xác nhận API đang deploy hoặc chạy trên thiết bị.

| Luồng | Kết quả đối chiếu |
| --- | --- |
| Đăng nhập / phiên | Mobile gọi login/access-token và users/me, dùng Bearer token. |
| Dataset | Danh sách, upload, detail và download dùng endpoint hiện tại. |
| Phân tích | Multipart files/upload với file, query, scope_columns phù hợp controller hiện tại. |
| Dự báo | forecast/predict và cấu trúc status/data phù hợp service hiện tại. |
| Lịch sử | Đã thêm tab Lịch sử, list/detail API history, search/status_filter và phân trang 20 bản ghi. |
| Chức năng chưa có UI mobile | Dataset quality-report, schema-analysis, clean; analytics/clustering; xóa lịch sử và stats. |

Lịch sử lấy trực tiếp từ backend, bao gồm các kết quả dự báo backend đã lưu. Không gọi lại AI khi mở chi tiết. Backend còn có trạng thái idle; mobile hiển thị Chưa thực thi. DTO lịch sử không cung cấp security_status nên màn hình không suy diễn trạng thái kiểm tra bảo mật.

Lưu ý backend: analyze_upload và dự báo thành công bỏ qua exception khi ghi lịch sử. Vì vậy một lần phân tích thành công có thể không xuất hiện nếu việc lưu backend thất bại. Chỉ xem tab lịch sử không sửa được hành vi này.

Các thay đổi có sẵn trong worktree được giữ lại. Lượt này bổ sung feature history, route và tab điều hướng.

Kiểm thử: 3 test mới history_test.dart đạt; 29 test hiện có trong mobile_mvc_forecast_test.dart và finai_contract_test.dart đạt. Kiểm thử dùng HTTP mock, không gọi AI hay API thật. Chưa build/cài APK hoặc kiểm tra trên emulator trong lượt này.
