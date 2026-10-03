# Bản đồ: Cuộc gọi & Phân tích cảm xúc

> Lập tại commit `c37c7293a9` — ngày 2026-10-03
> Bản đồ có thể lạc hậu khi code đổi. Luôn kiểm chứng lại điểm then chốt trước khi kết luận.

## Tóm tắt

Mảng này gồm bốn khối ghép lại:

1. **Tổng đài PBX + softphone WebRTC** — kênh `Channel::Phone` (`channel_phone`) giữ `wss_url`, `sip_domain`, cấu hình ICE/TURN. Mỗi agent được gán một `PhoneExtension` (SIP username/password). Dashboard dùng `jssip` (store Pinia `softphone.js`, component `SoftphoneWidget.vue`) để đăng ký SIP trực tiếp từ trình duyệt; credential lấy qua endpoint `GET inboxes/:id/phone_credentials`.
2. **Thu nhận sự kiện cuộc gọi** — PBX gửi webhook có HMAC tới `POST /webhooks/pbx/calls`; callbot Callytics/Voxa gửi tới `POST /webhooks/callytics/:token`. Cả hai đều quy về một điểm xử lý duy nhất: `Phone::PbxCallEventProcessor`. Processor này tạo/cập nhật `PhoneCall`, resolve contact + conversation, và tạo một `Message` với `content_type: :phone_call` để hiện bubble trong hội thoại.
3. **Ghi âm** — Rails không bao giờ để dashboard gọi trực tiếp PBX. `PhoneCallsController#recording` làm proxy: ký HMAC khi lấy từ PBX, hoặc dùng API key server-side khi lấy từ Callytics (và transcode Ogg → MP3 bằng `ffmpeg`, cache lại qua ActiveStorage `cached_recording`).
4. **Phân tích cảm xúc** — khi cuộc gọi vào trạng thái terminal và có ghi âm, `Phone::CallEmotionAnalysisJob` (queue `low`) chạy pipeline: tải ghi âm → phiên âm → LLM phân loại cảm xúc theo schema 5 nhãn tiếng Việt → lưu `PhoneCallEmotionReport` → ghi lại vào `phone_calls.metadata` → cập nhật `Message` và push realtime. Kết quả hiện ở bubble tin nhắn và ở trang Báo cáo cuộc gọi.

Lưu ý quan trọng ngay từ đầu: **đường phiên âm đang chạy thật là OpenRouter**, không phải service Python `call_emotion/`. Xem phần ⚠️ Phụ thuộc chéo.

## Database

| Bảng | Vai trò | Cột đáng chú ý |
|---|---|---|
| `phone_calls` | Bản ghi gốc của một cuộc gọi (một leg logic, khoá theo `pbx_id` + `linked_id`) | `account_id`, `inbox_id`, `contact_id`, `conversation_id`, `message_id`, `user_id`, `phone_extension_id`, `pbx_id`, `linked_id`, `last_event_id`, `direction`, `customer_number`, `extension`, `from_number`, `to_number`, `status` (default `ringing`), `started_at`, `answered_at`, `ended_at`, `duration_seconds`, `hangup_cause`, `recording_url` (text — là URL proxy nội bộ, không phải URL PBX), `metadata` (jsonb, default `{}`) |
| `phone_call_emotion_reports` | Báo cáo cảm xúc 1-1 với `phone_calls` | xem bảng cột đầy đủ bên dưới |
| `pbx_call_events` | Log thô mọi event webhook, dùng để chống xử lý trùng | `phone_call_id`, `pbx_id`, `event_id`, `linked_id`, `event_type`, `payload` (jsonb), `processed_at` |
| `phone_extensions` | Map agent ↔ số nội bộ SIP | `account_id`, `inbox_id`, `user_id`, `sip_username`, `sip_password` (text), `enabled` |
| `channel_phone` | Kênh Phone (một inbox) | `account_id`, `wss_url`, `sip_domain`, `sip_username`, `sip_password`, `stun_url`, `ice_servers` (jsonb default `[]`), `turn_shared_secret`, `turn_credential_ttl` (default 3600) |
| `callbot_webhooks` | Token endpoint cho callbot Callytics, scope theo inbox | `account_id`, `inbox_id`, `name`, `token` (unique), `enabled` — **bảng này có migration `20260911000003` nhưng KHÔNG xuất hiện trong `db/schema.rb`; xem Cạm bẫy** |

### Cột đầy đủ của `phone_call_emotion_reports`

(từ `db/schema.rb` và `db/migrate/20260930000003_create_phone_call_emotion_reports.rb`)

| Cột | Kiểu | Ràng buộc / default |
|---|---|---|
| `id` | bigint | PK |
| `phone_call_id` | bigint | `null: false`, FK, **index UNIQUE** → 1 báo cáo / 1 cuộc gọi |
| `account_id` | bigint | `null: false`, FK |
| `conversation_id` | bigint | `null: false`, FK |
| `inbox_id` | bigint | `null: false`, FK |
| `status` | string | `null: false`, default `'pending'` |
| `purpose` | string | `null: false`, default `'monitoring'` |
| `action_status` | string | `null: false`, default `'none'` |
| `emotion` | string | nullable — nhãn tiếng Việt đã chuẩn hoá |
| `emotion_color` | string | nullable — tự sinh bởi callback `set_emotion_color` |
| `reason` | text | nullable — lý do ngắn do LLM sinh |
| `transcript` | text | nullable — toàn văn phiên âm |
| `asr_model` | string | ví dụ `microsoft/mai-transcribe-2` |
| `asr_provider` | string | provider của route LLM đang dùng |
| `asr_runtime` | string | ví dụ `ruby_llm_transcription` (hoặc `sherpa-onnx-offline` nếu dùng service Python) |
| `llm_model` | string | model đã phân loại cảm xúc |
| `llm_provider` | string | |
| `error_message` | text | truncate 1 000 ký tự khi job fail |
| `processed_at` | datetime | |
| `created_at` / `updated_at` | datetime | `null: false` |

Index: `[account_id, status]`, `[account_id, emotion]`, `conversation_id`, `phone_call_id` (unique).

### Enum (hằng Ruby, không phải enum Postgres)

`PhoneCall` (`app/models/phone_call.rb`):
- `DIRECTIONS = %w[inbound outbound]` — có validate `inclusion`.
- `TERMINAL_STATUSES = %w[completed missed busy no_answer rejected cancelled failed]` — `terminal?` dựa vào đây.
- `status` **không** có validate inclusion; chỉ validate presence. Giá trị trung gian: `ringing`, `in_progress`.

`Phone::PbxCallEventProcessor::STATUS_RANK` — chỉ cho phép status tiến lên, không lùi:
`ringing` = 0, `in_progress` = 1, và mọi status terminal (`completed`, `missed`, `busy`, `no_answer`, `rejected`, `cancelled`, `failed`) = 2.

`PhoneCallEmotionReport` (`app/models/phone_call_emotion_report.rb`), cả ba đều có validate `inclusion`:
- `STATUSES = %w[pending processing completed failed skipped]`
  (ghi chú: `skipped` được khai báo nhưng **không có code nào gán giá trị này** — chưa xác minh dụng ý)
- `ACTION_STATUSES = %w[none needs_follow_up in_progress resolved]`
- `PURPOSES = %w[monitoring follow_up quality_review]`

Nhãn cảm xúc và màu (`EMOTION_COLORS`):

| Nhãn | Màu |
|---|---|
| `buồn` | `purple` |
| `trung tính` | `green` |
| `vui` | `blue` |
| `khó chịu` | `orange` |
| `gay gắt` | `red` |

Nhãn không khớp → fallback `gray`. `EMOTION_ALIASES` map ~22 biến thể (không dấu, tiếng Anh: `sad`, `neutral`, `happy`, `frustrated`, `angry`...) về 5 nhãn canonical. `LEGACY_STORED_LABELS` xử lý dữ liệu cũ bị cắt từ (`'trung'`, `'khó'`, `'chịu'`, `'gay'`, `'gắt'`) — dùng khi filter để không bỏ sót bản ghi lịch sử.

## Backend

| File | Vai trò |
|---|---|
| `app/models/phone_call.rb` | Model cuộc gọi. `terminal?`, `message_data` (payload cho `content_attributes` của Message, gộp cả `emotion_analysis`, `emotion_report`, `emotion_tag`, và `callbot_summary`/`callbot_outcome`/`callbot_analysis_status`). `has_one_attached :cached_recording`. |
| `app/models/phone_call_emotion_report.rb` | Model báo cáo cảm xúc. Chuẩn hoá nhãn (`normalize_emotion_label`), sinh màu, `emotion_filter_values` (dùng khi filter kể cả alias + nhãn legacy), `report_data` (payload API). |
| `app/models/pbx_call_event.rb` | Log event thô. |
| `app/models/phone_extension.rb` | Số nội bộ của agent. |
| `app/models/channel/phone.rb` | Kênh Phone: validate `wss_url` phải `wss://`, validate URL ICE phải `stun:`/`stuns:`/`turn:`/`turns:`, bắt buộc `turn_shared_secret` nếu có TURN server. Mã hoá `sip_password` và `turn_shared_secret` nếu bật encryption. Có `prepend_mod_with`. |
| `app/models/callbot_webhook.rb` | Token webhook callbot. Sinh token `SecureRandom.urlsafe_base64(32)`, validate inbox phải là Phone inbox, `endpoint_path` = `/webhooks/callytics/<token>`. |
| `app/controllers/webhooks/pbx/calls_controller.rb` | Nhận webhook PBX. Xác thực HMAC-SHA256 header `X-PBX-Signature` trên payload `"<X-PBX-Timestamp>.<raw_body>"`, chống replay 5 phút, `secure_compare`. Thiếu secret → `503`. |
| `app/controllers/webhooks/callytics/calls_controller.rb` | Nhận webhook callbot. Xác thực header `X-Callytics-Signature` kiểu Stripe (`t=...,v1=...`), payload ký là `"<t>.<raw_body>"`, drift 5 phút. Resolve `CallbotWebhook` theo `:token` trong URL. |
| `app/services/callbot/call_completed_processor.rb` | Dịch payload callbot `eventType: call.completed` / `eventVersion: '2.0'` sang định dạng event PBX nội bộ rồi gọi `PbxCallEventProcessor`. Gán `pbx_id = "callytics:<webhook.id>"`. Chuẩn hoá số VN. Chỉ chấp nhận `recording.access.method == 'vendor_api'` và resource khớp regex `^/api/v1/vendor/call-reports/[^/]+/recording$`. |
| `app/services/phone/pbx_call_event_processor.rb` | **Điểm vào chung duy nhất.** Idempotent qua `insert_all` + unique index `(pbx_id, event_id)` và `processed_at`. Resolve inbox (theo `inbox_id` → `sip_domain` → extension → inbox Phone duy nhất), resolve direction/extension/số khách, chuẩn hoá số về E.164 kiểu VN (`0xxx` → `+84xxx`), tạo contact+conversation, map event → status, tạo/cập nhật Message, và cuối cùng `enqueue_emotion_analysis`. |
| `app/services/phone/pbx_recording_fetcher.rb` | Tải ghi âm để phân tích. Hai nhánh: PBX (bắt buộc HTTPS, ký HMAC header `X-Chatwoot-Timestamp`/`-Nonce`/`-Signature`) và Callytics (header `X-Callytics-API-Key`). Giới hạn `MAX_BYTES = 100MB`, open_timeout 10s, read_timeout 120s. Raise `RecordingUnavailable`. |
| `app/services/phone/ice_server_builder.rb` | Sinh credential TURN tạm thời (username `"<expires_at>:<user_id>"`, credential = Base64 của HMAC-SHA1 với `turn_shared_secret`). |
| `app/jobs/phone/call_emotion_analysis_job.rb` | Job nền (`queue_as :low`). Guard: chỉ chạy nếu `terminal?` **và** có `pbx_recording_url` hoặc `callytics_recording_resource`. Chống chạy trùng: `with_lock`, bỏ qua nếu `status == 'completed'` hoặc đang `processing` dưới 30 phút. Ghi kết quả, merge vào `metadata['emotion_analysis']`, refresh Message + `send_update_event`. Fail → `status: 'failed'` + `error_message`. |
| `enterprise/app/services/phone/call_emotion_analysis_service.rb` | Orchestrator: fetch recording → `OpenrouterTranscriptionService` → LLM phân loại qua `Llm::FeatureRouter.resolve(feature: 'call_emotion_analysis')` + `RubyLLM.chat().with_schema(CallEmotionAnalysisSchema)`. Prompt tiếng Việt: `"Transcript cuộc gọi:\n<transcript>"`. Nhãn ngoài danh sách → fallback `'trung tính'`. `ensure recording&.close!`. |
| `enterprise/app/services/phone/openrouter_transcription_service.rb` | **Đường phiên âm đang dùng.** `MODEL = 'microsoft/mai-transcribe-2'`, gọi `RubyLLM.transcribe` với `language: 'vi'`, `format: 'verbose_json'`, `timestamps: :word`. Provider lấy từ cùng route `call_emotion_analysis`. Trả `asr_runtime = 'ruby_llm_transcription'`. |
| `enterprise/app/services/phone/zipformer_transcription_service.rb` | Client Faraday multipart POST `/transcribe` tới service Python (`CALL_EMOTION_SERVICE_URL`, timeout 180s). **Hiện là code không được gọi ở đâu** — xem Cạm bẫy. |
| `enterprise/app/services/tekomi/llm/call_emotion_analysis_schema.rb` | Schema `RubyLLM::Schema`: `label` (enum 5 nhãn tiếng Việt), `reason` (string, `max_length: 300`, yêu cầu tiếng Việt và chỉ dựa trên bằng chứng trong transcript). |
| `lib/llm/feature_router.rb` | Resolve feature → `{provider, model, params}` từ bảng `llm_feature_models`. Chưa cấu hình → raise `CustomExceptions::Llm::FeatureNotConfigured`. |
| `lib/llm/features.rb` | Đọc `config/llm.yml`, validate feature key tồn tại. |
| `app/controllers/api/v1/accounts/phone_calls_controller.rb` | API cho dashboard: chi tiết callbot, danh sách báo cáo + counts, proxy/stream ghi âm, chạy phân tích thủ công, đọc/cập nhật báo cáo. |
| `app/controllers/api/v1/accounts/inboxes/phone_extensions_controller.rb` | CRUD extension (admin only). |
| `app/controllers/api/v1/accounts/inboxes/callbot_webhooks_controller.rb` | CRUD webhook callbot (admin only), trả `endpoint_url` ghép từ `FRONTEND_URL`. |

Migration liên quan:
- `db/migrate/20260827000001_init_schema.rb` — schema gốc đã có `phone_calls`, `pbx_call_events`.
- `db/migrate/20260911000003_create_callbot_webhooks.rb`
- `db/migrate/20260911000004_backfill_callytics_recordings.rb` — backfill `metadata['callytics_recording_resource']` từ `callbot_report.recording.access.resource` cho các cuộc gọi nhận trước khi có proxy, và cập nhật `messages.content_attributes.data.recording_url`. `down` cố ý không làm gì.
- `db/migrate/20260929000002_seed_call_emotion_analysis_feature.rb` — seed `llm_feature_models` cho `call_emotion_analysis`: lấy provider đầu tiên, model kế thừa từ `conversation_analysis` hoặc fallback `gpt-4.1-mini`, tự thêm prefix `openai/` nếu provider là `openrouter`.
- `db/migrate/20260930000003_create_phone_call_emotion_reports.rb`

Spec hiện có: `spec/models/phone_call_emotion_report_spec.rb`, `spec/requests/api/v1/accounts/phone_calls_spec.rb`, `spec/services/phone/pbx_call_event_processor_spec.rb`, `spec/services/callbot/call_completed_processor_spec.rb`, `spec/enterprise/services/tekomi/llm/call_emotion_analysis_schema_spec.rb`, `spec/smoke/multichannel_conversation_flow_spec.rb`.

## Dịch vụ ngoài

### Service Python `call_emotion/` (sherpa-onnx + Zipformer)

| Thuộc tính | Giá trị |
|---|---|
| File | `call_emotion/server.py`, `call_emotion/Dockerfile`, `call_emotion/requirements.txt` |
| Vai trò | Phiên âm tiếng Việt **offline, chạy nội bộ** (không gửi audio ra ngoài). Không làm phân tích cảm xúc dù tên thư mục là `call_emotion`. |
| Framework | FastAPI + uvicorn, chạy `uvicorn server:app --host 0.0.0.0 --port 8080` |
| Cổng | `8080` (EXPOSE trong Dockerfile). Trong docker-compose **không publish ra host** — chỉ dùng qua network nội bộ. |
| Endpoint | `GET /health` → `{ready, error, model}`; `POST /transcribe` (multipart `file`) → `{transcript, asr_model: "trung381/zip-30m", asr_runtime: "sherpa-onnx-offline"}` |
| Model | Zipformer transducer 30M, decode `greedy_search`, `modeling_unit: "bpe"`, `provider: "cpu"`, `num_threads = max(1, cpu_count - 1)`, `sample_rate: 16000`, `feature_dim: 80` |
| Tiền xử lý audio | `soundfile` đọc, stereo → mono (mean), resample về 16 kHz bằng `scipy.signal.resample_poly`, normalize nếu peak > 1.0 |
| Biến môi trường | `MODEL_DIR` (default `/models`), `ASR_ENCODER` (`encoder-epoch-20-avg-10.int8.onnx`), `ASR_DECODER` (`decoder-epoch-20-avg-10.int8.onnx`), `ASR_JOINER` (`joiner-epoch-20-avg-10.int8.onnx`), `ASR_TOKENS` (`config.json`), `ASR_BPE` (`bpe.model`) |
| Volume mount | `${CALL_EMOTION_MODEL_HOST_PATH:-./call-emotion-model}:/models:ro` — thư mục host chứa file ONNX + BPE |
| Dependency pin | `fastapi==0.115.14`, `uvicorn[standard]==0.35.0`, `python-multipart==0.0.20`, `numpy==1.26.4`, `scipy==1.14.1`, `soundfile==0.14.0`, `sherpa-onnx==1.13.8`. Dockerfile cài `libsndfile1`. |
| Hành vi khởi động | Model load trong thread nền (`startup` hook). Nếu load lỗi, service vẫn lên nhưng `/transcribe` trả `503` và `/health` trả `error`. |

### OpenRouter (hoặc provider LLM được cấu hình)

- Dùng **hai lần** cho mỗi cuộc gọi, cùng một route `call_emotion_analysis`:
  1. Phiên âm — model hardcode `microsoft/mai-transcribe-2` qua `RubyLLM.transcribe`, `language: 'vi'`.
  2. Phân loại cảm xúc — model lấy từ `llm_feature_models.model`, có structured output theo `CallEmotionAnalysisSchema`.
- Provider và params đến từ bảng `llm_providers` / `llm_feature_models` (cấu hình trong DB, không qua ENV).

### Callytics / Voxa (callbot AI)

- Base URL default `https://api.app.voxa.vn` (`CALLYTICS_API_BASE_URL`).
- Gửi webhook `call.completed` v2.0 vào `/webhooks/callytics/:token`, ký HMAC bằng `CALLYTICS_WEBHOOK_SECRET`.
- Ghi âm lấy qua vendor API với `CALLYTICS_API_KEY` (scope `recordings:read`), chỉ cho phép đúng resource path `^/api/v1/vendor/call-reports/[^/]+/recording$`.
- Trả về Ogg/Opus → Rails transcode sang MP3 bằng `ffmpeg` (đã cài trong `docker/Dockerfile`).
- Payload callbot (`callbot_report`) giữ `result` (`outcome`, `summary`, `analysisStatus`, `customerIntent`, `customerDisposition`, `callback`, `business`, `captured`, `actions`), `conversation.turns` (transcript theo lượt) và `metadata`.

### Tổng đài PBX (customPBX)

- Gửi event tới `/webhooks/pbx/calls`, ký bằng `PBX_CALL_WEBHOOK_SECRET`.
- Event type nhận biết: `call.ringing`, `call.answered`, `call.completed`, `call.recording_ready`, `call.missed`. Event khác → đọc field `status` trong payload.
- `call.missed` map theo `hangup_cause`: `USER_BUSY` → `busy`, `CALL_REJECTED` → `rejected`, `ORIGINATOR_CANCEL` → `cancelled`, còn lại → `missed` (inbound) / `no_answer` (outbound).
- Rails lấy ghi âm từ PBX bằng HMAC ký riêng (`PBX_RECORDING_FETCH_SECRET`), bắt buộc HTTPS.

## API / Route

### Webhook công khai (`config/routes.rb`)

| Method | Path | Controller |
|---|---|---|
| POST | `/webhooks/pbx/calls` | `Webhooks::Pbx::CallsController#process_payload` |
| POST | `/webhooks/callytics/:token` | `Webhooks::Callytics::CallsController#process_payload` |

### API dashboard (`/api/v1/accounts/:account_id/...`)

| Method | Path | Action | Mô tả |
|---|---|---|---|
| GET | `phone_calls/emotion_reports` | `#emotion_reports` | Danh sách báo cáo + `counts` + `meta` phân trang. Filter: `call_status`, `direction`, `status` (gồm giá trị ảo `not_analyzed`), `emotion`, `action_status`, `purpose`. `page` ≥ 1, `limit` clamp 1..100 (default 50). Sắp xếp `COALESCE(started_at, created_at) DESC`. |
| GET | `phone_calls/:id` | `#show` | Chi tiết callbot. `404` nếu `metadata['callbot_report']` không phải Hash. |
| GET | `phone_calls/:id/recording` | `#recording` | Proxy/stream ghi âm. Với `?playback_url=true` trả `{url}` chứa signed token (hạn 1 giờ). |
| POST | `phone_calls/:id/emotion_analysis` | `#emotion_analysis` | Chạy phân tích **đồng bộ** ngay trong request. |
| GET | `phone_calls/:id/emotion_report` | `#emotion_report` | Trả `report_data`, hoặc `{status: 'pending', phone_call_id}` nếu chưa có báo cáo. |
| PATCH | `phone_calls/:id/emotion_report` | `#update_emotion_report` | Chỉ cho phép `action_status`, `purpose`. `404` nếu chưa có báo cáo. |
| GET/POST/PATCH/DELETE | `inboxes/:inbox_id/phone_extensions` | `Inboxes::PhoneExtensionsController` | Admin only. |
| GET/POST/PATCH/DELETE | `inboxes/:inbox_id/callbot_webhooks` | `Inboxes::CallbotWebhooksController` | Admin only. |
| GET | `inboxes/:id/phone_credentials` | `InboxesController#phone_credentials` | Credential SIP + ICE servers cho softphone của **user hiện tại** (`find_by!` nên 404 nếu agent chưa được gán extension). |

### Cơ chế xác thực ghi âm

`#recording` có đường vòng đặc biệt: `skip_before_action :authenticate_user!, :current_account, if: :signed_recording_request?`. Khi request có `params[:token]`, controller verify token bằng `Rails.application.message_verifier('phone_call_recording')` và đối chiếu lại cả `phone_call_id` và `account_id` trong payload với params URL. Lý do: thẻ `<audio>` của trình duyệt không gửi được header auth. Mọi response ghi âm đều set `Cache-Control: private, no-store`.

## Frontend

| File | Vai trò |
|---|---|
| `app/javascript/dashboard/api/phoneCalls.js` | API client (`ApiClient`, accountScoped): `show`, `emotionAnalysis`, `emotionReports`, `emotionReport`, `updateEmotionReport`. |
| `app/javascript/dashboard/components-next/message/bubbles/PhoneCall.vue` | Bubble cuộc gọi trong hội thoại (346 dòng). Tiêu đề theo status, icon `i-ph-phone-*`, player ghi âm, badge cảm xúc, khối kết quả, nút chạy lại phân tích, và tự tạo private note khi cảm xúc âm tính. |
| `app/javascript/dashboard/components-next/message/bubbles/PhoneCallDetailsDialog.vue` | Dialog chi tiết callbot (337 dòng): tổng quan, kết quả phân tích, dữ liệu nghiệp vụ, transcript theo lượt. |
| `app/javascript/dashboard/components-next/message/bubbles/emotionUtils.js` | `EMOTION_CONFIG` (5 nhãn + màu + alias), `normalizeEmotion`, `normalizedEmotionTag`. **Bản sao logic chuẩn hoá của Ruby ở phía JS** (bỏ dấu NFD, map `đ` → `d`). |
| `app/javascript/dashboard/components-next/message/chips/Audio.vue` | Player audio. Khi `attachment.requiresAuth === true`, gọi `axios.get(dataUrl, {params: {playback_url: true}})` để đổi lấy URL có signed token rồi mới gán vào `<audio>`. |
| `app/javascript/dashboard/components-next/message/Message.vue` | Map `CONTENT_TYPES.PHONE_CALL` → `PhoneCallBubble`. |
| `app/javascript/dashboard/components-next/message/constants.js` | `CONTENT_TYPES.PHONE_CALL = 'phone_call'` (khớp `Message` enum `phone_call: 13`). |
| `app/javascript/dashboard/routes/dashboard/settings/reports/PhoneCallReports.vue` | Trang báo cáo (354 dòng): 4 thẻ KPI, 6 select filter, bảng 9 cột, dropdown sửa `action_status` inline (optimistic + rollback khi lỗi), phân trang. |
| `app/javascript/dashboard/routes/dashboard/settings/reports/reports.routes.js` | Route `phone-calls` → `phone_call_reports` → `PhoneCallReports`. |
| `app/javascript/dashboard/components-next/sidebar/Sidebar.vue` | Mục sidebar `Reports Phone Calls` (dòng ~756). |
| `app/javascript/dashboard/stores/softphone.js` | Store Pinia dùng `jssip`: đăng ký SIP (`REGISTER_EXPIRES_SECONDS = 120`), `MEDIA_CONSTRAINTS = {audio: true, video: false}`, thông báo lỗi microphone theo loại, kiểm tra TURN/relay candidate. |
| `app/javascript/dashboard/components/tekomi/phone/SoftphoneWidget.vue` | Widget softphone, mount trong `Dashboard.vue` (async component, không có điều kiện `v-if`). |

Spec frontend: `PhoneCallReports.spec.js`, `emotionUtils.spec.js`, `stores/specs/softphone.spec.js`.

## Điểm vào trên giao diện

1. **Bubble trong hội thoại** — mỗi cuộc gọi tạo một `Message` `content_type: :phone_call`, nên hiển thị xen trong dòng thời gian hội thoại. Nội dung text là `"Cuộc gọi đến"` / `"Cuộc gọi đi"` (hardcode tiếng Việt trong `PbxCallEventProcessor#ensure_message`). Bubble là nơi agent:
   - nghe ghi âm (`AudioChip`),
   - xem badge cảm xúc và lý do,
   - bấm **Analyze call emotion** để chạy lại (nút **chỉ hiện khi** `emotionAnalysisError` hoặc `emotionReportStatus === 'failed'`),
   - mở dialog chi tiết nếu là cuộc gọi callbot (bubble trở thành `role="button"`, hỗ trợ Enter/Space).
2. **Sidebar → Reports → Phone calls** (`/app/accounts/:id/reports/phone-calls`) — bảng tổng hợp toàn account, filter, và sửa `action_status`.
3. **Softphone widget** — nổi trên mọi trang Dashboard, dùng để nhận/gọi qua WebRTC.
4. **Inbox settings → Phone extensions / Callbot webhooks** — cấu hình admin, qua API `inboxes/:id/phone_extensions` và `inboxes/:id/callbot_webhooks`.
5. **Link ngược về hội thoại** — mỗi dòng trong bảng báo cáo có `router-link` tới `/app/accounts/:accountId/conversations/:conversationId`.

## Luồng dữ liệu chính

### A. Cuộc gọi kết thúc → báo cáo cảm xúc (đường tự động)

```
PBX / Callbot
   │
   ├─ POST /webhooks/pbx/calls      (HMAC X-PBX-Signature, drift 5')
   └─ POST /webhooks/callytics/:token (HMAC X-Callytics-Signature t=,v1=)
                │
                └─ Callbot::CallCompletedProcessor  (chỉ nhánh callytics)
                        · validate eventType/eventVersion/call.id/direction/số KH
                        · dịch sang event PBX nội bộ, pbx_id = "callytics:<webhook.id>"
                        · trích callbot_recording_resource (chỉ method vendor_api)
                │
                ▼
        Phone::PbxCallEventProcessor#perform          ← ĐIỂM VÀO CHUNG
                1. validate_payload!  (event_id, event, linked_id)
                2. insert_event  → PbxCallEvent (insert_all, unique (pbx_id, event_id))
                3. event_record.with_lock:
                     · return nếu đã processed_at  → idempotent
                     · find_phone_call (pbx_id + linked_id) || create_phone_call
                         - resolve_context: extension → inbox → direction → customer_number
                         - Contacts::InboundPhoneResolver + ContactInboxWithContactBuilder
                         - resolve_conversation (tôn trọng lock_to_single_conversation?)
                     · apply_event: cập nhật thời gian, duration (lấy max), hangup_cause,
                       metadata['pbx_recording_url' | 'callytics_recording_resource' | 'callbot_report'],
                       recording_url = "/api/v1/accounts/<acc>/phone_calls/<id>/recording"
                     · status chỉ tiến lên theo STATUS_RANK
                     · ensure_message → Message(content_type: phone_call, content_attributes.data = message_data)
                     · event_record.update!(phone_call:, processed_at: now)
                4. enqueue_emotion_analysis  (NGOÀI lock)
                     guard: phone_call.terminal? && (pbx_recording_url || callytics_recording_resource)
                │
                ▼
        Phone::CallEmotionAnalysisJob  (Sidekiq queue `low`)
                1. guard lại: terminal? && recording_available?
                2. prepare_report: create_or_find_by!(phone_call_id)
                     with_lock → bỏ qua nếu 'completed', hoặc 'processing' < 30 phút
                     → status = 'processing'
                3. Phone::CallEmotionAnalysisService#perform
                     a. Phone::PbxRecordingFetcher#download
                          · PBX:       HTTPS + HMAC headers, tempfile .wav, ≤100MB
                          · Callytics: X-Callytics-API-Key, tempfile .ogg, ≤100MB
                     b. Phone::OpenrouterTranscriptionService#perform
                          · route = Llm::FeatureRouter.resolve('call_emotion_analysis')
                          · RubyLLM.transcribe(model 'microsoft/mai-transcribe-2',
                                               language 'vi', verbose_json, timestamps :word)
                          · transcript trống → TranscriptionFailed
                     c. analyze_transcript
                          · RubyLLM.chat(route model/provider).with_schema(CallEmotionAnalysisSchema)
                          · ask("Transcript cuộc gọi:\n<transcript>")
                          · normalize_label → ngoài 5 nhãn thì fallback 'trung tính'
                     d. ensure recording.close!
                4. persist_result
                     · PhoneCallEmotionReport: status 'completed', emotion, reason, transcript,
                       asr_model/provider/runtime, llm_model/provider, processed_at
                       (before_validation chuẩn hoá emotion + set emotion_color)
                     · phone_calls.metadata['emotion_analysis'] = kết quả + report_id + emotion_tag
                     · refresh_message: message.content_attributes = {data: message_data}
                                        message.send_update_event  → push realtime
                │
                ▼
        Dashboard
                · Bubble PhoneCall.vue nhận content_attributes mới → badge + lý do
                · Trang PhoneCallReports.vue (lần fetch sau) thấy báo cáo mới
```

Khi lỗi: `mark_failed` ghi `status: 'failed'` + `error_message` (truncate 1 000) bằng `update_columns` (bỏ qua validation/callback), rồi vẫn refresh Message → UI hiện nút **Analyze call emotion** để agent thử lại.

### B. Phân tích thủ công (agent bấm nút trong bubble)

```
PhoneCall.vue #analyzeEmotion
   └─ POST phone_calls/:id/emotion_analysis
         └─ PhoneCallsController#emotion_analysis   (ĐỒNG BỘ, trong request cycle)
               · authorize conversation, :show?
               · Phone::CallEmotionAnalysisService#perform   (lặp lại full pipeline)
               · update metadata, create_or_find_by! report, update! report
               · refresh Message + send_update_event
               · render JSON kết quả đã chuẩn hoá
   └─ addEmotionReviewNote(result)
         nếu emotion ∈ ['buồn','khó chịu','gay gắt']  →
         store.dispatch('createPendingMessageAndSend', {private: true})
         ghi private note "Call emotion review: <emotion>. ... <reason>"
```

Mã lỗi: `FeatureNotConfigured` → `422`; `RecordingUnavailable` / `TranscriptionFailed` → `502`; lỗi khác → `422` với message chung `'Call emotion analysis failed'`.

### C. Phát ghi âm

```
AudioChip (requiresAuth vì dataUrl bắt đầu bằng /api/)
   └─ GET phone_calls/:id/recording?playback_url=true
         → {url: ".../recording?token=<signed 1h>"}
   └─ <audio src="<url có token>">
         → GET phone_calls/:id/recording?token=...
              · skip authenticate_user! (verify message_verifier thay thế)
              · nhánh PBX:       stream_response (ActionController::Live, forward Range)
              · nhánh Callytics: nếu đã có cached_recording → send_cached_recording
                                 (hỗ trợ Range/206/416 thủ công)
                                 ngược lại: tải full body → ffmpeg Ogg→MP3 →
                                 attach cached_recording → send_cached_recording
```

## Cấu hình & biến môi trường

| Biến | Nơi đọc | Default | Có trong `.env.example`? |
|---|---|---|---|
| `PBX_CALL_WEBHOOK_SECRET` | `Webhooks::Pbx::CallsController` | — (blank → `503`) | ✅ dòng 85 |
| `PBX_RECORDING_FETCH_SECRET` | `PbxRecordingFetcher`, `PhoneCallsController` | — (blank → `RecordingUnavailable` / `404`) | ❌ **thiếu** |
| `CALL_EMOTION_SERVICE_URL` | `ZipformerTranscriptionService` | `http://call-emotion:8080` | ✅ dòng 87 |
| `CALL_EMOTION_MODEL_HOST_PATH` | `docker-compose.production.yaml` | `./call-emotion-model` | ✅ dòng 89 |
| `MODEL_DIR` | `call_emotion/server.py` | `/models` | — (set trong compose) |
| `ASR_ENCODER` / `ASR_DECODER` / `ASR_JOINER` / `ASR_TOKENS` / `ASR_BPE` | `call_emotion/server.py` | tên file epoch-20-avg-10 int8 / `config.json` / `bpe.model` | ❌ không có |
| `CALLYTICS_WEBHOOK_SECRET` | `Webhooks::Callytics::CallsController` | — (blank → `503`) | ✅ dòng 90 |
| `CALLYTICS_API_KEY` | `PbxRecordingFetcher`, `PhoneCallsController` | — (blank → `404` / `RecordingUnavailable`) | ✅ dòng 92 |
| `CALLYTICS_API_BASE_URL` | như trên | `https://api.app.voxa.vn` | ✅ dòng 93 |
| `FRONTEND_URL` | `CallbotWebhooksController#webhook_payload` | `''` | ✅ (chung) |

Cấu hình **không qua ENV**:
- `config/llm.yml` → `features.call_emotion_analysis.group: conversation`. File này chỉ khai báo feature key và group; **không** chứa model/provider.
- Model + provider thực tế nằm ở bảng DB `llm_feature_models` (khoá `feature_key = 'call_emotion_analysis'`) + `llm_providers`, seed bởi migration `20260929000002`.
- `config/llm_models.json` **không** có entry nào cho `call_emotion`.
- Cấu hình SIP/TURN per-inbox nằm trong `channel_phone` (`wss_url`, `sip_domain`, `ice_servers`, `turn_shared_secret`, `turn_credential_ttl`).
- Queue: job dùng `queue_as :low`, nằm gần cuối thứ tự ưu tiên trong `config/sidekiq.yml` (sau `critical`, `high`, `medium`, `default`, `mailers`, `action_mailbox_routing`).
- `ffmpeg` được cài trong `docker/Dockerfile` (dòng 138) — cần cho transcode Ogg→MP3 của Callytics.

## Feature flag

**Không có feature flag riêng cho cuộc gọi hay phân tích cảm xúc.** Đã kiểm `config/features.yml`: chỉ có `voice_recorder` và `channel_voice` (kênh Voice của Chatwoot OSS, khác `Channel::Phone` của Tekomi).

Việc bật/tắt thực tế dựa vào:
- **Route báo cáo**: `reports.routes.js` dùng `meta = { featureFlag: FEATURE_FLAGS.REPORTS, permissions: ['administrator', 'report_manage'] }` — tức là chỉ gắn với flag Reports chung.
- **API cuộc gọi**: không kiểm flag. `#show`/`#recording`/`#emotion_*` chỉ `authorize @phone_call.conversation, :show?`. Các endpoint cấu hình (`phone_extensions`, `callbot_webhooks`) dùng `check_admin_authorization?`.
- **Softphone widget**: mount vô điều kiện trong `Dashboard.vue` (không `v-if`); gating thực tế là endpoint `phone_credentials` trả `404` nếu inbox không phải Phone, và `find_by!` raise nếu user chưa có extension.
- **Webhook**: tự tắt mềm — trả `503` khi secret tương ứng blank.
- **Enterprise**: `CallEmotionAnalysisService` và cả hai service phiên âm nằm dưới `enterprise/`, nên trên build OSS thuần các class này không tồn tại → job và endpoint `emotion_analysis` sẽ raise `NameError`. **Chưa xác minh** có cơ chế nào chặn trước điểm đó trên OSS.

## i18n

| File | Key gốc | Nội dung |
|---|---|---|
| `app/javascript/dashboard/i18n/locale/en/conversation.json` | `CONVERSATION.PHONE_CALL` | 10 nhãn status (`INBOUND`, `OUTBOUND`, `IN_PROGRESS`, `COMPLETED`, `MISSED`, `BUSY`, `NO_ANSWER`, `REJECTED`, `CANCELLED`, `FAILED`) |
| | `CONVERSATION.PHONE_CALL.EMOTION_ANALYSIS` | `ANALYZE`, `ANALYZING`, `RESULT` (`{emotion}`), `REVIEW`, `NOTE` (`{emotion}`, `{reason}`), `NOTE_SAVED`, `NOTE_ERROR` |
| | `CONVERSATION.PHONE_CALL.DETAILS` | ~33 key cho dialog callbot (`TITLE`, `OVERVIEW`, `ANALYSIS`, `BUSINESS_DATA`, `TRANSCRIPT`, `CAPTURED_FIELDS`, `CONFIRMED_ACTIONS`, `METADATA`, …) |
| `.../en/report.json` | `PHONE_CALL_REPORTS` | 20 nhóm key: `HEADER`, `DESCRIPTION`, `TOTAL`, `LOADING`, `EMPTY`, `ERROR`, `UPDATE_ERROR`, `PREVIOUS`, `NEXT`, `EMPTY_VALUE`, `CONVERSATION_ID`, `PAGINATION`, `FILTERS`, `TABLE`, `CALL_STATUS`, `EMOTION`, `REPORT_STATUS`, `ACTION_STATUS`, `PURPOSE`, `DIRECTION` |
| `.../en/settings.json` | `SIDEBAR.REPORTS_PHONE_CALLS` | `"Phone calls"` (dòng 373) |
| `.../vi/conversation.json`, `.../vi/report.json`, `.../vi/settings.json` | cùng key | Đã có bản dịch tiếng Việt (ví dụ `PHONE_CALL_REPORTS.HEADER` = `"Báo cáo cuộc gọi"`) |

Lưu ý:
- **Backend `config/locales/en.yml` không có key nào** cho phone call / emotion. Mọi chuỗi backend là hardcode: nội dung Message (`'Cuộc gọi đến'` / `'Cuộc gọi đi'` trong `PbxCallEventProcessor`), prompt LLM (`"Transcript cuộc gọi:\n…"`), lý do fallback (`'Không có bằng chứng cảm xúc rõ ràng trong transcript.'`), và các message lỗi (tiếng Anh, được render trực tiếp ra UI qua `error.message`).
- Nhãn cảm xúc (`vui`, `trung tính`, `buồn`, `khó chịu`, `gay gắt`) **không i18n** — là giá trị dữ liệu tiếng Việt, hiển thị thẳng cả ở bubble và bảng báo cáo. Tuân đúng CLAUDE.md (chỉ sửa `en.yml`/`en.json`) nhưng cũng nghĩa là UI tiếng Anh vẫn thấy nhãn tiếng Việt.
- `PhoneCallReports.vue` disable lint `@intlify/vue-i18n/no-dynamic-keys` vì build key động `PHONE_CALL_REPORTS.<GROUP>.<VALUE_UPPERCASE>`.

## ⚠️ Phụ thuộc chéo

### 1. `docker-compose.production.yaml`: `rails` phụ thuộc `call-emotion`

```yaml
rails:
  depends_on:
    - redis
    - call-emotion
```

**Thiếu service `call-emotion` thì container `rails` không khởi động được.** Và service đó lại phụ thuộc vào volume mount model:

```yaml
call-emotion:
  build: { context: ./call_emotion }
  volumes:
    - ${CALL_EMOTION_MODEL_HOST_PATH:-./call-emotion-model}:/models:ro
```

Nếu thư mục `./call-emotion-model` trên host không tồn tại hoặc thiếu file ONNX/BPE, service vẫn lên (model load trong thread nền, lỗi được nuốt vào `engine.error`) nhưng `/health` báo `ready: false`. Nghĩa là: **lỗi thiếu model không làm compose fail, nó âm thầm và chỉ lộ ra khi gọi `/transcribe`** — mà `/transcribe` lại không được code Rails nào gọi (xem điểm 2).

Chú ý thêm: service `sidekiq` **không** `depends_on: call-emotion`, dù job phân tích cảm xúc chạy ở sidekiq. Bất đối xứng này không gây lỗi hiện tại (vì pipeline không dùng service Python), nhưng là dấu hiệu `depends_on` đặt sai chỗ.

### 2. Service Python là mồ côi — `ZipformerTranscriptionService` không ai gọi

- `enterprise/app/services/phone/zipformer_transcription_service.rb` là nơi duy nhất đọc `CALL_EMOTION_SERVICE_URL`.
- `grep -rn "Zipformer"` trong `app/`, `enterprise/`, `lib/`, `config/` chỉ ra chính file đó. **Không có caller nào.**
- `Phone::CallEmotionAnalysisService` gọi `Phone::OpenrouterTranscriptionService`.

Kết quả: cả stack `call_emotion/` + mount model + `depends_on` đang là **hạ tầng chết chắn chắn làm `rails` không boot được nếu thiếu, nhưng không đóng góp gì cho pipeline đang chạy**. Audio thực tế được gửi ra OpenRouter, không phải xử lý nội bộ — ngược lại mục tiêu "Private … transcription service" ghi trong docstring `server.py`.

### 3. Một route LLM nhưng hai mục đích khác bản chất

`Llm::FeatureRouter.resolve(feature: 'call_emotion_analysis')` được gọi ở **hai service khác nhau**:
- `OpenrouterTranscriptionService` → chỉ lấy `route[:provider]`, model thì **hardcode** `'microsoft/mai-transcribe-2'`.
- `CallEmotionAnalysisService#analyze_transcript` → lấy cả `provider`, `model`, `params`.

Hệ quả: nếu admin đổi provider của feature `call_emotion_analysis` sang một provider **không hỗ trợ `microsoft/mai-transcribe-2`** (ví dụ OpenAI thuần), phần phiên âm sẽ fail ngay cả khi phần phân loại hoạt động bình thường. `assume_model_exists: true` ở cả hai chỗ nên không có validate trước.

### 4. Chuỗi guard theo tầng cho việc enqueue phân tích

Điều kiện enqueue được kiểm **hai lần** (processor + job), và cả hai dùng cùng biểu thức:

```ruby
phone_call.terminal? && (metadata['pbx_recording_url'].present? || metadata['callytics_recording_resource'].present?)
```

Nếu PBX gửi `call.completed` **trước** `call.recording_ready` (một luồng rất thường gặp), lần enqueue đầu bị skip vì chưa có `pbx_recording_url`. Phân tích chỉ chạy khi event `recording_ready` tới sau đó — và `event_status('call.recording_ready')` trả `nil` nên status không bị đổi, `status_can_advance?` trả `false`, nhưng `apply_event` vẫn merge `pbx_recording_url` vào metadata và `enqueue_emotion_analysis` vẫn chạy. **Nếu PBX không bao giờ gửi `recording_ready`, báo cáo không bao giờ được tạo** và cuộc gọi hiện là `not_analyzed` trong bảng báo cáo (không phải `failed`), nên không có nút retry nào trên bubble.

### 5. `ffmpeg` là dependency cứng cho ghi âm Callytics

`PhoneCallsController#compatible_recording` shell-out `Open3.capture3('ffmpeg', ...)` khi `Content-Type` upstream bắt đầu bằng `audio/ogg`. Hiện `ffmpeg` có trong `docker/Dockerfile` (dòng 138). **Nếu image Rails bị rebuild thiếu `ffmpeg`, mọi ghi âm Callytics trả `502`** (`RecordingTranscodeError` → `head :bad_gateway`), còn ghi âm từ PBX (wav) vẫn chạy bình thường → lỗi sẽ trông như "chỉ callbot bị hỏng".

Lưu ý thêm: `PbxRecordingFetcher#download_callytics` **không** transcode, nó đưa file `.ogg` nguyên bản cho `RubyLLM.transcribe`. Nghĩa là pipeline phân tích và pipeline phát ghi âm xử lý format khác nhau — đổi logic transcode ở controller không ảnh hưởng job, và ngược lại.

### 6. Chuẩn hoá nhãn cảm xúc tồn tại ở 3 nơi, phải sửa đồng bộ

| Nơi | Nội dung |
|---|---|
| `app/models/phone_call_emotion_report.rb` | `EMOTION_COLORS`, `EMOTION_ALIASES` (22 entry), `LEGACY_STORED_LABELS`, `normalize_emotion_label`, `emotion_filter_values` |
| `enterprise/app/services/tekomi/llm/call_emotion_analysis_schema.rb` | `LABELS` (enum structured output gửi cho LLM) |
| `app/javascript/dashboard/components-next/message/bubbles/emotionUtils.js` | `EMOTION_CONFIG` với cùng bộ alias, `normalizeEmotion` |

Thêm `PhoneCallReports.vue` hardcode lại `options.emotion = ['vui','trung tính','buồn','khó chịu','gay gắt']` và `emotionClasses` (bản thứ tư của bảng màu, dùng `n-teal-*` cho `green` trong khi `PhoneCall.vue` dùng `n-green-*`). **Thêm một nhãn mới cần sửa ít nhất 4 chỗ**, và sai ở bất kỳ chỗ nào chỉ biểu hiện như "màu lệch" hoặc "filter ra 0 kết quả" chứ không raise lỗi.

### 7. Chuẩn hoá số điện thoại tồn tại ở 2 nơi với logic khác nhau

- `Phone::PbxCallEventProcessor#normalize_customer_number`: tôn trọng tiền tố `+` có sẵn, yêu cầu ≥ 8 chữ số, xử lý `00`, `0` → `+84`, `84`.
- `Callbot::CallCompletedProcessor#normalize_phone`: bỏ `00` trước, không xét tiền tố `+`, cùng mapping VN.

Hai hàm cho kết quả giống nhau trong các case thường gặp nhưng **không phải là cùng một hàm**. `CallCompletedProcessor` chuẩn hoá trước, rồi truyền vào `payload['customer_number']`, và `PbxCallEventProcessor` sẽ chuẩn hoá **lần hai**. Comment trong `CallCompletedProcessor` giải thích việc này là để `Contacts::InboundPhoneResolver` map `0342…`, `+84342…`, `84 342…` về cùng một contact.

### 8. `PhoneCall#message_data` vừa đọc `metadata` vừa đọc association

```ruby
emotion_analysis: metadata['emotion_analysis'],
emotion_report:   emotion_report&.report_data,
emotion_tag:      emotion_report&.emotion_tag || metadata.dig('emotion_analysis', 'emotion_tag')
```

Dữ liệu cảm xúc bị lưu **hai bản**: trong `phone_call_emotion_reports` (nguồn sự thật) và trong `phone_calls.metadata['emotion_analysis']` (bản chụp). `PhoneCall.rb` cũng tham chiếu `PhoneCallEmotionReport` và `report_data` lại tham chiếu ngược `phone_call.direction`, `phone_call.status`… → **phụ thuộc vòng** giữa hai model. `report_data` dùng `.compact`, nên field `nil` biến mất khỏi JSON thay vì về `null` — frontend phải tự xử lý key thiếu.

### 9. `PhoneCall.vue` chấp nhận cả snake_case và camelCase cho mọi field

Mỗi field được đọc hai kiểu (`call.value.customerNumber || call.value.customer_number`, …). Backend luôn gửi snake_case (`message_data` dùng symbol snake_case). Nhánh camelCase **chưa xác minh** nguồn gốc — có thể do một lớp transform key (`ActiveModelSerializers`/axios interceptor) ở một đường render khác. Khi thêm field mới cho bubble, cần biết là đường nào đang thực sự chạy, nếu không sẽ thêm fallback dư.

## Cạm bẫy đã biết

1. **`PBX_RECORDING_FETCH_SECRET` không có trong `.env.example`.** Chỉ hai file code đọc nó. Thiếu biến này: `PbxRecordingFetcher` raise `RecordingUnavailable, 'PBX recording secret is not configured'` → báo cáo `failed`; và `#recording` trả `404` cho ghi âm PBX. Triệu chứng nhìn như "PBX không trả ghi âm" chứ không như lỗi cấu hình.

2. **`db/schema.rb` lệch với migrations.** Version stamp là `2026_09_25_000002` nhưng có migration tới `2026_10_02_000001`. Cụ thể: bảng `callbot_webhooks` (migration `20260911000003`, tức *sớm hơn* version stamp) **không xuất hiện trong `db/schema.rb`**, trong khi `phone_call_emotion_reports` (migration `20260930000003`, *muộn hơn* version stamp) thì có. Dựng DB bằng `db:schema:load` sẽ **thiếu bảng `callbot_webhooks`** → webhook callbot chết. Phải dùng `db:migrate`. Nguyên nhân chính xác **chưa xác minh**.

3. **Endpoint `emotion_analysis` chạy đồng bộ trong request cycle.** `PhoneCallsController#emotion_analysis` làm toàn bộ việc: tải file ≤100MB, gọi ASR, gọi LLM. Với read_timeout 120s cho download + mạng OpenRouter, request này dễ vượt timeout của reverse proxy. Đây là code **gần như trùng lặp hoàn toàn** với `persist_result` trong job (cùng 11 field update, cùng logic merge metadata, cùng refresh message) — sửa một bên mà quên bên kia là rủi ro thực tế.

4. **Nút retry phân tích bị ẩn trong hầu hết trường hợp.** `PhoneCall.vue` chỉ render nút khi `emotionAnalysisError || emotionReportStatus === 'failed'`. Nếu báo cáo kẹt ở `processing` (job crash giữa đường, hoặc worker bị kill), UI không có nút nào, và job mới chỉ được phép chạy lại sau khi `updated_at` cũ hơn 30 phút. Nếu cuộc gọi chưa bao giờ được enqueue (xem Phụ thuộc chéo #4), status là `not_analyzed` → cũng không có nút.

5. **Status `'skipped'` được khai báo nhưng chưa dùng.** Nằm trong `PhoneCallEmotionReport::STATUSES` nhưng không code nào gán, và cũng **không có trong** `options.reportStatus` của `PhoneCallReports.vue` → nếu có bản ghi `skipped`, filter UI không hiển thị tùy chọn đó, và `label('REPORT_STATUS', 'skipped')` sẽ tra một i18n key không tồn tại.

6. **`mark_failed` dùng `update_columns`.** Bỏ qua validation và `before_validation` callback. Hợp lý ở đây (chỉ ghi status + error), nhưng nghĩa là `emotion_color` và `emotion` không được chuẩn hoá lại ở đường fail — nếu có lần chạy trước đó đã ghi `emotion`, giá trị cũ vẫn còn trong khi `status` đã là `failed`.

7. **Message lỗi backend bằng tiếng Anh, hiện thẳng ra UI.** `PhoneCall.vue` gán `emotionAnalysisError.value = error.message` và render trong `<p role="alert">`. Các message từ `RecordingUnavailable` / `TranscriptionFailed` (`'PBX returned HTTP 404'`, `'OpenRouter returned an empty transcript'`, …) đều là tiếng Anh hardcode, không qua i18n.

8. **`resolve_inbox` có fallback "inbox Phone duy nhất".** `PbxCallEventProcessor#resolve_inbox` thử lần lượt: `payload['inbox_id']` → `Channel::Phone` theo `sip_domain`/`pbx_id` → extension khớp **đúng một** inbox → và cuối cùng `Channel::Phone.limit(2)` nếu toàn hệ thống **chỉ có một** inbox Phone. Fallback cuối hoạt động tốt khi single-tenant, nhưng sẽ **âm thầm ngừng hoạt động** ngay khi account thứ hai tạo inbox Phone — cuộc gọi khi đó bị drop (event được mark `processed_at` mà không tạo `PhoneCall`), không có log cảnh báo.

9. **Nội dung Message hardcode tiếng Việt.** `ensure_message` set `content: 'Cuộc gọi đến' / 'Cuộc gọi đi'`. Giá trị này được lưu vào DB nên dashboard tiếng Anh cũng thấy tiếng Việt ở các chỗ dùng `message.content` (ví dụ preview trong danh sách hội thoại), dù bubble thì render qua i18n key `CONVERSATION.PHONE_CALL.*`.

10. **Private note cảm xúc âm tính chỉ tạo ở đường thủ công.** `addEmotionReviewNote` được gọi trong `#analyzeEmotion` của `PhoneCall.vue`. Đường tự động qua job **không** tạo private note — job chỉ cập nhật báo cáo và refresh Message. Nên với cuộc gọi được phân tích tự động (phần lớn), agent không có note nhắc việc trong hội thoại.

11. **`isEmotionNoteSaved` là state cục bộ của component.** Reload trang hoặc remount bubble sẽ reset về `false`, nên bấm **Analyze** lần nữa có thể tạo private note trùng. Không có kiểm tra phía server để chống trùng note.

12. **`emotion_reports` chạy `count` + `group` nhiều lần không cache.** Mỗi request `#emotion_reports` thực hiện: 1 `count` cho tổng filter, rồi `emotion_report_counts` làm thêm 1 `count` + 2 `group(...).count` trên `phone_calls` và 3 `group(...).count` trên `phone_call_emotion_reports` — tất cả **không áp filter**, scan toàn bộ account. Trên account nhiều cuộc gọi, trang báo cáo sẽ chậm dần. Index hiện có (`[account_id, status]`, `[account_id, emotion]`) giúp cho 2 trong số 3 group trên bảng report, nhưng `phone_calls` không có index nào trên `(account_id, status)` hay `(account_id, direction)`.

13. **`updateActionStatus` làm optimistic update rồi `Object.assign(row, data)`.** Vì `report_data` dùng `.compact`, các field `nil` không có trong response, nên `Object.assign` **không xoá** được giá trị cũ của field vừa trở thành `nil`. Hiện chưa gây lỗi thấy được vì PATCH chỉ đổi `action_status`/`purpose`, nhưng là bẫy nếu endpoint mở rộng.
