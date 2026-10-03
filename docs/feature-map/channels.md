# Bản đồ: Kênh kết nối

> Lập tại commit `c37c7293a9` — ngày 2026-10-03
> Bản đồ có thể lạc hậu khi code đổi. Luôn kiểm chứng lại điểm then chốt trước khi kết luận.

## Tóm tắt

Mỗi kênh kết nối là một **model channel riêng** (`app/models/channel/*.rb`), mỗi model có bảng riêng
(`channel_zalo_oa`, `channel_telegram`, …) và được nối với `Inbox` qua association đa hình
(`Inbox belongs_to :channel, polymorphic: true`). Toàn bộ model channel đều `include Channelable`
(`app/models/concerns/channelable.rb`), concern này khai báo `has_one :inbox, as: :channel` và
`belongs_to :account`.

Hai chiều dữ liệu được tách rạch ròi:

- **Nhận tin (inbound)**: controller webhook (`app/controllers/webhooks/`) → job
  (`app/jobs/webhooks/`) → service/builder tạo contact + conversation + message.
- **Gửi tin (outbound)**: `Message` after_create_commit → `SendReplyJob` →
  `<Channel>::SendOn<Channel>Service` (đều kế thừa `Base::SendOnChannelService`).

Fork này bổ sung **2 kênh không có trong Chatwoot gốc**: `Channel::ZaloOa` (Zalo Official Account,
qua OAuth + webhook chính thức của Zalo) và `Channel::ZaloPersonal` (Zalo cá nhân/nhóm, qua một
**worker Node riêng** nằm ở thư mục `zalo_worker/` dùng thư viện `zca-js` — đây là API không chính
thức). Kênh `Channel::Phone` (SIP/WebRTC) và `Channel::Tiktok` cũng là phần mở rộng không thuộc
Chatwoot OSS gốc (chưa xác minh đối chiếu upstream chi tiết, nhưng không nằm trong nhóm kênh
Chatwoot cổ điển).

## Bảng tổng hợp các kênh

| Kênh | Model | Bảng | Webhook nhận | Service gửi | Riêng của fork? |
|---|---|---|---|---|---|
| Website widget | `Channel::WebWidget` | `channel_web_widgets` | không có webhook — API widget `api/v1/widget/*` | `Messages::SendEmailNotificationService` (chỉ gửi email thông báo) | Không |
| API | `Channel::Api` | `channel_api` | không — client gọi `public/api/v1/inboxes/*` | `Messages::SendEmailNotificationService` | Không |
| Email | `Channel::Email` | `channel_email` | ActionMailbox (`app/mailboxes/`) + IMAP fetch job | `Email::SendOnEmailService` | Không |
| Facebook Page / Messenger | `Channel::FacebookPage` | `channel_facebook_pages` | `mount Facebook::Messenger::Server, at: 'bot'` | `Facebook::SendOnFacebookService` | Không |
| Instagram (qua FB Page) | `Channel::FacebookPage` (có `instagram_id`) | `channel_facebook_pages` | `POST /webhooks/instagram` | `Instagram::Messenger::SendOnInstagramService` | Không |
| Instagram (login trực tiếp) | `Channel::Instagram` | `channel_instagram` | `POST /webhooks/instagram` | `Instagram::SendOnInstagramService` | Không |
| Telegram | `Channel::Telegram` | `channel_telegram` | `POST /webhooks/telegram/:bot_token` | `Telegram::SendOnTelegramService` | Không |
| WhatsApp (Cloud / 360dialog) | `Channel::Whatsapp` | `channel_whatsapp` | `GET|POST /webhooks/whatsapp/:phone_number` | `Whatsapp::SendOnWhatsappService` | Không |
| WhatsApp / SMS qua Twilio | `Channel::TwilioSms` | `channel_twilio_sms` | `POST /twilio/callback` | `Twilio::SendOnTwilioService` | Không |
| SMS (Bandwidth) | `Channel::Sms` | `channel_sms` | `POST /webhooks/sms/:phone_number` | `Sms::SendOnSmsService` | Không |
| LINE | `Channel::Line` | `channel_line` | `POST /webhooks/line/:line_channel_id` | `Line::SendOnLineService` | Không |
| TikTok | `Channel::Tiktok` | `channel_tiktok` | `POST /webhooks/tiktok` | `Tiktok::SendOnTiktokService` | Mở rộng (không thuộc Chatwoot OSS cổ điển) |
| Twitter / X | `Channel::TwitterProfile` | `channel_twitter_profiles` | `GET|POST /webhooks/twitter` | `Twitter::SendOnTwitterService` | Không (đang bị loại khỏi danh sách thêm kênh trên UI) |
| **Zalo OA** | `Channel::ZaloOa` | `channel_zalo_oa` | `POST /webhooks/zalo_oa` | `ZaloOa::SendOnZaloOaService` | **Có** |
| **Zalo cá nhân** | `Channel::ZaloPersonal` | `channel_zalo_personal` | `POST /webhooks/zalo_personal` (worker gọi vào) | `Zalo::SendOnZaloPersonalService` | **Có** |
| Phone (SIP/WebRTC) | `Channel::Phone` | `channel_phone` | `POST /webhooks/pbx/calls`, `POST /webhooks/callytics/:token` | không có `SendOn…` (kênh thoại) | Mở rộng |

Lưu ý: `SendReplyJob::CHANNEL_SERVICES` là nguồn chân lý cho ánh xạ kênh → service gửi
(`app/jobs/send_reply_job.rb`). `Channel::FacebookPage` không nằm trong hash này mà được xử lý
riêng trong `send_on_facebook_page`.

## Database

Tất cả bảng channel ở `db/schema.rb` (dòng ~428–647). Mỗi bảng chỉ chứa thông tin kết nối/credential
của kênh đó; `inboxes.channel_type` + `inboxes.channel_id` là cầu nối (index
`index_inboxes_on_channel_id_and_channel_type`).

Hai bảng riêng của fork:

**`channel_zalo_oa`** (`db/schema.rb:620`)

| Cột | Kiểu | Ghi chú |
|---|---|---|
| `account_id` | integer, not null | |
| `backfill_watermark_ms` | bigint, default 0, not null | mốc thời gian đã backfill xong (ms) |
| `oa_id` | string, not null | **unique index** `index_channel_zalo_oa_on_oa_id` |
| `oa_name` | string | tên OA lấy từ Zalo |
| `app_id` | string, not null | |
| `app_secret` | text, not null | mã hoá nếu `Chatwoot.encryption_configured?` |
| `oa_secret_key` | text | dùng để xác thực chữ ký webhook; mã hoá |
| `access_token` / `refresh_token` | text | mã hoá |
| `token_expires_at` | datetime | |

**`channel_zalo_personal`** (`db/schema.rb:636`)

| Cột | Kiểu | Ghi chú |
|---|---|---|
| `account_id` | integer, not null | |
| `zalo_uid` | string, not null | **unique index** `index_channel_zalo_personal_on_zalo_uid` |
| `display_name` | string | |
| `credentials` | text, not null | JSON session zca-js, mã hoá |
| `status` | string, default `"reconnecting"`, not null | `connected` / `reconnecting` / `expired` |
| `status_updated_at`, `last_connected_at` | datetime | |
| `proxy_enabled` | boolean, default true, not null | ghi chú: cột này có trong annotation model nhưng **không thấy trong `db/schema.rb` ở dòng 636–646** — chưa xác minh (có thể migration mới chưa dump) |

## Backend — theo từng kênh

### Zalo OA (`Channel::ZaloOa`) — riêng của fork

- **Model**: `app/models/channel/zalo_oa.rb`
  - `EDITABLE_ATTRS = [:app_id, :app_secret, :oa_secret_key]` — cố ý **không** có `oa_id`, vì channel
    được tạo từ OAuth callback chứ không qua endpoint tạo inbox chung.
  - `valid_access_token` / `refresh_access_token!`: refresh token với `TOKEN_REFRESH_LEEWAY = 5.minutes`,
    khoá bằng `Redis::LockManager` (key `ZALO_OA_REFRESH_TOKEN_LOCK::<channel_id>`, TTL 30s). Nếu
    không lấy được lock thì trả về token hiện tại (chấp nhận token cũ còn hạn, tránh đua refresh token).
  - `prepend_mod_with('Channel::ZaloOa')` ở cuối file (hook Enterprise), **nhưng chưa có file override
    nào trong `enterprise/`** — kiểm chứng: `find enterprise -name "*zalo*"` không ra kết quả.
- **Tạo kênh (OAuth)**:
  - `app/controllers/api/v1/accounts/zalo_oa/authorizations_controller.rb` — nhận `app_id`,
    `app_secret`, `oa_secret_key`, sinh `state = SecureRandom.hex(24)`, lưu payload vào Redis key
    `zalo_oa:pending:<state>` TTL 15 phút, trả `redirect_url` do `ZaloOa::Client.permission_url` dựng.
  - `app/controllers/zalo_oa/callbacks_controller.rb` (`GET /zalo_oa/callback`) — đọc lại Redis, đổi
    `code` → token, gọi `ZaloOa::Client.fetch_oa_profile`, tạo channel + inbox trong một transaction,
    rồi `ZaloOa::BackfillJob.perform_later` và redirect tới trang gán agent.
- **Webhook**: `app/controllers/webhooks/zalo_oa_controller.rb` (`POST /webhooks/zalo_oa`)
  - Tìm channel theo `oa_id` lấy từ payload: với `event_name` bắt đầu `user_` thì OA là
    `recipient.id`, ngược lại là `sender.id`.
  - Xác thực chữ ký: `SHA256(app_id + raw_body + timestamp + oa_secret_key)` so với header
    `X-ZEvent-Signature` (bỏ tiền tố `mac=`), dùng `secure_compare`.
  - Sự kiện echo (`event_name` bắt đầu `oa_`) được enqueue **trễ 2 giây** để tránh race với API gửi tin.
- **Job**: `app/jobs/webhooks/zalo_oa_events_job.rb` (`MutexApplicationJob`, queue `low`)
  - `user_submit_info` → `ZaloOa::SharedInfoService`.
  - Các event khác → lock `ZALO_OA_MESSAGE_CREATE_LOCK::<inbox_id>::<user_id>` TTL 30s →
    `ZaloOa::IncomingMessageService`.
  - `retry_on LockAcquisitionError, wait: 2.seconds, attempts: 20` (ngân sách 38s > TTL lock 30s).
- **Builder/incoming**: `app/services/zalo_oa/incoming_message_service.rb`
  - Phân loại event: `TEXT_EVENTS`, `IMAGE_EVENTS`, `FILE_EVENTS`, `NO_CONTENT_EVENTS`.
  - Chống trùng: `already_imported?` kiểm tra `inbox.messages.exists?(source_id:)` **và** Redis key
    `ZALO_OA_SENT_MESSAGE::<inbox_id>::<zalo_message_id>`.
  - Contact: `ContactInboxWithContactBuilder` với `source_id = user_id`, tên lấy từ
    `ZaloOa::Client.fetch_user_profile`, fallback `"Zalo User <user_id>"`.
  - Tải attachment qua `Down.download(..., max_size: 40.megabytes)`; nếu lỗi thì **không huỷ tin**, mà
    ghi thêm ghi chú tiếng Việt `MISSING_ATTACHMENT_NOTE` kèm URL gốc.
  - Hỗ trợ vị trí (`user_send_location`) → attachment `file_type: :location`.
  - Sau mỗi tin inbound: `ZaloOa::ConsultationWindow.record_inbound` + `ZaloOa::RequestInfoJob`.
- **Service gửi**: `app/services/zalo_oa/send_on_zalo_oa_service.rb`
  - Gửi text qua `ZaloOa::MessageSender#send_text`; mỗi attachment là **một tin Zalo riêng**
    (Zalo không hỗ trợ multi-attachment).
  - `record_external_id` lưu từng id vào `content_attributes['external_message_ids']` và Redis
    `ZALO_OA_SENT_MESSAGE::…` để nhận ra echo; `source_id` = id đầu tiên.
  - Ghi đè `outgoing_message_originated_from_channel?` → trả `false` khi `partially_sent?`, để retry
    tiếp tục gửi các attachment còn lại.
  - Lỗi `WindowError` / `PermanentError` → đánh `message.status = :failed` + `external_error`.
- **Client / sender**:
  - `app/services/zalo_oa/client.rb` — `OAUTH_BASE = https://oauth.zaloapp.com/v4/oa`,
    `API_BASE = https://openapi.zalo.me`; có `exchange_code`, `refresh_token`, `fetch_oa_profile`
    (`/v2.0/oa/getoa`), `fetch_user_profile` (`/v3.0/oa/user/detail`), `send_request_user_info`,
    `list_recent_chats` (`/v2.0/oa/listrecentchat`), `conversation_messages`.
  - `app/services/zalo_oa/message_sender.rb` — gửi qua `/v3.0/oa/message/cs`, upload ảnh
    `/v2.0/oa/upload/image`, upload file `/v2.0/oa/upload/file`. Mã lỗi: `RETRYABLE_CODES = [-32, -100]`,
    `WINDOW_CODES = [-213, -217, -227, -230, -232, -234, -244]` (chưa follow, bị chặn, hết cửa sổ
    tương tác, giới nghiêm 22h–6h…). Nếu quote id không dùng được (`PermanentError`) thì gửi lại **bỏ quote**.
  - `app/services/zalo_oa/image_compressor.rb` — nén ảnh bằng `Vips` xuống `MAX_BYTES = 900_000`
    (`DIMENSIONS = [1600, 1280, 1024, 800]`, `JPEG_QUALITIES = [82, 72, 60]`); ảnh có alpha giữ PNG.
    GIF bị loại khỏi `COMPRESSIBLE_EXTENSIONS` để không mất animation.
- **Cửa sổ tư vấn**: `app/services/zalo_oa/consultation_window.rb` — `WINDOW = 48.hours`,
  `FREE_LIMIT = 8`, cảnh báo sớm ở `NEAR_LIMIT_AT = 6`. Ghi vào
  `conversation.additional_attributes['zalo_oa_last_inbound_at']` và `['zalo_oa_cs_sent_count']`;
  khi vượt/hết cửa sổ thì **tạo private note** trong hội thoại.
- **Backfill**: `app/jobs/zalo_oa/backfill_job.rb` (`MAX_CONVERSATIONS = 50`,
  `MAX_MESSAGES_PER_CONVERSATION = 100`, `PAGE_SIZE = 10`, lock 5 phút) +
  `app/jobs/zalo_oa/backfill_all_job.rb`. Lịch chạy: `config/schedule.yml` →
  `zalo_oa_backfill_job`, cron `*/5 * * * *`, queue `scheduled_jobs`.
  `app/services/zalo_oa/backfill_message.rb` biến raw history thành params giống webhook
  (có thêm `backfill: true` để không gửi lại card xin thông tin).
- **Xin thông tin khách**: `app/jobs/zalo_oa/request_info_job.rb` — bật/tắt bằng ENV
  `ZALO_OA_REQUEST_USER_INFO_ENABLED` (mặc định `false`), chỉ gửi **một lần mỗi hội thoại**
  (claim bằng `conversation.additional_attributes['zalo_oa_info_requested_at']`).
- **Nhận thông tin khách chia sẻ**: `app/services/zalo_oa/shared_info_service.rb` — event
  `user_submit_info`, cập nhật `name`, `phone_number` (regex `\A(\+[1-9]\d{1,14}|0\d{8,10})\z`),
  `location`.

### Zalo cá nhân (`Channel::ZaloPersonal`) — riêng của fork

- **Model**: `app/models/channel/zalo_personal.rb`
  - `STATUSES = %w[connected reconnecting expired]`; `EDITABLE_ATTRS = [:proxy_enabled]` (chỉ công
    tắc proxy là sửa được; credentials chỉ thay bằng quét QR mới).
  - `parsed_credentials` → `JSON.parse(credentials).symbolize_keys`.
  - `after_update_commit :reconnect_worker` khi `proxy_enabled` đổi và `status != 'expired'` →
    gọi `Zalo::WorkerClient.connect(self)`.
  - `prepend_mod_with('Channel::ZaloPersonal')` nhưng chưa có override Enterprise.
- **Worker Node**: thư mục `zalo_worker/` (`package.json`: `fastify`, `zca-js@2.1.2`,
  `https-proxy-agent`, `socks-proxy-agent`; Node >= 24). Nguồn: `zalo_worker/src/` —
  `main.ts`, `routes.ts`, `sessionManager.ts`, `qrLogin.ts`, `zcaAdapter.ts`, `classify.ts`,
  `eventForwarder.ts`, `railsClient.ts`, `proxyPool.ts`, `proxyOptions.ts`, `idempotency.ts`,
  `supervisor.ts`, `stickerResolver.ts`, `reactionIcons.ts`.
  Endpoint worker (`zalo_worker/src/routes.ts`): `GET /health`, `POST /qr/start`,
  `POST /sessions/:channelId/connect`, `GET /sessions/:channelId/profile`,
  `DELETE /sessions/:channelId`, `POST /sessions/:channelId/send`.
  Chạy dev qua `Procfile.dev` dòng `zalo: dotenv sh -c 'cd zalo_worker && npm run dev'`.
- **Đăng nhập QR**: `app/controllers/api/v1/accounts/zalo_personal/authorizations_controller.rb`
  - `create` → `Zalo::WorkerClient.start_qr_login(reauth_channel)`, lưu Redis
    `ZALO_PERSONAL_QR_SESSION::<qr_session_id>` TTL `QR_SESSION_TTL = 5.minutes`, trả `qr_image`.
  - `show` → dashboard poll; **kiểm tra `session[:account_id] == Current.account.id`**, nếu khác thì
    trả `expired` (qr_session_id là bearer token cho inbox sẽ sinh ra).
  - `reauth_channel` dùng `Current.account.zalo_personal_channels.find(params[:channel_id])` để
    channel của account khác đọc thành not found.
- **Hoàn tất QR**: `app/services/zalo/qr_completion_service.rb`
  - Nếu có `channel_id` → `reauthenticate`: **raise `Mismatch` nếu `channel.zalo_uid != zalo_uid`**
    (quét sai tài khoản sẽ không ghi đè), sau đó đặt lại `status: 'reconnecting'`.
  - Nếu không → `create_channel_with_inbox` (transaction: tạo channel + inbox).
  - Sau đó `Zalo::WorkerClient.connect(channel)` và ghi kết quả lại vào Redis TTL 5 phút để
    dashboard poll đọc được.
  - `fail!`: `reason == 'expired'` → status `expired`, còn lại → `error` + mã lỗi.
- **Webhook (worker → Rails)**: `app/controllers/webhooks/zalo_personal_controller.rb`
  (`POST /webhooks/zalo_personal`)
  - Xác thực bằng header `X-Zalo-Worker-Secret` so với `ENV.fetch('ZALO_WORKER_SECRET')` —
    **`fetch` không fallback**, thiếu biến môi trường là lỗi deploy và sẽ raise.
  - `QUEUED_EVENTS = %w[message reaction undo]` → đẩy vào `Webhooks::ZaloPersonalEventsJob`.
  - Các event còn lại xử lý inline: `status` → `channel.update_status!`,
    `credentials_refreshed` → ghi lại `credentials`, `qr_completed`/`qr_failed` →
    `Zalo::QrCompletionService`.
- **Job**: `app/jobs/webhooks/zalo_personal_events_job.rb` — lock
  `ZALO_PERSONAL_MESSAGE_CREATE_LOCK::<inbox_id>::<thread_id>` TTL 30s, dispatch sang
  `Zalo::IncomingMessageService` / `Zalo::ReactionService` / `Zalo::UndoService`.
- **Builder/incoming**: `app/services/zalo/incoming_message_service.rb`
  - **`contact_source_id = "#{params[:kind]}:#{thread_id}"`** (ví dụ `user:123`, `group:456`) — tiền
    tố ngăn trùng id giữa người và nhóm, và cho đường gửi biết loại thread mà không cần tra DB.
  - Nhóm = **một contact duy nhất**; tên lấy từ `Zalo::WorkerClient.profile`, fallback
    `GROUP_FALLBACK_NAME = 'Nhóm Zalo'`. Nội dung tin trong nhóm được tiền tố `**<sender_name>:**`
    để biết ai đang nói. `refresh_placeholder_name` sửa lại tên khi lookup sau đó thành công.
  - Tin do chính người vận hành gửi từ app Zalo (`is_self`) → `message_type: :outgoing`, nội dung
    tiền tố `SELF_PREFIX = '📱 từ app Zalo'`.
  - Chống trùng giống Zalo OA (bảng `messages` + Redis `ZALO_PERSONAL_SENT_MESSAGE::…`). Nếu đã có
    thì chỉ `store_quote_source_on_sent_message` (lưu `zalo_quote_source`).
  - Quote: lưu `in_reply_to_external_id`, `in_reply_to`, và **`zalo_quote_source`** (toàn bộ envelope
    mà zca-js cần để quote khi gửi).
- **Reaction / Undo**:
  - `app/services/zalo/reaction_service.rb` — Chatwoot không có reaction, nên biến thành **private
    note** gắn `in_reply_to` tin được thả cảm xúc.
  - `app/services/zalo/undo_service.rb` — chỉ mirror recall của người vận hành: `message&.destroy!`.
    Recall của khách **cố ý giữ lại** để agent biết nội dung đã bị thu hồi.
- **Service gửi**: `app/services/zalo/send_on_zalo_personal_service.rb`
  - `thread_target` tách `contact_inbox.source_id` theo `:` → `{ kind:, thread_id: }`.
  - Attachment: ghi blob ra `tmp/uploads/zalo-personal-<attachment_id>/<filename>` (giữ **đúng tên
    file gốc** vì zca-js từ chối upload không có extension), stream multipart, xoá thư mục sau khi xong.
  - `idempotency_key` = `"<message_id>:text"` hoặc `"<message_id>:<index>"`.
  - Lỗi: `NoSessionError` → `errors.zalo_personal.no_session`; `FileRejectedError` →
    `errors.zalo_personal.file_rejected` (i18n `config/locales/en.yml:173`).
- **Worker client**: `app/services/zalo/worker_client.rb` — base URL
  `ENV.fetch('ZALO_WORKER_URL', 'http://127.0.0.1:3100')`, `TIMEOUT = 30`, secret
  `ENV.fetch('ZALO_WORKER_SECRET')`. Map HTTP code: **409 → `NoSessionError`**, **422 →
  `FileRejectedError`**, còn lại → `Error`.
- **Khôi phục session sau restart worker**:
  `app/controllers/internal/zalo_personal/sessions_controller.rb`
  (`GET /internal/zalo_personal/sessions`) — trả `credentials` + `proxy_enabled` của **mọi**
  `Channel::ZaloPersonal` (`find_each`, không giới hạn account), chỉ bảo vệ bằng shared secret và
  giả định chỉ nghe trên loopback.

### Facebook Page / Messenger

- Model `app/models/channel/facebook_page.rb` — `after_create_commit :subscribe` /
  `before_destroy :unsubscribe` qua `Facebook::Messenger::Subscriptions`, subscribe các field
  `messages message_deliveries message_echoes message_reads standby messaging_handovers`.
  `validates :page_id, uniqueness: { scope: :account_id }`.
- Nhận tin: `mount Facebook::Messenger::Server, at: 'bot'` (`config/routes.rb:740`); handler đăng ký ở
  `config/initializers/facebook_messenger.rb` — `Bot.on :message` → `Webhooks::FacebookEventsJob`,
  `:delivery`/`:read` → `Webhooks::FacebookDeliveryJob`, `:message_echo` →
  `Webhooks::FacebookEventsJob` **trễ 2 giây**.
- Builder: `app/builders/messages/facebook/message_builder.rb` (kế thừa
  `Messages::Messenger::MessageBuilder`) — bỏ qua nếu `channel.reauthorization_required?`, chống
  redeliver bằng `inbox.messages.exists?(source_id: response.identifier)`, bắt
  `Koala::Facebook::AuthenticationError` → `channel.authorization_error!`.
- Gửi: `Facebook::SendOnFacebookService` (`Facebook::Messenger::Bot.deliver`).

### Instagram

- Hai đường: qua `Channel::FacebookPage` (có `instagram_id`) hoặc `Channel::Instagram` (login
  Instagram trực tiếp). `Inbox#instagram?` = `(facebook? || instagram_direct?) && channel.instagram_id.present?`.
- Model `Channel::Instagram`: `access_token` được **ghi đè getter** gọi
  `Instagram::RefreshOauthTokenService`; `subscribe` dùng
  `https://graph.instagram.com/<INSTAGRAM_API_VERSION>` với các field
  `messages message_reactions messaging_seen`.
- Webhook `app/controllers/webhooks/instagram_controller.rb` — verify token nhận **cả** `IG_VERIFY_TOKEN`
  và `INSTAGRAM_VERIFY_TOKEN`; app secret nhận từ channel + `INSTAGRAM_APP_SECRET` + `FB_APP_SECRET`.
  Echo event (`message.is_echo`) → delay 2 giây.
- Builder: `app/builders/messages/instagram/base_message_builder.rb`,
  `app/builders/messages/instagram/message_builder.rb`,
  `app/builders/messages/instagram/messenger/message_builder.rb`.

### Telegram

- Model `app/models/channel/telegram.rb` — `bot_token` mã hoá **deterministic** (để `uniqueness` và
  `find_by` còn chạy). `before_validation :ensure_valid_bot_token` gọi `getMe` và lấy `bot_name`;
  `before_save :setup_telegram_webhook` gọi `deleteWebhook` rồi `setWebhook` tới
  `<FRONTEND_URL>/webhooks/telegram/<bot_token>`.
- Model tự chứa luôn logic gửi (`send_message_on_telegram`, `message_request`), hỗ trợ
  `business_connection_id`, `reply_markup` cho `input_select`, parse_mode HTML.
- Webhook: `Webhooks::TelegramController` → `Webhooks::TelegramEventsJob` →
  `app/services/telegram/incoming_message_service.rb` (contact qua `ContactInboxWithContactBuilder`
  với `source_id = telegram_params_from_id`; avatar lấy từ `getUserProfilePhotos`).

### WhatsApp

- Model `app/models/channel/whatsapp.rb` — `PROVIDERS = %w[default whatsapp_cloud]`
  (`default` = 360dialog). `provider_service` → `Whatsapp::Providers::WhatsappCloudService` hoặc
  `Whatsapp::Providers::Whatsapp360DialogService`. `validate :validate_provider_config` gọi
  **remote** để kiểm chứng credential.
- Tự động setup webhook sau create nếu `provider == 'whatsapp_cloud'` và không phải embedded signup
  (`should_auto_setup_webhooks?`); teardown trước destroy.
- Voice: `voice_enabled?` yêu cầu `provider == 'whatsapp_cloud'` + `provider_config['calling_enabled']`
  + feature `channel_voice`. `enable_voice_calling!` bật ở Meta rồi mới `save!(validate: false)`.
- Webhook: `app/controllers/webhooks/whatsapp_controller.rb` — chặn số trong GlobalConfig
  `INACTIVE_WHATSAPP_NUMBERS`; tìm channel theo payload metadata
  (`Whatsapp::WebhookChannelFinderService`) hoặc theo `params[:phone_number]`.
- Incoming: `app/services/whatsapp/incoming_message_base_service.rb` +
  `incoming_message_whatsapp_cloud_service.rb`, có override Enterprise
  `enterprise/app/services/enterprise/whatsapp/incoming_message_base_service.rb`.
- Sync template/health: `app/jobs/channels/whatsapp/{templates_sync_job,health_sync_job,…}`.

### Twilio (SMS + WhatsApp)

- Model `app/models/channel/twilio_sms.rb` — `enum medium: { sms: 0, whatsapp: 1 }`; phải có
  **một trong hai** `messaging_service_sid` hoặc `phone_number`. `#name` trả `'Twilio SMS'` hoặc
  `'Whatsapp'` tuỳ medium.
- Override Enterprise: `enterprise/app/models/enterprise/channel/twilio_sms.rb` (và
  `.../channel/whatsapp.rb`) — phần voice.
- Webhook: `POST /twilio/callback` + `POST /twilio/delivery_status`; Enterprise thêm
  `twilio/voice/*` khi `ChatwootApp.enterprise?`.

### SMS (Bandwidth), LINE, TikTok, Twitter, Email, Website, API

- **SMS**: `Channel::Sms` gọi trực tiếp Bandwidth (`https://messaging.bandwidth.com/api/v2`) ngay
  trong model (`send_message`, `send_to_bandwidth`). `validate_provider_config` đang **bị comment**.
- **LINE**: `Channel::Line#client` tạo `Line::Bot::Client`; dev mode đặt
  `verify_mode: OpenSSL::SSL::VERIFY_NONE`. Webhook truyền cả `signature` + `post_body` xuống job.
- **TikTok**: webhook verify HMAC SHA256 header `Tiktok-Signature` (`t=`/`s=`) với
  `TIKTOK_APP_SECRET`, **từ chối nếu lệch quá 5 giây**. Echo event = `im_send_msg` → delay 2 giây.
  Contact qua `app/services/tiktok/messaging_helpers.rb`. Token qua `Tiktok::TokenService`.
- **Twitter**: `GET /webhooks/twitter` (CRC) + `POST /webhooks/twitter`, trỏ về
  `api/v1/webhooks#twitter_crc|twitter_events`.
- **Email**: inbound qua ActionMailbox (`app/mailboxes/application_mailbox.rb` route theo pattern
  `reply+<uuid>@domain` hoặc `EmailChannelFinder`), và IMAP pull qua
  `app/jobs/inboxes/fetch_imap_email_inboxes_job.rb` + `fetch_imap_emails_job.rb` →
  `app/mailboxes/imap/imap_mailbox.rb`. Outbound `Email::SendOnEmailService`.
- **Website widget**: không webhook; `Channel::WebWidget#create_contact_inbox` gọi
  `ContactInboxWithContactBuilder` **không truyền `source_id`** → `ContactInboxBuilder` tự sinh
  `SecureRandom.uuid`. Có `has_flags` (attachments, emoji_picker, end_conversation,
  use_inbox_avatar_for_bot, allow_mobile_webview) lưu bitmask ở `feature_flags`.
- **API**: contact tạo qua `app/controllers/public/api/v1/inboxes/contacts_controller.rb`;
  `source_id` cũng là `SecureRandom.uuid`.

## Webhook — đường dẫn nhận tin

Khai báo tập trung ở cuối `config/routes.rb` (dòng ~739–757).

| Đường dẫn | Controller | Kênh |
|---|---|---|
| `POST /bot` (mounted) | `Facebook::Messenger::Server` | Facebook Page / Messenger |
| `GET /webhooks/twitter` | `api/v1/webhooks#twitter_crc` | Twitter (CRC challenge) |
| `POST /webhooks/twitter` | `api/v1/webhooks#twitter_events` | Twitter |
| `POST /webhooks/line/:line_channel_id` | `webhooks/line#process_payload` | LINE |
| `POST /webhooks/telegram/:bot_token` | `webhooks/telegram#process_payload` | Telegram |
| `POST /webhooks/sms/:phone_number` | `webhooks/sms#process_payload` | SMS (Bandwidth) |
| `GET /webhooks/whatsapp/:phone_number` | `webhooks/whatsapp#verify` | WhatsApp (verify token) |
| `POST /webhooks/whatsapp/:phone_number` | `webhooks/whatsapp#process_payload` | WhatsApp |
| `GET /webhooks/instagram` | `webhooks/instagram#verify` | Instagram |
| `POST /webhooks/instagram` | `webhooks/instagram#events` | Instagram (cả qua FB Page) |
| `POST /webhooks/tiktok` | `webhooks/tiktok#events` | TikTok |
| `POST /webhooks/shopify` | `webhooks/shopify#events` | (integration, không phải kênh chat) |
| **`POST /webhooks/zalo_oa`** | `webhooks/zalo_oa#process_payload` | **Zalo OA** (một endpoint dùng chung cho mọi OA, phân biệt bằng `oa_id` trong payload) |
| **`POST /webhooks/zalo_personal`** | `webhooks/zalo_personal#process_payload` | **Zalo cá nhân** (do worker Node gọi vào) |
| `POST /webhooks/pbx/calls` | `webhooks/pbx/calls#process_payload` | Phone / PBX |
| `POST /webhooks/callytics/:token` | `webhooks/callytics/calls#process_payload` | Phone / Callytics |
| `GET /zalo_oa/callback` | `zalo_oa/callbacks#show` | **Zalo OA** (OAuth callback, không phải webhook tin) |
| `POST /twilio/callback` | `twilio/callback#create` | Twilio SMS/WhatsApp |
| `POST /twilio/delivery_status` | `twilio/delivery_status#create` | Twilio |
| `GET /instagram/callback`, `/tiktok/callback`, `/microsoft/callback`, `/google/callback` | `*/callbacks#show` | OAuth callback các kênh tương ứng |
| `GET /internal/zalo_personal/sessions` | `internal/zalo_personal/sessions#index` | **Zalo cá nhân** (worker lấy lại session sau restart) |

`Inbox#callback_webhook_url` (`app/models/inbox.rb`) dựng URL hiển thị trên UI, hiện chỉ cho
`Channel::TwilioSms`, `Channel::Sms`, `Channel::Line`, `Channel::Whatsapp`, `Channel::ZaloOa`.

## Frontend

### Trang thêm kênh

- **Danh sách kênh**: `app/javascript/dashboard/routes/dashboard/settings/inbox/ChannelList.vue` —
  mảng `channelList` theo thứ tự: `website`, `facebook`, `whatsapp`, `sms`, `email`, `api`,
  `telegram`, `line`, **`zalo_oa`**, **`zalo_personal`**, `phone`, `instagram`, rồi `tiktok` (chỉ khi
  `window.chatwootConfig?.tiktokAppId`), cuối cùng luôn thêm `whatsapp_call`.
  **`twitter` và `voice` không có trong danh sách này** dù vẫn tồn tại trong `ChannelFactory`.
- **Router component**: `.../inbox/ChannelFactory.vue` — map key → component:
  `facebook, website, twitter, api, email, sms, whatsapp, whatsapp_call, line, telegram, instagram,
  tiktok, voice, zalo_oa, zalo_personal, phone`.
- **Thẻ kênh + gating**: `app/javascript/dashboard/components/widgets/ChannelItem.vue` —
  `isActive` kiểm tra feature flag cho `website`/`facebook`/`email`/`instagram`/`tiktok`/`voice`,
  còn `zalo_oa`, `zalo_personal`, `phone`, `whatsapp`, `sms`, `telegram`, `line`, `api` chỉ cần nằm
  trong whitelist cuối hàm (**không có feature flag riêng**). `isBeta` cho `tiktok`, `voice`,
  `whatsapp_call`; `isComingSoon` chỉ cho `voice`.
- **Form từng kênh**: `.../inbox/channels/*.vue` — gồm `ZaloOa.vue` (nhập App ID / App Secret /
  OA Secret Key rồi redirect sang Zalo) và `ZaloPersonal.vue` (quét QR qua
  `useZaloQrLogin`).

### Cấu hình kênh (sau khi tạo)

- `.../inbox/Settings.vue` nhúng `ZaloSessionStatus` và `ZaloProxyToggle` khi
  `isAZaloPersonalChannel` (dòng ~906–915).
- `app/javascript/dashboard/components-next/Settings/ZaloSessionStatus.vue` — đèn trạng thái
  (`connected` xanh teal, `reconnecting` vàng amber, `expired` đỏ ruby), nút "Scan QR again" điều
  hướng tới `settings_inboxes_page_channel` với `sub_page: 'zalo_personal'` + `query.channel_id`.
- `app/javascript/dashboard/components-next/Settings/ZaloProxyToggle.vue` — toggle
  `inbox.zalo_proxy_enabled`, dispatch `inboxes/updateInbox` với `channel: { proxy_enabled }`.
- `app/javascript/dashboard/components/widgets/conversation/ZaloSessionBanner.vue` — banner trong
  màn hội thoại khi `inbox.zaloSessionStatus === 'expired'`, mở dialog quét QR ngay tại chỗ
  (dùng chung `useZaloQrLogin`).
- Composable: `app/javascript/dashboard/composables/useZaloQrLogin.js` — `POLL_INTERVAL = 2000`ms,
  poll `GET /zalo_personal/authorizations/:qr_session_id` tới khi `success` / `expired` / `error`.
- API client: `app/javascript/dashboard/api/channel/zaloOaChannel.js`,
  `app/javascript/dashboard/api/channel/zaloPersonalChannel.js`.
- Trường được serialize ra FE: `app/views/api/v1/models/_inbox.json.jbuilder` (dòng 177–182) —
  `zalo_session_status`, `zalo_display_name`, `zalo_status_updated_at`, `zalo_proxy_enabled`;
  chỉ xuất khi `resource.channel_type == 'Channel::ZaloPersonal'`.

### Icon kênh

`app/javascript/dashboard/components-next/icon/provider.js` có **hai** map:

- `channelTypeIconMap` (icon đơn sắc) — `Channel::ZaloOa` và `Channel::ZaloPersonal` **dùng chung**
  `i-woot-zalo`.
- `channelTypeBrandIconMap` (icon màu) — cả hai Zalo dùng `i-woot-zalo-color`.
- Xử lý đặc biệt: Email theo `provider` (`microsoft` → Outlook, `google` → Gmail);
  `Channel::TwilioSms` với `medium === 'whatsapp'` đổi sang icon WhatsApp;
  inbox bật voice dùng `getInboxVoiceIcon`.
- Fallback: `channelIcon` trả `i-ri-global-fill`, `channelBrandIcon` trả `null`.

`app/javascript/dashboard/helper/inbox.js` có `INBOX_TYPES` (hằng `Channel::*`) và map icon thứ ba
(`i-ri-*` / `i-woot-*`) — **ba nguồn icon song song**, xem phần phụ thuộc chéo.

## Điểm vào trên giao diện

| Điểm vào | File | Ghi chú |
|---|---|---|
| Settings → Inboxes → New inbox (grid chọn kênh) | `.../inbox/ChannelList.vue` | route `settings_inboxes_page_channel` với `sub_page = <key>` |
| Form kết nối từng kênh | `.../inbox/channels/<Channel>.vue` qua `ChannelFactory.vue` | |
| Settings → Inboxes → <inbox> (tab cấu hình) | `.../inbox/Settings.vue` | nơi nhúng `ZaloSessionStatus` / `ZaloProxyToggle` |
| Onboarding chọn kênh | `.../onboarding/inbox-setup/{InboxChannelsDialog,InboxChannelForm,ChannelRow,InboxChannelsFooter}.vue` | luồng thiết lập lần đầu |
| Banner trong màn hội thoại | `.../conversation/ZaloSessionBanner.vue` | khi session Zalo cá nhân hết hạn |
| Sidebar / nhãn kênh | `components-next/sidebar/ChannelLeaf.vue`, `components-next/icon/ChannelIcon.vue` | |
| Dashboard tổng quan (phân rã theo kênh) | `.../home/components/cards/ChannelBreakdownCard.vue`, `.../home/components/tabs/ChannelsTab.vue`, `.../home/helpers.js` (`CHANNEL_KEYS`) | nhãn i18n `HOME.DASHBOARD.CHANNELS.*` |
| Panel contact (danh tính theo kênh) | `components-next/Contacts/ContactsSidebar/ContactChannels.vue`, `.../conversation/CrmInfoPanel.vue` | |

## Luồng dữ liệu chính

### Nhận tin (ví dụ Zalo OA)

```
Zalo gửi POST /webhooks/zalo_oa
  → Webhooks::ZaloOaController#process_payload
      • find_channel: Channel::ZaloOa.find_by(oa_id: …) từ payload
      • valid_signature?: SHA256(app_id + raw_body + timestamp + oa_secret_key) == X-ZEvent-Signature
      • echo (event_name bắt đầu "oa_") → enqueue trễ 2s; còn lại → enqueue ngay
  → Webhooks::ZaloOaEventsJob (queue :low, MutexApplicationJob)
      • event "user_submit_info" → ZaloOa::SharedInfoService (cập nhật contact) → kết thúc
      • với_lock ZALO_OA_MESSAGE_CREATE_LOCK::<inbox_id>::<user_id> (TTL 30s)
  → ZaloOa::IncomingMessageService#perform
      1. return nếu user_id/source_id rỗng, hoặc already_imported? (messages.source_id hoặc Redis sent key)
      2. set_contact      → ContactInboxWithContactBuilder (source_id = user_id)
                          → Avatar::AvatarFromUrlJob nếu có avatar
      3. set_conversation → contact_inbox.conversations (lock_to_single_conversation ? last : chưa resolved)
                          → Conversation.create! nếu chưa có
      4. ConsultationWindow.record_inbound (nếu không phải event "oa_")
      5. build_message    → messages.build(message_type, sender, content, source_id, content_attributes)
      6. attach_media     → Down.download(max_size 40MB) → attachments.new
                          → lỗi: ghi chú MISSING_ATTACHMENT_NOTE, giữ nguyên tin
      7. @message.save!
      8. ZaloOa::RequestInfoJob (nếu inbound và không phải backfill)
```

### Nhận tin (Zalo cá nhân — khác ở chỗ worker đứng giữa)

```
Zalo (zca-js session trong zalo_worker) → eventForwarder.ts → POST /webhooks/zalo_personal
  → Webhooks::ZaloPersonalController (auth bằng X-Zalo-Worker-Secret)
      • message/reaction/undo → Webhooks::ZaloPersonalEventsJob
      • status / credentials_refreshed / qr_completed / qr_failed → xử lý inline
  → Webhooks::ZaloPersonalEventsJob (lock theo inbox_id + thread_id)
  → Zalo::IncomingMessageService  (source_id contact = "<kind>:<thread_id>")
    hoặc Zalo::ReactionService (→ private note)
    hoặc Zalo::UndoService (→ destroy! tin của chính mình)
```

Worker có cơ chế retry riêng ở `zalo_worker/src/eventForwarder.ts`:
`RETRY_BASE_MS = 1_000`, `RETRY_MAX_DELAY_MS = 30_000`, `RETRY_WINDOW_MS = 15 phút`,
`MAX_PENDING_EVENTS = 5_000` — chịu được một lần restart/deploy của Rails.

### Gửi tin (chung cho mọi kênh)

```
Agent gửi tin → Messages::MessageBuilder → message.save!
  → Message#execute_after_create_commit_callbacks → send_reply
      • không có attachment → SendReplyJob.perform_later(id)
      • có attachment       → SendReplyJob.set(wait: 2.seconds)   (chờ ActiveStorage attach)
  → SendReplyJob (queue :high)
      • Channel::FacebookPage → tách riêng: conversation.additional_attributes['type'] ==
        'instagram_direct_message' ? Instagram::Messenger::SendOnInstagramService
                                   : Facebook::SendOnFacebookService
      • còn lại → CHANNEL_SERVICES[channel_class_name]; không có trong map thì return (im lặng)
  → Base::SendOnChannelService#perform
      1. validate_target_channel  → raise 'Invalid channel service was called' nếu lệch class
      2. return unless outgoing_message? (outgoing hoặc template)
      3. return if invalid_message?  → private, hoặc source_id đã có (chống loop echo),
                                       hoặc content_type ∈ [voice_call, phone_call]
      4. perform_reply (từng kênh tự cài)
  → retry_on StandardError, wait: :polynomially_longer, attempts: 5
      • hết lượt → mark_failed: nếu chưa delivered? thì status = :failed,
        external_error = I18n.t('errors.send_reply.failed')
      • delivered? xét content_attributes['external_message_ids'].size >= attachments.size
        (cho Zalo OA / Zalo cá nhân), ngược lại chỉ xét source_id.present?
```

Nội dung gửi ra đi qua `message.outgoing_content` → `MessageContentPresenter#outgoing_content`
→ `Messages::MarkdownRendererService.new(content, channel_type, channel).render`.

## Cách liên hệ được tạo và khớp

`app/builders/contact_inbox_with_contact_builder.rb` là điểm vào chung. Các kênh gọi nó:
`app/services/{line,sms,telegram,zalo,zalo_oa}/incoming_message_service.rb`,
`app/services/tiktok/messaging_helpers.rb`, `app/services/phone/pbx_call_event_processor.rb`,
`app/models/channel/{facebook_page,instagram,twitter_profile,web_widget}.rb`,
`app/builders/messages/facebook/message_builder.rb`, `app/mailboxes/mailbox_helper.rb`,
`app/controllers/public/api/v1/inboxes/contacts_controller.rb`,
`app/services/contact_inbox_source_id_resolver.rb`.

**Hành vi early-return theo `source_id`** — quan trọng nhất:

```ruby
def find_or_create_contact_and_contact_inbox
  @contact_inbox = inbox.contact_inboxes.find_by(source_id: source_id) if source_id.present?
  return @contact_inbox if @contact_inbox
  ...
end
```

Nếu `(inbox, source_id)` đã tồn tại thì builder **trả về ngay** và **không cập nhật gì** trên
contact: tên, email, phone, `additional_attributes`, `custom_attributes` trong
`contact_attributes` đều bị bỏ qua. Hệ quả: khách Zalo đổi tên hiển thị sẽ **không** tự cập nhật
trong Tekomi — các service phải tự sửa (xem `Zalo::IncomingMessageService#refresh_placeholder_name`,
chỉ sửa khi tên hiện tại đang là placeholder `Nhóm Zalo` hoặc chính `thread_id`).

**Thứ tự khớp contact khi chưa có contact_inbox** (`find_contact`):

1. `identifier` → `account.contacts.find_by(identifier:)`
2. `email` → `account.contacts.from_email(email)`
3. `phone_number` → `Contacts::InboundPhoneResolver.new(account, phone_number).find_contact`
4. **chỉ với `Channel::Instagram`**: `find_contact_by_instagram_source_id(source_id)` — tìm
   `ContactInbox` có cùng `source_id` trên inbox `Channel::FacebookPage` của cùng account, để
   dùng lại contact cũ nhưng vẫn tạo `contact_inbox` mới.

Nếu không khớp → `create_contact`, tên fallback `Haikunator.haikunate(1000)`, truncate về
`ApplicationRecord::MAX_STRING_COLUMN_LENGTH`.

Chống race: toàn bộ bọc trong `ActiveRecord::Base.transaction(requires_new: true)` và
`rescue ActiveRecord::RecordNotUnique` → thử lại một lần.

**Sinh `source_id` khi không được truyền** (`app/builders/contact_inbox_builder.rb#generate_source_id`):

| channel_type | source_id |
|---|---|
| `Channel::TwilioSms` | `phone_number` (medium sms) hoặc `whatsapp:<phone_number>` |
| `Channel::Whatsapp` | `phone_number` bỏ dấu `+` |
| `Channel::Email` | `contact.email` |
| `Channel::Sms` | `contact.phone_number` |
| `Channel::Api`, `Channel::WebWidget` | `SecureRandom.uuid` |
| **khác** | **`raise "Unsupported operation for this channel: …"`** |

→ Zalo OA / Zalo cá nhân / Telegram / LINE / TikTok **bắt buộc** phải truyền `source_id`, nếu
không sẽ raise.

`update_old_contact_inbox` (khi `RecordNotUnique` vì source_id trùng mà contact khác) chỉ được phép
chạy cho `email? || sms? || twilio? || whatsapp?` (`allowed_channels?`); các kênh khác re-raise.

**Quy ước `source_id` theo kênh (đã kiểm chứng)**:

| Kênh | source_id của ContactInbox |
|---|---|
| Zalo OA | `user_id` của khách trên Zalo (chuỗi số) |
| Zalo cá nhân | **`"<kind>:<thread_id>"`** — `user:123` hoặc `group:456` |
| Telegram | `telegram_params_from_id` |
| LINE | `userId` từ payload |
| Instagram / Facebook | `sender_id` / `recipient_id` (tuỳ echo) |
| Web widget / API | UUID sinh ngẫu nhiên |

## Feature flag & cấu hình

### Feature flag (`config/features.yml`)

Chỉ các flag sau liên quan kênh: `channel_email`, `channel_facebook`, `channel_website`,
`channel_instagram`, `channel_voice`, `channel_tiktok`. **Không có `channel_zalo_oa` /
`channel_zalo_personal` / `channel_telegram` / `channel_line` / `channel_whatsapp`** — các kênh này
luôn hiển thị (xem whitelist cuối `ChannelItem.vue`).

### Biến môi trường (`.env.example`)

| Biến | Mặc định | Dùng ở |
|---|---|---|
| `ZALO_WORKER_URL` | `http://127.0.0.1:3100` | `Zalo::WorkerClient.base_url` |
| `ZALO_WORKER_PORT` | `3100` | worker Node |
| `ZALO_WORKER_SECRET` | *(bắt buộc, `ENV.fetch` không fallback)* | xác thực 2 chiều Rails ↔ worker |
| `ZALO_PROXY_POOL_FILE` | — | pool proxy (Webshare `host:port:user:pass` hoặc URL) |
| `ZALO_PROXY_POOL_HOST_PATH` | — | mount read-only vào worker ở production |
| `RAILS_BASE_URL` | `http://127.0.0.1:3000` | worker gọi về Rails |
| `ZALO_OA_REQUEST_USER_INFO_ENABLED` | `false` | `ZaloOa::RequestInfoJob#enabled?` |
| `ZALO_OA_REQUEST_USER_INFO_TITLE` | `Share your contact information` | nội dung card |
| `ZALO_OA_REQUEST_USER_INFO_SUBTITLE` | `Help us serve you better` | nội dung card |
| `ZALO_OA_REQUEST_USER_INFO_IMAGE_URL` | — | **nếu rỗng thì job không gửi gì** |
| `FRONTEND_URL` | — | dựng webhook URL cho Telegram, redirect_uri Zalo OA, `callback_webhook_url` |
| `ENABLE_INBOX_EVENTS` | — | gate dispatch `INBOX_CREATED/UPDATED` |

GlobalConfig liên quan kênh (`GlobalConfigService.load`): `INSTAGRAM_API_VERSION` (mặc định `v22.0`),
`IG_VERIFY_TOKEN`, `INSTAGRAM_VERIFY_TOKEN`, `INSTAGRAM_APP_SECRET`, `FB_APP_SECRET`,
`WHATSAPP_APP_SECRET`, `TIKTOK_APP_SECRET`, `INACTIVE_WHATSAPP_NUMBERS`.
Config phía client: `window.chatwootConfig.{fbAppId, instagramAppId, tiktokAppId}`.

### Redis key (`lib/redis/redis_keys.rb`)

| Hằng | Pattern |
|---|---|
| `ZALO_OA_REFRESH_TOKEN_MUTEX` | `ZALO_OA_REFRESH_TOKEN_LOCK::%<channel_id>s` |
| `ZALO_OA_MESSAGE_MUTEX` | `ZALO_OA_MESSAGE_CREATE_LOCK::%<inbox_id>s::%<user_id>s` |
| `ZALO_OA_SENT_MESSAGE` | `ZALO_OA_SENT_MESSAGE::%<inbox_id>s::%<zalo_message_id>s` |
| `ZALO_PERSONAL_MESSAGE_MUTEX` | `ZALO_PERSONAL_MESSAGE_CREATE_LOCK::%<inbox_id>s::%<thread_id>s` |
| `ZALO_PERSONAL_SENT_MESSAGE` | `ZALO_PERSONAL_SENT_MESSAGE::%<inbox_id>s::%<zalo_message_id>s` |
| `ZALO_PERSONAL_QR_SESSION` | `ZALO_PERSONAL_QR_SESSION::%<qr_session_id>s` |

Ngoài ra `zalo_oa:pending:<state>` (string nối tay, **không** qua `redis_keys.rb`) dùng cho OAuth
state của Zalo OA — xem phần cạm bẫy.

### Lịch chạy (`config/schedule.yml`)

- `zalo_oa_backfill_job`: cron `*/5 * * * *`, class `ZaloOa::BackfillAllJob`, queue `scheduled_jobs`.

## i18n

- **Backend** (`config/locales/en.yml`):
  - `errors.zalo_personal.no_session`, `errors.zalo_personal.file_rejected` (dòng ~173–175).
  - `errors.send_reply.failed` — dùng chung cho mọi kênh khi `SendReplyJob` hết retry.
  - Không có key backend riêng cho Zalo OA; `ZaloOa::ConsultationWindow` và
    `ZaloOa::IncomingMessageService` / `SendOnZaloOaService` dùng **chuỗi hard-code** (hằng
    `OUT_OF_WINDOW_NOTE`, `LIMIT_REACHED_NOTE` tiếng Anh; `MISSING_ATTACHMENT_NOTE` và text fallback
    attachment tiếng Việt).
- **Frontend** (`app/javascript/dashboard/i18n/locale/en/`):
  - `inboxMgmt.json`:
    - `INBOX_MGMT.ADD.AUTH.CHANNEL.*` — có `ZALO_OA`, `ZALO_PERSONAL` cùng 13 kênh khác.
    - `INBOX_MGMT.ADD.ZALO_OA_CHANNEL.*` (dòng ~466) — `APP_ID`, `APP_SECRET`, `OA_SECRET_KEY`,
      `SUBMIT_BUTTON`, `API.ERROR_MESSAGE`, `API_CALLBACK`.
    - `INBOX_MGMT.ADD.ZALO_PERSONAL_CHANNEL.*` (dòng ~491) — `QR.{INTRO,INSTRUCTIONS,ALT,EXPIRED,REGENERATE}`,
      `ERROR.{ACCOUNT_MISMATCH,DECLINED,GENERIC}`.
    - `INBOX_MGMT.ZALO_PERSONAL_SESSION.*` (dòng ~785) — `STATUS.{CONNECTED,RECONNECTING,EXPIRED}`,
      `SINCE`, `RESCAN`, `EXPIRED_HINT`.
    - `INBOX_MGMT.ZALO_PERSONAL_PROXY.*` (dòng ~796) — `ENABLED`, `DISABLED`, `HINT`, `SAVED`, `ERROR`.
    - Nhãn loại inbox (dòng ~1529) — `ZALO_OA: "Zalo OA"`, `ZALO_PERSONAL: "Zalo Personal"`.
  - `conversation.json`: `CONVERSATION.ZALO_SESSION_EXPIRED.{MESSAGE,MESSAGE_AGENT,RECONNECTED}` (dòng ~478).
  - `home.json`: `HOME.DASHBOARD.CHANNELS.{ZALO_OA,ZALO_PERSONAL}` (dòng ~194).
- Theo CLAUDE.md: chỉ sửa `en.yml` và `en.json`; các ngôn ngữ khác do Crowdin.

## ⚠️ Phụ thuộc chéo

Đây là phần dễ gây lỗi nhất khi thêm/sửa kênh. Thêm một kênh mới **phải** cập nhật đồng thời:

1. **`SendReplyJob::CHANNEL_SERVICES`** (`app/jobs/send_reply_job.rb:12`) — nếu quên, tin đi
   **im lặng không gửi** (`return unless service_class`, không log, không `failed`). Không có test
   nào ràng buộc map này với danh sách `Channel::*`.
2. **`SendReplyJob#delivered?`** — dựa vào `content_attributes['external_message_ids']`. Chỉ
   Zalo OA và Zalo cá nhân ghi field này. Kênh mới chia nhiều lần gửi mà không ghi
   `external_message_ids` sẽ bị `mark_failed` sai (hoặc được coi là delivered sai).
3. **`Base::SendOnChannelService#invalid_message?`** — chặn bằng `message.source_id.present?`.
   Kênh nào ghi `source_id` **trước khi** gửi xong hết attachment phải ghi đè
   `outgoing_message_originated_from_channel?` như hai service Zalo đã làm, nếu không retry sẽ bị
   bỏ qua và attachment còn lại mất.
4. **`ContactInboxBuilder#generate_source_id`** — kênh mới không nằm trong `case` sẽ `raise` nếu có
   bất kỳ đường nào gọi builder mà không truyền `source_id`.
5. **`ContactInboxBuilder#allowed_channels?`** — `email/sms/twilio/whatsapp`. Zalo và các kênh khác
   gặp `RecordNotUnique` do source_id trùng khác contact sẽ **re-raise** (đẩy lên Sidekiq retry).
6. **Ba map icon song song** — `provider.js:channelTypeIconMap`,
   `provider.js:channelTypeBrandIconMap`, và `helper/inbox.js` (hai map nữa, `i-ri-*` và `i-woot-*`).
   Trong `helper/inbox.js` map `i-ri-*` **thiếu** `ZALO_OA`/`ZALO_PERSONAL` còn map `i-woot-*` có —
   kênh mới dễ bị fallback `i-ri-global-fill` ở một trong các chỗ.
7. **`Inbox` helper predicates** (`app/models/inbox.rb`) — có `sms?`, `facebook?`, `instagram?`,
   `tiktok?`, `web_widget?`, `api?`, `phone?`, `email?`, `twilio?`, `twitter?`, `telegram?`,
   `whatsapp?` nhưng **không có `zalo_oa?` / `zalo_personal?`**. Mọi chỗ cần biết là Zalo đều so
   sánh chuỗi `resource.channel_type == 'Channel::ZaloPersonal'` (ví dụ `_inbox.json.jbuilder:177`).
8. **`Inbox#callback_webhook_url`** — `case channel_type` không có `else`; kênh thiếu nhánh trả `nil`
   và UI chỉ không hiện URL (im lặng).
9. **`Account` associations** (`app/models/account.rb:113-114`) — `zalo_oa_channels`,
   `zalo_personal_channels`. Thiếu association là `Zalo::QrCompletionService` và
   `ZaloOa::CallbacksController` sẽ nổ.
10. **`Api::V1::Accounts::InboxesController`** có **hai** danh sách phải khớp nhau:
    `allowed_channel_types` (`%w[web_widget api email line telegram whatsapp sms phone]`) và
    `channel_type_from_params` (hash 8 phần tử tương ứng). Zalo cố ý **không** nằm trong hai danh
    sách này (channel tạo qua OAuth/QR), nhưng `update_channel` vẫn dùng
    `get_channel_attributes(@inbox.channel_type)` → `EDITABLE_ATTRS`, nên **toggle proxy của Zalo cá
    nhân phụ thuộc vào `Channel::ZaloPersonal::EDITABLE_ATTRS = [:proxy_enabled]`**. Xoá hằng đó là
    hỏng toggle proxy.
11. **`Messages::MarkdownRendererService::CHANNEL_RENDERERS`** — **không có** `Channel::ZaloOa`,
    `Channel::ZaloPersonal`, `Channel::Tiktok`, `Channel::Api`, `Channel::Phone`. Những kênh này
    nhận **markdown thô** (`render` trả `@content` nguyên vẹn). Agent gõ `**bold**` sẽ ra
    `**bold**` trên Zalo.
12. **`ChannelList.vue` ⟷ `ChannelFactory.vue` ⟷ `ChannelItem.vue`** — ba file phải khớp key.
    Hiện `twitter` và `voice` có trong `ChannelFactory` nhưng không có trong `ChannelList`, nên
    chỉ vào được bằng URL trực tiếp.
13. **`home/helpers.js:CHANNEL_KEYS`** ⟷ `home.json:HOME.DASHBOARD.CHANNELS.*` — thiếu thì nhãn
    rơi về `OTHER`.
14. **Zalo cá nhân phụ thuộc process ngoài Rails**: `zalo_worker/` phải chạy. Nếu worker chết:
    nhận tin dừng hẳn (không có đường dự phòng), gửi tin báo lỗi `NoSessionError`. Khởi động lại
    worker cần `GET /internal/zalo_personal/sessions` hoạt động. `ZALO_WORKER_SECRET` dùng ở **ba**
    chỗ (`Zalo::WorkerClient`, `Webhooks::ZaloPersonalController`,
    `Internal::ZaloPersonal::SessionsController`) và cả trong worker — lệch là mất kênh.
15. **Zalo OA phụ thuộc `oa_secret_key`** cho chữ ký webhook, khác `app_secret` (dùng cho OAuth).
    Nhầm hai giá trị → webhook luôn trả `head :ok` nhưng **bỏ hết tin** (không log, không lỗi).
16. **`Channelable` → `prepend_mod_with`** — `Channel::ZaloOa`, `Channel::ZaloPersonal`,
    `Channel::Whatsapp`, `Channel::TwilioSms`, `Channel::Phone` đều gọi `prepend_mod_with`.
    Hiện chỉ `enterprise/app/models/enterprise/channel/{twilio_sms,whatsapp}.rb` tồn tại; hook Zalo
    là chỗ cắm sẵn chưa dùng.
17. **Enterprise override kênh**: `enterprise/app/models/enterprise/channelable.rb`,
    `enterprise/app/models/enterprise/inbox.rb` (`ensure_valid_max_assignment_limit`),
    `enterprise/app/services/enterprise/whatsapp/incoming_message_base_service.rb`. Sửa core phải
    đối chiếu các file này (xem CLAUDE.md).
18. **`ZaloOa::ConsultationWindow` ghi vào `conversation.additional_attributes`** (keys
    `zalo_oa_last_inbound_at`, `zalo_oa_cs_sent_count`) và `ZaloOa::RequestInfoJob` ghi
    `zalo_oa_info_requested_at` — cùng một jsonb với `chat_id`/`business_connection_id` của Telegram
    và `type` của Instagram. Mọi code ghi đè cả `additional_attributes` thay vì merge sẽ phá các key này.
19. **Delay 2 giây cho echo** xuất hiện ở **bốn** chỗ độc lập: `Webhooks::ZaloOaController`,
    `Webhooks::TiktokController`, `Webhooks::InstagramController`,
    `config/initializers/facebook_messenger.rb` (`:message_echo`), cộng thêm
    `Message#send_reply` dùng `wait: 2.seconds` khi có attachment. Không có hằng dùng chung.

## Cạm bẫy đã biết

- **Webhook Zalo OA im lặng khi không nhận ra OA**: `return head :ok if channel.blank?` và
  `return head :ok unless valid_signature?(channel)` — Zalo luôn thấy 200, không có log, không có
  metric. Sai `oa_secret_key` hoặc sai `oa_id` biểu hiện giống nhau: "không nhận được tin".
- **Một endpoint `POST /webhooks/zalo_oa` dùng chung cho mọi OA**: phân biệt hoàn toàn bằng
  payload. `Channel::ZaloOa` có unique index trên `oa_id` toàn hệ thống (không scope theo account),
  nên **một OA chỉ kết nối được vào một account duy nhất** trong cả instance. Tương tự với
  `channel_zalo_personal.zalo_uid`.
- **`zalo_oa:pending:<state>` không nằm trong `redis_keys.rb`**: key được nối chuỗi tay ở **hai**
  file (`Api::V1::Accounts::ZaloOa::AuthorizationsController#cache_key` và
  `ZaloOa::CallbacksController#cache_key`). Đổi một bên là hỏng OAuth. Khác hẳn với QR session của
  Zalo cá nhân (đã có hằng `ZALO_PERSONAL_QR_SESSION`).
- **`ZaloOa::CallbacksController` không kiểm tra account của người đang đăng nhập**: chỉ dựa vào
  `state` trong Redis (TTL 15 phút) và `Account.find(pending[:account_id])`. Không có bước xác thực
  user ở callback (controller kế thừa `ApplicationController`, không `authenticate_user!`). Chưa
  xác minh có before_action nào ở `ApplicationController` chặn hay không.
- **Session Zalo cá nhân hết hạn âm thầm**: Zalo chỉ cho **một web session mỗi tài khoản**; đăng
  nhập Zalo Web ở nơi khác là session này chết, kênh ngừng cả hai chiều. Vì thế mới có
  `ZaloSessionStatus`, `ZaloSessionBanner` và thông điệp lỗi dài trong `errors.zalo_personal.no_session`.
- **Quét QR lại sai tài khoản**: `Zalo::QrCompletionService#reauthenticate` raise `Mismatch` khi
  `zalo_uid` khác → UI hiện `ERROR.ACCOUNT_MISMATCH`. Đây là bảo vệ cố ý, không phải bug.
- **Nhóm Zalo = một contact**: mọi thành viên trong nhóm đổ vào một `Contact` duy nhất
  (`source_id = "group:<thread_id>"`), người nói được ghi vào nội dung tin dạng `**Tên:**`. Thống kê
  theo contact với inbox Zalo nhóm vì vậy không phản ánh số người thật.
- **Tên contact không tự cập nhật**: do early-return theo `source_id` trong
  `ContactInboxWithContactBuilder`. `Zalo::IncomingMessageService#refresh_placeholder_name` chỉ sửa
  khi tên đang là `Nhóm Zalo` hoặc `thread_id`; `ZaloOa::IncomingMessageService` không sửa gì.
- **`fetch_profile` của Zalo OA gọi API mỗi tin mới**: `@fetch_profile ||=` chỉ memo trong một lần
  `perform`, nên mỗi message của khách mới đều gọi `/v3.0/oa/user/detail` (lỗi chỉ `Rails.logger.warn`).
- **Cửa sổ tư vấn Zalo OA chỉ cảnh báo, không chặn**: `ConsultationWindow.record_outbound` tạo
  private note nhưng vẫn gửi. Việc chặn thật do Zalo trả `WINDOW_CODES` → `WindowError` →
  `message.status = :failed`.
- **Chuỗi cảnh báo cửa sổ tư vấn là hard-code tiếng Anh** trong
  `ZaloOa::ConsultationWindow::{OUT_OF_WINDOW_NOTE,LIMIT_REACHED_NOTE}` (và một chuỗi nội suy
  `"…near its 8-message limit (n/8)."`), trong khi fallback attachment lại hard-code tiếng Việt.
  Không qua i18n.
- **`Internal::ZaloPersonal::SessionsController#index` trả credentials của mọi account**:
  `Channel::ZaloPersonal.find_each`, không phân trang, không giới hạn — chỉ bảo vệ bằng shared
  secret + giả định loopback. Nếu endpoint này lọt ra ngoài là rò toàn bộ session Zalo.
- **`proxy_enabled` chỉ có hiệu lực sau khi worker reconnect**: `after_update_commit` gọi
  `Zalo::WorkerClient.connect`, và **không chạy khi `status == 'expired'`** (không có gì để reconnect).
- **`ZaloOa::RequestInfoJob` im lặng nếu thiếu `ZALO_OA_REQUEST_USER_INFO_IMAGE_URL`**:
  `return unless enabled? && image_url.present?`. Bật flag mà quên URL ảnh thì không có gì xảy ra.
- **Backfill dựa trên watermark toàn channel**: `backfill_watermark_ms` là **một** mốc cho cả
  channel, giới hạn `MAX_CONVERSATIONS = 50` và `MAX_MESSAGES_PER_CONVERSATION = 100`. Downtime dài
  với nhiều hội thoại sẽ mất tin ngoài giới hạn đó, và watermark nhảy lên `max_time_ms` nên không
  quay lại lấy.
- **5 route trùng path trong `config/routes.rb` (dòng 25–29)**: cùng
  `/app/accounts/:account_id/settings/inboxes/new/:inbox_id/agents` với 5 tên khác nhau
  (`app_twitter_inbox_agents`, `app_email_inbox_agents`, `app_instagram_inbox_agents`,
  `app_tiktok_inbox_agents`, `app_zalo_oa_inbox_agents`). Chỉ là alias url_helper cho cùng một SPA
  route — không phải bug, nhưng dễ tưởng là lỗi.
- **`Channel::Telegram` ghi webhook ra Telegram trong `before_save`**: một lần `save` sẽ gọi
  `deleteWebhook` + `setWebhook` qua mạng; `Channel::Whatsapp#validate_provider_config` cũng gọi
  remote **trong validation**. Cả hai làm `save` phụ thuộc mạng.
- **`Channel::Sms#validate_provider_config` đang bị comment** (`# before_save :validate_provider_config`)
  → credential Bandwidth sai vẫn tạo được inbox, chỉ phát hiện khi gửi tin.
- **`proxy_enabled` có trong annotation `Channel::ZaloPersonal` nhưng không thấy trong
  `db/schema.rb`** — chưa xác minh; cần kiểm tra lại migration/schema trước khi kết luận.
