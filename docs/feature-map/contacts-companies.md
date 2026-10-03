> Lập tại commit c37c7293a9 — ngày 2026-10-03

# Bản đồ: Liên hệ (Contact) & Doanh nghiệp (Company)

> Bản đồ có thể lạc hậu khi code đổi. Luôn kiểm chứng lại điểm then chốt trước khi kết luận.

## Tóm tắt

Vùng này gồm 5 khối tách biệt nhưng dính chặt vào nhau:

1. **Contact (OSS)** — `app/models/contact.rb`. Danh tính khách hàng ở cấp account. Ba khoá định danh: `email`, `phone_number`, `identifier`. Dedup xảy ra ở **3 chỗ độc lập**: `ContactInboxWithContactBuilder#find_contact` (khi tin nhắn vào), `ContactIdentifyAction` (widget / public API `setUser`), và `DataImport::ContactManager` (import CSV). Hợp nhất thủ công qua `ContactMergeAction`.
2. **ContactInbox (OSS)** — `app/models/contact_inbox.rb`. Bảng nối contact ↔ inbox qua `source_id` (unique theo `inbox_id`). Đây là "session" của một danh tính trên một kênh.
3. **Company (Enterprise-only)** — `enterprise/app/models/company.rb`. Toàn bộ model / controller / policy / view của Company nằm trong `enterprise/`, chỉ `contacts.company_id` và vài job tiện ích nằm ở OSS tree. Liên kết 1-N: `Company has_many :contacts`, `Contact belongs_to :company` (khai báo trong `enterprise/app/models/enterprise/concerns/contact.rb`, không có trong OSS `Contact`).
4. **Gắn sao (`vip`)** — cột boolean có trên **cả** `contacts` và `companies`. Trong code tên cột là `vip`; trong UI/i18n tên là "star / gắn sao". Dùng cho chế độ hiển thị "khách gắn sao" và cho thứ tự ưu tiên nhóm doanh nghiệp.
5. **Custom attribute definitions** — `app/models/custom_attribute_definition.rb`. Enum `attribute_model` có **5** giá trị (conversation / contact / company / deal / ticket), nhưng UI (`attributes/constants.js`) chỉ phơi ra **4** (conversation / contact / company / deal) — xem Cạm bẫy #9.

Đồng bộ liên hệ ↔ Perfex CRM (`additional_attributes.external.perfex_contact_id`, `Crm::Perfex::*`, trang `/contacts-directory`) **không mô tả lại ở đây** — xem [crm-perfex.md](crm-perfex.md).

Lưu ý nền: trong fork này `ChatwootApp.enterprise?` **hardcode `true`** (`lib/chatwoot_app.rb:14`) và `config/application.rb:46` eager-load toàn bộ `enterprise/app/**`. Nên mọi code "enterprise-only" của Company thực tế luôn được nạp; `if ChatwootApp.enterprise?` trong `config/routes.rb` luôn đúng.

## Database

### `contacts` (`db/schema.rb:680-710`)

| Cột | Kiểu | Ghi chú |
| --- | --- | --- |
| `name` | string, default `''` | |
| `middle_name`, `last_name` | string, default `''` | Có cột nhưng `permitted_params` của `ContactsController` **không** cho phép (xem Cạm bẫy #7) |
| `email` | string | Lowercase hoá trong `prepare_email_attribute`; rỗng → `nil` |
| `phone_number` | string | Validate `/\A(\+[1-9]\d{1,14}\|0\d{8,10})\z/` — chấp nhận **cả** E.164 và số nội địa bắt đầu bằng `0` |
| `identifier` | string | ID bên ngoài (widget `setUser`) |
| `account_id` | integer, not null | |
| `additional_attributes` | jsonb, default `{}` | `company_name`, `city`, `country`, `social_*`, `external.*` (CRM), `mapped_contact_id/name` (legacy) |
| `custom_attributes` | jsonb, default `{}` | Giá trị của `contact_attribute` definitions |
| `last_activity_at` | datetime | |
| `contact_type` | integer, default 0 | enum `{ visitor: 0, lead: 1, customer: 2 }` |
| `location`, `country_code` | string, default `''` | Denormalise từ `additional_attributes['city'/'country']` qua `Contacts::SyncAttributes` |
| `blocked` | boolean, default false, not null | |
| `company_id` | bigint, nullable | Có index; FK không khai báo trong schema |
| `vip` | boolean, default false, not null | **Chỉ có trong migration `db/migrate/20260928000001_add_vip_to_contacts.rb`, chưa có trong `db/schema.rb`** — xem Cạm bẫy #8 |

Index đáng chú ý:

- `uniq_email_per_account_contact (email, account_id) UNIQUE`
- `uniq_identifier_per_account_contact (identifier, account_id) UNIQUE`
- `index_contacts_on_phone_number_and_account_id (phone_number, account_id)` — **không unique**, nên trùng số điện thoại trong cùng account là hợp lệ ở tầng DB
- `index_contacts_on_lower_email_account_id (lower(email), account_id)` — phục vụ `Contact.from_email`
- `index_contacts_on_name_email_phone_number_identifier` — GIN `gin_trgm_ops`, phục vụ ILIKE search
- `index_contacts_on_nonempty_fields` và `index_resolved_contact_account_id` — partial index cho `resolved_contacts`
- `index_contacts_on_account_id_and_last_activity_at (… DESC NULLS LAST)`
- `index_contacts_on_account_id_and_vip (account_id, vip) WHERE vip = true` (chỉ trong migration)

### `companies` (`db/schema.rb:649-663`)

| Cột | Kiểu | Ghi chú |
| --- | --- | --- |
| `name` | string, **not null** | Max `Limits::COMPANY_NAME_LENGTH_LIMIT = 100` (`lib/limits.rb:9`) |
| `domain` | string, nullable | Validate regex tên miền; `allow_blank: true` |
| `description` | text | Max `Limits::COMPANY_DESCRIPTION_LENGTH_LIMIT = 1000` (`lib/limits.rb:10`) |
| `account_id` | bigint, not null | |
| `contacts_count` | integer, nullable | **counter_cache** do `belongs_to :company, counter_cache: true` ở phía Contact |
| `additional_attributes` | jsonb, default `{}` | `phonenumber`, `external.perfex_customer_id` (CRM) |
| `custom_attributes` | jsonb, default `{}` | Giá trị của `company_attribute` definitions; validate `jsonb_attributes_length` |
| `last_activity_at` | datetime | Roll-up 5 phút qua `Company#record_activity_at!` |
| `vip` | boolean, default false, not null | Chỉ trong `db/migrate/20261002000001_add_vip_to_companies.rb` — chưa có trong `schema.rb` |

Index:

- `index_companies_on_account_and_domain (account_id, domain) UNIQUE WHERE (domain IS NOT NULL)`
- `index_companies_on_name_and_account_id (name, account_id)` — không unique, trùng tên là hợp lệ
- `index_companies_on_account_id_and_vip (account_id, vip) WHERE vip = true` (chỉ trong migration)

### `contact_inboxes` (`db/schema.rb:665-678`)

| Cột | Ghi chú |
| --- | --- |
| `contact_id`, `inbox_id` | bigint, nullable ở DB nhưng `validates presence` ở model |
| `source_id` | text, not null. Khoá định danh của contact trên kênh đó |
| `hmac_verified` | boolean, default false |
| `pubsub_token` | string, unique (từ concern `Pubsubable`) |

Index: `index_contact_inboxes_on_inbox_id_and_source_id (inbox_id, source_id) UNIQUE`, `index_contact_inboxes_on_pubsub_token UNIQUE`, cùng index đơn trên `contact_id`, `inbox_id`, `source_id`.

### `custom_attribute_definitions` (`db/schema.rb:849-864`)

| Cột | Ghi chú |
| --- | --- |
| `attribute_display_name` | required |
| `attribute_key` | required, format `/\A[\p{L}\p{N}_.\-]+\z/` |
| `attribute_display_type` | integer, enum `{ text:0, number:1, currency:2, percent:3, link:4, date:5, list:6, checkbox:7 }` |
| `attribute_model` | integer, enum `{ conversation_attribute:0, contact_attribute:1, company_attribute:2, deal_attribute:3, ticket_attribute:4 }` |
| `attribute_values` | jsonb, default `[]` (cho type `list`) |
| `regex_pattern`, `regex_cue` | validate phía UI |
| `default_value` | integer (chỉ dùng cho checkbox) |

Index: `attribute_key_model_index (attribute_key, attribute_model, account_id) UNIQUE`.

`CustomAttributeDefinition::STANDARD_ATTRIBUTES` (dòng 25-32) chặn key trùng với field hệ thống. Danh sách cho `:company` là `%w[name domain description contacts_count created_at updated_at last_activity_at]`, cho `:contact` là `%w[name email phone_number identifier country_code city company_name created_at last_activity_at referer blocked]`.

## Backend

### Model Contact — `app/models/contact.rb`

- Callbacks theo thứ tự: `before_validation :prepare_contact_attributes` (lowercase email, khởi tạo jsonb) → `before_save :sync_contact_attributes` (`Contacts::SyncAttributes`) → `after_create_commit :dispatch_create_event, :ip_lookup` → `after_update_commit :dispatch_update_event` → `after_destroy_commit :dispatch_destroy_event` → `after_commit :enqueue_crm_cache_match, on: :create, if: :phone_number` (dòng 52, thuộc CRM — xem crm-perfex.md).
- `Contacts::SyncAttributes` (`app/services/contacts/sync_attributes.rb`): copy `additional_attributes['city'/'country']` sang cột `location`/`country_code`, và nâng `contact_type` từ `visitor` → `lead` khi có email / phone / khoá `social_*`.
- `Contact.resolved_contacts(use_crm_v2:)` (dòng 190-194): mặc định `WHERE email <> '' OR phone_number <> '' OR identifier <> ''`; nếu account bật flag `crm_v2` thì **đổi hẳn** sang `where(contact_type: 'lead')` — xem Cạm bẫy #6.
- `Contact#push_event_data` chỉ thêm `company_id` khi `account.feature_enabled?('companies')` (dòng 170). `webhook_data` **không** có `company_id` và **không** có `vip`.
- Scope sort: `order_on_name`, `order_on_last_activity_at`, `order_on_created_at`, `order_on_company_name` (đọc `additional_attributes->>'company_name'`, **không** join bảng `companies`), `order_on_city`, `order_on_country_name`.
- `Contact.include_mod_with('Concerns::Contact')` ở cuối file nạp overlay enterprise.

### Overlay Enterprise cho Contact — `enterprise/app/models/enterprise/concerns/contact.rb`

- `belongs_to :company, optional: true, counter_cache: true`
- `after_commit :associate_company_from_email, on: [:create, :update], if: :should_associate_company?`
- `before_save :sync_company_name_from_company, if: :will_save_change_to_company_id?` — ghi/xoá `additional_attributes['company_name']`
- `after_update_commit :record_company_activity, if: :saved_change_to_last_activity_at?` → `company.record_activity_at!`
- `should_associate_company?` (dòng 17-31) yêu cầu **đồng thời**: có email, `company_id` đang nil, email vừa đổi, và `saved_change_to_email.first.nil?` (tức email trước đó là nil), và account bật `companies`. Nghĩa là chỉ tự gắn doanh nghiệp **một lần duy nhất** khi email được set lần đầu.

### `Contacts::CompanyAssociationService` — `enterprise/app/services/contacts/company_association_service.rb`

Tách domain từ email → `Companies::BusinessEmailDetectorService` kiểm tra có phải email doanh nghiệp (không rác, không phải nhà cung cấp mail đại chúng — qua gem `valid_email2` + `EmailProviderInfo`) → `Company.find_or_create_by!(account:, domain:)` với `name` suy ra từ `additional_attributes['company_name']` hoặc `domain.split('.').first.tr('-_',' ').titleize`.

Ghi dữ liệu bằng `contact.update_columns(...)` + `Company.increment_counter(:contacts_count, …)` để **cố ý bỏ qua callbacks** (dòng 7-11) — hệ quả: không có `CONTACT_UPDATED` dispatch (Cạm bẫy #4).

### `Companies::ContactMembershipService` — `enterprise/app/services/companies/contact_membership_service.rb`

- `assign(contact:)` → `contact.update!(company: company)` + `company.record_activity_at!(contact.last_activity_at)` nếu có.
- `remove(contact:)` → `contact.update!(company: nil)`.

Đi qua `update!` nên **có** callback: counter_cache, `sync_company_name_from_company`, `dispatch_update_event`.

### Model Company — `enterprise/app/models/company.rb`

- `ACTIVITY_ROLLUP_INTERVAL = 5.minutes`; `record_activity_at!` bỏ qua update nếu `last_activity_at > activity_at - 5.minutes`.
- `has_many :contacts, dependent: :nullify` — xoá company **không** xoá contact.
- `after_create_commit :fetch_favicon, if: domain.present?` → `Avatar::AvatarFromFaviconJob.set(wait: 5.seconds)` (fetch favicon qua `https://www.google.com/s2/favicons?domain=…&sz=256`).
- `after_update_commit :enqueue_contact_company_name_sync, if: :saved_change_to_name?` → `Companies::SyncContactNamesJob`.
- Scope: `ordered_by_name`, `search_by_name_or_domain` (ILIKE trên `name` OR `domain`), `order_on_contacts_count`, `order_on_last_activity_at`.
- `include Avatarable` → `has_one_attached :avatar`, `avatar_url` trả bản resize 250px.

### Merge & dedup

**`ContactMergeAction`** (`app/actions/contact_merge_action.rb`) — chạy trong 1 transaction:

1. `validate_contacts` — cả hai phải cùng `account_id`.
2. `merge_conversations` / `merge_messages` (theo `sender`) / `merge_contact_inboxes` / `merge_contact_notes` → đổi `contact_id` sang base.
3. `merge_and_remove_mergee_contact` (dòng 51-66): hợp nhất chỉ 6 khoá `%w[identifier name email phone_number additional_attributes custom_attributes]`, `compact_blank` rồi `mergee.deep_merge(base)` — **base thắng** khi xung đột. Xoá `mapped_contact_id`/`mapped_contact_name` khỏi `additional_attributes`. Destroy mergee **trước** khi `base_contact.update!` (để giải phóng unique index email/identifier), và dispatch `CONTACT_MERGED` ở giữa.
4. `preserve_company(mergee_company_id)` (dòng 71-75): `company_id` **không** nằm trong tập mergeable; nếu base chưa có company thì thừa hưởng của mergee.

**`ContactIdentifyAction`** (`app/actions/contact_identify_action.rb`) — dedup theo thứ tự ưu tiên `identifier` → `email` → `phone_number`, mỗi bước gọi `ContactMergeAction` với contact tìm được làm **base**. Hai cơ chế bảo vệ:

- `merge_contacts?` (dòng 72-85): nếu contact tìm được đã có `identifier` khác với `params[:identifier]` thì **không merge** và loại khoá đó khỏi `@attributes_to_update`.
- `mergable_phone_contact?` (dòng 90-98): email có ưu tiên cao hơn phone; nếu contact trùng số đã có email khác thì không merge theo phone.

**`ContactInboxWithContactBuilder#find_contact`** (`app/builders/contact_inbox_with_contact_builder.rb:67-74`) — thứ tự: `identifier` → `email` (`Contact.from_email`, so sánh lowercase) → `phone_number` (qua `Contacts::InboundPhoneResolver`) → với kênh Instagram còn tìm thêm theo `source_id` của `Channel::FacebookPage`. Nếu không có → `create_contact` với tên fallback `Haikunator.haikunate(1000)`.

**`Contacts::InboundPhoneResolver`** (`app/services/contacts/inbound_phone_resolver.rb`) — khớp chính xác trước, sau đó so sánh chuỗi số đã normalise (`PhoneNumberNormalizer`) để `+84…` / `0…` / có dấu cách không sinh contact trùng. Bước 2 **load toàn bộ contact có phone của account vào Ruby** (`find do … end`) — tốn bộ nhớ ở account lớn.

**`ContactInboxBuilder`** (`app/builders/contact_inbox_builder.rb`) — sinh `source_id` theo channel_type (TwilioSms / Whatsapp / Email / Sms / Api / WebWidget); channel khác → `raise`. Khi gặp `RecordNotUnique` thì đổi `source_id` của contact_inbox **cũ** sang giá trị random rồi retry — chỉ cho phép với email/sms/twilio/whatsapp (`allowed_channels?`), còn lại raise lại. Overlay `enterprise/app/builders/enterprise/contact_inbox_builder.rb` thêm nhánh Twilio voice (`channel.voice_enabled?`).

**`DataImport::ContactManager`** (`app/services/data_import/contact_manager.rb`) — dedup riêng cho import CSV: `identifier` → `email` → `phone_number`, và tự thêm `+` nếu số không bắt đầu bằng `+` (`format_phone_number`). Mọi cột CSV không nằm trong `identifier/email/name/phone_number` bị nhét vào `custom_attributes`.

### Jobs

| Job | Vị trí | Queue | Việc |
| --- | --- | --- | --- |
| `Companies::DeleteJob` | `enterprise/app/jobs/companies/delete_job.rb` | `low` | Batch 1000: `update_all` xoá `company_id` và khoá `company_name` trong jsonb, rồi `company.destroy!`. Cố ý bỏ callbacks để không bắn webhook/automation |
| `Companies::SyncContactNamesJob` | `enterprise/app/jobs/companies/sync_contact_names_job.rb` | `low` | Batch 1000 `jsonb_set(additional_attributes, '{company_name}', …)` khi company đổi tên |
| `Companies::FetchAvatarsJob` | `app/jobs/companies/fetch_avatars_job.rb` (**OSS tree**) | `low` | Enqueue `Avatar::AvatarFromFaviconJob` cho mọi company có domain nhưng chưa có avatar |
| `Avatar::AvatarFromFaviconJob` | `app/jobs/avatar/avatar_from_favicon_job.rb` | `purgable` | Gọi `Avatar::AvatarFromUrlJob.perform_now` với URL favicon Google |
| `Migration::CompanyBackfillJob` → `Migration::CompanyAccountBatchJob` | `enterprise/app/jobs/migration/` | `low` | Backfill company từ domain email của contact có sẵn (dùng `update_column`, bỏ callbacks) |
| `Migration::BackfillCompaniesContactsCountJob` | `app/jobs/migration/` | `async_database_migration` | `Company.reset_counters(id, :contacts)`; có guard `return unless ChatwootApp.enterprise?` |
| `Contacts::BulkActionJob` | `app/jobs/contacts/bulk_action_job.rb` | — | Bulk delete / gắn-bỏ label |
| `Account::ContactsExportJob` | `app/jobs/account/contacts_export_job.rb` | — | Export CSV, gửi mail `contact_export_complete.liquid` |
| `Internal::RemoveStaleContactsJob`, `Internal::RemoveStaleContactInboxesJob`, `Internal::ProcessStaleContactsJob` | `app/jobs/internal/` | — | Dọn contact/contact_inbox rác (scope `stale_without_conversations`) |

Rake: `enterprise/lib/tasks/companies.rake` — `companies:backfill` và `companies:fetch_missing_avatars`.

### Policy

- `ContactPolicy` (`app/policies/contact_policy.rb`): gần như tất cả `true`; `destroy?` yêu cầu administrator; `import?`/`export?` yêu cầu administrator, và overlay `enterprise/app/policies/enterprise/contact_policy.rb` mở thêm cho custom role có permission `contact_manage`.
- `CompanyPolicy` (`enterprise/app/policies/company_policy.rb`): `index/search/show/create/update/avatar/destroy_custom_attributes` đều `true`; chỉ `destroy?` yêu cầu `@account_user.administrator?`.

## API / Route

Tất cả nằm dưới `/api/v1/accounts/:account_id`. Số dòng dưới đây theo `config/routes.rb`.

### Contacts (dòng 249-272)

| Method | Path | Controller#action |
| --- | --- | --- |
| GET | `/contacts` | `contacts#index` (15/trang, `Sift` sort) |
| GET | `/contacts/active` | `contacts#active` (online) |
| GET | `/contacts/search?q=` | `contacts#search` |
| POST | `/contacts/filter` | `contacts#filter` (`Contacts::FilterService`) |
| POST | `/contacts/import` | `contacts#import` |
| POST | `/contacts/export` | `contacts#export` |
| POST | `/contacts/crm_force_sync` | CRM — xem crm-perfex.md |
| GET | `/contacts/:id` | `contacts#show` |
| POST | `/contacts` | `contacts#create` (kèm `inbox_id`/`source_id` → `ContactInboxBuilder`) |
| PATCH/PUT | `/contacts/:id` | `contacts#update` |
| DELETE | `/contacts/:id` | `contacts#destroy` (chặn nếu contact đang online) |
| GET | `/contacts/:id/contactable_inboxes` | `contacts#contactable_inboxes` |
| POST | `/contacts/:id/destroy_custom_attributes` | `contacts#destroy_custom_attributes` |
| DELETE | `/contacts/:id/avatar` | `contacts#avatar` |
| POST/DELETE | `/contacts/:id/match_crm`, `/unmap_crm`, `/crm_force_sync` | CRM — xem crm-perfex.md |

Nested (`scope module: :contacts`): `GET /contacts/:contact_id/conversations`, `POST /contacts/:contact_id/contact_inboxes`, `GET|POST /contacts/:contact_id/labels`, `resources :notes` (full CRUD), `GET /deals`, `GET /tickets`, `GET /attachments`, và khi enterprise: `GET /conversation_analyses`, `POST /contacts/:id/call`.

`PATCH /contacts/:id` permit (`app/controllers/api/v1/accounts/contacts_controller.rb:220`): `:name, :identifier, :email, :phone_number, :avatar, :blocked, :vip, :avatar_url, additional_attributes: {}, custom_attributes: {}`. Overlay `enterprise/app/controllers/enterprise/api/v1/accounts/contacts_controller.rb` thêm `company_id` **chỉ khi** account bật `companies` **và** params có khoá `company_id`; giá trị rỗng → `nil`, giá trị khác → `Current.account.companies.find(...)` (404 nếu company không thuộc account).

`custom_attributes` khi update được **merge** với giá trị cũ (`contact_custom_attributes`, dòng 223-227), `additional_attributes` cũng vậy — nên không có cách nào xoá một khoá bằng `PATCH`; phải dùng `POST /destroy_custom_attributes`.

Tham số đặc biệt của `contacts#index`: `company_id=none` → `where(company_id: nil)` (dòng 169, dùng bởi trang CRM Directory), `labels=` → `tagged_with(any: true)`, `include_contact_inboxes=false` → bỏ eager-load contact_inboxes.

### Companies (dòng 229-247) — controller nằm trong `enterprise/`

| Method | Path | Controller#action |
| --- | --- | --- |
| GET | `/companies` | `companies#index` (25/trang) |
| GET | `/companies/search?q=` | `companies#search` (422 nếu thiếu `q`) |
| GET | `/companies/:id` | `companies#show` |
| POST | `/companies` | `companies#create` |
| PATCH/PUT | `/companies/:id` | `companies#update` |
| DELETE | `/companies/:id` | `companies#destroy` → enqueue `Companies::DeleteJob`, trả `head :ok` ngay |
| POST | `/companies/:id/destroy_custom_attributes` | `companies#destroy_custom_attributes` |
| DELETE | `/companies/:id/avatar` | `companies#avatar` |
| GET | `/companies/:company_id/contacts` | `companies/contacts#index` (15/trang, order `name, id`) |
| GET | `/companies/:company_id/contacts/search?q=` | `companies/contacts#search` (chỉ contact **chưa** thuộc company này) |
| POST | `/companies/:company_id/contacts` | `companies/contacts#create` (body `contact_id`) → gắn |
| DELETE | `/companies/:company_id/contacts/:id` | `companies/contacts#destroy` → gỡ |
| GET | `/companies/:company_id/conversations` | `companies/conversations#index` (limit 20, qua `Conversations::PermissionFilterService`) |
| GET | `/companies/:company_id/notes` | `companies/notes#index` (limit 20) |
| GET | `/companies/:company_id/deals` | `companies/deals#index` (`include CrmDealsFeatureConcern`, `authorize Deal, :index?`) |
| GET | `/companies/:company_id/attachments` | `companies/attachments#index` (100/trang) |

Mọi endpoint company đi qua `ensure_companies_enabled!`: nếu account chưa bật flag `companies` → `403 {"error":"Companies are not enabled for this account"}` (chuỗi hardcode, không i18n).

`company_params` (`enterprise/app/controllers/api/v1/accounts/companies_controller.rb:86-96`): `:name, :domain, :description, :avatar, :vip, additional_attributes: {}, custom_attributes: {}`. `update` merge `custom_attributes` với giá trị cũ (dòng 98-107).

`Api::V1::Accounts::Companies::BaseController` (`enterprise/.../companies/base_controller.rb`) load `@company` từ `params[:company_id]` và cung cấp `authorize_company_read!` (`:show?`) / `authorize_company_update!` (`:update?`). `companies/contacts#index|search` dùng read, `#create|destroy` dùng update.

### Custom attribute definitions (dòng 356)

`resources :custom_attribute_definitions, only: [:index, :show, :create, :update, :destroy]`. `GET` nhận query `attribute_model` (scope `with_attribute_model`); không truyền → trả **tất cả** model. Payload permit: `attribute_display_name, attribute_description, attribute_display_type, attribute_key, attribute_model, regex_pattern, regex_cue, attribute_values: []`. Không permit `default_value`.

### Khác

- `POST /api/v1/accounts/:id/actions/contact_merge` (dòng 56) — body `base_contact_id` + `mergee_contact_id`, view trả partial contact của base.
- `POST /api/v1/accounts/:id/contact_inboxes/filter` (dòng 126-130) — tìm contact theo `inbox_id` + `source_id`, 404 nếu không có.
- Widget: `GET|PATCH /api/v1/widget/contact`, `POST /destroy_custom_attributes`, `PATCH /set_user` (dòng 581-585) — đi qua `ContactIdentifyAction`.
- Public inbox API: `POST|GET|PATCH /public/api/v1/inboxes/:inbox_id/contacts` (dòng 698) — `create` dùng `ContactInboxWithContactBuilder`, `update` dùng `ContactIdentifyAction`; có kiểm HMAC.

### Hình dạng JSON

`app/views/api/v1/models/_contact.json.jbuilder`:

```
additional_attributes, availability_status, email, id, name, phone_number,
blocked, vip, identifier,
company_id        # CHỈ khi Current.account.feature_enabled?('companies')
thumbnail (avatar_url), custom_attributes,
last_activity_at (epoch), created_at (epoch),
contact_inboxes[] # chỉ khi local `with_contact_inboxes` được truyền
```

`enterprise/app/views/api/v1/models/_company.json.jbuilder`: `id, name, contacts_count, domain, description, vip, custom_attributes, additional_attributes, avatar_url, last_activity_at, created_at, updated_at` (3 mốc thời gian là epoch integer).

`enterprise/app/views/api/v1/accounts/companies/contacts/_contact.json.jbuilder` bọc partial contact và thêm `company_id`, `linked_to_current_company` (bool), `company` (object lồng hoặc `null`).

`index`/`search` của companies và companies/contacts đều có `meta: { total_count, page }`.

## Frontend

### Store

- **Contacts (Vuex)** — `app/javascript/dashboard/store/modules/contacts/{actions,getters,mutations,index}.js`. `buildContactFormData` (actions.js:12-38) có xử lý đặc biệt: `company_id` được append **cả khi rỗng** (`shouldAppendBlankCompanyId`) để có thể gỡ liên kết; các field rỗng khác bị bỏ. `merge` action (dòng 293) gọi `AccountActionsAPI.merge(parentId, childId)`.
- **Companies (Pinia)** — `app/javascript/dashboard/stores/companies.js`, tạo qua `createStore({ name: 'companies', type: 'pinia' })`. State phụ: `activeCompanyId`, `companyContacts(+Meta)`, `companyConversations`, `companyNotes`, `companyDeals`, `companyAttachments`, `contactSearchResults(+Meta)`, `activeContactSearchQuery`. Mỗi loại fetch có **request token** riêng (`companyDetailRequestToken`, `companyContactsRequestToken`, …) để bỏ kết quả về muộn khi người dùng đổi company; `resetCompanyDetailState()` tăng tất cả token và xoá state.
  - `camelizeCompany` dùng `stopPaths: ['custom_attributes']` → `additional_attributes` **bị** camelize sâu (nên đọc `additionalAttributes.external.perfexCustomerId`).
  - `camelizeContact` dùng `stopPaths: ['custom_attributes', 'additional_attributes']` → giữ nguyên snake_case.
  - `getCompanyAttachments` cố ý **không** camelize (comment dòng 394-395) vì component attachment dùng key snake_case.
- **Attributes (Vuex)** — `app/javascript/dashboard/store/modules/attributes.js`. Getter theo model: `getConversationAttributes`, `getContactAttributes`, `getCompanyAttributes`, `getDealAttributes`, `getTicketAttributes`, và `getAttributesByModel(model)`. API `AttributeAPI.getAttributesByModel()` (`api/attributes.js:9-11`) gọi `GET /custom_attribute_definitions` **không tham số** → nạp mọi model một lượt; action `attributes/get` nhận tham số nhưng **bỏ qua** nó.
- **conversationStats (Vuex)** — `app/javascript/dashboard/store/modules/conversationStats.js`. Ngoài `mineCount/vipCount/allCount/unAssignedCount` còn có `companyCounts` (object), `companyStarredWaitingIds` (array), `noCompanyCount`. Fetch qua `ConversationApi.meta(params)` với 3 mức debounce theo `allCount` (`getMetaDebounceKey`: >2000 hoặc ==0 → `superLong` 15s).

### API client

- `app/javascript/dashboard/api/contacts.js` (extends `ApiClient`, `accountScoped`).
- `app/javascript/dashboard/api/companies.js` — `get({page, sort})`, `search(q, page, sort)`, `listContacts/listNotes/listConversations/listDeals/listAttachments`, `searchContacts`, `createContact`, `removeContact`, `destroyCustomAttributes`, `destroyAvatar`. `buildParams` loại field `undefined`/`''` nhưng **giữ** `q=''`.
- `app/javascript/dashboard/api/inbox/conversation.js:32` — truyền `company_id` vào `GET /conversations`.

### Component Company

```
components-next/Companies/
├── CompaniesCard/CompaniesCard.vue          thẻ trong danh sách
├── CompaniesDetailsLayout.vue  CompaniesListLayout.vue
├── CompaniesHeader/CompanyHeader.vue + components/{CompanyMoreActions,CompanySortMenu}.vue
├── CompanyCreateDialog.vue                  dialog tạo mới (gửi domain = null nếu rỗng)
├── CompanySelector.vue                      ComboBox chọn/tạo company trong form contact
├── CompanyStarButton.vue                    toggle `vip`
├── CompanyDetail/
│   ├── CompanyProfileCard.vue               avatar upload/delete + star + form name/domain/description
│   ├── CompanyContactsSidebar.vue  CompanyHistorySidebar.vue  CompanyNotesSidebar.vue
│   ├── ConfirmCompanyDeleteDialog.vue
│   └── CompanyCustomAttributes.vue  CompanyCustomAttributeItem.vue   ← KHÔNG được import ở đâu (Cạm bẫy #10)
└── ConversationPanel/
    ├── CompanyPanel.vue
    └── CompanyPanelSection.vue
```

Trang: `routes/dashboard/companies/pages/{CompaniesIndex,CompanyDetailView}.vue`, route config `routes/dashboard/companies/routes.js` (route name `companies_dashboard_index`, `companies_dashboard_show`; meta `featureFlag: FEATURE_FLAGS.COMPANIES`, `permissions: ['administrator','agent']`, `installationTypes: [CLOUD, ENTERPRISE]`).

`CompanyDetailView.vue:65-69` có **3** tab sidebar: `history` (mặc định), `notes`, `contacts` — **không có** tab Overview / Deals / Files. `loadSidebarTab` (dòng 115-121) chỉ gọi `getCompanyNotes` cho tab notes và `getCompanyConversations` cho tab history; `getCompanyContacts` được gọi ở chỗ khác (phân trang).

### `CompanyPanel.vue` — panel "Doanh nghiệp" trong sidebar hội thoại

`app/javascript/dashboard/components-next/Companies/ConversationPanel/CompanyPanel.vue`. Props `companyId`, `contactId`. Có **5 section** (qua `CompanyPanelSection.vue`), không phải Overview/Contacts/Deals/Files:

| Section | Key | Nguồn dữ liệu | Ghi chú |
| --- | --- | --- | --- |
| Thông tin doanh nghiệp | `info` | `company.description`, `websiteUrl` (tự thêm `https://` nếu domain thiếu scheme), `infoRows` | `infoRows` = `CRM ID` (`additionalAttributes.external.perfexCustomerId`) + `phone` (`additionalAttributes.phonenumber`) + toàn bộ `customAttributes`, nhãn tra từ `attributes/getCompanyAttributes`, bỏ dòng rỗng |
| Người liên hệ chính | `contacts` | `companiesStore.companyContacts` | `mainContact` = contact của hội thoại hiện tại, fallback contact đầu tiên; `otherContacts` tối đa `PREVIEW_LIMIT - 1 = 4`. Có `VoiceCallButton` và link `mailto:` |
| Hội thoại đang mở | `conversations` | `companyConversations.filter(status === 'open')`, hiển thị tối đa 5 | |
| Cơ hội đang mở | `deals` | `companyDeals.filter(!closedAt)`, tối đa 5, tổng giá trị qua `formatVND` | Chỉ render khi flag `crm_deals` bật |
| Ghi chú doanh nghiệp | `notes` | `companyNotes.slice(0, 3)` | Section bị ẩn hoàn toàn nếu rỗng (`v-if="notes.length"`) |

`watch` trên `companyId` (dòng 167-180, `immediate`) gọi `resetCompanyDetailState()` rồi `show`, `getCompanyContacts`, `getCompanyConversations`, `getCompanyNotes`, và `getCompanyDeals` nếu `crm_deals` bật. **Không** gọi `getCompanyAttachments`.

Mỗi section mở/đóng theo `sectionHasData` (có dữ liệu thì mở sẵn), người dùng click thì ghi `openOverrides` cho tới khi đổi company.

### Chế độ hiển thị trong danh sách hội thoại

- **Constant**: `app/javascript/dashboard/constants/globals.js:10-14`
  ```js
  DISPLAY_MODE: { DEFAULT: 'default', COMPANY: 'company', VIP: 'vip' }
  ```
  và `ASSIGNEE_TYPE` (dòng 3-9) có thêm `COMPANY: 'company'`, `VIP: 'vip'`.
- **Phân quyền**: `app/javascript/dashboard/constants/permissions.js:55-68`
  ```js
  DISPLAY_MODE_PERMISSIONS = {
    default: { permissions: [...ROLES, ...CONVERSATION_PERMISSIONS] },
    company: { permissions: [...ROLES, 'conversation_manage', 'conversation_participating_manage'] },
    vip:     { permissions: [...ROLES, ...CONVERSATION_PERMISSIONS] },
  }
  ```
  Tức chế độ `company` **không** mở cho custom role chỉ có `conversation_unassigned_manage`.
- **Dropdown**: `components-next/Conversation/ConversationDisplayMode.vue` — nút icon `i-lucide-settings-2`, nhãn `CHAT_LIST.DISPLAY_MODE.LABEL`, đổi màu xanh khi mode ≠ `default`; danh sách option nhận từ prop.
- **`ChatList.vue`**:
  - `displayModeOptions` (dòng 206-219): `filterItemsByPermission(DISPLAY_MODE_PERMISSIONS, …)` rồi lọc bỏ `company` nếu account không bật `FEATURE_FLAGS.COMPANIES`; nhãn `t('CHAT_LIST.DISPLAY_MODE.OPTIONS.' + key)`.
  - `isCompanyMode` (dòng 195-200): mode = `company` **và** không có filter/folder đang áp.
  - `effectiveAssigneeType` (dòng 246-253): mode `vip` → `assignee_type=vip`; mode `company` → `assignee_type=all`; còn lại → tab assignee đang chọn.
  - `conversationList` (dòng ~400-412): mode `vip` lọc `conversation.meta?.sender?.vip`; mode company lọc `conversation.meta?.sender?.company_id`.
  - `activeAssigneeTabCount` (dòng 280-292): mode ≠ default thì lấy `vipCount` hoặc `allCount` thay vì count theo tab.
  - `updateDisplayMode` (dòng 705-712): lưu vào UI settings khoá `conversation_display_mode`; `onMounted` (dòng 898-906) đọc lại và chấp nhận nếu còn trong `displayModeOptions`; `?tab=vip` trên URL ép mode `vip`.
  - Template dòng 1069: `<CompanyConversationList v-if="isCompanyMode">`, ngược lại `<ConversationList>`.
- **`CompanyConversationList.vue`** (`app/javascript/dashboard/components/CompanyConversationList.vue`):
  - `fetchCompanies` (dòng 104-122) phân trang **vòng lặp tới hết** `GET /companies` (`page` tăng dần đến `meta.total_count`).
  - `conversationsByCompany` nhóm theo `conversation.meta.sender.company_id`, contact không có company vào khoá `'none'` (`NO_COMPANY_KEY`).
  - `companyCount(id)` đọc `conversationStats.companyCounts[id]`, với `'none'` đọc `conversationStats.noCompanyCount`.
  - `companyTier` (dòng 84-87): tier 0 = company gắn sao **và** có khách gắn sao đang chờ; tier 1 = có khách gắn sao đang chờ; tier 2 = còn lại. `hasStarredWaiting` ưu tiên dữ liệu đã load (`isVipAwaitingReply`), fallback `conversationStats.companyStarredWaitingIds`.
  - Mở toàn bộ nhóm lần đầu (`expandAllCompanies`), nhóm có `companyCount === 0` **không** click được, mỗi nhóm fetch riêng qua `store.dispatch('fetchCompanyConversations', { …filters, assigneeType: 'all', companyId, page })`.
  - Badge sao: `i-ph-star-fill` + tooltip `COMPANIES.STAR.BADGE`.

### Gắn sao liên hệ (contact `vip`)

`routes/dashboard/conversation/contact/ContactInfo.vue` — `toggleVip()` (dòng 147-165) `dispatch('contacts/update', { id, vip })`, alert `CONTACT_PANEL.VIP.MARKED` / `UNMARKED` / `ERROR`; nút `i-ph-star-fill` / `i-ph-star` màu amber (dòng 371-386); `<VipBadge>` cạnh tên (dòng 245). Badge cũng xuất hiện trong `ConversationCard.vue`, `ConversationCardExpanded.vue`, `ConversationHeader.vue`, `NeedsAttentionList.vue`.

### Custom attribute (UI)

`routes/dashboard/settings/attributes/constants.js`:

```js
ATTRIBUTE_MODELS = [
  { id: 0, key: 'CONVERSATION' },
  { id: 1, key: 'CONTACT' },
  { id: 2, key: 'COMPANY', featureFlag: 'companies' },
  { id: 3, key: 'DEAL',    featureFlag: 'crm_deals' },
];
ATTRIBUTE_TYPES = [TEXT:0, NUMBER:1, LINK:4, DATE:5, LIST:6, CHECKBOX:7];
```

`Index.vue:39-45` và `AddAttribute.vue:56-61` lọc model theo `featureFlag` qua `isFeatureEnabledonAccount`. `ATTRIBUTE_TYPES` **thiếu** `currency: 2` và `percent: 3` dù model Rails có.

Hiển thị giá trị: `components-next/Contacts/ContactsSidebar/ContactCustomAttributes.vue` + `ContactCustomAttributeItem.vue` (dùng getter `attributes/getContactAttributes`, sắp xếp theo UI setting `conversation_elements_order_conversation_contact_panel`). Phía Company thì `CompanyPanel.vue` tự render inline từ `attributes/getCompanyAttributes`.

### Form contact ↔ company

`components-next/Contacts/ContactsForm/ContactsForm.vue`:
- `editDetailsForm` map `COMPANY_NAME` → field `additionalAttributes.companyName` (dòng 44).
- `showCompanySelector` (dòng 97-101) = flag `companies` bật **và** (`state.companyId` có giá trị **hoặc** `additionalAttributes.companyName` rỗng). Tức contact có `company_name` tự do nhưng chưa có `company_id` thì vẫn giữ input text, không hiện selector.
- `handleCompanySelection` (dòng 244-249) set cả `companyId` và `additionalAttributes.companyName` rồi emit update.

`CompanySelector.vue` lazy-fetch khi mở dropdown (`handleOpen`), có option `create:<name>` để tạo company mới ngay trong combobox qua `CompanyCreateDialog`.

## Điểm vào giao diện

| Nơi | Đường dẫn / thao tác |
| --- | --- |
| Danh sách liên hệ | Sidebar → Contacts → All Contacts (`/app/accounts/:id/contacts`) |
| Chi tiết / sửa liên hệ | Route name `contacts_edit` → `routes/dashboard/contacts/pages/ContactManageView.vue` |
| Hợp nhất liên hệ | Contact detail → sidebar `ContactMerge.vue` / `ContactsForm/ContactMergeForm.vue`; bản cũ `modules/contact/ContactMergeModal.vue` + `components/MergeContact.vue` |
| Import / Export liên hệ | `ContactImportDialog.vue`, `ContactExportDialog.vue` (chỉ admin hoặc custom role `contact_manage`) |
| Danh sách doanh nghiệp | `components-next/sidebar/Sidebar.vue:721-738` → "Companies / All Companies" (`companies_dashboard_index`). **Đang bị ẩn bởi `DEMO_MODE`** — xem Cạm bẫy #2 |
| Chi tiết doanh nghiệp | `/app/accounts/:id/companies/:companyId` (`companies_dashboard_show`); cũng tới được từ nút "Chi tiết" trong `CompanyPanel` |
| Panel Doanh nghiệp trong hội thoại | `components/widgets/conversation/ConversationSidebar.vue:116-156` — 2 tab `contact` / `company`, chỉ hiện khi `activePanel === 'contact'` **và** flag `companies` bật; tab company luôn hiện kể cả contact chưa có company (hiện empty state `CONVERSATION.SIDEBAR.NO_COMPANY`) |
| Gắn sao liên hệ | Nút sao trong `ContactInfo.vue` (panel Liên hệ) |
| Gắn sao doanh nghiệp | `CompanyStarButton.vue` — trong `CompanyPanel` (header) và `CompanyProfileCard` (trang chi tiết) |
| Gắn / gỡ liên hệ vào doanh nghiệp | `CompanyContactsSidebar.vue` (tab Contacts trang chi tiết company), hoặc `CompanySelector` trong form contact |
| Chế độ hiển thị hội thoại | Nút bánh răng `i-lucide-settings-2` trên header danh sách hội thoại → "Mặc định / Hiển thị theo doanh nghiệp / Hiển thị khách gắn sao" |
| Quản lý custom attribute | Settings → Custom Attributes (`routes/dashboard/settings/attributes/Index.vue`), tab theo model |

## Luồng dữ liệu

### A. Tin nhắn vào → tạo / khớp contact → tự gắn company

```
Channel inbound (webhook/IMAP/…)
  └─ ContactInboxWithContactBuilder#perform
       ├─ inbox.contact_inboxes.find_by(source_id:)   → trả luôn nếu đã có
       └─ transaction:
            ├─ find_contact: identifier → email → phone (InboundPhoneResolver) → (IG) FB source_id
            ├─ create_contact nếu không thấy  (name fallback Haikunator)
            └─ ContactInboxBuilder → ContactInbox (retry đổi source_id cũ nếu RecordNotUnique)
       └─ Avatar::AvatarFromUrlJob nếu có avatar_url

Contact#save
  ├─ before_save Contacts::SyncAttributes      → location/country_code, contact_type lead
  ├─ after_create_commit CONTACT_CREATED + ContactIpLookupJob (nếu flag ip_lookup)
  ├─ after_commit (create, có phone) → Crm::Perfex::MatchFromCacheJob   ← xem crm-perfex.md
  └─ after_commit (enterprise, email vừa set lần đầu, flag companies)
       └─ Contacts::CompanyAssociationService
            ├─ BusinessEmailDetectorService (bỏ email rác / mail đại chúng)
            ├─ Company.find_or_create_by!(account, domain)
            │     └─ after_create_commit → Avatar::AvatarFromFaviconJob (wait 5s)
            └─ contact.update_columns(company_id, additional_attributes.company_name)
                 + Company.increment_counter(:contacts_count)   ← KHÔNG bắn CONTACT_UPDATED
```

### B. Widget `setUser` → dedup + merge

```
PATCH /api/v1/widget/contact/set_user   (HMAC nếu identifier_hash / hmac_mandatory)
  └─ a_different_contact?  → build contact_inbox mới (danh tính khác)
  └─ ContactIdentifyAction(discard_invalid_attrs: true)
       transaction:
         merge theo identifier → merge theo email → merge theo phone
           (mỗi lần: ContactMergeAction, contact tìm được làm BASE)
         update_contact: chỉ ghi các khoá còn lại trong @attributes_to_update,
                         custom/additional_attributes deep_merge
         enqueue_avatar_job nếu có avatar_url và chưa có avatar
```

### C. Gắn liên hệ vào doanh nghiệp (thủ công)

```
UI CompanyContactsSidebar → companiesStore.attachContactToCompany(companyId, contactId)
  → POST /companies/:company_id/contacts { contact_id }
      authorize_company_update!  (CompanyPolicy#update? = true)
      Companies::ContactMembershipService#assign
        ├─ contact.update!(company:)      → counter_cache +1
        │    before_save sync_company_name_from_company → additional_attributes.company_name
        │    after_update_commit CONTACT_UPDATED
        └─ company.record_activity_at!(contact.last_activity_at)
  → store gọi lại getCompanyContacts(page 1) + clearContactSearchResults()
```

Gỡ: `DELETE /companies/:company_id/contacts/:id` → `remove` → `contact.update!(company: nil)` → `sync_company_name_from_company` **xoá** khoá `company_name`, counter_cache −1.

### D. Đổi tên doanh nghiệp → đồng bộ denormalise

```
PATCH /companies/:id {name}
  → Company#after_update_commit (saved_change_to_name?)
      → Companies::SyncContactNamesJob (queue low)
          batch 1000: UPDATE contacts SET additional_attributes =
            jsonb_set(additional_attributes, '{company_name}', '<name>', true)
```

### E. Xoá doanh nghiệp

```
DELETE /companies/:id   (CompanyPolicy#destroy? → chỉ administrator)
  → Companies::DeleteJob.perform_later  ; HTTP trả head :ok ngay
      batch 1000: UPDATE contacts SET company_id = NULL,
                  additional_attributes = additional_attributes - 'company_name'
      company.destroy!   (has_many :contacts dependent: :nullify)
```

### F. Chế độ "theo doanh nghiệp" trong danh sách hội thoại

```
ConversationDisplayMode → ChatList.updateDisplayMode('company')
  ├─ updateUISettings({ conversation_display_mode: 'company' })
  └─ resetAndFetchData()  (effectiveAssigneeType = 'all')

CompanyConversationList onMounted
  ├─ fetchCompanies(): lặp GET /companies?page=N tới hết total_count
  └─ expandAllCompanies(): với mỗi nhóm có companyCount > 0
        store.dispatch('fetchCompanyConversations', {…filters, assigneeType:'all', companyId, page})
          → GET /conversations?company_id=<id>&assignee_type=all&…
              Enterprise::ConversationFinder#filter_by_company
                company_id == 'none' → company_id NULL
          → SET_ALL_CONVERSATION (không reset list)

conversationStats/get → GET /conversations/meta
  Enterprise::ConversationFinder#company_meta  (1 query GROUP BY contacts.company_id)
    company_counts / company_starred_waiting_ids / no_company_count
  → meta.json.jbuilder CHỈ render company_counts   ← Cạm bẫy #1
```

## Feature flag

| Flag | Mặc định (`config/features.yml`) | Cột | Ảnh hưởng |
| --- | --- | --- | --- |
| `companies` | `enabled: false` (dòng 211-213) | mặc định | Bật/tắt toàn bộ Company: `ensure_companies_enabled!` ở backend (403), `company_id` trong `_contact.json.jbuilder` và `push_event_data`, callback `associate_company_from_email`, overlay `company_id` trong `permitted_params`, tab Company trong `ConversationSidebar`, option `company` trong `DISPLAY_MODE`, model `COMPANY` trong `ATTRIBUTE_MODELS`, `CompanySelector` trong form contact, route `companies_dashboard_*` (`meta.featureFlag`) |
| `crm_deals` | `enabled: false`, `column: feature_flags_ext_1` (dòng 253-256) | ext_1 | Section "Cơ hội đang mở" trong `CompanyPanel`, `GET /companies/:id/deals` (`CrmDealsFeatureConcern`), model `DEAL` trong `ATTRIBUTE_MODELS` |
| `crm_v2` | `enabled: false`, `chatwoot_internal: true` (dòng 181-184) | mặc định | **Đổi hẳn** định nghĩa `Contact.resolved_contacts` sang `contact_type = 'lead'` (Cạm bẫy #6) |
| `ip_lookup` | — | — | `ContactIpLookupJob` sau khi tạo contact |
| `crm` / `crm_integration` / `crm_tickets` | xem crm-perfex.md | | |

Hằng JS: `app/javascript/dashboard/featureFlags.js:54` `COMPANIES: 'companies'`, dòng 15 `CRM_DEALS: 'crm_deals'`.

Route gate bổ sung của trang Companies (`routes/dashboard/companies/routes.js:7-11`): `permissions: ['administrator','agent']` và `installationTypes: [CLOUD, ENTERPRISE]`.

## i18n

### Frontend — `en.json` / `vi.json` (đã xác minh có trong cả hai)

**`app/javascript/dashboard/i18n/locale/{en,vi}/companies.json`** — namespace `COMPANIES`:

| Key | en | vi |
| --- | --- | --- |
| `COMPANIES.HEADER` | Companies | Doanh nghiệp |
| `COMPANIES.CONTACTS_COUNT` | `{n} contact \| {n} contacts` | `{n} liên hệ \| {n} liên hệ` |
| `COMPANIES.UNNAMED` | Unnamed Company | Doanh nghiệp chưa đặt tên |
| `COMPANIES.SELECTOR.PLACEHOLDER` / `.CREATE_OPTION` | Select company / `Add "{name}"` | Chọn doanh nghiệp / `Thêm "{name}"` |
| `COMPANIES.STAR.MARK` / `.UNMARK` | Star this company / Unstar this company | Gắn sao doanh nghiệp / Bỏ gắn sao doanh nghiệp |
| `COMPANIES.STAR.MARKED` / `.UNMARKED` / `.ERROR` / `.BADGE` | Company starred / … / … / Starred company | Đã gắn sao doanh nghiệp / … / … / Doanh nghiệp gắn sao |
| `COMPANIES.CONVERSATION_PANEL.PROFILE.{TITLE,WEBSITE,EMPTY}` | Company details / Website / No company details yet. | Thông tin doanh nghiệp / Website / Chưa có thông tin doanh nghiệp. |
| `COMPANIES.CONVERSATION_PANEL.PHONE` | Phone number | Số điện thoại |
| `COMPANIES.CONVERSATION_PANEL.INFO.CRM_ID` | CRM ID | Mã CRM |
| `COMPANIES.CONVERSATION_PANEL.SECTIONS.{MAIN_CONTACT,CONVERSATIONS,DEALS,NOTES,EMPTY}` | Main contact / `Open conversations ({n})` / `Open deals ({n})` / Company notes / Nothing here yet. | Người liên hệ chính / `Hội thoại đang mở ({n})` / `Cơ hội đang mở ({n})` / Ghi chú doanh nghiệp / Chưa có dữ liệu. |
| `COMPANIES.CONVERSATION_PANEL.{DETAILS,OPEN_COMPANY,CURRENT_CONTACT,VIEW_ALL_COUNT,EMPTY}` | Details / Open company / In this chat / `View all ({n})` / This company is no longer available. | Chi tiết / Mở trang doanh nghiệp / Đang chat / `Xem tất cả ({n})` / Doanh nghiệp này không còn tồn tại. |
| `COMPANIES.DETAIL.SIDEBAR.TABS.{HISTORY,NOTES,CONTACTS,ATTRIBUTES}` | History / Notes / Contacts / Attributes | Lịch sử / Ghi chú / Liên hệ / Thuộc tính |
| `COMPANIES.DETAIL.CONTACTS.*` | nhóm gắn/gỡ liên hệ (`ADD_SUCCESS`, `REASSIGN_SUCCESS`, `REMOVE_SUCCESS`, dialog `DIALOGS.ADD.*`) | đã dịch đầy đủ |
| `COMPANIES.DETAIL.DELETE.*` | Danger zone / Delete company? / … | Vùng nguy hiểm / Xoá doanh nghiệp? / … |
| `COMPANIES_LAYOUT.PAGINATION_FOOTER.SHOWING` | `Showing {startItem} – {endItem} of {totalItems} companies` | `Hiển thị {startItem} – {endItem} trong {totalItems} doanh nghiệp` |

**`{en,vi}/chatlist.json`**:

| Key | en | vi |
| --- | --- | --- |
| `CHAT_LIST.DISPLAY_MODE.LABEL` (dòng 159) | Display mode | Chế độ hiển thị |
| `CHAT_LIST.DISPLAY_MODE.OPTIONS.default` | Default | Mặc định |
| `CHAT_LIST.DISPLAY_MODE.OPTIONS.company` | Group by company | Hiển thị theo doanh nghiệp |
| `CHAT_LIST.DISPLAY_MODE.OPTIONS.vip` | Starred customers only | Hiển thị khách gắn sao |
| `CHAT_LIST.COMPANY_LIST.EMPTY` (dòng 18-24 / 20-26) | No companies yet | Chưa có doanh nghiệp nào |
| `CHAT_LIST.COMPANY_LIST.NO_CONVERSATIONS` | No conversations for this company | Doanh nghiệp này chưa có hội thoại nào |
| `CHAT_LIST.COMPANY_LIST.LOAD_MORE` | Load more | Xem thêm |
| `CHAT_LIST.COMPANY_LIST.FETCH_ERROR` | Could not load companies | Không tải được danh sách doanh nghiệp |
| `CHAT_LIST.COMPANY_LIST.NO_COMPANY` | No company | Chưa thuộc doanh nghiệp |

**`{en,vi}/conversation.json`** → `CONVERSATION.SIDEBAR`:

| Key | en | vi |
| --- | --- | --- |
| `CONTACT` | Contact | Liên hệ |
| `COMPANY` | Company | Doanh nghiệp |
| `NO_COMPANY` | This contact is not linked to a company yet. | Liên hệ này chưa thuộc doanh nghiệp nào. |
| `COLLAPSE_PANEL` | Collapse panel (Alt+O) | Thu gọn bảng thông tin (Alt+O) |

**`{en,vi}/contact.json`** → `CONTACT_PANEL.VIP`: `BADGE` Starred customer / Khách gắn sao; `MARK` Star this customer / Gắn sao khách hàng; `UNMARK`, `MARKED`, `UNMARKED`, `ERROR` đều đã dịch. `CONTACTS_LAYOUT.SIDEBAR.MERGE.*` (`TITLE` Merge contact / Hợp nhất liên hệ, `PRIMARY` Primary contact / Liên hệ chính, `PRIMARY_HELP_LABEL` To be saved / Sẽ được giữ lại, `PARENT_HELP_LABEL` To be deleted / Sẽ được xoá, …) cũng đã dịch.

**`{en,vi}/settings.json`** → `SIDEBAR.COMPANIES` = Companies / Doanh nghiệp (dòng 329 en, 327 vi), `SIDEBAR.ALL_COMPANIES` = All Companies / Tất cả doanh nghiệp.

Namespace `ATTRIBUTES_MGMT.TABS.*`, `ATTRIBUTES_MGMT.ATTRIBUTE_MODELS.*`, `ATTRIBUTES_MGMT.ATTRIBUTE_TYPES.*` dùng cho trang custom attribute (key suy từ `ATTRIBUTE_MODELS[].key` / `ATTRIBUTE_TYPES[].key`, ví dụ `ATTRIBUTES_MGMT.TABS.COMPANY`).

### Backend — `config/locales/en.yml`

| Key | Giá trị | Dùng ở |
| --- | --- | --- |
| `errors.companies.domain.invalid` (dòng 131-133) | `must be a valid domain name` | `Company` validate `:domain` |
| `errors.companies.search.query_missing` (dòng 134-135) | `Specify search string with parameter q` | `CompaniesController#search` |
| `errors.contacts.email.invalid` (dòng 127-128) | `Invalid email` | `Contact` validate `:email` |
| `errors.contacts.phone_number.invalid` (dòng 129-130) | `should be in e164 format` | `Contact` validate `:phone_number` — **thông điệp sai thực tế**, regex còn nhận số `0…` |
| `errors.contacts.import.failed` (dòng 123-124) | `File is blank` | `ContactsController#import` |
| `errors.contacts.export.success` (dòng 125-126) | `We will notify you once contacts export file is ready to view.` | `ContactsController#export` |
| `errors.custom_attribute_definition.attribute_key_format` (dòng 201) | `must only contain letters, numbers, underscores, hyphens, and dots` | `CustomAttributeDefinition` validate `:attribute_key` |
| `errors.custom_attribute_definition.key_conflict` (dòng 202) | `The provided key is not allowed as it might conflict with default attributes.` | `attribute_must_not_conflict` |
| `contacts.online.delete` (dòng 396-397) | `%{contact_name} is Online, please try again later` | `ContactsController#destroy` |

Chuỗi `"Companies are not enabled for this account"` (companies_controller:79 và companies/base_controller:10) và `"Specify search string with parameter q"` (companies/contacts_controller:22) được **hardcode**, không qua i18n.

## ⚠️ Phụ thuộc chéo

- **[crm-perfex.md](crm-perfex.md)** — `contacts.additional_attributes.external.perfex_contact_id`, `companies.additional_attributes.external.perfex_customer_id`, `Crm::Perfex::{ContactSyncService,ContactMatcherService,CompanySyncService,CompanyResolverService,ContactChannelUnmapper}`, callback `Contact#enqueue_crm_cache_match`, route `match_crm` / `unmap_crm` / `crm_force_sync`, trang `/contacts-directory` (`components-next/Contacts/CrmDirectory/Index.vue`, gọi `contacts#index` với `company_id: 'none'`). Trang CRM Directory **phụ thuộc vào API `companies` chỉ có trong `enterprise/`**. `CompanyPanel.vue` đọc `additionalAttributes.external.perfexCustomerId` để hiện dòng "Mã CRM".
- **[conversations.md](conversations.md)** — `Enterprise::ConversationFinder` (`enterprise/app/finders/enterprise/conversation_finder.rb`) nhúng `company_meta` và `filter_by_company` vào `set_up`; `conversations/index.json.jbuilder` + `meta.json.jbuilder` phơi `vip_count` và `company_counts`; `Conversations::PermissionFilterService` được dùng lại trong `companies/{conversations,attachments}_controller`. Sửa `ConversationFinder#set_up` là động vào chế độ hiển thị theo doanh nghiệp.
- **[channels.md](channels.md)** — `ContactInbox.source_id` format phụ thuộc channel_type; `ContactInboxBuilder#generate_source_id` raise với channel chưa hỗ trợ. Thêm kênh mới phải cập nhật builder (và overlay enterprise cho Twilio voice).
- **Deal & Ticket** (`deals-tickets.md`, chưa lập) — `Contact has_many :deals, dependent: :nullify` và `has_many :tickets, dependent: :nullify`; `companies/deals_controller` lọc deal theo `@company.contacts`; `CustomAttributeDefinition` có thêm `deal_attribute` / `ticket_attribute`; `COMPANIES.CONVERSATION_PANEL.SECTIONS.DEALS` gate bằng flag `crm_deals`; `formatVND` import từ `components-next/Deals/constants`.
- **Cuộc gọi** ([phone-calls.md](phone-calls.md)) — `CompanyPanel` render `components-next/Contacts/VoiceCallButton.vue` cho `mainContact.phoneNumber`; route `POST /contacts/:id/call`.
- **Trợ lý AI** (`ai-assistant.md`, chưa lập) — `enterprise/app/services/tekomi/llm/contact_attributes_service.rb` và `contact_notes_service.rb` sinh custom attribute / note cho contact bằng LLM; `enterprise/lib/tekomi/prompts/snippets/contact.liquid`; tool copilot `get_contact_service.rb`, `search_contacts_service.rb`, `add_contact_note_tool.rb`; `app/services/llm_formatter/contact_llm_formatter.rb`. `enterprise/app/services/tekomi/audience_matcher.rb` và `llm/system_prompts_service.rb` có tham chiếu `company`.
- **Campaign** — `Contact has_many :campaign_recipients, dependent: :destroy_async` (enterprise concern).
- **Widget / pre-chat** — `CustomAttributeDefinition` với model conversation/contact đồng bộ sang `pre_chat_form_options` của web widget qua `Inboxes::{Sync,Update}WidgetPreChatCustomFieldsJob`. Đổi `attribute_model` giữa conversation/contact ↔ company là bật/tắt đồng bộ này (`widget_attribute?`).
- **Unread count filter** — `CustomAttributeDefinition` với `conversation_attribute` invalidate `Conversations::UnreadCounts::FilteredCountInvalidator`; không áp dụng cho contact/company attribute.
- **Avatar** — `Avatarable` dùng chung cho `Contact`, `Company`, `User`, `Inbox`…; `Company` dựa vào `Avatar::AvatarFromFaviconJob` → `Avatar::AvatarFromUrlJob`.

## Cạm bẫy đã biết

1. **`no_company_count` và `company_starred_waiting_ids` được tính nhưng không bao giờ gửi về client.** `Enterprise::ConversationFinder#company_meta` (`enterprise/app/finders/enterprise/conversation_finder.rb:36-40`) trả 3 khoá, nhưng `app/views/api/v1/accounts/conversations/meta.json.jbuilder:7` và `index.json.jbuilder:8` chỉ render `company_counts`. Hệ quả thực tế ở `CompanyConversationList.vue`: `conversationStats.noCompanyCount` luôn `0` → nhóm "Chưa thuộc doanh nghiệp" luôn hiện số 0, bị `:disabled` (`companyCount(id)` falsy) nên **không bao giờ mở được**, và hội thoại của contact chưa có company không hiển thị trong chế độ theo doanh nghiệp; `companyStarredWaitingIds` luôn `[]` → `companyTier` / `priorityCompanyIds` chỉ hoạt động với nhóm đã load sẵn, mất tính năng "tự mở nhóm có khách gắn sao đang chờ".

2. **Menu "Companies" đang bị ẩn bởi cờ demo.** `app/javascript/dashboard/components-next/sidebar/Sidebar.vue:1036-1039`: `const DEMO_MODE = true;` và `DEMO_HIDDEN_TOP_LEVEL = ['Calls', 'Companies', 'Portals']`. Mục Companies vẫn được build ở dòng 721-738 nhưng bị filter bỏ. Trang `/companies` chỉ vào được bằng URL trực tiếp hoặc nút "Chi tiết" trong `CompanyPanel`. Ngoài ra mục sidebar này **không** có gate `featureFlag: companies` riêng (chỉ route meta có), nên nếu tắt `DEMO_MODE` thì menu sẽ hiện cả khi flag `companies` chưa bật.

3. **`ContactMergeAction` không chuyển deal, ticket, nhãn (label) và CSAT của contact bị gộp.** `app/actions/contact_merge_action.rb` chỉ xử lý `conversations`, `messages`, `contact_inboxes`, `notes` (dòng 35-49). Khi `@mergee_contact.reload.destroy!` chạy (dòng 62): `has_many :deals, dependent: :nullify` và `has_many :tickets, dependent: :nullify` → **deal/ticket bị mất `contact_id`**, không gắn sang contact base; `csat_survey_responses` và (enterprise) `campaign_recipients`, `conversation_analyses` bị `destroy_async`; nhãn (`Labelable` / taggings) của mergee không được gộp. Chỉ `company_id` được xử lý riêng qua `preserve_company`.

4. **Tự gắn doanh nghiệp theo email bỏ qua toàn bộ callback, nên UI không cập nhật.** `Contacts::CompanyAssociationService#associate_company_from_email` (`enterprise/app/services/contacts/company_association_service.rb:7-11`) dùng `contact.update_columns` + `Company.increment_counter` → không bắn `CONTACT_UPDATED`, không đi qua `sync_company_name_from_company`, không cập nhật `updated_at`. Dashboard đang mở sẽ không thấy `company_id` mới cho tới khi reload. Thêm nữa `should_associate_company?` yêu cầu `saved_change_to_email.first.nil?` nên **đổi email sang domain khác không bao giờ gắn lại company**.

5. **Thiếu đồng bộ giữa `additional_attributes['company_name']` và `company_id`.** Có 3 đường ghi `company_name` khác nhau: `sync_company_name_from_company` (callback, theo `company_id`), `Companies::SyncContactNamesJob` (SQL thuần khi đổi tên company), và nhập tay qua `ContactsForm` / `DataImport::ContactManager` (không liên quan `company_id`). Scope sắp xếp `Contact.order_on_company_name` và filter `company_name` (`contactFilterItems/index.js:57`) đọc **chuỗi trong jsonb**, không join `companies` — nên một contact có `company_id` nhưng `company_name` lệch (hoặc rỗng) sẽ sắp/lọc sai. `CompanyPanel` thì ngược lại, luôn đọc `company.name` thật.

6. **Flag `crm_v2` thay đổi hoàn toàn ngữ nghĩa `/contacts`.** `Contact.resolved_contacts(use_crm_v2: true)` (`app/models/contact.rb:190-194`) trả `where(contact_type: 'lead')` thay cho điều kiện "có email/phone/identifier". Vì `Contacts::SyncAttributes#set_contact_type` chỉ nâng `visitor → lead` và không bao giờ set `customer`, nhưng CRM/import có thể set `customer`, nên khi bật `crm_v2` các contact `contact_type = customer` **biến mất khỏi danh sách liên hệ**. Flag này `chatwoot_internal: true`, mặc định tắt.

7. **`middle_name` / `last_name` có trong DB nhưng không có đường ghi qua API dashboard.** `ContactsController#permitted_params` (dòng 220) không permit hai cột này, `_contact.json.jbuilder` cũng không trả về. `ContactsForm.vue` có `firstName`/`lastName` nhưng `emitContactUpdate` (dòng 103-109) **loại bỏ cả hai** (`const { firstName, lastName, ...stateWithoutNames } = state`) trước khi emit. Hai cột này thực tế là dead column ở luồng dashboard.

8. **`db/schema.rb` lạc hậu so với `db/migrate/`.** `db/schema.rb:15` khai version `2026_09_25_000002`, nhưng còn 6 migration mới hơn chưa dump, trong đó có `20260928000001_add_vip_to_contacts.rb` và `20261002000001_add_vip_to_companies.rb`. Cột `vip` (và index `(account_id, vip) WHERE vip = true`) **không có trong `schema.rb`** dù code dùng khắp nơi (`_contact.json.jbuilder:8`, `_company.json.jbuilder:6`, `Enterprise::ConversationFinder:32`, `companies_controller:92`). Annotation ở đầu `app/models/contact.rb` thì đã có `vip` — tức annotation mới hơn schema. Đừng dùng `schema.rb` làm nguồn chân lý cho vùng này; đọc `db/migrate/`.

9. **Enum `attribute_model` có 5 giá trị, UI chỉ phơi 4; `attribute_display_type` có 8, UI chỉ phơi 6.** `CustomAttributeDefinition` (dòng 47-48) định nghĩa `ticket_attribute: 4` và `currency: 2`, `percent: 3`, nhưng `routes/dashboard/settings/attributes/constants.js` không liệt kê `TICKET`, `CURRENCY`, `PERCENT`. Store đã có getter `getTicketAttributes` nhưng không có tab nào để tạo. Tạo loại này chỉ làm được qua API trực tiếp.

10. **`CompanyCustomAttributes.vue` + `CompanyCustomAttributeItem.vue` là code chết; tab "Attributes" của company không tồn tại.** Hai file trong `components-next/Companies/CompanyDetail/` chỉ import lẫn nhau, không component/route nào import chúng (`grep -rn "CompanyCustomAttribute" app/javascript` chỉ ra chính hai file đó). `CompanyDetailView.vue:65-69` chỉ có 3 tab `history/notes/contacts`. Khoá i18n `COMPANIES.DETAIL.SIDEBAR.TABS.ATTRIBUTES` và cả nhóm `COMPANIES.DETAIL.ATTRIBUTES.*` (en + vi) hiện **không được dùng**. Thực tế custom attribute của company chỉ đọc-được qua `infoRows` trong `CompanyPanel.vue` (không sửa được trong UI).

11. **API `GET /companies/:id/attachments` và `companiesStore.getCompanyAttachments` không có người gọi.** Controller `enterprise/app/controllers/api/v1/accounts/companies/attachments_controller.rb`, route `get :attachments` (`config/routes.rb:244`), `CompanyAPI.listAttachments` và action `getCompanyAttachments` (`stores/companies.js:396-427`) đều tồn tại, nhưng không component nào đọc `companyAttachments`. Không có panel "Files" nào cho company ở thời điểm này.

12. **`fetchCompanies` trong chế độ theo doanh nghiệp tải *tất cả* company bằng vòng lặp đồng bộ.** `CompanyConversationList.vue:104-122` gọi `GET /companies?page=N` lặp lại đến khi `all.length >= meta.total_count`, mỗi trang 25 bản ghi, tuần tự (`eslint-disable no-await-in-loop`). Account có vài nghìn doanh nghiệp sẽ tạo hàng trăm request liên tiếp khi vừa bật chế độ này, và mọi nhóm đều được `expandAllCompanies()` mở sẵn → thêm một request `/conversations` cho từng nhóm có hội thoại.

13. **`Contacts::InboundPhoneResolver` bước fallback load toàn bộ contact có số điện thoại vào Ruby.** `app/services/contacts/inbound_phone_resolver.rb:17-19`: `@account.contacts.where.not(phone_number: [nil, '']).find do … end` — `find` của Enumerable, không phải của ActiveRecord, nên quét tuần tự toàn bảng trong tiến trình app. Nằm trên đường tin nhắn vào (`ContactInboxWithContactBuilder#find_contact_by_phone_number`), nên là điểm nóng khi account lớn.

14. **Công ty không có `domain` dễ sinh trùng, và `domain = ''` lọt validation nhưng vi phạm unique index.** `Company` validate uniqueness domain với `if: -> { domain.present? }` và `allow_blank: true`, nhưng partial unique index là `WHERE (domain IS NOT NULL)` — chuỗi rỗng **là** NOT NULL, nên hai company cùng account với `domain = ''` sẽ `RecordNotUnique` ở DB mà model không báo trước. UI hiện tại tránh được vì `CompanyCreateDialog.vue:41` và `CompanyProfileCard.vue:117` gửi `domain: form.domain.trim() || null`; gọi API trực tiếp với `domain: ""` thì không. Ngoài ra `index_companies_on_name_and_account_id` không unique nên nhiều company trùng tên (domain nil) là hợp lệ.

15. **`DELETE /companies/:id` trả `200` trước khi xoá xong.** `CompaniesController#destroy` (dòng 51-54) chỉ enqueue `Companies::DeleteJob` rồi `head :ok`; store xoá bản ghi khỏi `records` ngay (`stores/companies.js:212`). Nếu job fail hoặc queue `low` nghẽn, company vẫn còn trong DB nhưng đã biến mất khỏi danh sách phía client cho tới khi refetch.

16. **`PATCH` không xoá được khoá jsonb.** `contact_update_params` (contacts_controller:235-239) và `company_update_params` (companies_controller:105-107) đều **merge** `custom_attributes` (và contact còn merge cả `additional_attributes`) với giá trị cũ. Muốn xoá một khoá phải gọi `POST .../destroy_custom_attributes` với mảng key. Với `additional_attributes` của contact thì **không có** endpoint xoá nào — chỉ ghi đè được bằng giá trị rỗng.

17. **Thông điệp lỗi số điện thoại sai so với validation thực tế.** `errors.contacts.phone_number.invalid` = `"should be in e164 format"` (`config/locales/en.yml:129-130`), nhưng regex ở `app/models/contact.rb:60` là `/\A(\+[1-9]\d{1,14}|0\d{8,10})\z/` — chấp nhận cả số nội địa `0…`. Người dùng nhập `0901234567` thành công nhưng nhập sai định dạng lại nhận thông điệp nói phải dùng E.164.

18. **Chuỗi lỗi "Companies are not enabled for this account" bị hardcode ở 2 chỗ.** `enterprise/app/controllers/api/v1/accounts/companies_controller.rb:79` và `enterprise/app/controllers/api/v1/accounts/companies/base_controller.rb:10` lặp nguyên chuỗi, không dùng i18n — vi phạm quy ước i18n của repo và không đổi được theo ngôn ngữ / thương hiệu.
