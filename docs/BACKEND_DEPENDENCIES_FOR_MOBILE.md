# Phụ thuộc backend cho FinAI Mobile — 25/10/2026

Đối chiếu source tại KL, chưa kiểm thử runtime. Các mục dưới đây do Cả/Trí xác minh và sửa ở backend; mobile không thay thuật toán hoặc sửa số liệu nhận về.

| Vấn đề | Nguồn source backend/app | Ảnh hưởng/đề nghị |
|---|---|---|
| AI lỗi/thiếu key có thể trả code comment, execution idle và history success | api/routes/files.py | Cần lỗi provider có code an toàn, execution trạng thái đúng; mobile không đánh dấu idle thành công |
| Analysis dataset_id chưa có | api/main.py và api/routes/files.py | Mobile download rồi multipart tạm; cần API dataset_id, scope_columns JSON để hỗ trợ dấu phẩy trong tên cột |
| Storage fields và mã lỗi có thể chưa merge/deploy | dto/response/dataset.py, api/routes/datasets.py, services/dataset_storage.py, exceptions/error_code.py | Xác nhận backend runtime dùng source mới; mobile unknown không mặc định available |
| Metrics tính trên y_train/y_fitted | analytics/forecasting.py | Cần holdout/backtest theo thời gian để đánh giá; mobile ghi rõ in-sample |
| MAPE bỏ actual=0, all-zero trả0 | analytics/forecasting.py | Đề nghị metadata metric_status/zero_count và null nếu không tính được; mobile cảnh báo actual = 0 |
| R² bị giới hạn về0..1 | analytics/forecasting.py | Không coi R² là bằng chứng dự báo tương lai; đề nghị trả R² gốc và phương pháp |
| Forecast periods thiên về MS/tháng, dữ liệu thiếu kỳ | analytics/forecasting.py | Cần tần suất và chính sách missing theo dữ liệu; MVP mobile yêu cầu bảng tháng đã chuẩn bị |
| Khoảng dự báo gắn95% chưa backtest coverage | analytics/forecasting.py | Mobile ghi khoảng ước lượng từ backend, không khẳng định đảm bảo95% |
| financial_facts long format có kỳ/chỉ tiêu/filing chồng lấn | core/data_loader.py và api/routes/files.py | Cần chọn concept/kỳ/unit và khử trùng báo cáo; không sum theo end rồi gọi doanh thu tháng |
| history memory_mb gán cố định, status AI có thể sai | api/routes/files.py, forecast.py, history.py | Không hiển thị là đo RAM thật. History mobile không triển khai lượt này |

Không khôi phục file theo tên tương tự, không xóa dữ liệu/volume để che lỗi, không đưa đường dẫn nội bộ/secret vào UI. Mọi dependency cần kiểm chứng lại sau pull. Khi thiếu forecast endpoint thật, dùng lỗi rõ theoHTTP404; không mock kết quả hoặc tự fallback gọi AI.
