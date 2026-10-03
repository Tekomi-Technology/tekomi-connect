> Lập tại commit `c37c7293a9` — ngày 2026-10-03

# Bản đồ: Super Admin, cấu hình hệ thống, phân quyền & Báo cáo

> Nhánh `customer/gmo-develop` (white-label "GMO Connect").
> Bản đồ có thể lạc hậu khi code đổi. Luôn kiểm chứng lại điểm then chốt trước khi kết luận.

## Tóm tắt

Vùng này gồm bốn khối tách biệt nhưng dính nhau rất chặt:

1. **Super Admin console** — dùng gem `administrate`. Toàn bộ controller nằm ở
   `app/controllers/super_admin/*`, định nghĩa field/field-set ở `app/dashboards/*_dashboard.rb`,
   view ERB ở `app/views/super_admin/`. Xác thực bằng Devise scope riêng (`SuperAdmin` model),
   **không** dùng `AccountUser` role. Mount tại `/super_admin` (`config/routes.rb:806-850`).
2. **Cấu hình cài đặt (instance config)** — bảng `installation_configs`, đọc qua
   `GlobalConfigService.load` / `GlobalConfig.get`. Nguyên tắc: **hàng DB thắng ENV**; ENV chỉ là
   nguồn seed một lần rồi được ghi ngược vào DB.
3. **Phân quyền** — hai tầng: `AccountUser#role` enum (`agent`/`administrator`) trong OSS, cộng thêm
   `CustomRole` (Enterprise) với 6 permission chuỗi. Backend cưỡng chế qua Pundit policy; frontend
   cưỡng chế qua `meta.permissions` trên route + `usePolicy()` + các bảng hằng trong
   `dashboard/constants/permissions.js`.
4. **Báo cáo** — hai họ API cùng tồn tại:
   - `api/v2/accounts/reports*` (admin-only, qua `ReportPolicy`) — trang **Reports** cũ trong sidebar.
   - `api/v2/accounts/dashboard` (**mọi thành viên**, không policy) — trang **Overview dashboard**
     mới ở `/accounts/:id/home`, dựng lại ở commit `b7aff25e80` (API) + `b9fdd11585` (UI KPI tabs).

Lưu ý quan trọng của nhánh này: mục **Reports → Tickets** và **Settings → Ticket SLA** đã bị gỡ khỏi
sidebar/route ở commit `6360e33c4d` ("feat(tickets): read conversation tickets from the CRM and retire
the internal ticket UI"), nhưng **backend vẫn còn sống** và một loạt file frontend trở thành mồ côi.
Chi tiết ở mục [Cạm bẫy đã biết](#cạm-bẫy-đã-biết) #1 và #2.

## Database

### `installation_configs`

Schema annotate ở `app/models/installation_config.rb:1-16`.

| Cột | Kiểu | Ghi chú |
|---|---|---|
| `name` | `string not null` | UNIQUE (`index_installation_configs_on_name`), thêm một UNIQUE `(name, created_at)` |
| `serialized_value` | `jsonb not null` | thực chất serialize **YAML** vào cột jsonb (xem dưới) |
| `locked` | `boolean default(TRUE) not null` | `true` = không hiện trong CRUD `installation_configs` |
| `created_at`/`updated_at` | `datetime` | `default_scope { order(created_at: :desc) }` (`:37`) |

- `serialize :serialized_value, coder: YAML, type: ActiveSupport::HashWithIndifferentAccess`
  (`:29`) — đây là di sản, trong comment code ghi rõ `FIX ME : fixes breakage of installation config.
  we need to migrate.`
- Accessor `value` / `value=` bọc quanh key `:value` của hash (`:42-50`).
- `scope :editable, -> { where(locked: false) }` (`:38`) — `SuperAdmin::InstallationConfigsController#scoped_resource`
  chỉ liệt kê hàng này.
- `after_commit :clear_cache` → `GlobalConfig.clear_cache` (`:40`, `:58-60`).
- Validate riêng: `saml_sso_users_check` — chặn tắt `ENABLE_SAML_SSO_LOGIN` nếu còn `User` nào
  `provider: 'saml'` (`:33`, `:62-67`).

### `account_users`

Schema ở `app/models/account_user.rb:1-25`.

| Cột | Ghi chú |
|---|---|
| `role` | `integer default(agent)` — `enum role: { agent: 0, administrator: 1 }` (`:34`) |
| `custom_role_id` | bigint, index `index_account_users_on_custom_role_id` — association chỉ tồn tại ở Enterprise (`enterprise/app/models/enterprise/concerns/account_user.rb`) |
| `agent_capacity_policy_id` | bigint (Enterprise) |
| `availability` | `integer default(online) not null` — `enum availability: { online: 0, offline: 1, busy: 2 }` |
| `auto_offline` | `boolean default(TRUE)` |
| `active_at` | `datetime` |
| `inviter_id` | FK tới `users` |
| UNIQUE | `uniq_user_id_per_account_id (account_id, user_id)` + validate `uniqueness scope: :account_id` (`:45`) |

### `custom_roles` (Enterprise)

`enterprise/app/models/custom_role.rb:1-16`.

| Cột | Ghi chú |
|---|---|
| `name` | string, validate presence |
| `description` | string |
| `permissions` | `text default([]), is an Array` — validate `inclusion: { in: PERMISSIONS }` |
| `account_id` | bigint not null, index |

`CustomRole::PERMISSIONS` (`:35-42`) — **đúng 6 giá trị**:
`conversation_manage`, `conversation_unassigned_manage`, `conversation_participating_manage`,
`contact_manage`, `report_manage`, `knowledge_base_manage`.

`has_many :account_users, dependent: :nullify` (`:29`) — xoá role thì agent tụt về `role` enum.

### Feature flag trên `accounts`

Lưu bằng **bitset** qua gem `flag_shih_tzu`, concern `app/models/concerns/featurable.rb`.

- Hai cột bigint: `feature_flags` và `feature_flags_ext_1`
  (`Featurable::FEATURE_FLAG_COLUMNS`, `:5`). Mỗi cột tối đa **63** flag (`MAX_FEATURES_PER_COLUMN`, `:6`).
- Thứ tự khai báo trong `config/features.yml` **là** vị trí bit → comment đầu file ghi rõ
  `DO NOT change the order of features EVER` và `feature_flags` đã đầy 63/63.
- `Featurable.feature_flag_mappings_for` (`:16-30`) raise `ArgumentError` nếu vượt 63 hoặc gặp tên
  cột lạ → sai cấu hình sẽ **nổ khi boot**, không âm thầm.

### Bảng báo cáo

`reporting_events` (`app/models/reporting_event.rb:1-28`):

| Cột | Ghi chú |
|---|---|
| `name` | string — `first_response`, `conversation_resolved`, `reply_time`, … |
| `value` | float, validate presence |
| `value_in_business_hours` | float |
| `event_start_time` / `event_end_time` | datetime |
| `account_id`, `conversation_id`, `inbox_id`, `user_id` | integer |

Index đáng chú ý: `index_reporting_events_for_response_distribution (account_id, name, inbox_id, created_at)`
và `reporting_events__account_id__name__created_at`.

`reporting_events_rollups` (`app/models/reporting_events_rollup.rb:1-22`):
`date`, `dimension_type` (enum string: `account`/`agent`/`inbox`/`team`), `dimension_id`,
`metric` (enum string 6 giá trị: `resolutions_count`, `first_response`, `resolution_time`,
`reply_time`, `bot_resolutions_count`, `bot_handoffs_count`), `count`, `sum_value`,
`sum_value_business_hours`. UNIQUE `index_rollup_unique_key (account_id, date, dimension_type, dimension_id, metric)`.

## Backend

### Super Admin

`SuperAdmin::ApplicationController` (`app/controllers/super_admin/application_controller.rb`):
- `before_action :authenticate_super_admin!` (`:16`) — Devise scope `super_admin`, hoàn toàn độc lập
  với `User`/`AccountUser`.
- `around_action :switch_super_admin_locale` (`:17`, `:45-47`) — locale lấy từ
  `current_super_admin.ui_settings['locale']`, fallback `ENV['DEFAULT_LOCALE']`.
- `render_vue_component` (`:34-43`) — nhúng component Vue vào ERB bằng `div#app[data-component-name]`.
- `order` override: mặc định sắp `id desc` (`:25-30`).

Controller | Vai trò
---|---
`accounts_controller.rb` | CRUD account + `seed`, `reset_cache`, `destroy` (async), xử lý metadata suspend
`app_configs_controller.rb` | Form cấu hình theo nhóm (general / facebook / perfex / …)
`installation_configs_controller.rb` | CRUD thô từng hàng `InstallationConfig` (chỉ hàng `locked: false`)
`dashboard_controller.rb` | Trang chủ console: 4 con số + chart 30 ngày
`settings_controller.rb` | Chỉ `def show; end` — trang danh sách nhóm cấu hình
`users_controller.rb` | CRUD user, `destroy_avatar`, `resend_confirmation`
`account_users_controller.rb` | Gán user vào account (không hiện ở nav chính)
`access_tokens_controller.rb`, `agent_bots_controller.rb`, `platform_apps_controller.rb`, `platform_banners_controller.rb`, `instance_statuses_controller.rb`, `push_diagnostics_controller.rb` | phần còn lại của console
`enterprise/app/controllers/super_admin/llm_*` | Chỉ tồn tại khi `ChatwootApp.enterprise?`

#### `SuperAdmin::AppConfigsController`

`app/controllers/super_admin/app_configs_controller.rb`.

- Allowlist cứng theo nhóm (`:44-63`). `@config` lấy từ `params[:config]`, default `'general'` (`:40-42`).
  - `GENERAL_CONFIGS` (`:2-3`): `ENABLE_ACCOUNT_SIGNUP`, `FIREBASE_PROJECT_ID`, `FIREBASE_CREDENTIALS`,
    `WEBHOOK_TIMEOUT`, `MAXIMUM_FILE_UPLOAD_SIZE`, `WIDGET_TOKEN_EXPIRY`.
  - `META_INCIDENT_CONFIGS` (`:4`): `DISABLE_META_INBOX_CREATION`, `DISABLE_META_MESSAGE_SENDING` —
    **chỉ thêm vào khi `ChatwootApp.chatwoot_cloud?`** (`:45`).
  - `mapping` (`:47-60`) gồm các nhóm: `facebook`, `shopify`, `microsoft`, `email`, `linear`, `slack`,
    `instagram`, `tiktok`, `whatsapp_embedded`, `notion`, `google`, **`perfex`**.
  - Nhóm `perfex` là phần riêng của fork: `EXTERNAL_TICKET_SYSTEM_URL`,
    `EXTERNAL_TICKET_SYSTEM_API_KEY`, `EXTERNAL_TICKET_DEPARTMENT_ID` (xem thêm `crm-perfex.md`).
- Enterprise mở rộng thêm nhóm qua `prepend_mod_with` (`:81`):
  `enterprise/app/controllers/enterprise/super_admin/app_configs_controller.rb` thêm
  `custom_branding` (LOGO/LOGO_DARK/BRAND_NAME/INSTALLATION_NAME/…), `internal`
  (bao gồm `OTEL_PROVIDER`, `LANGFUSE_*`, `TEKOMI_CLOUD_PLAN_LIMITS`, `BLOCKED_EMAIL_DOMAINS`…),
  `tekomi` (`TEKOMI_FIRECRAWL_API_KEY`), `saml` (`ENABLE_SAML_SSO_LOGIN`).
- `#show` (`:8-19`): đọc giá trị hiện tại từ DB rồi **merge metadata** (`display_title`, `type`,
  `description`) lấy từ `ConfigLoader.new.general_configs` tức `config/installation_config.yml`.
  `type` chi phối widget render: `boolean` → select, `code` → textarea mono, `secret` → password +
  nút con mắt (`app/views/super_admin/app_configs/show.html.erb`).
- `#create` (`:21-36`): lặp `params['app_config']`, bỏ qua key không nằm trong allowlist,
  `InstallationConfig.where(name: key).first_or_create(value:, locked: false)` rồi set lại `value`
  và `save`.
- `restart_required_config_saved?` (`:76-78`) so với `InstallationConfig::RESTART_REQUIRED_CONFIG_KEYS`
  = `LANGFUSE_BASE_URL`, `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`, `OTEL_PROVIDER`; nếu trùng thì
  flash kiểu `success` kèm `I18n.t('super_admin.flash.restart_required')`.

Danh sách nhóm hiện trong sidebar console do `SuperAdmin::NavigationHelper#settings_pages`
(`app/helpers/super_admin/navigation_helper.rb:6-15`) sinh ra từ
`app/helpers/super_admin/features.yml` — chỉ những entry có **cả** `config_key` và `enabled: true`.

#### `SuperAdmin::AccountsController#seed`

`app/controllers/super_admin/accounts_controller.rb:54-57`:

```ruby
def seed
  Internal::SeedAccountJob.perform_later(requested_resource)
  redirect_back(..., notice: I18n.t('super_admin.accounts.seed.triggered'))
end
```

Chuỗi gọi: route `POST /super_admin/accounts/:id/seed` (`config/routes.rb:819`) →
`Internal::SeedAccountJob` (`app/jobs/internal/seed_account_job.rb`, `queue_as :low`) →
`Seeders::AccountSeeder#perform!` (`lib/seeders/account_seeder.rb`).

`Seeders::AccountSeeder`:
- Constructor raise `'Account Seeding is not allowed.'` nếu
  `ENV.fetch('ENABLE_ACCOUNT_SEEDING', !Rails.env.production?)` là falsy (`:13`).
- Đọc fixture `lib/seeders/seed_data.yml` (`:15`).
- `perform!` (`:19-28`): `set_up_account` → `seed_teams` → `seed_custom_roles` → `set_up_users` →
  `seed_labels` → `seed_canned_responses` → `seed_inboxes` → `seed_contacts`.
- **`set_up_account` (`:30-37`) là huỷ dữ liệu**: `destroy_all` trên teams, conversations, labels,
  inboxes, contacts, và `custom_roles` (nếu model đáp ứng).
- `create_user_record` (`:73-79`): password cố định `Password1!.`, `skip_confirmation!`, kéo avatar
  từ `xsgames.co` qua `Avatar::AvatarFromUrlJob`.

Partial nút bấm: `app/views/super_admin/accounts/_seed_data.html.erb` — bọc trong
`if ENV.fetch('ENABLE_ACCOUNT_SEEDING', !Rails.env.production?)`.

#### `SuperAdmin::AccountsController` — suspend & feature flag

- `resource_params` (`:38-44`): tách `suspension_category`/`suspension_reason` ra khỏi attribute của
  model, nén `limits`, và map `params[:enabled_features].keys` → `permitted_params[:selected_feature_flags]`
  (setter do `Featurable` định nghĩa động, `app/models/concerns/featurable.rb:64-71`).
- `validate_suspension_metadata` (`:73-84`) + `apply_suspension_metadata` (`:110-117`): ghi lịch sử
  suspend vào `account.internal_attributes['suspensions']` (mảng `{category, reason, suspended_at}`).
  Category phải thuộc `Account::SUSPENSION_CATEGORIES`, reason ≤ 256 ký tự.
- `#destroy` (`:64-69`): không xoá trực tiếp, đẩy `DeleteObjectJob`.
- `#reset_cache` (`:59-62`): `requested_resource.reset_cache_keys`.
- Enterprise prepend (`enterprise/app/controllers/enterprise/super_admin/accounts_controller.rb`)
  xử lý `manually_managed_features` qua `Internal::Accounts::InternalAttributesService` — chỉ hiện
  trên Chatwoot Cloud.

Field-set console: `app/dashboards/account_dashboard.rb`. Phần enterprise thêm field
`limits: AccountLimitsField`, `all_features: AccountFeaturesField`, và (chỉ cloud)
`manually_managed_features: ManuallyManagedFeaturesField` (`:11-25`).
`COLLECTION_FILTERS` (`:104-109`): `active`, `suspended`, `recent` (30 ngày), `marked_for_deletion`.

Tên hiển thị của feature flag trong console do
`SuperAdmin::AccountFeaturesHelper.feature_display_names` sinh ra:
`I18n.t("super_admin.account_features.#{name}", default: feature['display_name'])`
(`app/helpers/super_admin/account_features_helper.rb:7-11`), rồi lọc bỏ
`chatwoot_internal` (chỉ khi **không** phải cloud) và `deprecated` (`:13-23`).

#### `SuperAdmin::DashboardController`

`app/controllers/super_admin/dashboard_controller.rb` — `index` trả HTML hoặc JSON.
`dashboard_stats` cache `Rails.cache` key `'super_admin:dashboard_stats'` **30 phút** (`:14`), gồm:
`chartData` (`Conversation.unscoped.group_by_day(:created_at, range: 30.days.ago..2.seconds.ago).count`),
`accountsCount`, `usersCount`, `inboxesCount`, `conversationsCount`.
`conversations_count_estimate` (`:27-33`) đọc `reltuples` từ `pg_class` thay vì `COUNT(*)`, fallback
`Conversation.count` khi `reltuples` còn `-1` (bảng chưa VACUUM/ANALYZE).

### Cấu hình hệ thống: `GlobalConfig` / `GlobalConfigService`

`lib/global_config.rb` + `lib/global_config_service.rb`.

Thứ tự ưu tiên khi đọc một key (ví dụ `GlobalConfigService.load('WEBHOOK_TIMEOUT', 5)`):

1. **Redis cache** `"V1:GLOBAL_CONFIG:<KEY>"`, TTL `1.day`
   (`GlobalConfig::VERSION`/`KEY_PREFIX`/`DEFAULT_EXPIRY`, `:2-4`; `load_from_cache` `:40-51`).
2. **Hàng `installation_configs`** — `db_fallback` (`:53-55`). Giá trị này được **ghi vào cache**
   (kể cả khi là `nil`).
3. **ENV** — chỉ khi DB rỗng: `GlobalConfigService.load` fetch `ENV[config_key]`, nếu vẫn rỗng thì
   dùng `default_value`; rồi **tạo luôn hàng DB** `locked: false` và `GlobalConfig.clear_cache`
   (`lib/global_config_service.rb:8-15`).

Nghĩa là: **hàng DB ưu tiên hơn ENV**, và ENV chỉ có tác dụng một lần (lần đọc đầu tiên khi DB
chưa có hàng). Sau đó sửa ENV không còn hiệu lực — phải sửa trong Super Admin.

- `GlobalConfig.get(*keys)` trả `HashWithIndifferentAccess`; `typecast_config` (`:32-38`) cast
  `boolean` dựa trên `type` khai báo trong `config/installation_config.yml`.
- `GlobalConfig.clear_cache` (`:23-28`) chạy `conn.keys("V1:GLOBAL_CONFIG:*")` rồi `expire ... 0`
  trên Redis `$alfred`.

`ConfigLoader` (`lib/config_loader.rb`) là bộ reconcile chạy lúc deploy/seed:
- `reconcile_general_config` (`:40-46`) nạp `config/installation_config.yml` (472 dòng) vào DB.
- `reconcile_feature_config` (`:69-79`) nạp `config/features.yml` vào **một hàng duy nhất**
  tên `ACCOUNT_LEVEL_FEATURE_DEFAULTS` (`locked: true`).
- Cờ `reconcile_only_new` (default `true`) quyết định có ghi đè giá trị đang có hay không (`:7-16`).

Các config quan trọng (trích `config/installation_config.yml`, đã đổi brand cho fork):
`INSTALLATION_NAME: 'GMO Connect'`, `BRAND_NAME: 'GMO Connect'`, `LOGO`, `LOGO_DARK`,
`LOGO_THUMBNAIL`, `BRAND_URL`, `WIDGET_BRAND_URL`, `TERMS_URL`, `PRIVACY_URL`,
`DISPLAY_MANIFEST` (`type: boolean`, display_title đã đổi thành `'GMO Metadata'`),
`ENABLE_ACCOUNT_SIGNUP` (`locked: false`, `type: boolean`),
`CREATE_NEW_ACCOUNT_FROM_DASHBOARD`, `HCAPTCHA_SITE_KEY`/`HCAPTCHA_SERVER_KEY`,
`INSTALLATION_EVENTS_WEBHOOK_URL`, và `ACCOUNT_LEVEL_FEATURE_DEFAULTS` (sinh tự động).

### Phân quyền

#### Backend

`AccountUser#permissions` (`app/models/account_user.rb:58-60`):

```ruby
def permissions
  administrator? ? ['administrator'] : ['agent']
end
```

Enterprise override (`enterprise/app/models/enterprise/account_user.rb`):

```ruby
def permissions
  custom_role.present? ? (custom_role.permissions + ['custom_role']) : super
end
```

→ Khi user có `custom_role`, mảng permission **thay thế hoàn toàn** `['agent']`/`['administrator']`
và thêm literal `'custom_role'`.

`AccountUser` còn include hai mod enterprise (`:102-104`):
`Enterprise::AccountUser` (prepend), `Enterprise::Audit::AccountUser` (audited các cột
`availability, role, account_id, inviter_id, user_id`), `Enterprise::Concerns::AccountUser`
(`belongs_to :custom_role`, `belongs_to :agent_capacity_policy`).

Thay đổi `role` hoặc `custom_role_id` kích hoạt invalidate cache unread count
(`filtered_unread_count_visibility_changed?` `:85-87` → `Conversations::UnreadCounts::FilteredCountInvalidator`)
và dispatch `ACCOUNT_CACHE_INVALIDATED`. `CustomRole` cũng làm tương tự khi `permissions` đổi
(`enterprise/app/models/custom_role.rb:49-70`).

Policy liên quan tới báo cáo:

| File | Nội dung |
|---|---|
| `app/policies/report_policy.rb` | `view?` = `@account_user.administrator?` |
| `enterprise/app/policies/enterprise/report_policy.rb` | `view?` = `custom_role.permissions.include?('report_manage') \|\| super` |
| `app/policies/csat_survey_response_policy.rb` | `index?`/`metrics?`/`download?` = admin |
| `enterprise/app/policies/enterprise/csat_survey_response_policy.rb` | thêm `report_manage` cho cả 4 action (kể cả `update?`) |

Helper dùng chung ở `app/controllers/api/base_controller.rb`:
- `check_authorization(model = nil)` (`:14-18`) — suy model từ `controller_name.classify` rồi `authorize`.
- `check_admin_authorization?` (`:20-22`) — `raise Pundit::NotAuthorizedError unless Current.account_user.administrator?`.
  **Không** có nhánh custom_role.

#### Frontend

`app/javascript/dashboard/constants/permissions.js`:

```js
AVAILABLE_CUSTOM_ROLE_PERMISSIONS = [
  'conversation_manage', 'conversation_unassigned_manage',
  'conversation_participating_manage', 'contact_manage',
  'report_manage', 'knowledge_base_manage',
]
ROLES = ['agent', 'administrator']
REPORTS_PERMISSIONS = 'report_manage'
```

`ASSIGNEE_TYPE_TAB_PERMISSIONS` (`:32-53`) — quyết định tab nào của ChatList hiện ra:

| Tab | `count` getter | Permission được phép |
|---|---|---|
| `me` | `mineCount` | `ROLES` + cả 3 `CONVERSATION_PERMISSIONS` |
| `unassigned` | `unAssignedCount` | `ROLES` + `conversation_manage` + `conversation_unassigned_manage` |
| `all` | `allCount` | `ROLES` + `conversation_manage` + `conversation_participating_manage` |

`DISPLAY_MODE_PERMISSIONS` (`:55-69`) — quyết định chế độ hiển thị danh sách hội thoại:

| Mode | Permission |
|---|---|
| `default` | `ROLES` + cả 3 `CONVERSATION_PERMISSIONS` |
| `company` | `ROLES` + `conversation_manage` + `conversation_participating_manage` |
| `vip` | `ROLES` + cả 3 `CONVERSATION_PERMISSIONS` |

Cả hai hằng chỉ được tiêu thụ ở **một chỗ**: `app/javascript/dashboard/components/ChatList.vue`
(import `:52-53`, dùng `:206` và `:229`).

`app/javascript/dashboard/helper/permissionsHelper.js`:
- `hasPermissions(required, available)` — logic **OR** (`some`), không phải AND.
- `getUserPermissions(user, accountId)` — đọc `account.permissions` từ payload `/api/v1/profile`.
- `getUserRole(user, accountId)` — trả `'custom_role'` nếu có `custom_role_id`, ngược lại
  `account.role || 'agent'`.
- `filterItemsByPermission(items, userPermissions, getPermissions, transformItem)`.

`app/javascript/dashboard/helper/routeHelpers.js`:
- `routeIsAccessibleFor(route, userPermissions)` (`:15-18`) đọc `route.meta.permissions`.
- `defaultRedirectPage` (`:20-38`) — thứ tự fallback: `home` → `contacts` → **`reports/overview`** →
  `portals`, cuối cùng `home`.
- `validateLoggedInRoutes` (`:56-83`) — account bị suspend thì chỉ còn `account_suspended`
  (+ `billing_settings_index` cho administrator).

`app/javascript/dashboard/composables/usePolicy.js` — `shouldShow(featureFlag, permissions, installationTypes)`:
1. fail nếu `checkPermissions` sai;
2. fail nếu `checkInstallationType` sai (`INSTALLATION_TYPES.ENTERPRISE/CLOUD/COMMUNITY`);
3. **nếu không phải Chatwoot Cloud thì trả `true` luôn** (`:58`) — feature flag bị bỏ qua;
4. trên cloud: `isFeatureFlagEnabled(flag) || CLOUD_PAID_FEATURES.includes(flag)`.

Sidebar lấy permission/flag của từng leaf bằng cách resolve route rồi đọc `meta`
(`app/javascript/dashboard/components-next/sidebar/provider.js:107-128`).

Serialize sang frontend:
- `app/views/api/v1/models/_user.json.jbuilder:19-35` — mỗi phần tử `accounts[]` có `role`,
  `permissions` (= `account_user.permissions`), và khi enterprise thì partial
  `api/v1/models/_account_user` thêm `custom_role_id` + `custom_role {id,name,description,permissions}`.
- `app/views/api/v1/models/_account.json.jbuilder:28` — `json.features @account.enabled_features`.

### Báo cáo — Backend

#### Controller

| Controller | Authorization | Action |
|---|---|---|
| `app/controllers/api/v2/accounts/reports_controller.rb` | `authorize :report, :view?` (`:105-107`) | `index`, `summary`, `bot_summary`, `agents`, `inboxes`, `labels`, `teams`, `conversations`, `conversations_summary`, `conversation_traffic`, `drilldown`, `bot_metrics`, `inbox_label_matrix`, `first_response_time_distribution`, `outgoing_messages_count` |
| `app/controllers/api/v2/accounts/summary_reports_controller.rb` | `authorize :report, :view?` | `agent`, `team`, `inbox`, `label`, `channel` |
| `app/controllers/api/v2/accounts/live_reports_controller.rb` | `authorize :report, :view?` | `conversation_metrics`, `grouped_conversation_metrics` |
| `app/controllers/api/v2/accounts/ticket_reports_controller.rb` | `authorize :report, :view?` + `CrmTicketsFeatureConcern` | `index` |
| `app/controllers/api/v2/accounts/dashboard_controller.rb` | **không có** | `show` |

Chi tiết đáng ghi:
- `ReportsController#drilldown` (`:54-59`) có **cổng riêng, chặt hơn**:
  `return head :unauthorized unless Current.account_user.administrator?`, rồi
  `head :unprocessable_entity unless valid_drilldown_params?` (`:153-157`) — yêu cầu đủ
  `metric, bucket_timestamp, since, until`, metric phải nằm trong `Reports::ReportMetricRegistry`,
  `type` phải thuộc `V2::Reports::DrilldownBuilder::SUPPORTED_DIMENSION_TYPES`, và
  `Reports::DrilldownTimestampValidator.valid?`.
- `#outgoing_messages_count` (`:88-95`) chỉ nhận `group_by ∈ %w[agent team inbox label]`
  (`OUTGOING_MESSAGES_ALLOWED_GROUP_BY`), ngoài ra `422`.
- `#summary`/`#bot_summary` tự tính luôn kỳ trước: `build_summary` (`:180-185`) gọi
  `MetricBuilder` hai lần và merge `previous:`; khoảng trước = `since - (until - since) .. since`
  (`range`, `:167-178`).
- Các action CSV (`agents`, `inboxes`, `labels`, `teams`, `conversations_summary`,
  `conversation_traffic`) dùng `generate_csv` (`:99-103`) đặt `Content-Type: text/csv` + render
  template `.csv` ở `app/views/api/v2/accounts/reports/*`.
- `SummaryReportsController#channel` (`:21-25`) là action **duy nhất** chặn phạm vi ngày:
  `date_range_too_long?` > `6.months` → `render_could_not_create_error(I18n.t('errors.reports.date_range_too_long'))`.
- `LiveReportsController#conversation_metrics` cache Redis `Redis::Alfred` 1 phút, key
  `live_reports:conversation_metrics:<account_id>:<team_id|all>` (`:56-72`).
  `#grouped_conversation_metrics` **không** cache và chỉ cho `group_by ∈ %w[team_id assignee_id]` (`:35-42`).

#### Builder / Service

Thư mục `app/builders/v2/reports/`:

| File | Vai trò |
|---|---|
| `conversations/base_report_builder.rb` | chọn `V2::Reports::Timeseries::ReportBuilder` nếu metric được registry hỗ trợ |
| `conversations/metric_builder.rb` | `#summary` trả 7 key: `conversations_count`, `incoming_messages_count`, `outgoing_messages_count`, `avg_first_response_time`, `avg_resolution_time`, `resolutions_count`, `reply_time`; `#bot_summary` trả `bot_resolutions_count`, `bot_handoffs_count` |
| `conversations/report_builder.rb` | `#timeseries` cho một metric |
| `timeseries/base_timeseries_builder.rb`, `timeseries/report_builder.rb` | gom theo khoảng thời gian |
| `base_summary_builder.rb` | khung chung cho summary theo chiều; map `group_by_key` → `dimension_type` (`account_id→account`, `user_id→agent`, `inbox_id→inbox`, `conversations.team_id→team`) ở `:43-50` |
| `agent_summary_builder.rb`, `team_summary_builder.rb`, `inbox_summary_builder.rb`, `label_summary_builder.rb`, `channel_summary_builder.rb` | 5 chiều summary |
| `drilldown_builder.rb` | đào sâu một bucket; `DEFAULT_PER_PAGE 25`, `MAX_PER_PAGE 100`, `SUPPORTED_GROUP_BY = hour/day/week/month/year`, `SUPPORTED_DIMENSION_TYPES = account/inbox/agent/label/team` |
| `drilldown_record_serializer.rb` | serialize record của drilldown |
| `bot_metrics_builder.rb`, `inbox_label_matrix_builder.rb`, `first_response_time_distribution_builder.rb`, `outgoing_messages_count_builder.rb` | các widget lẻ |
| `dashboard_builder.rb` | **Overview dashboard** (xem dưới) |
| `app/builders/v2/report_builder.rb` | builder v2 cũ, còn dùng cho `conversation_metrics` và heatmap |
| `app/builders/tickets/report_builder.rb` | báo cáo ticket (xem Cạm bẫy #1) |

Tầng truy vấn: `app/services/reports/`
- `Reports::DataSource.for(**context)` (`data_source.rb:8-13`) — **hiện luôn trả
  `Reports::RawDataSource`**; comment trong code ghi
  `TODO: Route to Reports::RollupDataSource when rollup reads are implemented`.
- `Reports::ReportMetricRegistry` (`report_metric_registry.rb`) — `Data.define` mô tả từng metric:
  `name`, `aggregate` (`:count`/`:average`), `raw_event_name`, `rollup_metric`, `summary_key`,
  `raw_count_strategy`.
- `Reports::DrilldownTimestampValidator`, `Reports::RawDataSource`.
- `ReportingEvents::RollupService`, `ReportingEvents::BackfillService`,
  `ReportingEvents::MetricRegistry`, `ReportingEvents::EventMetricRegistry` — sinh/lấp
  `reporting_events_rollups`.
- `Reports::TimeFormatPresenter` (`app/presenters/reports/time_format_presenter.rb`) — format thời
  lượng cho CSV.

Helper controller: `app/helpers/api/v2/accounts/reports_helper.rb` (dựng mảng cho CSV) và
`app/controllers/concerns/api/v2/accounts/heatmap_helper.rb` → thực tế file là
`Api::V2::Accounts::HeatmapHelper`; `since_timestamp` (`:96-99`) đọc `params[:days_before]`,
default `6.days`.

#### `V2::Reports::DashboardBuilder` — Overview dashboard

`app/builders/v2/reports/dashboard_builder.rb` (thêm mới ở `b7aff25e80`, sửa ở `b9fdd11585`).
Comment đầu file nói rõ chủ ý: *"Totals cover the whole account (or one inbox); lists that link to
conversations only include inboxes the user can access."*

`#build` (`:14-24`) trả 7 nhánh: `summary`, `timeseries`, `live`, `channels`,
`first_response_distribution`, `csat`, `activity`.

| Nhánh | Nguồn |
|---|---|
| `summary` | `MetricBuilder#summary` kỳ hiện tại + `previous:` kỳ trước |
| `timeseries` | 4 metric trong `TIMESERIES_METRICS` (`conversations_count`, `resolutions_count`, `avg_first_response_time`, `avg_resolution_time`) + `previous_conversations_count` |
| `live` | `open`, `pending`, `unassigned`, `unattended`, `starred_waiting` (join `contacts.vip = true` và `waiting_since NOT NULL`) |
| `channels` | group `inboxes.channel_type` × `conversations.status`, sort giảm theo `total` |
| `first_response_distribution` | `ReportingEvent` name `first_response`, bucket `FIRST_RESPONSE_BUCKETS` = `0-1h`, `1-4h`, `4-8h`, `8-24h`, `24h+` (`:8-10`) |
| `csat` | `account.csat_survey_responses` — `average`, `previous_average`, `total`, `distribution` (group `rating`), `recent` (5 bản mới nhất, **đã lọc inbox**) |
| `activity` | trộn `resolved_events` + `starred_waiting_events` + `csat_events`, sort theo timestamp giảm, cắt `ACTIVITY_LIMIT = 8` |

Hằng: `ACTIVITY_LIMIT = 8`, `RECENT_LIMIT = 5` (`:6-7`).

Lọc theo inbox cho **danh sách** dùng `list_inbox_ids` (`:132-137`) = `user.assigned_inboxes.pluck(:id)`
giao với `inbox_id` nếu có. `User#assigned_inboxes` (`app/models/user.rb:141-143`) trả
**toàn bộ inbox của account nếu là administrator**, ngược lại chỉ inbox được gán.
Ngược lại, `conversations` (`:139-142`) và `summary`/`timeseries`/`channels`/`csat.average`
**không** lọc theo inbox của user.

`base_params` (`:160-168`) đặt cứng `business_hours: false`, `group_by: params[:group_by] || 'day'`.
`previous_since` = `since - (until - since)` (`:178-180`).

Enterprise override (`enterprise/app/builders/enterprise/v2/reports/dashboard_builder.rb`,
nối qua `prepend_mod_with` ở `:187`):
- `#build` → `super.merge(sla: sla)`.
- `sla` (`:10-22`): `total`, `missed`, `active`, `hit_rate` (1 chữ số thập phân, `nil` khi `total == 0`),
  `timeseries` (`{timestamp, hit, missed}`).
- `MISSED_STATUSES = %w[missed active_with_misses]` (`:2`).
- `activity_events` → `super + sla_missed_events` (`:43-51`), thêm loại `sla_missed`.
- Timezone của timeseries SLA: `ActiveSupport::TimeZone[params[:timezone_offset].to_f]` (`:39-41`),
  `permit: %w[day week month hour]`.
- **Không kiểm tra feature flag `sla`** — chỉ cần bản Enterprise là có nhánh `sla`.

## API / Route

### Super Admin (`config/routes.rb:806-850`)

```
devise_for :super_admins, path: 'super_admin', controllers: { sessions: 'super_admin/devise/sessions' }
GET    /super_admin/logout
GET    /super_admin                               super_admin/dashboard#index
GET    /super_admin/app_config                    super_admin/app_configs#show      (?config=<nhóm>)
POST   /super_admin/app_config                    super_admin/app_configs#create
GET|POST /super_admin/push_diagnostics            + POST .../destroy_subscriptions
resources :accounts                               (index/new/create/show/edit/update/destroy)
POST   /super_admin/accounts/:id/seed             super_admin/accounts#seed
POST   /super_admin/accounts/:id/reset_cache      super_admin/accounts#reset_cache
resources :users                                  + DELETE :id/avatar, POST :id/resend_confirmation
resources :access_tokens                          (index/show)
resources :installation_configs                   (index/new/create/show/edit/update)  # KHÔNG có destroy
resources :agent_bots                             + DELETE :id/avatar
resources :platform_apps
resources :platform_banners
GET    /super_admin/instance_status
GET    /super_admin/settings                      super_admin/settings#show
# chỉ khi ChatwootApp.enterprise?
resources :llm_providers
GET|PATCH /super_admin/llm_feature_models
resources :llm_prompt_templates                   (param: :key)
resources :account_users                          (new/create/show/edit/update/destroy)
mount Sidekiq::Web => '/super_admin/monitoring/sidekiq'   # authenticated :super_admin
```

Ngoài ra `namespace :installation` (`:852-855`): `GET|POST /installation/onboarding`.

Thứ tự khai báo `resources` trong block quyết định thứ tự sidebar console (comment ở `:817`).

### Báo cáo (`config/routes.rb:599-639`, prefix `/api/v2/accounts/:account_id`)

```
GET  dashboard                                     api/v2/accounts/dashboard#show
GET  summary_reports/agent | team | inbox | label | channel
GET  reports                                       #index           (?metric=&since=&until=&type=&id=&group_by=&business_hours=&timezone_offset=)
GET  reports/summary
GET  reports/bot_summary
GET  reports/agents            (CSV)
GET  reports/inboxes           (CSV)
GET  reports/labels            (CSV)
GET  reports/teams             (CSV)
GET  reports/conversations
GET  reports/conversations_summary   (CSV)
GET  reports/conversation_traffic    (CSV)
GET  reports/drilldown
GET  reports/bot_metrics
GET  reports/inbox_label_matrix
GET  reports/first_response_time_distribution
GET  reports/outgoing_messages_count
GET  live_reports/conversation_metrics
GET  live_reports/grouped_conversation_metrics
GET  ticket_reports                                 # còn sống, không còn UI
```

Các endpoint báo cáo liên quan nằm ở **v1** (`config/routes.rb:324-339`):

```
GET  /api/v1/accounts/:id/csat_survey_responses
GET  /api/v1/accounts/:id/csat_survey_responses/metrics
GET  /api/v1/accounts/:id/csat_survey_responses/download
PATCH /api/v1/accounts/:id/csat_survey_responses/:id        # chỉ enterprise
GET  /api/v1/accounts/:id/applied_slas                      # enterprise, admin-only
GET  /api/v1/accounts/:id/applied_slas/metrics
GET  /api/v1/accounts/:id/applied_slas/download
GET  /api/v1/accounts/:id/reporting_events                  # chỉ enterprise
```

API client frontend tương ứng:
`dashboard/api/reports.js` (v2 `reports`), `summaryReports.js`, `liveReports.js` (v2 `live_reports`),
`dashboard.js` (v2 `dashboard`), `csatReports.js` (v1 `csat_survey_responses`),
`slaReports.js` (v1 `applied_slas`), `ticketReports.js` (v2 `ticket_reports`, **mồ côi**).

## Frontend

### Trang Reports (sidebar → Reports)

Route: `app/javascript/dashboard/routes/dashboard/settings/reports/reports.routes.js`.
Mọi route con dùng chung `meta` (`:28-31`):

```js
const meta = {
  featureFlag: FEATURE_FLAGS.REPORTS,          // 'reports'
  permissions: ['administrator', 'report_manage'],
};
```

| Path (dưới `accounts/:accountId/reports`) | `name` | Component |
|---|---|---|
| `''` | — | redirect → `account_overview_reports` |
| `overview` | `account_overview_reports` | `LiveReports.vue` |
| `conversation` | `conversation_reports` | `Index.vue` |
| `agent` | `agent_reports` | `AgentReports.vue` (nhóm `oldReportRoutes`) |
| `inboxes` | `inbox_reports` | `InboxReports.vue` |
| `label` | `label_reports` | `LabelReports.vue` |
| `teams` | `team_reports` | `TeamReports.vue` |
| `agents_overview` / `agents/:id` | `agent_reports_index` / `agent_reports_show` | `AgentReportsIndex/Show.vue` |
| `inboxes_overview` / `inboxes/:id` | `inbox_reports_index` / `inbox_reports_show` | |
| `teams_overview` / `teams/:id` | `team_reports_index` / `team_reports_show` | |
| `labels_overview` / `labels/:id` | `label_reports_index` / `label_reports_show` | |
| `sla` | `sla_reports` | `SLAReports.vue` |
| `phone-calls` | `phone_call_reports` | `PhoneCallReports.vue` |
| `csat` | `csat_reports` | `CsatResponses.vue` |
| `bot` | `bot_reports` | `BotReports.vue` |

Hai nhóm `oldReportRoutes` (`:33-58`) và `revisedReportRoutes` (`:60-110`) **cùng được đăng ký**
(`:136-137`) — bản cũ không còn link từ sidebar nhưng URL vẫn mở được.

Component phụ: `components/ReportsWrapper.vue` (layout), `ReportHeader.vue`, `ReportFilters.vue`,
`ReportMetricCard.vue`, `ReportDrilldownCard.vue`, `ReportDrilldownDrawer.vue`,
`SummaryReports.vue`, `SummaryReportLink.vue`, `OverviewReportFilters.vue`,
`StatsLiveReportsContainer.vue`, `AgentLiveReportContainer.vue`, `BotMetrics.vue`,
thư mục `ChartElements/`, `Csat/`, `Filters/` (+ `Filters/v3`), `heatmaps/`, `SLA/`, `overview/`
(`AgentTable.vue`, `TeamTable.vue`, `AgentCell.vue`, `MetricCard.vue`).

Composable: `composables/useReportDrilldown.js`. Helper: `helpers/reportFilterHelper.js`.
Hằng: `constants.js` — `GROUP_BY_FILTER`, `GROUP_BY_OPTIONS` (DAY/WEEK/MONTH/YEAR),
`DATE_RANGE_OPTIONS` (`LAST_7_DAYS` offset 6, `LAST_30_DAYS` 29, `LAST_3_MONTHS` 89,
`LAST_6_MONTHS` 179, `LAST_YEAR`, …) — mỗi range khai báo sẵn `groupByOptions` hợp lệ.

Store Vuex: `store/modules/reports.js`, `summaryReports.js`, `csat.js`, `sla.js`, `SLAReports.js`.

### Overview dashboard (sidebar → Home)

Route: `app/javascript/dashboard/routes/dashboard/home/routes.js`

```js
{ path: frontendURL('accounts/:accountId/home'), name: 'account_home',
  component: HomeIndex,
  meta: { permissions: [...ROLES, ...CONVERSATION_PERMISSIONS] } }
```

→ **không** có `featureFlag`, và permission là nhóm hội thoại, **không** phải `report_manage`.

`home/Index.vue`:
- Mảng `TABS` (`:16-29`) đúng 7 tab, thứ tự này cũng quyết định chiều slide:
  `overview`, `conversations`, `resolved`, `response`, `csat`, `sla`, `channels`.
  Cờ `withGroupBy` (overview/conversations/resolved/response/sla) và `withDays` (chỉ conversations).
- `TRANSITIONS` (`:31-44`) — hiệu ứng 3D `translateX + rotateY + scale`, có
  `motion-reduce:transition-none`.
- `selectTab` so index cũ/mới để chọn `forward`/`backward` (`:62-67`).
- Ba trạng thái render: skeleton (`!data && isLoading`), lỗi (`!data && hasError`, nút retry
  `HOME.RETRY`), nội dung (`data`).

`home/components/`:
- `DashboardHeader.vue` — chọn period, chọn inbox (`inboxes/getInboxes`), nút refresh, nhãn
  "cập nhật lúc" (`useNow` interval 30s).
- `KpiTabs.vue` — 7 tile KPI; `tiles` computed (`:45`+), tile `sla` lấy `data?.sla?.hit_rate`,
  hiển thị `'—'` khi `null` (`:127-133`).
- `cards/`: `DashboardCard.vue`, `MiniStat.vue`, `TrendChart.vue`, `CategoryBarChart.vue`,
  `RadialChart.vue`, `ActivityFeedCard.vue`, `ChannelBreakdownCard.vue`, `ResolutionRingCard.vue`,
  `SlaGaugeCard.vue`, `TodayQueueCard.vue`, `TrafficCard.vue`.
- `tabs/`: `OverviewTab.vue`, `ConversationsTab.vue`, `ResolvedTab.vue`, `ResponseTab.vue`,
  `CsatTab.vue`, `SlaTab.vue`, `ChannelsTab.vue`.

`home/composables/useOverviewDashboard.js`:
- State: `period` (default `'week'`), `inboxId`, `data` (`shallowRef`), `isLoading`, `hasError`,
  `updatedAt`, `range`.
- Chống race: biến `requestId` tăng dần, response cũ bị bỏ (`:32-33`) — comment:
  *"A slower response for an older filter must not overwrite a newer one."*
- `watch([period, inboxId], load)` + `onMounted(load)`.
- `timezoneOffset()` = `-new Date().getTimezoneOffset() / 60`.

`home/composables/useChartTheme.js` — theme ApexCharts từ color token của dự án.

`home/helpers.js`:
- `PERIODS = ['day','week','month','quarter']`.
- `periodRange(period)` (`:9-29`) trả `{since, until, groupBy}` epoch giây;
  `quarter` → từ đầu quý, `groupBy: 'week'`; `day` → `groupBy: 'hour'`; còn lại `'day'`.
  `month` = **30 ngày** cố định, không phải đầu tháng.
- `percent`, `deltaPercent`, `formatNumber` (Intl, `'—'` khi null), `splitDuration` →
  `{value, unit}` với unit `SECONDS/MINUTES/HOURS/DAYS`, `formatDuration(seconds, t)`.
- `channelLabelKey(channelType)` map `INBOX_TYPES` → `HOME.DASHBOARD.CHANNELS.<KEY>`, fallback
  `OTHER`. Có hỗ trợ `ZALO_OA`, `ZALO_PERSONAL`, `PHONE` (phần riêng của fork).
- `SERIES_DOT_CLASSES` — 6 class Tailwind khớp thứ tự palette của `useChartTheme`.

Thư viện chart: **ApexCharts**, thêm vào ở commit `b9fdd11585` (`package.json`).

## Điểm vào giao diện

### Super Admin

- `https://<host>/super_admin` — đăng nhập bằng `SuperAdmin` (Devise riêng, không phải tài khoản agent).
- Sidebar console: Dashboard → Accounts → Users → Access Tokens → Installation Configs → Agent Bots
  → Platform Apps → Platform Banners → Instance Status → Settings (+ LLM Providers / LLM Feature
  Models / LLM Prompt Templates khi Enterprise). Thứ tự theo khai báo route.
- **Settings** (`/super_admin/settings`) liệt kê các nhóm cấu hình; mỗi nhóm link tới
  `/super_admin/app_config?config=<key>`. Danh sách nhóm = entry trong
  `app/helpers/super_admin/features.yml` có `config_key` + `enabled: true`:
  `general`, `saml`, `custom_branding`, `tekomi`, `email`, `facebook`, `instagram`, `tiktok`,
  `google`, `microsoft`, `linear`, `notion`, `slack`, `whatsapp_embedded`, `shopify`,
  **`perfex`** (hiển thị là "External Ticket System").
- **Seed dữ liệu mẫu**: `/super_admin/accounts/:id` → phần cuối trang show, nút
  `Generate Seed Data` (`app/views/super_admin/accounts/_seed_data.html.erb`). Chỉ render khi
  `ENABLE_ACCOUNT_SEEDING` bật hoặc không phải production.
- **Reset cache**: cùng trang, partial `_reset_cache.html.erb`.
- Sidekiq Web: `/super_admin/monitoring/sidekiq`.

### Dashboard agent

- **Home / Overview dashboard**: sidebar item `Home` (`i-lucide-house`,
  `app/javascript/dashboard/components-next/sidebar/Sidebar.vue:~744-752` trong `menuItems`) →
  route `account_home` → `/app/accounts/:id/home`.
- **Reports**: sidebar group `Reports` (icon `i-lucide-chart-spline`, màu `text-n-ruby-10`),
  `Sidebar.vue:740-777`. Thứ tự leaf hiện tại:
  1. `SIDEBAR.REPORTS_OVERVIEW` → `account_overview_reports`
  2. `SIDEBAR.REPORTS_CONVERSATION` → `conversation_reports`
  3. `SIDEBAR.REPORTS_PHONE_CALLS` → `phone_call_reports`
  4. `...reportRoutes.value` → `newReportRoutes()` (`:347-370`): Agents, Labels, Inbox, Team
     (trỏ vào nhóm `*_reports_index`, `activeOn` gồm `*_reports_show`)
  5. `SIDEBAR.CSAT` → `csat_reports`
  6. `SIDEBAR.REPORTS_SLA` → `sla_reports`
  7. `SIDEBAR.REPORTS_BOT` → `bot_reports`
- **Không còn** leaf `Reports Tickets` và **không còn** group `Tickets`; cũng không còn
  `Settings → Ticket SLA`. Đã xác minh: `grep` `SIDEBAR.REPORTS_TICKETS` / `SIDEBAR.TICKET_SLA` /
  `SIDEBAR.TICKETS` trong `app/javascript` (trừ file locale) cho **0 kết quả**.
- Hiển thị leaf được lọc bằng `usePolicy().shouldShow` với `meta.permissions` + `meta.featureFlag`
  resolve từ router (`components-next/sidebar/provider.js:107-128`).

## Luồng dữ liệu

### Đọc một config instance

```
Code gọi GlobalConfigService.load('WEBHOOK_TIMEOUT', 5)
  → GlobalConfig.get('WEBHOOK_TIMEOUT')
      → Redis $alfred GET "V1:GLOBAL_CONFIG:WEBHOOK_TIMEOUT"
        ├─ hit  → JSON.parse(...)['value']
        └─ miss → InstallationConfig.find_by(name:)&.value
                  → SET cache (ex: 1 day)   ← ghi cả khi value = nil
      → typecast_config: cast boolean theo `type` trong config/installation_config.yml
  → nếu blank: ENV.fetch('WEBHOOK_TIMEOUT') { 5 }
              → InstallationConfig.where(name:).first_or_create(value:, locked: false)
              → GlobalConfig.clear_cache
```

### Sửa config qua Super Admin

```
POST /super_admin/app_config?config=perfex   (form_with trong show.html.erb)
  → SuperAdmin::AppConfigsController#create
      → lọc theo @allowed_configs (mapping cứng)
      → InstallationConfig#save
          → after_commit :clear_cache → GlobalConfig.clear_cache (xoá mọi key V1:GLOBAL_CONFIG:*)
  → redirect_to super_admin_settings_path
      flash notice  = 'super_admin.app_configs.updated'
      flash success = + 'super_admin.flash.restart_required'  (nếu key ∈ RESTART_REQUIRED_CONFIG_KEYS)
```

### Seed dữ liệu mẫu cho account

```
Super Admin → Accounts → #<id> → "Generate Seed Data"
  POST /super_admin/accounts/:id/seed
    → Internal::SeedAccountJob.perform_later(account)        queue :low
        → Seeders::AccountSeeder.new(account:).perform!
            raise 'Account Seeding is not allowed.' nếu ENABLE_ACCOUNT_SEEDING falsy
            set_up_account   → destroy_all: teams, conversations, labels, inboxes, contacts, custom_roles
            seed_teams       ← lib/seeders/seed_data.yml['teams']
            seed_custom_roles← ['custom_roles'] (chỉ khi account.respond_to?(:custom_roles))
            set_up_users     → User.find_or_create_by!(email:) password 'Password1!.'
                               + AccountUser (role / custom_role) + teams
                               + Avatar::AvatarFromUrlJob
            seed_labels / seed_canned_responses / seed_inboxes / seed_contacts
```

CLI tương đương (ghi trong `CLAUDE.md`):
`bundle exec rails runner "Internal::SeedAccountJob.perform_now(Account.find(<id>))"`.

### Phân quyền một request báo cáo

```
GET /api/v2/accounts/1/reports/summary
  → Api::V1::Accounts::BaseController (set Current.account, Current.account_user)
  → before_action :check_authorization → authorize :report, :view?
      ReportPolicy#view?            = account_user.administrator?
      Enterprise::ReportPolicy#view? = custom_role.permissions.include?('report_manage') || super
  → V2::Reports::Conversations::MetricBuilder (x2: kỳ hiện tại + kỳ trước)
      → Reports::DataSource.for(...) → Reports::RawDataSource
          → reporting_events / conversations / messages
```

Phía UI, cùng một quyền được kiểm hai lần độc lập:
```
router.beforeEach → validateAuthenticateRoutePermission (routes/index.js)
  → validateLoggedInRoutes (helper/routeHelpers.js)
      → routeIsAccessibleFor(to, getUserPermissions(user, accountId))
        so meta.permissions = ['administrator','report_manage'] (OR)
      → sai → defaultRedirectPage: home → contacts → reports/overview → portals
Sidebar leaf  → usePolicy().shouldShow(meta.featureFlag, meta.permissions)
```

### Overview dashboard

```
/app/accounts/:id/home  (meta.permissions = ROLES + CONVERSATION_PERMISSIONS)
  home/Index.vue onMounted → useOverviewDashboard.load()
    periodRange(period) → { since, until, groupBy }
    GET /api/v2/accounts/:id/dashboard
        ?since=&until=&group_by=&inbox_id=&timezone_offset=
      → Api::V2::Accounts::DashboardController#show   (KHÔNG authorize)
          422 nếu thiếu since hoặc until
          → V2::Reports::DashboardBuilder#build
              summary / timeseries              → MetricBuilder + ReportBuilder (x nhiều lần)
              live / channels                   → account.conversations (toàn account hoặc 1 inbox)
              first_response_distribution       → ReportingEvent name='first_response'
              csat                              → account.csat_survey_responses
              activity                          → resolved + starred_waiting + csat (lọc theo
                                                   user.assigned_inboxes)
              [Enterprise] sla + sla_missed_events → account.applied_slas
    → data.value = response.data ; updatedAt = Date.now()
  KpiTabs (7 tile) → chọn tab → <component :is> + Transition 3D
```

## Feature flag

### Khai báo

`config/features.yml` — mảng YAML, mỗi entry: `name`, `display_name`, `enabled`, và tuỳ chọn
`column`, `help_url`, `chatwoot_internal`, `deprecated`.

Quy tắc bắt buộc ghi ở đầu file (`:12-16`):
- Cột `feature_flags` **đã đầy 63/63** → flag mới **phải** đặt `column: feature_flags_ext_1` và
  append vào cuối.
- Không đổi thứ tự, không xoá entry, không đổi `column` của flag đã release.

Flag liên quan trực tiếp vùng này:

| Flag | `enabled` mặc định | Cột | Ghi chú |
|---|---|---|---|
| `reports` | `true` | `feature_flags` | gắn vào mọi route `reports/*` qua `meta.featureFlag` |
| `report_rollup` | `false` | `feature_flags` | **không được đọc ở bất kỳ file `.rb`/`.js` nào** (grep chỉ ra `config/features.yml` và `config/locales/vi.yml`) |
| `sla` | `false` | `feature_flags` | `FEATURE_FLAGS.SLA`, nằm trong `CLOUD_PAID_FEATURES` |
| `custom_roles` | `false` | `feature_flags` | cổng của `Api::V1::Accounts::CustomRolesController` |
| `audit_logs` | `false` | `feature_flags` | `CLOUD_PAID_FEATURES` |
| `crm_tickets` | `false` | `feature_flags_ext_1` | cổng `CrmTicketsFeatureConcern` cho `ticket_reports` |
| `api_and_webhooks` | `true` | `feature_flags_ext_1` | chi phối `json.access_token` trong `_user.json.jbuilder` |
| `saml` | `false` | `feature_flags` | `CLOUD_PAID_FEATURES` |

### Cưỡng chế backend

`Featurable#feature_enabled?(name)` (`app/models/concerns/featurable.rb:96-100`):

```ruby
def feature_enabled?(name)
  return true if !ChatwootApp.chatwoot_cloud? && UNRESTRICTED_FEATURES.include?(name.to_s)
  send("feature_#{name}?")
end
```

`UNRESTRICTED_FEATURES` (`:14`) = mọi flag **không** `chatwoot_internal` và **không** `deprecated`.
→ Trên bản self-hosted/Enterprise (không phải Chatwoot Cloud), phần lớn flag **luôn bật** bất kể
bitset. Chỉ flag `chatwoot_internal`/`deprecated` mới thật sự phụ thuộc bitset.

`all_features` / `enabled_features` / `disabled_features` (`:102-114`) — `enabled_features` là thứ
được serialize ra `json.features`.

`before_create :enable_default_features` (`:54`, `:118-124`) đọc hàng
`ACCOUNT_LEVEL_FEATURE_DEFAULTS` để bật flag mặc định cho account mới.

### Cưỡng chế frontend

`app/javascript/dashboard/featureFlags.js` — `FEATURE_FLAGS` (59 key) map tên hằng → chuỗi trong
`config/features.yml`. Các key liên quan: `REPORTS: 'reports'`, `SLA: 'sla'`,
`CUSTOM_ROLES: 'custom_roles'`, `AUDIT_LOGS: 'audit_logs'`, `CRM_TICKETS: 'crm_tickets'`,
`API_AND_WEBHOOKS: 'api_and_webhooks'`.
**Không có** key nào cho `report_rollup`.

`CLOUD_PAID_FEATURES` (`:63-73`) — 9 flag: `SLA`, `TEKOMI`, `TEKOMI_CUSTOM_TOOLS`, `CUSTOM_ROLES`,
`AUDIT_LOGS`, `HELP_CENTER`, `SAML`, `CONVERSATION_REQUIRED_ATTRIBUTES`, `ADVANCED_ASSIGNMENT`.
Comment ngay trên (`:61-62`): *"Self-hosted installations do not consult this list and expose every
public feature."*

`isFeatureEnabledonAccount` — getter Vuex ở `store/modules/accounts.js:51-54`:

```js
isFeatureEnabledonAccount: $state => (id, featureName) => {
  const { features = {} } = findRecordById($state, id);
  return features[featureName] || false;
},
```

Nguồn `features` chính là `json.features @account.enabled_features`. Dùng trực tiếp ở 20+ component
(`Sidebar.vue`, `provider.js` của filter, `CsatResponses.vue`, `ContactPanel.vue`, …), hoặc gián
tiếp qua `useAccount().isFeatureEnabledonAccount` / `usePolicy().isFeatureFlagEnabled`.

## i18n

### Backend (`config/locales/en.yml`, khối `super_admin:` từ dòng 656)

| Key | Dùng ở |
|---|---|
| `super_admin.navigation.*` (`console`, `admin_dashboard`, `dashboard`, `sidekiq`, `instance_health`, `push_diagnostics`, `agent_dashboard`, `logout`) | sidebar console |
| `super_admin.dashboard.*` (`title`, `accounts`, `users`, `inboxes`, `conversations`, `not_available`, `chart_aria_label`) | `dashboard#index` |
| `super_admin.flash.invalid_action` | `SuperAdmin::ApplicationController#invalid_action_perfomed` |
| `super_admin.flash.restart_required` | `app_configs_controller.rb:69`, `installation_configs_controller.rb:75` |
| `super_admin.settings.*` (`title`, `subtitle`, `edition`, `plan_details_html`, `features`) | `settings#show` |
| `super_admin.app_configs.title` / `.updated` / `.submit` / `.'true'` / `.'false'` | `app_configs#show`/`#create` |
| `super_admin.app_configs.fields.<KEY>.title` | nhãn field, fallback `display_title` trong `installation_config.yml` rồi tới chính key |
| `super_admin.features.<config>.name` | tiêu đề trang app_config |
| `super_admin.filters.*` (`filter_by`, `all_records`, `clear`) | `COLLECTION_FILTERS` |
| `super_admin.accounts.deletion_in_progress` | `accounts#destroy` |
| `super_admin.accounts.seed.description` / `.warning` / `.button` / `.triggered` | partial `_seed_data` + `accounts#seed` |
| `super_admin.accounts.reset_cache.description_html` / `.cleared` | partial `_reset_cache` + `accounts#reset_cache` |
| `super_admin.users.resend_confirmation.already_confirmed` / `.sent` | `users#resend_confirmation` |
| `super_admin.account_features.<flag_name>` | `AccountFeaturesHelper.feature_display_names`, fallback `display_name` trong `features.yml` |
| `errors.reports.date_range_too_long` | `SummaryReportsController#channel` |

`config/locales/vi.yml` có khối `super_admin.account_features.*` dịch đầy đủ tên flag
(`report_rollup: 'Tổng hợp báo cáo'`, `reports: 'Báo cáo'`, …) — **`en.yml` không có khối
`account_features`**, nên bản tiếng Anh chạy bằng `default:` = `display_name`.

### Frontend

`app/javascript/dashboard/i18n/locale/en/report.json` — 12 nhóm gốc:
`REPORT`, `AGENT_REPORTS`, `LABEL_REPORTS`, `INBOX_REPORTS`, `TEAM_REPORTS`, `CSAT_REPORTS`,
`BOT_REPORTS`, `OVERVIEW_REPORTS`, `DAYS_OF_WEEK`, `SLA_REPORTS`, `PHONE_CALL_REPORTS`,
`SUMMARY_REPORTS`.

- `REPORT.*`: `HEADER`, `LOADING_CHART`, `NO_ENOUGH_DATA`, `DOWNLOAD_CONVERSATION_REPORTS`,
  `DATA_FETCHING_FAILED`, `SUMMARY_FETCHING_FAILED`, `METRICS`, `DATE_RANGE_OPTIONS`,
  `CUSTOM_DATE_RANGE`, `GROUP_BY_FILTER_DROPDOWN_LABEL`, `DURATION_FILTER_LABEL`,
  `GROUPING_OPTIONS`, `GROUP_BY_DAY_OPTIONS`, `GROUP_BY_WEEK_OPTIONS`, `GROUP_BY_MONTH_OPTIONS`,
  `GROUP_BY_YEAR_OPTIONS`, `BUSINESS_HOURS`, `FILTER_ACTIONS`, `DRILLDOWN`, `PAGINATION`.
- `OVERVIEW_REPORTS.*`: `HEADER`, `LIVE`, `HEATMAP_ARIA_LABEL`, `ACCOUNT_CONVERSATIONS`,
  `CONVERSATION_HEATMAP`, `RESOLUTION_HEATMAP`, `AGENT_CONVERSATIONS`, `TEAM_CONVERSATIONS`,
  `AGENT_STATUS`.
- `SUMMARY_REPORTS.*`: `INBOX`, `AGENT`, `TEAM`, `LABEL`, `AVG_RESOLUTION_TIME`,
  `AVG_FIRST_RESPONSE_TIME`, `AVG_REPLY_TIME`, `RESOLUTION_COUNT`, `CONVERSATIONS`.

`en/home.json` — khối Overview dashboard (viết lại ở `b9fdd11585`, có bản `vi/home.json` tương ứng):
`HOME.TITLE`, `HOME.GREETING`, `HOME.RETRY`, `HOME.ATTENTION.*`, và `HOME.DASHBOARD.*` gồm:
- trạng thái: `LIVE`, `TAGLINE`, `UPDATING`, `UPDATED_NOW`, `UPDATED_AGO`, `ERROR`, `EMPTY`
- `PERIOD.DAY|WEEK|MONTH|QUARTER`
- `FILTER.ALL_CHANNELS`, `FILTER.CHANNEL`
- `UNITS.SECONDS|MINUTES|HOURS|DAYS`
- `TABS.OVERVIEW`, `TABS.OVERVIEW_VALUE`, `TABS.CONVERSATIONS`, `TABS.RESOLVED`, `TABS.RESPONSE`,
  `TABS.CSAT`, `TABS.SLA`, `TABS.CHANNELS`
- `DELTA.FLAT|UP|DOWN|FASTER|SLOWER`
- `HINT.HEALTHY|NEEDS_ATTENTION|COMPLETION|FIVE_STAR|SLA_MISSED|SLA_CLEAN|SHARE`
- `COMMON.THIS_PERIOD|PREVIOUS_PERIOD|VS_PREVIOUS|PREVIOUS_VALUE|PERCENT|PERCENT_PAREN`
- nhóm theo card: `QUEUE.*`, `SLA.*`, `RESOLUTION.*`, `TRAFFIC.*`, `CHANNELS_CARD.*`, `ACTIVITY.*`,
  `CONVERSATIONS.*`, `RESOLVED.*`, `RESPONSE.*`, `CHANNELS.*` (key kênh do `channelLabelKey` sinh)

`en/settings.json` khối `SIDEBAR` — key đang dùng: `REPORTS`, `REPORTS_OVERVIEW`,
`REPORTS_CONVERSATION`, `REPORTS_PHONE_CALLS`, `REPORTS_AGENT`, `REPORTS_LABEL`, `REPORTS_INBOX`,
`REPORTS_TEAM`, `CSAT`, `REPORTS_SLA`, `REPORTS_BOT`.
Key **mồ côi** còn trong file: `SIDEBAR.REPORTS_TICKETS` (`en/settings.json:382`,
`vi/settings.json:377`) và `SIDEBAR.TICKET_SLA` (`en:392`, `vi:387`).

`en/tickets.json` còn nguyên khối `TICKET_REPORTS` (`:198`) và `TICKET_SLA` (`:149`) phục vụ
`TicketReports.vue` đã mồ côi.

`en/customRole.json` — UI quản lý Custom Role.

Theo `CLAUDE.md`: chỉ sửa `en.yml` (backend) và `en.json` (frontend); các locale khác qua Crowdin —
nhưng nhánh này đã có `vi/*.json` và `config/locales/vi.yml` được bảo trì tay.

## ⚠️ Phụ thuộc chéo

1. **`config/features.yml` ↔ cột bitset `accounts.feature_flags*`** — đổi thứ tự / xoá entry làm
   lệch toàn bộ flag của mọi account đang chạy. `Featurable.feature_flag_mappings_for` chỉ raise khi
   vượt 63 hoặc cột lạ, **không** phát hiện được việc đổi thứ tự.
2. **`config/features.yml` → `InstallationConfig['ACCOUNT_LEVEL_FEATURE_DEFAULTS']`** — qua
   `ConfigLoader#reconcile_feature_config`. Thêm flag mới mà không chạy lại `ConfigLoader` thì
   account tạo mới sẽ không bật flag mặc định.
3. **`config/features.yml` → `featureFlags.js`** — hai danh sách tách rời, không có kiểm tra tự động.
   Hiện `report_rollup`, `advanced_search_indexing`, `conversation_required_attributes`… có bên YAML
   mà việc có/không có bên JS phải tra tay.
4. **`app/helpers/super_admin/features.yml` ↔ `allowed_configs` trong `AppConfigsController`** —
   thêm nhóm cấu hình phải sửa **cả hai**: `features.yml` (để nhóm hiện ra ở Settings) và `mapping`
   (để key được phép lưu). Thiếu nửa sau thì form hiện ra nhưng submit âm thầm bỏ qua
   (`next unless @allowed_configs.include?(key)`, `:24`).
5. **`config/installation_config.yml` → form app_config** — `type`/`display_title` của field lấy từ
   đây. Key có trong `allowed_configs` nhưng không có trong YAML sẽ render input text trần, nhãn là
   chính tên key.
6. **`InstallationConfig` → Redis `$alfred`** — mọi lần save gọi
   `GlobalConfig.clear_cache` → `KEYS "V1:GLOBAL_CONFIG:*"`. Redis dùng chung với presence tracker,
   unread count, live report cache.
7. **`AccountUser#role` / `custom_role_id` → unread count cache** —
   `Conversations::UnreadCounts::FilteredCountInvalidator` + dispatch `ACCOUNT_CACHE_INVALIDATED`.
   Sửa phân quyền kéo theo invalidate cache hội thoại (xem `conversations.md`).
8. **`CustomRole::PERMISSIONS` (Ruby) ↔ `AVAILABLE_CUSTOM_ROLE_PERMISSIONS` (JS)** — hai danh sách
   6 phần tử phải khớp tay. Thêm permission mới cần sửa: model, policy enterprise tương ứng,
   `permissions.js`, và `meta.permissions` của route liên quan.
9. **`ReportPolicy` ↔ `meta.permissions` của `reports.routes.js`** — route cho
   `['administrator','report_manage']` còn từng endpoint có cổng riêng khác nhau
   (`drilldown` admin-only, `applied_slas` admin-only). Sửa policy phải soát lại cả hai phía.
10. **`V2::Reports::DashboardBuilder` ↔ `Enterprise::V2::Reports::DashboardBuilder`** — override
    enterprise gọi `self.class::RECENT_LIMIT` và các private method `conversation_event`,
    `list_inbox_ids`, `range`, `inbox_id`, `activity_events`. Đổi tên/bỏ bất kỳ method nào trong
    OSS builder sẽ làm vỡ bản Enterprise mà OSS test không thấy.
11. **`DashboardBuilder` → `ReportingEvent` + `CsatSurveyResponse` + `AppliedSla`** — một request
    `GET /dashboard` chạy rất nhiều truy vấn (2 lần `MetricBuilder#summary` × 7 metric, 5 chuỗi
    timeseries, 5 bucket first-response, 3-4 truy vấn CSAT, 3 truy vấn activity, + 4 truy vấn SLA).
    Không có cache ở tầng này.
12. **`Reports::DataSource.for` → `RawDataSource`** — toàn bộ báo cáo hiện đọc thẳng
    `reporting_events`. Bảng `reporting_events_rollups` và `ReportingEvents::RollupService` đã có
    nhưng **chưa được đọc**; bật đường rollup sẽ thay đổi số liệu của tất cả report cùng lúc.
13. **`ticket_reports` → `Tickets::ReportBuilder` → `Pipeline`/`PipelineStage`/`Ticket`/`TicketStageEvent`** —
    các model ticket nội bộ vẫn còn (`app/models/ticket*.rb`, `Pipeline#pipeline_type_ticket`),
    nên endpoint không chết; xem `crm-perfex.md` cho phần CRM thay thế.
14. **`PhoneCallReports.vue` / `PhoneCallEmotionReport`** — thuộc vùng cuộc gọi, chi tiết ở
    `phone-calls.md`; ở đây chỉ là một leaf trong group Reports.
15. **`_user.json.jbuilder` → `permissionsHelper` → router guard** — bất kỳ thay đổi hình dạng
    `accounts[].permissions` / `custom_role_id` đều làm sai `getUserRole`, `routeIsAccessibleFor`
    và toàn bộ lọc sidebar.

## Cạm bẫy đã biết

1. **`ticket_reports` còn sống ở backend, mồ côi ở frontend.**
   Commit `6360e33c4d` xoá import `TicketReports` và route `ticket_reports` khỏi
   `reports.routes.js`, xoá group `Tickets` khỏi `Sidebar.vue`, nhưng **giữ lại**:
   - `config/routes.rb:636` — `resources :ticket_reports, only: [:index]`
   - `app/controllers/api/v2/accounts/ticket_reports_controller.rb`
   - `app/views/api/v2/accounts/ticket_reports/index.json.jbuilder`
   - `app/builders/tickets/report_builder.rb`
   - `app/javascript/dashboard/api/ticketReports.js`
   - `app/javascript/dashboard/routes/dashboard/settings/reports/TicketReports.vue`
     (vẫn import `dashboard/stores/ticketPipelines`, store này cũng còn tồn tại)
   - i18n `TICKET_REPORTS` trong `en/tickets.json:198`, `SIDEBAR.REPORTS_TICKETS` trong
     `en/settings.json:382`
   Endpoint `GET /api/v2/accounts/:id/ticket_reports` vẫn trả dữ liệu. Nếu định bỏ hẳn thì phải xoá
   cả 7 chỗ trên; nếu định bật lại thì chỉ cần thêm route + leaf sidebar.

2. **`Ticket SLA` cũng mồ côi, nhưng mồ côi sâu hơn.**
   `app/javascript/dashboard/routes/dashboard/settings/ticketSla/ticketSla.routes.js` vẫn tồn tại và
   vẫn khai báo `name: 'ticket_sla_index'`, nhưng commit `6360e33c4d` đã xoá dòng
   `import ticketSla from './ticketSla/ticketSla.routes'` và `...ticketSla.routes` khỏi
   `settings.routes.js` → **route không bao giờ được đăng ký**. Tương tự
   `routes/dashboard/tickets/routes.js` (`tickets_dashboard_index`, `tickets_pipeline_index`) bị gỡ
   khỏi `dashboard.routes.js`. Hệ quả: `accountScopedRoute('ticket_sla_index')` hay bất kỳ
   `router.resolve({name:'tickets_pipeline_index'})` sẽ **throw/trả về route không tồn tại**, không
   phải lỗi 404 thân thiện. i18n `SIDEBAR.TICKET_SLA` còn lại ở `en/settings.json:392`.

3. **`feature_enabled?` vô hiệu hoá gần như toàn bộ feature flag trên bản self-hosted.**
   `Featurable#feature_enabled?` (`:96-100`) trả `true` cho mọi flag trong `UNRESTRICTED_FEATURES`
   khi `!ChatwootApp.chatwoot_cloud?`. `crm_tickets` không có `chatwoot_internal`/`deprecated` nên
   nằm trong danh sách này → `CrmTicketsFeatureConcern#ensure_crm_tickets_enabled` **luôn pass**
   trên bản self-hosted, kể cả khi bit `crm_tickets` đang tắt trong Super Admin.
   Phía frontend cũng vậy: `usePolicy().shouldShow` trả `true` ngay khi `!isOnChatwootCloud` (`:58`).
   → Tắt flag trong Super Admin trên self-hosted **không** khoá được tính năng; chỉ các flag
   `chatwoot_internal` (ví dụ `conversation_unread_counts`, `search_with_gin`, `crm_v2`,
   `advanced_search_indexing`) là thật sự tắt được.

4. **`GET /api/v2/accounts/:id/dashboard` không có kiểm tra phân quyền nào.**
   `Api::V2::Accounts::DashboardController` (`app/controllers/api/v2/accounts/dashboard_controller.rb`)
   chỉ có `#show` và `permitted_params`, **không** `before_action :check_authorization`, không
   `authorize`. Đây là chủ ý (comment: *"readable by every member of the account"*), nhưng hệ quả:
   `summary`, `timeseries`, `channels`, `live`, `first_response_distribution`, `csat.average/total/distribution`
   và (Enterprise) `sla` **đều là số liệu toàn account**, không lọc theo inbox mà agent được gán.
   Chỉ các *danh sách* (`csat.recent`, `activity`) mới lọc qua `list_inbox_ids`. Một agent chỉ được
   gán 1 inbox vẫn thấy tổng số hội thoại / CSAT / SLA của cả account.

5. **Custom role `report_manage` xem được Reports nhưng vỡ ở 2 endpoint.**
   - `ReportsController#drilldown` (`:55`): `return head :unauthorized unless Current.account_user.administrator?`
     → mọi lần bấm vào điểm trên chart để đào sâu đều `401` với user custom role.
   - `Api::V1::Accounts::AppliedSlasController` (`enterprise/…/applied_slas_controller.rb:10`):
     `before_action :check_admin_authorization?` → trang `sla_reports` (route cho phép
     `report_manage`) load UI thành công nhưng mọi request dữ liệu đều `401`.
   Trong khi đó `CsatSurveyResponsePolicy` **đã** được enterprise mở cho `report_manage`
   (`enterprise/app/policies/enterprise/csat_survey_response_policy.rb`) → cách xử lý không nhất
   quán giữa các trang trong cùng một group sidebar.

6. **Custom role chỉ có `report_manage` không vào được Overview dashboard.**
   `home/routes.js` đặt `meta.permissions = [...ROLES, ...CONVERSATION_PERMISSIONS]`, tức
   `agent`, `administrator`, `conversation_manage`, `conversation_unassigned_manage`,
   `conversation_participating_manage`. Mảng `permissions` của custom role **thay thế** chứ không
   bổ sung `'agent'` (`Enterprise::AccountUser#permissions`), nên user chỉ có `report_manage`
   bị `validateLoggedInRoutes` đẩy sang `defaultRedirectPage` → `reports/overview`.
   → Mô tả "overview dashboard API for all members" đúng ở tầng API nhưng **không đúng** ở tầng
   route: trang `/home` không mở cho mọi thành viên.

7. **Tab SLA luôn hiện trên Overview dashboard, kể cả bản Community.**
   `home/Index.vue:16-29` khai báo cố định 7 tab, trong đó có `sla`; `KpiTabs.vue:127-133` hiển thị
   `data?.sla?.hit_rate ?? '—'`. Nhánh `sla` chỉ được thêm bởi
   `Enterprise::V2::Reports::DashboardBuilder`. Trên bản không-enterprise, tile SLA hiện giá trị
   `—` và tab `SlaTab.vue` hiển thị `HOME.DASHBOARD.SLA.UNAVAILABLE`. Tệ hơn: **bản Enterprise vẫn
   tính SLA dù feature flag `sla` đang tắt** — override không kiểm `feature_enabled?('sla')`.

8. **`InstallationConfig` dùng `serialize ... coder: YAML` trên cột `jsonb`.**
   `app/models/installation_config.rb:25-29` có comment `FIX ME ... we need to migrate`.
   Hệ quả thực tế: `SuperAdmin::AppConfigsController#show` (`:11-14`) phải `pluck(:name, :serialized_value)`
   rồi tự bóc `serialized_value['value']` thay vì query JSONB. Mọi truy vấn kiểu
   `where("serialized_value->>'value' = ?")` sẽ **không** hoạt động như mong đợi.

9. **`GlobalConfig` cache cả giá trị `nil`.**
   `load_from_cache` (`lib/global_config.rb:44-48`): khi cache miss, nó ghi `{value: nil}.to_json`
   vào Redis với TTL 1 ngày nếu DB không có hàng. Vì `cached_value` lúc đó **không blank**
   (`'{"value":null}'`), lần đọc sau sẽ hit cache và trả `nil` suốt 1 ngày.
   `GlobalConfigService.load` xử lý bằng cách gọi `GlobalConfig.clear_cache` ngay sau khi tạo hàng
   (`lib/global_config_service.rb:14`, kèm comment *"To clear a nil value that might have been
   cached in the previous call"*). Code nào gọi **`GlobalConfig.get` trực tiếp** (không qua
   `GlobalConfigService`) sẽ không có cơ chế vá này.

10. **`locked: true` không bảo vệ giá trị khỏi form app_config.**
    `SuperAdmin::InstallationConfigsController#scoped_resource` chỉ liệt kê `resource_class.editable`
    (`locked: false`), nên tưởng là hàng `locked` bất khả xâm phạm. Nhưng
    `AppConfigsController#create` (`:26-28`) làm `InstallationConfig.where(name: key).first_or_create(...)`
    rồi `i.value = value; i.save` — **không kiểm `locked`**. Mọi key nằm trong `allowed_configs`
    đều ghi được, kể cả khi `config/installation_config.yml` đặt `locked: true` (ví dụ nhóm
    `custom_branding` của Enterprise ghi lên `INSTALLATION_NAME`, `LOGO`, `DISPLAY_MANIFEST`).
    `InstallationConfigsController#resource_params` thì luôn `.merge(locked: false)` (`:65`).

11. **Nút Seed bị ẩn nhưng route vẫn mở, và lỗi chỉ hiện trong Sidekiq.**
    `_seed_data.html.erb:1` ẩn form khi `ENABLE_ACCOUNT_SEEDING` falsy trong production, nhưng
    `POST /super_admin/accounts/:id/seed` (`config/routes.rb:819`) vẫn tồn tại.
    `accounts#seed` luôn `redirect_back` với notice `'Account seeding triggered'`, còn
    `Seeders::AccountSeeder#initialize` mới `raise 'Account Seeding is not allowed.'` — raise xảy ra
    **trong job ở queue `:low`**, nên super admin thấy thông báo thành công trong khi không có gì
    chạy.

12. **`AccountSeeder` xoá sạch dữ liệu account.**
    `set_up_account` (`lib/seeders/account_seeder.rb:30-37`) `destroy_all` trên `teams`,
    `conversations`, `labels`, `inboxes`, `contacts`, `custom_roles`. Warning có trong UI
    (`super_admin.accounts.seed.warning`) nhưng **không có bước xác nhận** nào — một click là mất.
    Thêm nữa, user seed đặt password cố định `Password1!.` và `skip_confirmation!` (`:74-76`).

13. **`SummaryReportsController` chỉ chặn phạm vi ngày cho đúng 1 trong 5 action.**
    `date_range_too_long?` (6 tháng) chỉ được gọi trong `#channel` (`:22`).
    `#agent`, `#team`, `#inbox`, `#label` nhận khoảng ngày tuỳ ý. `ReportsController` và
    `DashboardController` cũng không giới hạn (chỉ `DashboardController` bắt buộc có
    `since`/`until`, trả `422` nếu thiếu). Phía UI, `constants.js` khống chế bằng
    `DATE_RANGE_OPTIONS` nhưng gọi API trực tiếp thì không có chặn.

14. **Trùng lặp route báo cáo cũ/mới cùng tồn tại.**
    `reports.routes.js` đăng ký cả `oldReportRoutes` (`agent`, `inboxes`, `label`, `teams`) và
    `revisedReportRoutes` (`agents_overview`, `inboxes_overview`, …). Sidebar chỉ trỏ vào bản
    revised (`newReportRoutes()`), nhưng URL cũ vẫn mở được và render component cũ
    (`AgentReports.vue` …). `reportRoutes = computed(() => newReportRoutes())` ở
    `Sidebar.vue:372` là computed bọc một hàm thuần — tàn dư của giai đoạn có A/B theo flag.

15. **`super_admin:dashboard_stats` cache 30 phút cho toàn instance, dùng số ước lượng.**
    `SuperAdmin::DashboardController#dashboard_stats` cache `Rails.cache` key global, và
    `conversationsCount` đến từ `pg_class.reltuples` (`:27-33`) — là **số ước lượng**, lệch với
    `Conversation.count` thật, chỉ chính xác sau `VACUUM/ANALYZE`. Đừng dùng con số này để đối soát.

16. **`report_rollup` là flag chết.**
    `grep -rn "report_rollup" app enterprise lib config --include=*.rb --include=*.yml` chỉ ra
    `config/features.yml:84` và `config/locales/vi.yml:900`. Không có code nào đọc nó.
    Đường rollup thực tế bị chặn ở `Reports::DataSource.for` (`app/services/reports/data_source.rb:8-13`)
    bằng một `TODO`, luôn trả `RawDataSource`.

17. **`LiveReports` cache 1 phút nhưng chỉ nửa endpoint.**
    `#conversation_metrics` cache Redis 1 phút theo `(account, team)`; `#grouped_conversation_metrics`
    chạy 3 truy vấn `GROUP BY` mỗi lần gọi, không cache. Hai endpoint này nằm trên cùng trang
    `LiveReports.vue` và thường poll định kỳ.

18. **`en.yml` thiếu khối `super_admin.account_features`.**
    `AccountFeaturesHelper.feature_display_names` dùng
    `I18n.t("super_admin.account_features.#{name}", default: feature['display_name'])`.
    `config/locales/vi.yml` có khối này, `config/locales/en.yml` **không** → bản tiếng Anh của
    console luôn chạy nhánh `default:`, tức hiển thị `display_name` thô từ `features.yml`
    (ví dụ `"GMO AI V1 Action Classifier"`). Thêm key vào `en.yml` sẽ thay đổi nhãn đang hiển thị.
