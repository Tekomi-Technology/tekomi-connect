# Bản đồ tính năng — Tekomi Connect

> Lập tại commit `c37c7293a9` — ngày 2026-10-03
> Nhánh: `customer/gmo-develop` (white-label "GMO Connect")

Mục đích: trả lời nhanh câu hỏi "tính năng X nằm ở đâu, chạy thế nào" mà không phải
quét lại toàn bộ repo. Mỗi file mô tả một vùng tính năng theo cùng một khuôn:

Tóm tắt → Database → Backend → API/Route → Frontend → Điểm vào giao diện →
Luồng dữ liệu → Feature flag → i18n → ⚠️ Phụ thuộc chéo → Cạm bẫy đã biết

## Các vùng tính năng

| Vùng | File | Trạng thái |
|---|---|---|
| Kênh liên lạc (Web, FB, Zalo, Email, WhatsApp, SMS, Voice…) | [channels.md](channels.md) | ✅ |
| Hội thoại, danh sách, bộ lọc, phân quyền xem | [conversations.md](conversations.md) | ✅ |
| Đồng bộ CRM Perfex (liên hệ, ticket, deal) | [crm-perfex.md](crm-perfex.md) | ✅ |
| Cuộc gọi điện thoại + báo cáo cảm xúc | [phone-calls.md](phone-calls.md) | ✅ |
| Deal & Ticket | deals-tickets.md | ⏳ chưa lập |
| Liên hệ & Doanh nghiệp | [contacts-companies.md](contacts-companies.md) | ✅ |
| Trợ lý AI / Captain / LLM | ai-assistant.md | ⏳ chưa lập |
| Super Admin & Báo cáo | [admin-reports.md](admin-reports.md) | ✅ |
| Hạ tầng, deploy, Docker, job/queue | infra.md | ⏳ chưa lập |

## Cách dùng

- Tìm theo tên tính năng trong bảng trên, mở đúng 1 file thay vì `rg` cả repo.
- Mục **⚠️ Phụ thuộc chéo** của mỗi file cho biết sửa chỗ đó sẽ động đến vùng nào khác.
- Mục **Cạm bẫy đã biết** ghi lại các hack cố ý, spec lạc hậu, và chỗ dễ sửa sai.

## Lưu ý về độ tươi

Bản đồ được lập bằng cách đọc code thật tại commit ghi ở đầu mỗi file. Khi một file
nói tới class/route/flag cụ thể, **xác minh nó còn tồn tại** trước khi dựa vào.
Sau các thay đổi lớn, cập nhật lại file tương ứng và đổi dòng commit ở đầu file.
