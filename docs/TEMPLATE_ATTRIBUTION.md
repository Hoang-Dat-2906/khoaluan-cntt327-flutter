# Nguồn template và phần phát triển FinAI

Ứng dụng phát triển từ Kite Flutter Admin Dashboard của Colorlib: https://github.com/ColorlibHQ/kite-flutter-admin-dashboard. Giấy phép MIT, copyright 2026 Colorlib; LICENSE và thông báo bản quyền nguồn vẫn được giữ.

Nhóm tái sử dụng packages/kite_ui, theme controller, cấu trúc Riverpod/go_router và phần mã template không nằm trong navigation FinAI. Các màn hình orders/customers/products/inbox/board/calendar/chat cùng dashboard mock cũ không được đưa vào luồng runtime FinAI. Chúng có thể còn trong source để bảo toàn template và không được tính là nghiệp vụ khóa luận đã hoàn thành.

Phần mới của nhóm: tên hiển thị FinAI Mobile; shell/navigation ba mục; đăng nhập FastAPI và secure token; bootstrap/guard phiên thật; ApiClient; model/service dataset; màn hình danh sách/detail/schema; form query và kết quả; adapter download/multipart; upload mobile; trạng thái bảo mật/thực thi riêng; test hợp đồng và test UI; tài liệu tích hợp.

Tên package Dart kite và applicationId com.colorlib.kite hiện chưa đổi để tránh migration ngoài phạm vi. Nếu phát hành chính thức cần chọn applicationId riêng, icon phát hành và chứng thư ký. Không nhận toàn bộ template là sản phẩm do nhóm viết mới. Chưa có ảnh trước tùy biến được chụp trong lượt này; nếu không có bằng chứng lịch sử thì không tạo ảnh giả thay thế.
