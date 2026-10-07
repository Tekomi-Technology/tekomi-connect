# Cấu hình GMO AI theo từng account

Ngày: 2026-10-07. Trạng thái: đã triển khai, chờ review.

## Mục tiêu

Bỏ toàn bộ cấu hình AI khỏi Super Admin. Mỗi account tự quyết định provider, model, prompt và API key của mình trong `Settings → GMO AI`, do administrator của account thao tác.

Trước thay đổi này cấu hình bị chia hai nơi: Super Admin giữ danh sách provider và mapping 33 feature → model (`llm_providers`, `llm_feature_models`, `llm_prompt_templates`), account chỉ giữ API key và prompt override. Sau thay đổi, nguồn sự thật nằm hoàn toàn ở account, còn code giữ phần mặc định.

## Nguyên tắc

Admin của account không biết `false_promise_detection` hay `instruction_migration` là gì, nên không bắt họ cấu hình 33 feature. Họ chọn **một provider + một model mặc định**; muốn tinh chỉnh thì override từng feature trong mục nâng cao.

Ba feature không mở cho account vì model phải khớp hạ tầng, không phải khớp sở thích:

- `embedding` — đổi model là đổi số chiều vector, vector đã index sẽ không dùng được nữa.
- `audio_transcription` — cần API transcription kiểu OpenAI.
- `call_emotion_analysis` — `Phone::JevEmotionAnalysisService` buộc OpenRouter và tự ghim model `typesafe/jev-1.13`.

Ba feature này lấy `provider_type` + `model` cố định từ `config/llm.yml`, không hiện trên UI. Vẫn đọc bảng override trước nên dev sửa được bằng console khi cần.

## Dữ liệu

| Thứ cần lưu | Nơi lưu |
|---|---|
| API key + endpoint của account | `account_llm_providers` (thêm cột `api_base`, `api_key` cho phép NULL để dùng Ollama) |
| Provider + model mặc định | `accounts.settings` qua `store_accessor` → `llm_default_provider_type`, `llm_default_model` |
| Override theo feature | bảng mới `account_llm_feature_models` (`feature_key`, `provider_type`, `model`, `reasoning`, `params`), unique theo `(account_id, feature_key)` |
| Prompt riêng | `account_llm_prompt_templates` (không đổi) |
| Khoá FireCrawl | `account_llm_providers` với `provider_type: 'firecrawl'` |

Danh sách provider chuyển từ hằng số Ruby sang mục `providers:` trong `config/llm.yml`, kèm `label`, `requires_api_base` (Ollama) và `supports_reasoning` (OpenRouter). `config/llm.yml` cũng mang thêm `suggested_model` cho từng feature — lấy từ bảng mapping của migration `20260911000002`, dùng làm placeholder gợi ý trên UI.

Bảng `llm_providers`, `llm_feature_models`, `llm_prompt_templates` bị drop.

`config/llm.yml` có thêm mục `services:` cho vendor không phải LLM — hiện chỉ FireCrawl. `Llm::Services` phục vụ danh sách này; `account_llm_providers` nhận cả hai loại (`Llm::Providers.types + Llm::Services.types`), nhưng chỉ `Llm::Providers.types` xuất hiện trong dropdown chọn model, nên FireCrawl không bao giờ bị chọn làm model.

### Endpoint tuỳ chỉnh

Trước thay đổi này `api_base` chỉ nằm ở bảng global: `Llm::Config.apply!` nạp nó vào cấu hình RubyLLM toàn cục, còn `context_for` chỉ xoá `api_key` chứ không xoá `api_base`, nên endpoint global vẫn chảy vào context của account. Bỏ bảng global mà không mang `api_base` theo thì mọi cài đặt dùng endpoint OpenAI-compatible sẽ lặng lẽ quay về `api.openai.com`. Vì vậy:

- Migration copy `llm_providers.api_base` xuống `account_llm_providers.api_base` theo `provider_type`.
- UI hiện ô endpoint cho mọi provider mà RubyLLM có setter `<provider>_api_base=` (payload trả `supports_api_base`), bắt buộc với Ollama, tuỳ chọn với phần còn lại — đúng như form Super Admin cũ.
- `AccountLlmProvider` giữ lại validate `api_base_supported` của `LlmProvider` cũ để Mistral và xAI không nhận endpoint mà RubyLLM không dùng được.

## Thứ tự resolve

`Llm::FeatureRouter.resolve(feature:, account:)`:

1. Feature không có trong `llm.yml` → `UnknownFeatureError`.
2. Có row trong `account_llm_feature_models` → dùng row đó (`request_params` gộp `reasoning` + `params`).
3. Feature cố định trong `llm.yml` → dùng `provider_type` + `model` của file.
4. Còn lại → provider + model mặc định của account.
5. Chưa chọn mặc định → `FeatureNotConfigured`.
6. Account không có API key của provider đã chọn → `TenantProviderNotConfigured`.

Mọi nhánh lỗi vẫn ghi `Llm::AlertRecorder`, nên admin thấy ngay ở tab AI alerts.

## FireCrawl

Khoá FireCrawl là cấu hình AI cuối cùng còn nằm ở Super Admin (`TEKOMI_FIRECRAWL_API_KEY`, tab GMO AI), nay chuyển về account. Toàn bộ điểm gọi đều có account nên không phải nới API nào ra ngoài:

- `Firecrawl::Configuration` đổi sang `configured?(account:)`, `client(account:)`, `api_key(account:)`.
- `Tekomi::Tools::FirecrawlService` nhận account ở `initialize` và `self.configured?`.
- `Tekomi::Documents::SinglePageFetcher` nhận thêm `account:`, do `SyncService` truyền `@document.account`.
- `Tekomi::Documents::CrawlJob` và `Enterprise::Webhooks::FirecrawlController` dùng `document.account` / `assistant.account`.
- `Tekomi::FirecrawlHelper#generate_firecrawl_token` nhận `account` thay cho `account_id`. Công thức token không đổi (4 ký tự cuối của key + assistant id + account id) nên crawl đang chạy vẫn xác thực được sau khi migrate.

Super Admin mất hẳn nhóm config `tekomi`: bỏ nhánh `when 'tekomi'` trong `Enterprise::SuperAdmin::AppConfigsController`, bỏ `TEKOMI_FIRECRAWL_API_KEY` khỏi `config/installation_config.yml`, và bỏ `config_key: 'tekomi'` khỏi `app/helpers/super_admin/features.yml` — dòng GMO AI vẫn nằm trong danh sách feature nhưng không còn link cấu hình, và cũng không còn mục nào trong menu Settings của Super Admin.

Migration `20261007000002_move_firecrawl_key_to_accounts` copy giá trị InstallationConfig hiện tại xuống mọi account đã có key AI, rồi xoá InstallationConfig đó. Đây là một secret dùng chung được nhân bản — chấp nhận để không làm gián đoạn account đang chạy; sau này mỗi account có thể thay bằng khoá riêng.

Những `TEKOMI_*` còn lại ở Super Admin **không phải cấu hình AI** nên giữ nguyên: `TEKOMI_CLOUD_PLAN_LIMITS`, `TEKOMI_TOPUP_OPTIONS` (billing) và `TEKOMI_DOCUMENT_AUTO_SYNC_*` (giới hạn scheduler toàn hệ thống).

## Những chỗ khác bị ảnh hưởng

- `Llm::Config.apply!` không còn nạp key global từ DB; chỉ set `model_registry_file` và `logger`. Không còn khoá AI nào ở mức cài đặt.
- `Internal::AccountAnalysis::ContentEvaluatorService` (moderation của Super Admin) trước đây chạy nhờ key global trong DB, nay không còn khoá. Chấp nhận được vì `Internal::AccountAnalysisJob` đã `return unless ChatwootApp.chatwoot_cloud?` và không có chỗ nào trong repo enqueue job này, nên đường chạy đó chết sẵn trên bản self-hosted. Nếu sau này Cloud cần, đưa nó qua `FeatureRouter` với một feature key riêng thay vì dựng lại khoá global.
- Bỏ `LLM_PROVIDERS_CONFIG_VERSION` trên Redis và `bump_version!`: không còn config global nào cần invalidate.
- `Llm::Prompts.body` rút chuỗi fallback còn `account → file .liquid`.
- i18n `super_admin.llm_prompt_templates.prompts.*` và `super_admin.llm_feature_models.features.*` chuyển sang `llm.prompts.*` và `llm.features.*` (en.yml và vi.yml), vì controller của account đang đọc các key này. Thêm 5 feature `deal_*` còn thiếu tên.
- Hai migration cũ (`20260929000002`, `20261005000002`) tham chiếu trực tiếp `LlmProvider` / `LlmFeatureModel` nên được viết lại bằng SQL thuần để `db:migrate` trên máy mới không nổ `NameError` sau khi model bị xoá.

## Migrate dữ liệu đang chạy

`20261007000001_move_llm_config_to_accounts` chạy ba bước trong một migration: tạo cột và bảng mới, chuyển dữ liệu, rồi drop ba bảng global.

Với mỗi account **đang có ít nhất một API key**:

- Model mặc định lấy từ cặp `(provider_type, model)` của feature `assistant` trong cấu hình global, nếu provider đó account có key; không có thì lấy cặp xuất hiện nhiều nhất trong số provider mà account có key.
- Mỗi feature global được copy thành override, trừ khi nó trùng với model mặc định vừa chọn hoặc trùng với route cố định trong `llm.yml`.
- Prompt global được copy thành prompt của account nếu account chưa có override cho key đó.

Nhờ vậy account đang chạy giữ nguyên cả model lẫn chi phí như trước khi đổi. Account chưa từng nhập key thì không có gì để giữ, admin phải tự cấu hình.

Migration không hoàn tác được (`IrreversibleMigration`) vì key và model là dữ liệu riêng của từng cài đặt.

## Đánh đổi đã biết

- Account đặt model mặc định là một model đắt thì **toàn bộ** feature chat dùng model đó. Trước đây Super Admin đặt gpt-4.1-mini cho các việc rẻ và gpt-5.2 cho assistant. UI bù lại bằng placeholder gợi ý model cho từng feature, nhưng không tự áp dụng.
- `model` không được kiểm tra có tồn tại hay có hỗ trợ tool-calling / structured output (`assume_model_exists: true`). Chọn model yếu thì `assistant` và các service dùng JSON schema sẽ lỗi runtime và hiện ở tab AI alerts dạng `provider` hoặc `unknown`. Ô model mặc định vì vậy là dropdown đọc từ `config/llm_models.json`, chỉ mục nâng cao mới cho nhập tay.
- Các spec FireCrawl chuyển từ `create(:installation_config, ...)` sang stub `Firecrawl::Configuration.api_key`, vì `account_llm_providers` dùng `encrypts` và môi trường test không chắc có khoá `ACTIVE_RECORD_ENCRYPTION_*`.
- `Tekomi::Rag::Client` vẫn ghim `openrouter`, nên account dùng RAG buộc phải có key OpenRouter kể cả khi provider mặc định là provider khác.
