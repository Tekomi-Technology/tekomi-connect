# Bản đồ: Tích hợp CRM Perfex

> Lập tại commit `c37c7293a9` — ngày 2026-10-03
> Bản đồ có thể lạc hậu khi code đổi. Luôn kiểm chứng lại điểm then chốt trước khi kết luận.

## Tóm tắt

Tekomi Connect tích hợp một chiều-rưỡi với Perfex CRM (trong code gọi là "External Ticket System"):

1. **Đồng bộ danh bạ (kéo về)** — job theo giờ (`Crm::Perfex::SyncContactsJob`, cron `15 * * * *`) crawl toàn bộ `contacts` và `customers` của Perfex, cache vào Redis, upsert thành `Company` + `Contact` của Tekomi, rồi **khớp** (match) các contact chưa có ID Perfex theo email / số điện thoại.
2. **Khớp tức thời** — mỗi `Contact` mới tạo **có `phone_number`** sẽ enqueue `Crm::Perfex::MatchFromCacheJob` để khớp từ cache Redis (không gọi API).
3. **Gửi ticket (đẩy lên)** — agent mở dialog "Send conversation transcript", chọn "Send the Ticket to CRM system" → `POST .../conversations/:id/external_ticket` → `Crm::Perfex::TicketDeliveryJob` tạo ticket trong Perfex kèm transcript hội thoại.
4. **Đọc ticket (kéo về)** — panel "Tickets" trong sidebar hội thoại gọi `GET .../conversations/:id/crm_tickets`, controller đọc danh sách ticket id đã lưu trên `conversations.custom_attributes` rồi fetch chi tiết từng ticket từ Perfex.
5. **Trang "Danh bạ CRM"** (`/contacts-directory`) — cây Company → Contact, badge `CRM` cho contact đã khớp, nút "Sync CRM" kích hoạt force sync.
6. **Cấu hình** — 3 khoá `EXTERNAL_TICKET_*` qua Super Admin → Settings → "External Ticket System" (hoặc ENV fallback).

Không có code Perfex nào trong `enterprise/` — toàn bộ nằm ở OSS tree. Tuy nhiên trang "Danh bạ CRM" **phụ thuộc vào API `companies` chỉ tồn tại trong `enterprise/`** (xem phần Phụ thuộc chéo).

## Database

Không có bảng/cột riêng cho Perfex. Toàn bộ dữ liệu nhét vào các cột `jsonb` có sẵn.

| Bảng / cột | Vai trò |
| --- | --- |
| `contacts.additional_attributes` (jsonb) | Chứa `external` (ID Perfex) và `crm` (tên + mốc thời gian khớp/thất bại) |
| `contacts.company_id` (bigint, có index) | Trỏ tới `Company` được resolve từ `userid` (customer) của Perfex |
| `contacts.email`, `contacts.phone_number` | Khoá khớp. `email` có unique index theo account + index `lower(email)` |
| `companies.additional_attributes` (jsonb) | Chứa `external.perfex_customer_id` và `phonenumber` |
| `companies.name` | Lấy từ `customer['company']`, fallback `"Perfex #<userid>"` |
| `conversations.custom_attributes` (jsonb) | Chứa `crm_tickets` (mảng ticket đã gửi), `crm_ticket` (dạng cũ, 1 ticket), `crm_ticket_error`, `crm_ticket_failed_at` |

### Cấu trúc JSON — `contacts.additional_attributes`

```json
{
  "external": {
    "perfex_contact_id": "123",
    "perfex_customer_id": "45"
  },
  "crm": {
    "name": "Nguyen Van A",
    "matched_at": "2026-10-03T10:00:00+07:00",
    "match_failed_at": "2026-10-03T09:00:00+07:00"
  }
}
```

- `external.perfex_contact_id` — `id` của record `contacts` trong Perfex. **Đây là cờ "đã khớp"** mà toàn bộ hệ thống (backend, frontend, job) dùng để quyết định.
- `external.perfex_customer_id` — `userid` (customer/company) trong Perfex.
- `crm.name` — `"#{firstname} #{lastname}".strip` từ Perfex, dùng để hiển thị tên "thật" cạnh tên kênh (`crmDisplayHelper.js`).
- `crm.matched_at` / `crm.match_failed_at` — hai khoá loại trừ nhau: khi khớp thành công `match_failed_at` bị `delete`; khi thất bại chỉ ghi `match_failed_at`.
- Lưu ý kiểu dữ liệu: `ContactMatcherService#mark_matched` ghi `perfex_contact_id` **nguyên kiểu từ JSON API** (có thể là `Integer`), còn `ContactSyncService#sync_contact` ghi `.to_s` (String). → cùng một khoá có thể là số hoặc chuỗi tuỳ đường vào (xem Cạm bẫy).

### Cấu trúc JSON — `companies.additional_attributes`

```json
{
  "phonenumber": "0901234567",
  "external": { "perfex_customer_id": "45" }
}
```

`perfex_customer_id` ở đây **luôn là String** (`userid.to_s` trong cả `CompanySyncService` và `CompanyResolverService`).

### Cấu trúc JSON — `conversations.custom_attributes`

```json
{
  "crm_tickets": [
    { "ticket_id": "77", "sent_at": "2026-10-03T10:00:00+07:00", "session_at": "2026-10-03T09:50:00+07:00" }
  ],
  "crm_ticket_error": "Perfex CRM API error: 500 - ...",
  "crm_ticket_failed_at": "2026-10-03T10:00:00+07:00"
}
```

- `crm_tickets` — mảng, append-only, dedupe theo `ticket_id`; `ticket_id` luôn String.
- `crm_ticket` (Hash, số ít) — **dạng cũ**, không còn được ghi mới. `Crm::Perfex::ConversationTickets.entries` normalise cả hai dạng; khi ghi delivery mới, khoá `crm_ticket` bị xoá (`.except('crm_ticket')`).
- `session_at` = `conversation.status_changed_at&.iso8601` (hiện không thấy nơi nào đọc lại giá trị này).
- `crm_ticket_error` / `crm_ticket_failed_at` — chỉ ghi khi `retry_on` đã cạn 5 lần thử; bị xoá khi có delivery thành công sau đó.

## Backend

| File | Vai trò |
| --- | --- |
| `app/services/crm/perfex/config.rb` | Đọc 3 khoá cấu hình qua `GlobalConfigService`. `configured?` = có `system_url` **và** `api_key` (department_id không bắt buộc) |
| `app/services/crm/perfex/api/base_client.rb` | HTTParty client. `get`/`post`, header `Authorization: Bearer <api_key>`, `Content-Type: application/json`. Raise `ApiError(message, code, response)` khi non-2xx, khi JSON lỗi, hoặc khi body có `success == false` |
| `app/services/crm/perfex/api/contact_client.rb` | `fetch_all_contacts` — phân trang `per_page: 100`, dừng khi batch rỗng hoặc đã lấy đủ `meta.total` |
| `app/services/crm/perfex/api/customer_client.rb` | `show(userid)`, `fetch_all_customers` (phân trang giống trên) |
| `app/services/crm/perfex/api/ticket_client.rb` | `create_ticket(subject:, message:, department:, userid:, contactid: nil)`, `fetch_ticket(id)` |
| `app/services/crm/perfex/directory_cache_service.rb` | Cache danh bạ contact Perfex trong Redis. Key `crm:perfex:directory:v1`, TTL 24h, chỉ lưu `id userid firstname lastname email phonenumber`. API: `peek` (chỉ đọc, nil nếu lạnh), `fetch_all` (đọc hoặc crawl + ghi), `refresh!` (crawl lại) |
| `app/services/crm/perfex/customer_directory_cache_service.rb` | Subclass; key `crm:perfex:customer-directory:v1`, fields `userid company phonenumber`, nguồn `fetch_all_customers`. **Dùng chung `TTL` 24h của lớp cha** |
| `app/services/crm/perfex/contact_matcher_service.rb` | Khớp `Contact` của Tekomi với contact Perfex. Build map email (lowercase) + map phone (normalize). Ưu tiên email trước, rồi phone. Ghi `external`/`crm`, resolve `company_id` |
| `app/services/crm/perfex/company_resolver_service.rb` | `userid` → `Company`. Tìm theo `external.perfex_customer_id`, nếu không có thì `customer_client.show(userid)` rồi tạo. Có cache in-memory theo `[account_id, userid]` trong 1 instance |
| `app/services/crm/perfex/contact_sync_service.rb` | Upsert `Contact` từ danh bạ Perfex, theo từng account. Preload 3 map (theo perfex_contact_id, theo email, companies theo perfex_customer_id) để tránh N+1 |
| `app/services/crm/perfex/company_sync_service.rb` | Upsert `Company` từ danh bạ customer Perfex, theo từng account |
| `app/services/crm/perfex/contact_channel_unmapper.rb` | "Tách khách hàng": tạo contact mới (tên = `contact_inbox.source_id`) và chuyển toàn bộ `contact_inbox` + conversations + messages + `PhoneCall` + `CsatSurveyResponse` (+ `::Call` nếu định nghĩa) sang contact mới. Chạy trong transaction với `lock!` |
| `app/services/crm/perfex/conversation_tickets.rb` | Normalise `custom_attributes` → mảng `{ticket_id, sent_at, session_at}`, hỗ trợ cả `crm_tickets` (mới) và `crm_ticket` (cũ) |
| `app/services/crm/perfex/mappers/ticket_message_formatter.rb` | Dựng HTML transcript cho body ticket. Giới hạn `ACTIVITY_NOTE_MAX_SIZE = 1800` ký tự, lấy tin **mới nhất trước** (`reverse_each`), escape HTML, `\n` → `<br>`, force locale `:en` |
| `app/jobs/crm/perfex/sync_contacts_job.rb` | Job theo giờ. Queue `scheduled_jobs`. Redis lock `crm:perfex:directory-sync:lock` TTL 15 phút. `refresh!` cả 2 cache → sync companies → sync contacts → match tất cả contact chưa có `perfex_contact_id` (toàn hệ thống, không scope account) |
| `app/jobs/crm/perfex/match_from_cache_job.rb` | Queue `default`. Khớp 1 contact từ cache (`peek`), thoát ngay nếu chưa cấu hình / contact không tồn tại / đã khớp / cache lạnh |
| `app/jobs/crm/perfex/ticket_delivery_job.rb` | Queue `medium`. `retry_on ApiError` 5 lần, backoff `:polynomially_longer`; block retry cuối ghi `crm_ticket_error`/`crm_ticket_failed_at`. `DEFAULT_CUSTOMER_ID = 1` làm fallback cho `userid` (có `# TODO: demo tam thoi`) |
| `lib/phone_number_normalizer.rb` | `normalize` — bỏ ký tự không phải số, bỏ prefix `84`, bỏ prefix `0`. Khoá so sánh hướng VN |
| `app/models/contact.rb:52,209` | `after_commit :enqueue_crm_cache_match, on: :create, if: :phone_number` → enqueue `MatchFromCacheJob`. Rescue `StandardError` và chỉ log |
| `app/controllers/api/v1/accounts/contacts_controller.rb` | `match_crm`, `unmap_crm`, `crm_force_sync`, helper `cache_age_minutes` |
| `app/controllers/api/v1/accounts/conversations_controller.rb:82-88` | `external_ticket` — chặn nếu contact chưa có `perfex_contact_id`, rồi `TicketDeliveryJob.perform_later` |
| `app/controllers/api/v1/accounts/conversations/crm_tickets_controller.rb` | `index` — đọc ticket từ Perfex, bỏ qua ticket lỗi/đã xoá |
| `app/controllers/concerns/crm_tickets_feature_concern.rb` | Chặn nếu account chưa bật feature `crm_tickets` |
| `app/controllers/super_admin/app_configs_controller.rb:59` | Mapping `'perfex' => %w[EXTERNAL_TICKET_SYSTEM_URL EXTERNAL_TICKET_SYSTEM_API_KEY EXTERNAL_TICKET_DEPARTMENT_ID]` |
| `app/policies/contact_policy.rb` | `match_crm?`, `unmap_crm?`, `crm_force_sync?` đều `true` (mọi role có quyền) |
| `config/schedule.yml:30-33` | Cron `15 * * * *` cho `Crm::Perfex::SyncContactsJob` |
| `app/helpers/super_admin/features.yml:154-159` | Entry `perfex` → tên hiển thị "External Ticket System", icon `icon-ticket`, `config_key: 'perfex'` |

## API Perfex được gọi

Base URL = `EXTERNAL_TICKET_SYSTEM_URL` (ví dụ mô tả trong `installation_config.yml`: `https://crm.example.com/rest_api/v1/`). Path được ghép bằng `URI.join`.

| Endpoint | Client nào gọi | Dùng làm gì |
| --- | --- | --- |
| `GET contacts?page=N&per_page=100` | `Api::ContactClient#fetch_all_contacts` | Crawl toàn bộ contact Perfex để cache + khớp + upsert |
| `GET customers?page=N&per_page=100` | `Api::CustomerClient#fetch_all_customers` | Crawl toàn bộ customer (company) để cache + upsert `Company` |
| `GET customers/:userid` | `Api::CustomerClient#show` | `CompanyResolverService` tạo `Company` lần đầu khi khớp contact (lấy `company`, `phonenumber`) |
| `POST tickets` | `Api::TicketClient#create_ticket` | Tạo ticket. Body: `{subject, message, department, userid, contactid?}` |
| `GET tickets/:id` | `Api::TicketClient#fetch_ticket` | Lấy chi tiết ticket cho panel "Tickets" |

Trường đọc từ response ticket: `ticketid`, `subject`, `status`, `priority`, `department`, `date`, `lastreply` (xem `crm_tickets_controller.rb:27`). Khi tạo ticket, ID lấy từ `data['ticketid'] || data['id']`.

## API nội bộ / Route

| Method | Path | Controller#action | Ghi chú |
| --- | --- | --- | --- |
| `POST` | `/api/v1/accounts/:account_id/contacts/:id/match_crm` | `contacts#match_crm` | Khớp 1 contact **đồng bộ** (gọi API Perfex ngay nếu cache lạnh). Trả về `additional_attributes` của contact. Lỗi API → `502` + `{error: 'crm_unreachable'}` |
| `DELETE` | `/api/v1/accounts/:account_id/contacts/:id/unmap_crm?conversation_id=<display_id>` | `contacts#unmap_crm` | Tách kênh khỏi contact CRM. Render view `show`. Lỗi `UnmapError` → `422` + message |
| `POST` | `/api/v1/accounts/:account_id/contacts/crm_force_sync` | `contacts#crm_force_sync` | Enqueue `SyncContactsJob` nếu lock chưa giữ. `202` + `{running, cache_age_minutes}`. Lỗi Redis → `503` + `{error: 'crm_sync_unavailable'}` |
| `POST` | `/api/v1/accounts/:account_id/contacts/:id/crm_force_sync` | `contacts#crm_force_sync` | **Route trùng** cũng được khai báo ở `member` (`config/routes.rb:262`); frontend chỉ dùng bản `collection` |
| `POST` | `/api/v1/accounts/:account_id/conversations/:id/external_ticket` | `conversations#external_ticket` | `422` nếu contact chưa khớp CRM, ngược lại `head :ok` và enqueue job |
| `GET` | `/api/v1/accounts/:account_id/conversations/:conversation_id/crm_tickets` | `conversations/crm_tickets#index` | `{payload: [...]}`. Trả `[]` nếu không có ticket hoặc chưa cấu hình. Chặn bởi feature `crm_tickets` → `Pundit::NotAuthorizedError` |
| `GET/POST` | `/super_admin/app_config?config=perfex` | `super_admin/app_configs#show/#create` | Form cấu hình 3 khoá |

Route liên quan (Enterprise, mà trang Danh bạ CRM phụ thuộc): `GET /api/v1/accounts/:id/companies`, `GET .../companies/:id/contacts`.

## Frontend

| File | Vai trò |
| --- | --- |
| `app/javascript/dashboard/components-next/Contacts/CrmDirectory/Index.vue` | Trang "Danh bạ CRM". Cây Company có thể mở/đóng + nhóm "Ungrouped contacts". Badge `CRM` nếu `additional_attributes.external.perfex_contact_id`. Nút "Sync CRM" → `contacts/crmForceSync` |
| `app/javascript/dashboard/components/widgets/conversation/CrmInfoPanel.vue` | Accordion "CRM Information" trong sidebar hội thoại. Hiển thị `crm.name` + `CRM ID`, nút "Detach customer" (`unmap_crm`). Khi chưa khớp: "Unidentified customer", nút "Sync CRM" (force sync + polling 5s/180s qua `matchCrm`) và "Attach to customer" (tìm contact rồi `contacts/merge`) |
| `app/javascript/dashboard/components-next/Tickets/ConversationTickets.vue` | Panel "Tickets" (read-only). Watch `conversationId` + JSON của `custom_attributes.crm_tickets || crm_ticket`, gọi `CrmTicketsAPI.getByConversation`, emit `loaded(count)` |
| `app/javascript/dashboard/components/widgets/conversation/EmailTranscriptModal.vue` | Dialog gửi transcript. Radio `other_system` = "Send the Ticket to CRM system", **disabled** khi `isCrmMatched` false (đọc `external.perfex_contact_id` của sender). Có textarea `note` |
| `app/javascript/dashboard/api/contacts.js:52-64` | `matchCrm`, `unmapCrm`, `crmForceSync` |
| `app/javascript/dashboard/api/crmTickets.js` | `getByConversation(conversationId)` |
| `app/javascript/dashboard/api/inbox/conversation.js:119-123` | `sendConversationToExternalSystem({conversationId, note})` |
| `app/javascript/dashboard/store/modules/contacts/actions.js:244-263` | `matchCrm` (commit `SET_CONTACT_ITEM` với `additional_attributes` từ response), `crmForceSync` (trả raw `response.data`) |
| `app/javascript/dashboard/store/modules/conversations/actions.js:506` | `sendConversationToExternalSystem` |
| `app/javascript/dashboard/helper/crmDisplayHelper.js` | `getMappedContactName` (đọc `additional_attributes.crm.name`), `getSenderDisplayName` → `"Zalo User 123 (Nguyễn Văn A)"` |
| `app/javascript/dashboard/routes/dashboard/conversation/ContactPanel.vue` | Render section `crm_info` (`CrmInfoPanel`) và `tickets` (`ConversationTickets`). `sectionHasData.crm_info` dựa trên `external.perfex_contact_id` → chỉ **mở sẵn** accordion, không ẩn |
| `app/javascript/dashboard/components-next/Companies/ConversationPanel/CompanyPanel.vue:54-79` | Hiển thị row "CRM ID" từ `additionalAttributes.external.perfexCustomerId` (camelCase sau khi deserialize) |
| `app/javascript/dashboard/routes/dashboard/contacts/routes.js:42-48` | Route `crm_directory_index` tại `accounts/:accountId/contacts-directory`, meta `featureFlag: FEATURE_FLAGS.CRM` |
| `app/javascript/dashboard/components-next/sidebar/Sidebar.vue:669-674` | Item sidebar "CRM Directory", icon `i-lucide-building-2` |

## Điểm vào trên giao diện

1. **Sidebar → Contacts → "CRM Directory"** → `/accounts/:id/contacts-directory`. Nút "Sync CRM" ở góc phải header.
2. **Sidebar hội thoại → accordion "CRM Information"** → `CrmInfoPanel`: xem CRM ID, "Detach customer", "Sync CRM", "Attach to customer".
3. **Sidebar hội thoại → accordion "Tickets"** → danh sách ticket Perfex (cần feature `crm_tickets`).
4. **Menu hội thoại → "Send conversation transcript"** → chọn radio "Send the Ticket to CRM system" + ghi chú → gửi ticket. Radio bị khoá kèm hint "Match this contact with the CRM in the sidebar before sending" nếu contact chưa khớp.
5. **Panel Company trong hội thoại** → row "CRM ID".
6. **Super Admin → Settings → "External Ticket System"** → form 3 khoá cấu hình.

## Luồng dữ liệu chính

### A. Luồng đồng bộ danh bạ (theo giờ)

```
Cron 15 * * * * (config/schedule.yml)
  └─ Crm::Perfex::SyncContactsJob#perform          [queue: scheduled_jobs]
       ├─ return unless Config.configured?          ← thoát im lặng nếu thiếu URL/API key
       ├─ Redis SET crm:perfex:directory-sync:lock NX EX 900
       │    └─ return unless acquired               ← thoát im lặng nếu job khác đang chạy
       ├─ DirectoryCacheService#refresh!            → GET contacts (phân trang 100)
       ├─ CustomerDirectoryCacheService#refresh!    → GET customers (phân trang 100)
       ├─ sync_companies: Account.find_each → CompanySyncService#sync(customers)
       │    → upsert Company theo external.perfex_customer_id
       ├─ sync_contacts:  Account.find_each → ContactSyncService#sync(perfex_contacts)
       │    → upsert Contact theo external.perfex_contact_id, bỏ qua nếu email đã tồn tại
       ├─ Contact.where("... perfex_contact_id IS NULL")   ← TOÀN BỘ account
       │    └─ ContactMatcherService#match_all
       │         ├─ email_map / phone_map từ cache
       │         ├─ khớp email (lowercase) → fallback khớp phone (normalize VN)
       │         ├─ match → mark_matched: ghi external + crm.name + crm.matched_at,
       │         │                        xoá crm.match_failed_at,
       │         │                        CompanyResolverService#resolve → company_id
       │         └─ miss  → mark_failed: ghi crm.match_failed_at (idempotent)
       ├─ rescue ApiError → chỉ Rails.logger.error
       └─ ensure: Redis DEL lock
```

### B. Luồng khớp tức thời (contact mới)

```
Contact#create (có phone_number)
  └─ after_commit enqueue_crm_cache_match
       └─ Crm::Perfex::MatchFromCacheJob#perform(contact_id)   [queue: default]
            ├─ return unless Config.configured?
            ├─ return if contact nil || đã có external.perfex_contact_id
            ├─ DirectoryCacheService#peek                      ← CHỈ đọc cache
            │    └─ return if cache lạnh                       ← thoát im lặng
            └─ ContactMatcherService#match_one(contact, cached)
```

### C. Luồng khớp thủ công / force sync (từ UI)

```
CrmInfoPanel "Sync CRM"
  └─ POST contacts/crm_force_sync
       ├─ Redis EXISTS lock → running?
       ├─ SyncContactsJob.perform_later nếu !running
       └─ 202 { running, cache_age_minutes }       ← cache_age từ TTL của crm:perfex:directory:v1
  └─ setInterval 5s (tối đa 180s): POST contacts/:id/match_crm
       └─ ContactMatcherService#match_one(contact)  ← fetch_all: crawl Perfex nếu cache lạnh
```

### D. Luồng gửi ticket

```
EmailTranscriptModal: chọn "other_system" + note → onSubmit
  └─ store: sendConversationToExternalSystem
       └─ POST conversations/:display_id/external_ticket { note }
            ├─ 422 nếu contact.additional_attributes.external.perfex_contact_id blank
            └─ Crm::Perfex::TicketDeliveryJob.perform_later(conversation, note)   [queue: medium]
                 ├─ return if contact_id blank                 ← kiểm tra lần 2
                 ├─ TicketMessageFormatter.transcript_text(conversation)
                 │    ├─ I18n.with_locale(:en)
                 │    ├─ messages.chat.select(&:conversation_transcriptable?)
                 │    ├─ reverse_each, cắt ở 1800 ký tự (giữ tin MỚI NHẤT)
                 │    ├─ escape HTML, "\n" → "<br>"
                 │    └─ i18n key crm.ticket_message
                 ├─ message = transcript + "<br><br>---<br>Ghi chú: " + escape(note)
                 ├─ POST tickets { subject, message, department, userid, contactid }
                 │    ├─ subject = "[<BRAND_NAME|GMO> Chatbot] <company> - <contact.name>"
                 │    └─ userid  = external.perfex_customer_id || 1 (DEFAULT_CUSTOMER_ID)
                 └─ record_delivery: custom_attributes
                      ├─ xoá crm_ticket_error / crm_ticket_failed_at / crm_ticket
                      └─ append vào crm_tickets [{ticket_id, sent_at, session_at}]
   (nếu ApiError 5 lần: retry_on block ghi crm_ticket_error + crm_ticket_failed_at)
```

### E. Luồng đọc ticket

```
ContactPanel accordion "Tickets" (nếu feature crm_tickets bật)
  └─ ConversationTickets.vue: watch([conversationId, ticketRefs]) immediate
       └─ GET conversations/:display_id/crm_tickets
            ├─ before_action: raise Pundit::NotAuthorizedError nếu !feature_enabled?('crm_tickets')
            ├─ ConversationTickets.entries(custom_attributes)  ← normalise crm_tickets / crm_ticket
            ├─ return { payload: [] } nếu rỗng HOẶC !Config.configured?
            └─ entries.reverse.filter_map → GET tickets/:id cho TỪNG ticket
                 ├─ slice ticketid/subject/status/priority/department/date/lastreply + sent_at
                 └─ rescue ApiError → Rails.logger.warn + nil (ticket bị xoá không làm hỏng panel)
```

### F. Luồng tách khách hàng (unmap)

```
CrmInfoPanel "Detach customer" (ConfirmButton)
  └─ DELETE contacts/:id/unmap_crm?conversation_id=<display_id>
       └─ ContactChannelUnmapper#perform (transaction + lock!)
            ├─ validate!: contact thuộc account, conversation thuộc contact, có perfex_contact_id
            ├─ tạo Contact mới: name = contact_inbox.source_id, last_activity_at = max
            ├─ contact_inbox.update!(contact: detached)
            ├─ conversations.update_all(contact_id: detached)   ← cùng contact_inbox_id
            ├─ Message (sender_type Contact).update_all(sender_id: detached)
            └─ PhoneCall / CsatSurveyResponse / ::Call .update_all(contact_id: detached)
       └─ store.dispatch('getConversation', conversationId) để refresh
```

## Cấu hình

| Khoá | Mô tả | Nơi đặt |
| --- | --- | --- |
| `EXTERNAL_TICKET_SYSTEM_URL` | Base REST API URL của Perfex, ví dụ `https://crm.example.com/rest_api/v1/` | Super Admin → Settings → "External Ticket System", hoặc ENV |
| `EXTERNAL_TICKET_SYSTEM_API_KEY` | API key (`type: secret` → render thành password field có nút hiện/ẩn) | như trên |
| `EXTERNAL_TICKET_DEPARTMENT_ID` | Department mọi ticket được nộp vào | như trên |

- Khai báo: `config/installation_config.yml:456-472`, cả 3 đều `locked: false`, `value: ''`.
- Whitelist Super Admin: `app/controllers/super_admin/app_configs_controller.rb:59`.
- Entry menu Super Admin: `app/helpers/super_admin/features.yml:154-159` (tên hiển thị "External Ticket System"; bản dịch VI ở `config/locales/vi.yml:878-880`).
- **Thứ tự ưu tiên** (`lib/global_config_service.rb`):
  1. `GlobalConfig.get(key)[key]` — tức row `InstallationConfig` (sửa được từ Super Admin). Nếu `present?` → dùng.
  2. Nếu rỗng → `ENV.fetch(key) { default }`. `Crm::Perfex::Config` truyền `default = ''`.
  3. Nếu lấy được từ ENV → **tự tạo row `InstallationConfig`** rồi `GlobalConfig.clear_cache`. Nghĩa là giá trị ENV bị "đóng băng" vào DB ở lần đọc đầu; thay đổi ENV sau đó **không** có tác dụng.
- `Crm::Perfex::Config.configured?` chỉ cần `system_url` + `api_key`. `department_id` rỗng vẫn gửi ticket (truyền `department: ''` cho Perfex).
- `BRAND_NAME` (config riêng) ảnh hưởng tới subject ticket (`GlobalConfigService.load('BRAND_NAME', 'GMO')`) và nội dung transcript (`GlobalConfig.get('BRAND_NAME')['BRAND_NAME'] || 'Chatwoot'`).

## Feature flag

| Flag | Khai báo | Ảnh hưởng gì |
| --- | --- | --- |
| `crm_tickets` | `config/features.yml:261` (`enabled: false`, `column: feature_flags_ext_1`) | Bắt buộc cho `GET .../crm_tickets` (qua `CrmTicketsFeatureConcern`) và cho việc render accordion "Tickets" (`ContactPanel.vue:372`) |
| `crm` (`FEATURE_FLAGS.CRM`) | `app/javascript/dashboard/featureFlags.js:14` | Meta của route `crm_directory_index` và toàn bộ route contacts |
| `companies` | kiểm tra ở `enterprise/app/controllers/api/v1/accounts/companies_controller.rb:77` | **Không được kiểm tra ở frontend trang Danh bạ CRM.** Nếu tắt → API trả `403` → trang hiện alert lỗi |
| `crm_v2` | `config/features.yml:181` (`chatwoot_internal: true`) | Đổi `Contact.resolved_contacts` sang `where(contact_type: 'lead')` → ảnh hưởng danh sách "Ungrouped contacts" của trang Danh bạ CRM |

**Không có feature flag nào gate các action `match_crm` / `unmap_crm` / `crm_force_sync` / `external_ticket`.** Chúng chỉ gate bằng `Config.configured?` ở tầng job/service (và `match_crm` thì không gate gì cả — xem Cạm bẫy).

## i18n

### Backend (`config/locales/en.yml:577-602`, namespace `crm:`)

| Khoá | Dùng ở |
| --- | --- |
| `crm.no_message` | `TicketMessageFormatter` khi không có message nào |
| `crm.attachment` (`[Attachment: %{type}]`) | mỗi message có attachment |
| `crm.no_content` (`[No content]`) | message rỗng nội dung |
| `crm.ticket_message` | template body ticket; params `channel_info`, `company_line`, `brand_name`, `url`, `format_messages` |
| `crm.created_activity`, `crm.transcript_activity` | **Không thấy nơi nào dùng trong luồng Perfex** (có thể là di sản LeadSquared) |

`config/locales/vi.yml:539+` có cùng block `crm:` nhưng nội dung vẫn là tiếng Anh. Không quan trọng vì formatter force `I18n.with_locale(:en)`.

Chuỗi hardcode: `"Ghi chú: "` trong `ticket_delivery_job.rb:23` và `"\nCompany: "` trong `ticket_message_formatter.rb:88` **không qua i18n**.

### Frontend (`app/javascript/dashboard/i18n/locale/en/`)

| Khoá | File |
| --- | --- |
| `CRM_DIRECTORY.*` (TITLE, SUBTITLE, SYNC_BUTTON, SYNC_STARTED, SYNC_STARTED_FIRST_TIME, LOADING, NO_CONTACTS, UNGROUPED) | `settings.json:1076` |
| `SIDEBAR.CRM_DIRECTORY` | `settings.json:367` |
| `CONVERSATION_SIDEBAR.ACCORDION.CRM_INFO` | `conversation.json` |
| `CONVERSATION_SIDEBAR.CRM_INFO.*` (USERID_LABEL, USERID_WITH_VALUE, UNIDENTIFIED, FORCE_SYNC, FORCE_SYNC_STARTED, FORCE_SYNC_TIMEOUT, ASSIGN_TO_CUSTOMER, ASSIGN_SEARCH_PLACEHOLDER, CHANNEL_MERGED, UNMAP, UNMAP_CONFIRM, CHANNEL_UNMAPPED, UNMAP_ERROR, NOT_FOUND) | `conversation.json` |
| `EMAIL_TRANSCRIPT.FORM.SEND_TO_EXTERNAL_SYSTEM`, `.EXTERNAL_SYSTEM_DISABLED_HINT`, `.NOTE.PLACEHOLDER` | `conversation.json` |
| `EMAIL_TRANSCRIPT.SEND_EXTERNAL_SYSTEM_SUCCESS` / `_ERROR` | `conversation.json` |
| `TICKETS.CONVERSATION.*` (TITLE, EMPTY, LOAD_ERROR, ...) | `tickets.json` — **dùng chung với CRM Tickets nội bộ** (`crm_deals`/`tickets` pipeline), không riêng Perfex |

`CONVERSATION_SIDEBAR.CRM_INFO` đã có bản dịch VI.

## ⚠️ Phụ thuộc chéo

1. **Trang "Danh bạ CRM" phụ thuộc API `companies` chỉ có trong `enterprise/`.**
   `CrmDirectory/Index.vue` gọi `CompanyAPI.get` và `CompanyAPI.listContacts`. Controller `Api::V1::Accounts::CompaniesController` **chỉ tồn tại** ở `enterprise/app/controllers/api/v1/accounts/companies_controller.rb` (kế thừa `EnterpriseAccountsController`), nhưng route `resources :companies` trong `config/routes.rb:229` **không** được bọc `if ChatwootApp.enterprise?`. Hệ quả: trong build OSS thuần, route tồn tại nhưng controller không → trang Danh bạ CRM sẽ lỗi. Ngoài ra controller còn gate bằng feature `companies` (trả `403`), mà frontend không kiểm tra flag này.

2. **`Company` là tài sản Enterprise nhưng bị OSS service ghi trực tiếp.**
   `CompanySyncService` và `CompanyResolverService` (ở `app/services/`, tức OSS) `create!` record `Company` và ghi `additional_attributes`. Nếu Enterprise thêm validation/callback cho `Company`, hai service OSS này sẽ bị ảnh hưởng. Trường `vip` trong jbuilder Enterprise không được Perfex sync điền.

3. **`Contact#after_commit :enqueue_crm_cache_match` chạy cho MỌI contact mới có `phone_number`, trên MỌI account.**
   Mọi inbox (Zalo, WhatsApp, Telegram, widget…) tạo contact có số điện thoại đều enqueue `MatchFromCacheJob`. Nếu Perfex chưa cấu hình, job chỉ `return` — nhưng vẫn tốn một job cho mỗi contact. Không có kiểm tra "account này có dùng Perfex không".

4. **`SyncContactsJob` là job toàn cục (không scope account).**
   Nó `Account.find_each` rồi đổ **cùng một** danh bạ Perfex vào **mọi** account trong instance, và `Contact.where(... IS NULL)` quét toàn bộ bảng `contacts` không giới hạn account. Trên instance multi-tenant, dữ liệu CRM của một khách bị nhân bản sang toàn bộ account khác. Đây là thiết kế single-tenant ngầm định.

5. **Nút "Attach to customer" dùng `ContactMergeAction` chung của Chatwoot, không phải code Perfex.**
   `CrmInfoPanel.assignTo` → `contacts/merge`. `ContactMergeAction#merge_and_remove_mergee_contact` deep_merge `additional_attributes` (ưu tiên base contact) và `except('mapped_contact_id', 'mapped_contact_name')`. Nghĩa là `external.perfex_contact_id` của mergee **được thừa hưởng** nếu base chưa có. `preserve_company` giữ `company_id`. Thay đổi `ContactMergeAction` sẽ ảnh hưởng luồng gán khách hàng Perfex.

6. **`ContactChannelUnmapper` chạm vào 5 bảng khác nhau** (`contact_inboxes`, `conversations`, `messages`, `phone_calls`, `csat_survey_responses`, và `calls` nếu `defined?(::Call)`). Thêm bảng mới tham chiếu `contact_id` theo conversation (deals, tickets nội bộ, notes…) mà không cập nhật unmapper sẽ để lại dữ liệu trỏ sai contact. Hiện `Note`, `Deal`, `Ticket` **không** được xử lý.

7. **`conversations.custom_attributes` là không gian dùng chung.**
   Perfex chiếm 4 khoá (`crm_tickets`, `crm_ticket`, `crm_ticket_error`, `crm_ticket_failed_at`). `ConversationCustomAttributesConcern` / `POST .../custom_attributes` cho phép agent và automation ghi tuỳ ý vào cùng cột → có thể ghi đè hoặc xoá tham chiếu ticket. Ngoài ra `ContactPanel.sectionHasData.conversation_info` coi **mọi** giá trị trong `custom_attributes` là dữ liệu → accordion "Conversation Information" tự mở chỉ vì có `crm_tickets`.

8. **`Redis::Alfred` ($alfred) là Redis chung.** 3 khoá: `crm:perfex:directory:v1`, `crm:perfex:customer-directory:v1`, `crm:perfex:directory-sync:lock`. Flush Redis → cache lạnh → `MatchFromCacheJob` thoát im lặng cho mọi contact mới cho tới lần cron kế tiếp.

9. **`TicketMessageFormatter` phụ thuộc `Rails.application.routes.url_helpers` + `app_account_conversation_url`** → cần `default_url_options`/`FRONTEND_URL` được cấu hình, nếu không sẽ raise khi build body ticket (và kích hoạt retry của job).

10. **`crm_tickets` feature flag dùng chung tên với CRM Tickets nội bộ** (pipeline/stage/deals của Tekomi, xem `CrmFeatureConcern`, `config/features.yml:261`). Bật/tắt flag này ảnh hưởng cả hai tính năng, và `TICKETS.CONVERSATION.*` i18n cũng dùng chung.

11. **`BRAND_NAME` ảnh hưởng subject ticket.** Đổi `BRAND_NAME` sẽ đổi prefix subject (`"[<BRAND> Chatbot]"`), phá vỡ mọi rule/filter phía Perfex dựa trên subject.

12. **`Crm::Perfex::Api::BaseClient::ApiError` được rescue ở 6 nơi khác nhau** (sync job, match job, contacts#match_crm, crm_tickets#index, CompanyResolverService, retry_on của TicketDeliveryJob). Thêm loại lỗi mới (ví dụ raise `ArgumentError`) sẽ không được bắt ở bất kỳ đâu.

## Cạm bẫy đã biết

### Nuốt lỗi / thoát im lặng

1. **`SyncContactsJob` thoát im lặng 2 lần** — `return unless Config.configured?` và `return unless acquired` (lock). Không log, không metric. Nếu lock bị kẹt (ví dụ process bị kill giữa `set` và `ensure`), lock tự hết sau 15 phút nhưng trong khoảng đó mọi lần cron + force sync đều no-op, và `crm_force_sync` trả `running: true` cho người dùng.
2. **`MatchFromCacheJob` thoát im lặng khi cache lạnh** (`return if cached.blank?`). Sau khi deploy mới / flush Redis, mọi contact mới sẽ **không** được khớp tới khi `SyncContactsJob` chạy (tối đa 1 giờ).
3. **`ApiError` ở `SyncContactsJob` chỉ `Rails.logger.error`** → job "thành công" trong mắt Sidekiq, không retry, không alert. Nếu Perfex down cả ngày sẽ không ai biết.
4. **`CompanyResolverService#create_company` rescue `ApiError` → trả `nil`** → contact được khớp nhưng `company_id` vẫn `nil`, không có cờ nào ghi lại. Lần match sau sẽ thử lại.
5. **`ContactMatcherService#mark_matched` rescue `ActiveRecord::RecordInvalid` → chỉ log + `contact.reload`** → match bị bỏ hoàn toàn, không đặt `match_failed_at`, nên UI hiển thị "Unidentified customer" **không kèm** thông báo "Could not find this customer in the CRM".
6. **`ContactSyncService` rescue `RecordInvalid` cho mỗi record** → contact Perfex bị bỏ im lặng (ví dụ email trùng khác account-case, số điện thoại không khớp regex `\A(\+[1-9]\d{1,14}|0\d{8,10})\z`). Số điện thoại Perfex dạng `84901234567` (không có `+`, không có `0`) sẽ **fail validation** và contact bị bỏ.
7. **`crm_tickets#index` rescue `ApiError` cho từng ticket → `nil`** → ticket đã xoá/không truy cập được **im lặng biến mất** khỏi panel, trong khi `custom_attributes.crm_tickets` vẫn giữ tham chiếu.
8. **`CrmInfoPanel.pollUntilMatched` có `catch` rỗng** (comment "keep polling") → lỗi `502 crm_unreachable` trong lúc poll bị ẩn hoàn toàn; người dùng chỉ thấy timeout sau 180s.
9. **`Contact#enqueue_crm_cache_match` rescue `StandardError`** → Redis/Sidekiq down không làm hỏng việc tạo contact, nhưng cũng không có cơ chế bù.
10. **`CrmDirectory/Index.vue` `useAlert(error.message)`** → với lỗi axios, `error.message` là `"Request failed with status code 403"`, không nói gì về feature `companies` bị tắt.

### Ghi đè / mất dữ liệu

11. **`ContactSyncService#update_existing_contact` GHI ĐÈ `email` và `phone_number` của Tekomi bằng giá trị Perfex** (`email: new_email || existing.email`). Đây là chiều ngược với `ContactMatcherService#mark_matched`, nơi có comment rõ ràng *"Locally managed fields (name, phone_number) are never overwritten with CRM values"*. → **Hai service cùng chạy trong một job nhưng áp dụng hai chính sách ngược nhau.** Contact nào đã có `external.perfex_contact_id` sẽ bị Perfex ghi đè email/phone mỗi giờ.
12. **`CompanySyncService` ghi đè `Company#name`** mỗi giờ bằng `customer['company']` (hoặc `"Perfex #<userid>"`). Mọi tên công ty chỉnh tay trong Tekomi bị xoá.
13. **`CompanySyncService` dùng `merge('phonenumber' => new_phone)`** — nếu Perfex trả `nil`, `additional_attributes['phonenumber']` bị set thành `nil` (khác với "giữ nguyên").
14. **`ContactSyncService#sync_contact` bỏ qua contact Perfex nếu email đã tồn tại ở Tekomi** nhưng **không** ghi `external.perfex_contact_id` lên contact đó → contact vẫn "chưa khớp" tới khi `ContactMatcherService#match_all` chạy sau đó trong cùng job (nó sẽ khớp theo email). Thứ tự này là bắt buộc; đảo ngược sẽ tạo contact trùng.
15. **`ContactChannelUnmapper` tạo contact mới không có email / phone / identifier** → contact đó **không nằm trong `Contact.resolved_contacts`** nên **biến mất khỏi danh sách Contacts và khỏi trang Danh bạ CRM**, dù vẫn giữ toàn bộ hội thoại. Chỉ truy cập được qua chính hội thoại đó.
16. **`matchCrm` store action commit `SET_CONTACT_ITEM` với TOÀN BỘ `additional_attributes` từ response** → thay thế (không merge) object này trong store Vuex.
17. **`record_delivery` dedupe theo `ticket_id` rồi append** → nếu Perfex trả cùng `ticketid` cho 2 lần gửi khác nhau, bản ghi `sent_at` đầu bị mất.

### Vấn đề kiểu dữ liệu / logic

18. **`perfex_contact_id` có 2 kiểu khác nhau.** `ContactMatcherService#mark_matched` ghi `perfex_contact['id']` nguyên bản (Integer từ JSON Perfex), còn `ContactSyncService` ghi `.to_s`. Query `additional_attributes -> 'external' ->> 'perfex_contact_id' IS NOT NULL` không quan tâm, nhưng `ContactSyncService` preload map bằng `.to_s` nên vẫn khớp. Tuy vậy bất kỳ so sánh `== "123"` ở Ruby/JS sẽ phụ thuộc đường vào. Tương tự `perfex_customer_id`: matcher ghi raw, sync ghi `.to_s`.
19. **Không có GIN index trên `contacts.additional_attributes` / `companies.additional_attributes`.** Cả 4 query dạng `additional_attributes -> 'external' ->> '...' IS NOT NULL` trong `SyncContactsJob`, `ContactSyncService`, `CompanySyncService`, `CompanyResolverService` sẽ là **sequential scan** trên toàn bảng, mỗi account, mỗi giờ. (Đã kiểm chứng `db/schema.rb`: chỉ có GIN index cho `messages.additional_attributes->'campaign_id'`.)
20. **`DirectoryCacheService` cache theo instance, không theo account** → đúng với thiết kế single-tenant, nhưng `CACHED_FIELDS` chỉ gồm 6 trường. Nếu muốn khớp theo trường khác phải bump `v1` thành `v2`, nếu không cache cũ sẽ trả object thiếu trường.
21. **`match_crm` (POST) KHÔNG kiểm tra `Config.configured?`.** Nếu chưa cấu hình, `base_url` là `''` → `URI.join('', 'contacts')` raise `URI::InvalidURIError` (hoặc `ArgumentError`), **không** phải `ApiError` → không được rescue → `500`.
22. **`external_ticket` KHÔNG kiểm tra `Config.configured?`** và cũng không gate feature flag. Job sẽ enqueue rồi fail với lỗi URI, chạy hết 5 lần retry, rồi ghi `crm_ticket_error`.
23. **`TicketDeliveryJob` fallback `userid: 1`** (`DEFAULT_CUSTOMER_ID`, kèm `# TODO: demo tam thoi`). Contact đã khớp `perfex_contact_id` nhưng thiếu `perfex_customer_id` sẽ nộp ticket vào **customer #1 của Perfex** — gần chắc là sai khách hàng.
24. **`department: Crm::Perfex::Config.department_id` có thể là `''`** vì `configured?` không yêu cầu khoá này.
25. **`TicketMessageFormatter#company_line` đọc `contact.additional_attributes['company_name']`** — nhưng luồng Perfex lưu công ty ở `contact.company_id` / `Company`, **không** ở `additional_attributes['company_name']`. → dòng "Company:" trong body ticket gần như **luôn rỗng** cho contact đồng bộ từ Perfex. (Ngược lại, `subject_for` thì dùng đúng `contact.company&.name`.)
26. **Transcript bị cắt ở 1800 ký tự và lấy từ MỚI NHẤT trở về trước**, nhưng join không đảo lại thứ tự → thứ tự tin nhắn trong ticket là **ngược thời gian** (mới → cũ).
27. **`TicketMessageFormatter` force `I18n.with_locale(:en)`** → nội dung ticket luôn tiếng Anh dù agent dùng VI; chỉ dòng `"Ghi chú:"` là tiếng Việt hardcode.
28. **`ContactMatcherService#build_maps` có lỗi logic nhỏ**: `normalized = normalize(...) if ...present?` — nếu `phonenumber` rỗng, `normalized` **giữ giá trị của vòng lặp trước** (biến local tồn tại qua các iteration của block `each`? thực tế không — `normalized` là local của block nên reset mỗi lần; **đã kiểm chứng là an toàn**). Nhưng khi 2 contact Perfex có cùng email/phone, map chỉ giữ **bản cuối** — không có cảnh báo trùng.
29. **`mark_failed` chỉ ghi `match_failed_at` một lần** nhưng điều kiện là `perfex_contact_id.blank? && match_failed_at.present?`. Contact đã khớp rồi sau đó mất khớp (contact bị xoá ở Perfex) sẽ **bị ghi lại `match_failed_at` mỗi giờ** vì `perfex_contact_id` vẫn present → `already_failed` false → `update!` mỗi lần. Write amplification.
30. **`CrmDirectory/Index.vue` `toggleCompany` chỉ fetch TRANG 1** của `listContacts` (`RESULTS_PER_PAGE = 15` ở `enterprise/.../companies/contacts_controller.rb`). Company có 40 contact sẽ chỉ hiện 15, dù badge count hiện `40`. Không có "load more".
31. **Điều kiện dừng phân trang `rows.length < 15` trong `CrmDirectory`** không khớp với `RESULTS_PER_PAGE = 25` của `CompaniesController` → mỗi lần load tốn thêm 1 request thừa (hội tụ nhờ `page > 50` và trang rỗng, nên không treo).
32. **`fetchUngrouped` dùng `company_id: 'none'` + `resolved_contacts`** → chỉ gồm contact có email/phone/identifier. Contact tạo bởi unmapper (xem #15) không xuất hiện. Nếu account bật `crm_v2` thì danh sách này đổi hẳn thành `contact_type: 'lead'`.
33. **`crm_force_sync` cho phép MỌI role** (`ContactPolicy#crm_force_sync? → true`), kể cả agent thường, kích hoạt một job crawl toàn bộ CRM. Chỉ có lock Redis chống spam.
34. **`crm_force_sync` được khai báo ở cả `collection` và `member`** (`config/routes.rb:256` và `:262`) → route trùng lặp; bản `member` không ai dùng.
35. **Spec `spec/jobs/crm/perfex/ticket_delivery_job_spec.rb` ĐÃ LẠC HẬU.** Nó assert `conversation.custom_attributes['crm_ticket']` (Hash, số ít) và `delivery['ticket_id']).to eq(77)` (Integer), trong khi code hiện ghi `custom_attributes['crm_tickets']` (Array) với `ticket_id` là String `"77"`. Spec này gần như chắc chắn fail — chưa xác minh bằng cách chạy test (nhiệm vụ này không chạy test).
36. **`DEFAULT_CUSTOMER_ID` và comment TODO tiếng Việt không dấu** (`# TODO: demo tam thoi - thay bang gia tri cau hinh duoc sau khi demo xong`) cho thấy giá trị này là tạm thời cho demo, chưa production-ready.
