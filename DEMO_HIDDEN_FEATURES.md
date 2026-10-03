# ⚠️ Sidebar tạm ẩn tính năng để demo khách hàng

**Ngày ẩn:** 2026-09-07
**Lý do:** Demo Dashboard cho khách hàng, chỉ hiển thị đúng những tính năng đã có trong tài liệu `Tekomi_Connect.docx` (mục 4.1 → 4.8). Các tính năng khác trong sản phẩm thật vẫn tồn tại và hoạt động bình thường — chỉ bị **ẩn khỏi sidebar**, không xoá, không tắt logic.

**File đã sửa:** `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`
(tìm comment `TEMP DEMO FILTER` gần cuối hàm `menuItems`)

## Cách khôi phục lại sidebar đầy đủ

Mở file trên, tìm dòng:

```js
const DEMO_MODE = true;
```

Đổi thành:

```js
const DEMO_MODE = false;
```

Lưu lại — toàn bộ sidebar sẽ trở về đầy đủ như cũ ngay lập tức. Sau khi xác nhận ổn, có thể xoá luôn cả khối code `TEMP DEMO FILTER` (từ dòng comment `====` đầu tiên đến hết) và đổi dòng `const items = [` ở đầu hàm `menuItems` lại thành `return [` để dọn sạch code.

## Danh sách đã ẩn

**Menu cấp cao:**
- Calls
- Companies
- Portals (Help Center)

**Đã bỏ ẩn (2026-09-22):** Reports — khách cần xem báo cáo, nên đã gỡ khỏi danh sách ẩn (`DEMO_HIDDEN_TOP_LEVEL`) trong khi các mục khác vẫn giữ nguyên trạng thái ẩn.

**Đã bỏ ẩn (2026-10-03):** Custom Roles — quản trị viên cần quản lý vai trò và phân quyền theo account.

**Menu con trong Settings (5 mục):**
- Templates (WhatsApp)
- Data (Import/Export)
- Audit Logs
- Security
- Billing

**Giữ lại:** Home, Inbox, Conversation, Contacts, Campaigns, Reports, Tekomi AI, Account Settings, Agents, Teams, Inboxes, Labels, Custom Attributes, Automation, Agent Bots, Macros, Canned Responses, Integrations, Custom Roles, SLA, Conversation Workflow và Pipelines.

## Lưu ý cho phiên Claude Code sau

Nếu người dùng nhắc "khôi phục sidebar", "bỏ chế độ demo", hoặc tương tự — đọc file này trước, thực hiện đúng bước "Cách khôi phục" ở trên, sau đó **xoá file `DEMO_HIDDEN_FEATURES.md` này** vì nó chỉ có giá trị tạm thời.
