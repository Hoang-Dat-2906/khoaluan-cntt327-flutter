# Contract mobile MVC — đối chiếu source 25/10/2026

Đối chiếu source, chưa kiểm thử runtime. Backend checkout KL có thể có thay đổi local chưa merge. Bản cũ 24/10 bên dưới giữ như lịch sử và không có hiệu lực nếu mâu thuẫn bảng mới.

| Chức năng | Request và response hiện dùng |
|---|---|
| Login | POST /api/v1/login/access-token, URL encoded username/password; access_token |
| User | GET /api/v1/users/me, Bearer; is_active/is_superuser |
| Dataset | GET /api/v1/datasets/?skip=0&limit=100; data/count |
| Detail/quality | GET /api/v1/datasets/{id}; /{id}/quality-report (mobile hiện dùng schema metadata từ detail) |
| Upload | POST /api/v1/datasets/upload multipart file; description tùy chọn chưa đưa vào form mobile |
| Download | GET /api/v1/datasets/{id}/download, Bearer, tối đa 15 MiB phía mobile |
| Analysis | POST /api/v1/files/upload multipart file/query/scope_columns dấu phẩy; download có token trước POST |
| Forecast | POST /api/v1/forecast/predict JSON dataset_id, target_column, date_column, horizon 1..12, model_type |
| History | GET /api/v1/history/; /{id}; /stats, chưa tích hợp mobile |

analysis/run và analysis-history là API đề xuất trong tài liệu cũ, chưa được include trong backend router hiện đọc. Không fallback POST do lỗi mạng/timeout/404. Forecast hiện có source thật, không tiếp tục đánh dấu là chưa có API.

Dataset thêm file_available bool nullable khi server cũ không trả; storage_status available/missing/invalid_path/unavailable/unknown. Missing/error/processing hoặc file_available=false bị chặn phía client; unknown được ghi chưa xác nhận, server sẽ kiểm tra khi dùng. Không gửi đường dẫn server hoặc sửa file gốc.

Lỗi JSON {code,message,detail}: client chỉ giữ code hợp lệ và thông điệp allowlist, không lộ message/detail raw. Error body tối đa 16 KiB; body hỏng/quá lớn dùng HTTP fallback. AUTH_001/400 sai đăng nhập; AUTH_008/403 token không hợp lệ; DATASET_001/404 thiếu bản ghi; DATASET_002/403 thiếu quyền; DATASET_003/404 thiếu file; DATASET_006/403 path không hợp lệ; DATASET_008/503 kho lưu trữ chưa truy cập. Chỉ 401 hoặc AUTH_008/403 xóa phiên. Không phải mọi 403 đều hết phiên.

Forecast trả envelope status/dataset_name/execution_time_ms/data. data có target_column/model_type, metrics {mae,rmse,mape,r2}, forecast_table [{period,forecast_value,lower_bound,upper_bound}], historical_table [{period,actual_value,fitted_value}], chart_image Base64/data URI. Mobile yêu cầu bảng không rỗng, số hữu hạn, target/model/horizon khớp yêu cầu. Chỉ số thiếu/sai kiểu/không hữu hạn hiển thị Không xác định; dòng số liệu không hợp lệ là lỗi parser. Không tạo số hoặc ảnh thay thế.

Metrics hiện tính trên train/fitted; MAPE loại actual=0 và all-zero trả 0; khoảng dự báo chưa kiểm định; nhãn tương lai thiên về tháng. Màn hình ghi đúng giới hạn, không gọi fitted là test prediction. Xem docs/BACKEND_DEPENDENCIES_FOR_MOBILE.md.

Nguồn: backend/app/api/main.py, api/routes/datasets.py, files.py, forecast.py, history.py; dto/request/forecast.py; dto/response/dataset.py; exceptions/error_code.py; analytics/forecasting.py.

## Contract lịch sử 24/10 (không áp dụng thay bảng mới)

# Contract API FinAI Mobile

Đối chiếu mã nguồn FastAPI và OpenAPI live tại localhost:8000 trong lượt triển khai mục V ngày 24/10/2026. API_BASE_URL là origin, không kèm /api/v1; ApiClient nối prefix một lần. Mọi endpoint bảo vệ gửi Authorization Bearer. Không lưu credential thật trong tài liệu.

| Nghiệp vụ | Contract xác minh |
|---|---|
| Login | POST /api/v1/login/access-token, application/x-www-form-urlencoded với username và password; nhận access_token. Sai thông tin hiện trả 400. |
| User | GET /api/v1/users/me; id, email, full_name nullable, is_active, is_superuser. |
| Dataset list | GET /api/v1/datasets/?skip=0&limit=100; {data: Dataset[], count: int}. Admin xem mọi dataset được backend cho phép; User theo owner. |
| Detail | GET /api/v1/datasets/{id}; DatasetPublic. 403 không đủ quyền, 404 không có dataset. |
| Quality | GET /api/v1/datasets/{id}/quality-report; dữ liệu profile đã lưu. Mobile hiện dùng schema_info từ detail; không coi đó là lần đọc lại file. |
| Download | GET /api/v1/datasets/{id}/download; bytes. Có thể 404 dù metadata còn nếu file vật lý bị mất. |
| Upload | POST /api/v1/datasets/upload; multipart file, description optional; trả DatasetPublic. |
| Analyze | POST /api/v1/files/upload; multipart file, query, scope_columns là chuỗi phân cách bằng dấu phẩy. |
| Delete test data | DELETE /api/v1/datasets/{id}; smoke test chỉ xóa dataset do chính nó vừa tạo. |

DatasetPublic dùng id/filename/file_type/size_bytes/row_count/column_count/version/status/owner_id/created_at/schema_info/sample_data/description. Parser mobile đọc schema_info JSON string, object hoặc list cột; null/malformed tạo cảnh báo và không coi là schema sạch. Tên cột được giữ nguyên, kể cả khoảng trắng; mobile không làm sạch nội dung thay backend.

Kết quả phân tích đọc stdout, ai_code, chart_image, execution_status, execution_error, execution_time_ms, security_status. chart_image hiện là data:image/png;base64,... từ sandbox. HTTP 200 và message thành công không đủ để ghi nhận thực thi thành công. Trạng thái thiếu hoặc mâu thuẫn được hiển thị rõ.

## Chế độ đang triển khai

Chỉ có một chế độ tương thích đã xác minh: download dataset có token rồi POST file bytes tới files/upload. Không tự gọi endpoint đề xuất và không retry POST. Giới hạn file 15 MB; ảnh URL tối đa 5 MB, chỉ cùng origin API; tổng JSON phân tích tối đa 8 MB. Timeout thường 25 giây, upload 60 giây, phân tích 6 phút. Client timeout không hủy job backend; người dùng không nên bấm gửi lại liên tục.

Luồng dùng bộ nhớ, không ghi file tạm trên thiết bị. Download vượt giới hạn hoặc 404 dừng trước POST. Không tự tạo bản ghi dataset mới khi phân tích. Tên file được loại dấu phân cách đường dẫn trước multipart. Tên cột có dấu phẩy bị từ chối rõ vì contract cũ không biểu diễn được.

## Dependency chưa có

OpenAPI hiện không có POST /api/v1/analysis/run và POST /api/v1/forecast/predict. Chưa có UI forecast giả. Khi Cả/Trí cung cấp route thật, cần bổ sung service riêng theo schema xác minh, không fallback tự động từ mọi lỗi 404/5xx.

Backend vẫn có rủi ro xử lý Excel nhiều dòng tiêu đề và cộng trùng financial facts. Mobile hiện cảnh báo schema bất thường và không tự dựng số thay thế; chưa xác minh độ chính xác tổng quát của mã Gemini.
