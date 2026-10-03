# Kế hoạch triển khai: Zalo cá nhân & Zalo nhóm

Ngày: 2026-09-04 · Nhánh: `feature/chat-zalo` · Trạng thái: **đang thử nghiệm**

## 1. Mục tiêu

Đưa tính năng chat Zalo cá nhân và Zalo nhóm từ sidecar `zca-bridge` vào thẳng Chatwoot core.

**Động lực: gọn vận hành** — hiện phải chạy thêm một service Node và một PostgreSQL riêng. Sau khi làm xong chỉ còn một codebase, một database, một lần deploy.

Không phải vì thương hiệu, không phải vì giới hạn API. Đây là điểm quan trọng khi cân nhắc đánh đổi: phương án nào chỉ gộp được deployment mà không gộp được kiến trúc thì không đạt mục tiêu.

## 2. Ràng buộc cốt lõi

Zalo cá nhân dùng `zca-js` — thư viện **không chính thức, chỉ có bản Node.js**, hoạt động bằng cách giả lập một phiên Zalo Web đã đăng nhập.

Hệ quả không thể tránh:

- Phải có **một tiến trình Node chạy nền**, Rails không thay thế được
- Phải **giữ kết nối WebSocket thường trực 24/7** cho từng tài khoản
- Đăng nhập bằng **quét QR**, phiên hết hạn theo sự kiện chứ không theo lịch
- **Mỗi tài khoản chỉ được sống ở đúng một tiến trình** — không nhân bản ngang được

Điểm thuận lợi: image production của Chatwoot đã có sẵn Node 24 ở stage runtime (`docker/Dockerfile`), đúng mức `zca-js` yêu cầu.

## 3. Phương án đã chọn

**Node giữ phiên, Rails sở hữu toàn bộ dữ liệu.**

Zalo cá nhân là channel gốc của Chatwoot, đúng khuôn `Channel::ZaloOa` đang chạy. Node worker chỉ làm đúng một việc: giữ phiên `zca-js`, xử lý QR, tự kết nối lại. Node **không có database**.

```
Zalo ──WebSocket──▶ Node worker ──HTTP nội bộ──▶ Rails ──▶ DB Chatwoot
                    (chỉ giữ phiên)              (Sidekiq, model, service)
```

Hai phương án bị loại:

- **Bê nguyên bridge vào repo, đổi DB** — vẫn là kênh API, vẫn giữ mapping/queue riêng, hai nguồn sự thật. Gộp được deploy nhưng không gộp được kiến trúc.
- **Lai (Rails giữ config, Node giữ handler)** — quyền sở hữu dữ liệu nhập nhằng, dễ thành nợ kỹ thuật.

Điều Chatwoot cho sẵn mà bridge phải tự dựng:

| zca-bridge tự dựng | Chatwoot có sẵn |
|---|---|
| bảng `accounts` | `channel_zalo_personal` |
| bảng `conversations` (ánh xạ) | `contact_inboxes` + `conversations` |
| bảng `message_map` (chống trùng, quote) | `messages.source_id` + `content_attributes` |
| `job_queue` + dead-letter | Sidekiq |
| `settings`, `admin_users`, `logs` | `installation_configs`, `users`, `audits` |

## 4. Phạm vi

**Làm:**

1. Nhắn tin hai chiều, đủ ảnh / ghi âm / video / tệp / sticker / vị trí / danh thiếp / liên kết / nhắc việc
2. Chat nhóm — mỗi nhóm là một contact, tin nhắn prefix tên người gửi
3. Chống trùng tin khi nhân viên nhắn trực tiếp từ app Zalo trên điện thoại
4. Đăng nhập QR, tự kết nối lại, hiển thị trạng thái phiên
5. Trả lời trích dẫn, thả cảm xúc, thu hồi tin

**Không làm (đã cân nhắc và loại):**

- Proxy riêng mỗi tài khoản — bỏ theo yêu cầu
- Giao diện quản trị riêng, hàng đợi riêng, cảnh báo Telegram/webhook
- Kho lưu media và link tải token hoá
- Gửi link thay thế khi Zalo từ chối tệp
- Nén ảnh trước khi gửi (giới hạn Zalo cá nhân rộng, bridge cũng không nén)
- Chuyển đổi dữ liệu cũ — chưa có dữ liệu production

## 5. Quyết định đã chốt

| Vấn đề | Chốt | Lý do |
|---|---|---|
| Chat cá nhân và nhóm | **Chung một inbox** | Dùng chung một phiên đăng nhập, không tách được |
| Contact trùng giữa OA và cá nhân | **Để riêng hai contact** | Zalo cấp hai ID khác nhau, không có cách biết chắc là một người. Nhân viên tự gộp khi cần |
| Xoá tin trong Chatwoot | **Không thu hồi bên Zalo** | Tránh xoá nhầm trong helpdesk lại ảnh hưởng tới khách |
| Khách thu hồi tin bên Zalo | **Giữ nguyên trong Chatwoot** | Nhân viên cần biết khách đã nói gì rồi rút lại |
| Mình thu hồi tin từ app Zalo | **Xoá trong Chatwoot** | Đồng bộ đúng ý định của chính mình |
| Gửi trùng khi mất phản hồi | **Có khoá chống trùng** | Node nhớ mã định danh trong RAM vài phút |
| Trạng thái phiên | **3 trạng thái** | `connected` / `reconnecting` / `expired`. Bỏ `pending_qr` vì channel chỉ tạo sau khi quét QR thành công |
| Cảnh báo khi phiên chết | **Chỉ hiển thị trong giao diện** | Giai đoạn thử nghiệm, ít tài khoản. Nâng lên email khi chạy thật |
| Xoá inbox | **Đóng phiên và xoá credentials** | |
| Hai inbox cùng một tài khoản Zalo | **Chặn** bằng unique index `zalo_uid` | |
| Tên nhóm | Lấy lúc **tạo contact**; nếu lỗi thì thử lại ở tin sau, chừng nào tên còn là placeholder | Đơn giản hơn cách bridge đếm theo vòng đời tiến trình. **Đánh đổi: nhóm đổi tên về sau sẽ không tự cập nhật** — chấp nhận ở bản thử nghiệm |
| Bị kick khỏi nhóm | Không xử lý đặc biệt | Tin ngừng đến, hội thoại giữ nguyên |
| Tệp quá lớn | Để Zalo từ chối rồi báo lỗi | Không chặn trước ở Chatwoot |
| Tải media thất bại | **Ném lỗi để Sidekiq thử lại** | Khác Zalo OA hiện tại (chỉ log rồi bỏ qua). Lỗi CDN phần lớn là tạm thời |

## 6. Mô hình dữ liệu

Chỉ thêm **một bảng**: `channel_zalo_personal`

| Cột | Kiểu | Ghi chú |
|---|---|---|
| `account_id` | integer, not null | |
| `zalo_uid` | string, not null, **unique** | UID tài khoản Zalo đã đăng nhập |
| `display_name` | string | Tên tài khoản Zalo |
| `credentials` | text, **encrypted** | JSON `{imei, cookie, userAgent, language}` |
| `status` | string, not null, default `reconnecting` | |
| `status_updated_at` | datetime | Để biết kẹt reconnect bao lâu |
| `last_connected_at` | datetime | |

### Ánh xạ Zalo → Chatwoot

| | Chat cá nhân | Chat nhóm |
|---|---|---|
| `contact_inboxes.source_id` | `user:<uid>` | `group:<id nhóm>` |
| Contact | Người đó | **Cả nhóm là một contact** |
| Tên contact | Tên người gửi | Tên nhóm (hỏi Node `getGroupInfo`) |
| Nội dung tin | Nguyên văn | Prefix `**Tên người gửi:**` |

`source_id` có tiền tố để tránh trùng giữa ID người và ID nhóm, đồng thời lúc gửi biết ngay phải gửi vào nhóm hay cho người mà không cần tra database.

### Dùng cột có sẵn thay bảng riêng

| Nhu cầu | Lưu ở đâu |
|---|---|
| Ánh xạ msgId Zalo ↔ message Chatwoot | `messages.source_id` |
| Nhiều msgId cho một tin nhiều tệp | `content_attributes.external_message_ids` |
| Cụm dữ liệu để trích dẫn lại (`uidFrom`, `cliMsgId`, `msgType`, `ts`, `content`, `ttl`) | `content_attributes.zalo_quote_source` |
| Chặn echo tin vừa gửi | Redis key, TTL ngắn |

## 7. Giao thức Rails ↔ Node

Node lắng nghe `127.0.0.1:3100`, **không mở ra ngoài**. Hai chiều xác thực bằng `ZALO_WORKER_SECRET`.

### Node → Rails

```
POST /webhooks/zalo_personal
X-Zalo-Worker-Secret: <secret>
```

| event | Rails xử lý |
|---|---|
| `message` | `Zalo::IncomingMessageService` |
| `reaction` | Tạo ghi chú nội bộ gắn vào tin được thả cảm xúc |
| `undo` | Xoá message, chỉ khi `is_self` |
| `status` | Cập nhật `channel.status` |
| `credentials_refreshed` | Lưu cookie mới |

Payload `message` đã được Node chuẩn hoá — Rails không cần biết `msgType` của Zalo:

```json
{
  "channel_id": 12,
  "kind": "user | group",
  "thread_id": "...",
  "msg_id": "...",
  "sender_uid": "...",
  "sender_name": "...",
  "is_self": false,
  "quote_msg_id": null,
  "quote_source": { "uidFrom": "...", "cliMsgId": "...", "msgType": "...", "ts": "...", "content": {}, "ttl": 0 },
  "content": "nội dung đã dựng sẵn",
  "media": { "type": "image|audio|video|file", "url": "...", "filename": "..." }
}
```

**Vì sao Node phân loại chứ không phải Rails:** sticker chỉ mang `{id, catId}`, phải gọi API qua session mới lấy được ảnh — chỉ Node làm được.

### Rails → Node

| Endpoint | Việc |
|---|---|
| `POST /qr/start` | Bắt đầu login QR, trả ảnh QR |
| `POST /sessions/:channel_id/connect` | Mở phiên (credentials gửi kèm) |
| `POST /sessions/:channel_id/send` | Gửi text / tệp (multipart) |
| `GET /sessions/:channel_id/profile` | Tên và avatar của một người hoặc một nhóm — Rails gọi khi lần đầu thấy thread |
| `DELETE /sessions/:channel_id` | Đóng phiên |
| `GET /health` | Trạng thái từng phiên |

Node khởi động thì tự gọi `GET /internal/zalo_personal/sessions` để lấy danh sách channel cần kết nối.

**Vì sao HTTP chứ không Redis:** chiều Rails→Node cần phản hồi đồng bộ (`msgId` trả về để lưu `source_id`). Redis pub/sub không có request–response tự nhiên. Retry đã có Sidekiq lo.

### Phân loại lỗi khi gửi

| Node trả | Rails làm |
|---|---|
| `200` + msgId | Lưu `source_id`, ghi Redis chống echo |
| `409 no_session` | Tin **thất bại**, báo cần quét QR |
| `422 file_rejected` | Tin **thất bại**, ghi lý do Zalo trả về |
| `5xx` / timeout | Ném lỗi → Sidekiq thử lại |

## 8. Chống trùng

Ba nguồn có thể gây trùng:

| Nguồn | Cách chặn |
|---|---|
| Echo tin vừa gửi từ Chatwoot (`selfListen`) | Redis key ghi lúc gửi |
| Sidekiq chạy lại job nhận tin | `inbox.messages.exists?(source_id:)` |
| Sidekiq thử lại lúc gửi, đã gửi một phần | Bỏ qua số tệp đã có msgId trong `external_message_ids` |
| Node gửi xong nhưng mất phản hồi | Khoá chống trùng trong RAM của Node |

Tin mình gửi từ **app Zalo trên điện thoại** không bị chặn — nhập vào thành tin outgoing với prefix `📱 từ app Zalo`.

## 9. Danh sách file

### Rails — mới

```
db/migrate/20260904000001_create_channel_zalo_personal.rb
app/models/channel/zalo_personal.rb
app/controllers/webhooks/zalo_personal_controller.rb
app/controllers/api/v1/accounts/zalo_personal/authorizations_controller.rb
app/controllers/internal/zalo_personal/sessions_controller.rb
app/jobs/webhooks/zalo_personal_events_job.rb
app/services/zalo/incoming_message_service.rb
app/services/zalo/send_on_zalo_personal_service.rb
app/services/zalo/worker_client.rb
```

### Rails — sửa

```
app/models/account.rb              # has_many :zalo_personal_channels
lib/redis/redis_keys.rb            # key chống echo, mutex theo thread
config/routes.rb                   # 3 nhóm route
Procfile / Procfile.dev            # thêm tiến trình zalo worker
```

### Node worker — mới

```
zalo_worker/package.json
zalo_worker/tsconfig.json
zalo_worker/src/main.ts             # Fastify + boot
zalo_worker/src/routes.ts           # 5 endpoint
zalo_worker/src/railsClient.ts      # đẩy sự kiện về Rails
zalo_worker/src/zcaAdapter.ts       # bê từ bridge, bỏ proxy
zalo_worker/src/sessionManager.ts   # bê từ bridge
zalo_worker/src/supervisor.ts       # bê từ bridge, bỏ nhánh proxy
zalo_worker/src/qrLogin.ts          # bê từ bridge, bỏ proxy
zalo_worker/src/classify.ts         # bê từ bridge
zalo_worker/src/types.ts            # bê từ bridge, bỏ kiểu OaUser
zalo_worker/src/idempotency.ts      # mới — khoá chống gửi trùng
```

### Frontend — mới và sửa

```
dashboard/routes/dashboard/settings/inbox/channels/ZaloPersonal.vue   # mới
dashboard/api/channel/zaloPersonalChannel.js                          # mới
dashboard/routes/dashboard/settings/inbox/ChannelFactory.vue
dashboard/routes/dashboard/settings/inbox/ChannelList.vue
dashboard/helper/inbox.js
dashboard/composables/useInbox.js
dashboard/i18n/locale/en/inboxMgmt.json     # chỉ en, còn lại qua Crowdin
theme/icons.js
dashboard/components-next/icon/provider.js
```

### Biến môi trường mới

```
ZALO_WORKER_URL=http://127.0.0.1:3100
ZALO_WORKER_SECRET=<sinh ngẫu nhiên>
ZALO_WORKER_PORT=3100
```

## 10. Thứ tự triển khai

| Bước | Nội dung | Kiểm tra được gì |
|---|---|---|
| 1 | Migration + model + liên kết account | `rails db:migrate`, tạo channel bằng console |
| 2 | Node worker khung: Fastify, `/health`, adapter, session, supervisor | Chạy được, `/health` trả rỗng |
| 3 | Luồng QR: controller + `/qr/start` + tạo channel/inbox | Quét QR tạo được inbox |
| 4 | Nhận tin: webhook controller + job + `IncomingMessageService` | Nhắn từ điện thoại vào, thấy trong Chatwoot |
| 5 | Gửi tin: `SendOnZaloPersonalService` + `/send` | Trả lời từ Chatwoot, khách nhận được |
| 6 | Nhóm: tên nhóm, prefix người gửi | Nhắn trong nhóm, hiển thị đúng |
| 7 | Trích dẫn, cảm xúc, thu hồi | Từng cái một |
| 8 | Tự kết nối lại + trạng thái | Tắt mạng, xem có tự nối lại |
| 9 | Giao diện: màn hình QR, khối trạng thái, icon, i18n | Toàn bộ luồng từ giao diện |

Từ bước 3 trở đi mỗi bước đều chạy thử được bằng tay, không cần chờ tới cuối.

## 11. Rủi ro

| Rủi ro | Mức | Ghi chú |
|---|---|---|
| **Tài khoản Zalo bị khoá** | Cao | Bản chất của API không chính thức. Chỉ dùng tài khoản phụ, không dùng tài khoản kinh doanh chính |
| **`zca-js` hỏng khi Zalo đổi giao thức** | Trung bình | Thư viện cộng đồng. Zalo OA không bị ảnh hưởng vì dùng API chính thức |
| **Tiến trình Node chết** | Trung bình | Tin ngừng chảy trong khi Chatwoot vẫn chạy. Cần giám sát và tự khởi động lại |
| **Phiên hết hạn không ai để ý** | Trung bình | Bản đầu chỉ hiển thị trạng thái trong giao diện. Nâng lên email khi chạy thật |
| **Mất tin lúc mất kết nối** | **Chưa rõ — cần kiểm chứng sớm** | Bridge chỉ có cơ chế lấy bù cho Zalo OA, chưa có cho tài khoản cá nhân. Nếu Zalo không đẩy bù thì mỗi lần mất kết nối là một khoảng trống tin nhắn |
| **Mỗi lần deploy là một lần gián đoạn** | Thấp | Các phiên phải đăng nhập lại, mất vài giây tới vài chục giây |

## 12. Điều cần kiểm chứng sớm

1. **Zalo có đẩy bù tin nhắn sau khi kết nối lại không?** Nếu không, cần tính phương án lấy bù. Đây là rủi ro lớn nhất chưa được xác nhận.
2. **`imei` mà `zca-js` sinh ra có khác nhau giữa các tài khoản không?** Nếu trùng pattern thì nhiều tài khoản dễ bị nhận diện là cùng một máy.
3. **Phiên sống được bao lâu trên thực tế?** Ghi lại thời điểm quét QR và thời điểm chuyển `expired` cho từng tài khoản để có số liệu thật.
