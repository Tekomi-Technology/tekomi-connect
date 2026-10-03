# Hướng dẫn kiểm thử: Zalo cá nhân & Zalo nhóm

Ngày: 2026-09-04 · Nhánh: `feature/chat-zalo` · Đi kèm [kế hoạch triển khai](2026-09-04-zalo-personal-chat-plan.md)

> **Trạng thái code khi viết tài liệu này:** đã qua `ruby -c`, `tsc --noEmit`, `eslint`, JSON hợp lệ — nhưng **chưa có dòng nào từng chạy**. Toàn bộ phần dưới là chạy thật lần đầu.

## 0. Chuẩn bị

### Tài khoản Zalo

Dùng **tài khoản phụ**, không dùng tài khoản kinh doanh chính hay tài khoản chứa dữ liệu quan trọng. `zca-js` là thư viện không chính thức; Zalo có thể hạn chế hoặc khoá tài khoản bị phát hiện.

Cần một điện thoại đã đăng nhập tài khoản đó để quét QR, và **một tài khoản Zalo thứ hai** để đóng vai khách nhắn vào.

### Môi trường

```bash
# Ruby (máy dev hiện chưa có 3.4.4)
rbenv install 3.4.4 && gem install bundler && bundle install

# Node worker
cd zalo_worker && npm install && cd ..

# Migration
bundle exec rails db:migrate
```

Biến trong `.env` (đã thêm sẵn):

```
ZALO_WORKER_URL=http://127.0.0.1:3100
ZALO_WORKER_PORT=3100
ZALO_WORKER_SECRET=<đã sinh sẵn>
RAILS_BASE_URL=http://127.0.0.1:3000
```

### Chạy

```bash
overmind start -f Procfile.dev
```

Phải thấy 4 tiến trình: `backend`, `worker`, `vite`, `zalo`.

---

## 1. Worker sống chưa

```bash
source .env
curl -s -H "X-Zalo-Worker-Secret: $ZALO_WORKER_SECRET" http://127.0.0.1:3100/health
```

**Mong đợi:** `{"sessions":[]}`

| Lỗi | Nguyên nhân |
|---|---|
| `Connection refused` | Tiến trình `zalo` chết. Xem log overmind |
| `{"error":"unauthorized"}` | Secret trong shell khác secret worker đang chạy |
| Worker chết ngay khi khởi động | Thiếu `ZALO_WORKER_SECRET` — worker cố tình từ chối chạy khi không có secret |

Kiểm tra worker có đọc được `.env` không: dòng `zalo` trong `Procfile.dev` phải có tiền tố `dotenv`. Chỉ Rails tự nạp `.env`, tiến trình khác thì không.

---

## 2. Quét QR tạo inbox

**Cài đặt → Inbox → Thêm inbox → Zalo Personal → Kết nối Zalo**

| Bước | Mong đợi |
|---|---|
| Bấm nút | Hiện mã QR trong vài giây |
| Quét bằng app Zalo | Chuyển sang màn hình thêm nhân viên |
| Không quét, chờ ~2 phút | Hiện "mã đã hết hạn" + nút tạo mã mới |
| Quét rồi **bấm từ chối** trên điện thoại | Hiện thông báo bị từ chối |

Kiểm tra trong database:

```sql
SELECT id, zalo_uid, display_name, status FROM channel_zalo_personal;
SELECT id, name, channel_type FROM inboxes WHERE channel_type = 'Channel::ZaloPersonal';
```

`status` phải là `connected` sau vài giây. Còn `reconnecting` quá lâu thì xem log tiến trình `zalo`.

```bash
curl -s -H "X-Zalo-Worker-Secret: $ZALO_WORKER_SECRET" http://127.0.0.1:3100/health
# giờ phải có 1 phiên
```

---

## 3. Nhận tin 1-1

Từ tài khoản Zalo thứ hai, nhắn vào tài khoản vừa kết nối.

| Kiểm | Mong đợi |
|---|---|
| Hội thoại mới xuất hiện | Có, trong vài giây |
| Tên contact | Tên thật của người nhắn, **không phải** dãy số |
| Nội dung | Đúng nguyên văn |

```sql
SELECT source_id, name FROM contacts c
  JOIN contact_inboxes ci ON ci.contact_id = c.id
  WHERE ci.source_id LIKE 'user:%';
```

`source_id` phải có tiền tố `user:`.

Lần lượt gửi thêm: **ảnh, ghi âm, video, tệp, sticker, vị trí, danh thiếp, liên kết**.

Mong đợi: ảnh/ghi âm/video/tệp/sticker hiện thành đính kèm thật; vị trí thành link Google Maps; danh thiếp và liên kết thành text có biểu tượng. **Không tin nào được để trống.**

---

## 4. Gửi tin từ Chatwoot

| Kiểm | Mong đợi |
|---|---|
| Gửi text | Khách nhận được |
| Tin **không** bị nhân đôi trong Chatwoot | Đúng — echo bị chặn bằng Redis |

```bash
redis-cli --scan --pattern 'alfred:ZALO_PERSONAL_SENT_MESSAGE*'
```

```sql
SELECT id, source_id, content_attributes FROM messages
  WHERE message_type = 1 ORDER BY id DESC LIMIT 3;
```

`source_id` phải có giá trị sau khi gửi thành công.

---

## 5. Gửi tệp — bài test dễ lộ lỗi nhất

Gửi **một ảnh** từ Chatwoot, rồi gửi **một tin có nhiều tệp**.

Đây là chỗ rủi ro đã biết: `@fastify/multipart` chỉ đọc được field đứng **trước** phần file. Phía Rails xếp `file` cuối cùng, nhưng chưa xác nhận HTTParty giữ đúng thứ tự đó.

| Triệu chứng | Nghĩa là |
|---|---|
| Worker log lỗi thiếu `thread_id` hoặc gửi vào sai người | Thứ tự field sai — cần đổi cách dựng multipart |
| Khách nhận đủ tệp, chú thích nằm ở tệp đầu | Đúng như thiết kế |
| Nhiều tệp → nhiều tin Zalo riêng | Đúng — Zalo không hỗ trợ gửi gộp |

```sql
SELECT content_attributes -> 'external_message_ids' FROM messages WHERE id = <id>;
```

Phải có đủ số msgId bằng số tệp.

**Test gửi dở dang:** gửi tin 3 tệp, tắt tiến trình `zalo` giữa chừng, bật lại. Sidekiq thử lại — khách **không được** nhận trùng tệp đã gửi.

---

## 6. Chat nhóm

Thêm tài khoản Zalo đã kết nối vào một nhóm, rồi nhắn vào nhóm đó.

| Kiểm | Mong đợi |
|---|---|
| Tên contact | **Tên nhóm**, không phải tên một thành viên |
| Nội dung tin | Có prefix `**Tên người gửi:**` xuống dòng |
| `source_id` | Bắt đầu bằng `group:` |
| Nhiều người nhắn | Tất cả về **cùng một** hội thoại |

Nếu tên contact là `Nhóm Zalo` thì lần lấy tên nhóm bị lỗi — tin tiếp theo sẽ thử lại. Vẫn giữ nguyên sau nhiều tin thì kiểm endpoint:

```bash
curl -s -H "X-Zalo-Worker-Secret: $ZALO_WORKER_SECRET" \
  "http://127.0.0.1:3100/sessions/<channel_id>/profile?kind=group&id=<group_id>"
```

> **Hạn chế đã biết:** nhóm đổi tên về sau **không** tự cập nhật trong Chatwoot.

---

## 7. Trích dẫn, cảm xúc, thu hồi

| Thao tác | Mong đợi |
|---|---|
| Khách trả lời trích dẫn một tin | Chatwoot hiện đúng quan hệ trả lời |
| Nhân viên bấm trả lời một tin rồi gửi | Khách thấy tin trích dẫn bên Zalo |
| Khách thả cảm xúc | Xuất hiện **ghi chú nội bộ** gắn vào tin đó |
| Khách gỡ cảm xúc | Không có gì xảy ra — đúng thiết kế |
| Khách thu hồi tin | Tin **vẫn còn** trong Chatwoot — đúng thiết kế |
| Mình thu hồi tin từ app Zalo | Tin **bị xoá** trong Chatwoot |

Trích dẫn chiều Chatwoot → Zalo phụ thuộc `zalo_quote_source` đã lưu lúc nhận tin:

```sql
SELECT content_attributes -> 'zalo_quote_source' FROM messages WHERE id = <id>;
```

Rỗng thì tin sẽ gửi đi mà không có trích dẫn.

---

## 8. Nhắn từ app Zalo trên điện thoại

Dùng chính điện thoại đã đăng nhập, nhắn cho khách.

| Kiểm | Mong đợi |
|---|---|
| Tin xuất hiện trong Chatwoot | Có, dạng tin đi |
| Có prefix | `📱 từ app Zalo` |
| Không bị gửi lại cho khách | Đúng — chống lặp |

---

## 9. Mất kết nối và tự nối lại

Tắt mạng máy chủ khoảng một phút rồi bật lại.

| Kiểm | Mong đợi |
|---|---|
| Trạng thái trong cài đặt inbox | Chuyển sang `Đang kết nối lại…` |
| Sau khi có mạng | Về `Đang hoạt động` trong vòng ~5 phút (chờ tăng dần 5s→5 phút) |
| Gửi tin lúc đang mất kết nối | Tin **thất bại** kèm lý do, không treo |

### Câu hỏi quan trọng nhất của cả đợt test

**Tin khách gửi trong lúc mất kết nối có về Chatwoot sau khi nối lại không?**

Nhờ người khác nhắn vào trong lúc đang mất mạng, rồi đếm lại sau khi nối lại.

- **Có về** → tốt, không cần làm gì thêm
- **Không về** → đây là **mất tin thật sự**, cần thiết kế cơ chế lấy bù trước khi dùng cho khách hàng

`zca-bridge` chỉ có cơ chế lấy bù cho Zalo OA, chưa có cho tài khoản cá nhân — nên khả năng cao là mất. Cần xác nhận sớm.

---

## 10. Phiên hết hạn

Khó ép xảy ra. Cách chủ động nhất: vào app Zalo trên điện thoại, mục quản lý thiết bị đăng nhập, **đăng xuất thiết bị tương ứng với phiên đang chạy**.

| Kiểm | Mong đợi |
|---|---|
| Trạng thái | Chuyển sang `Phiên hết hạn` |
| Cài đặt inbox | Hiện nút **Quét QR lại** |
| Bấm nút | Quay lại màn hình QR |
| Quét bằng **đúng** tài khoản cũ | Phiên khôi phục, hội thoại cũ còn nguyên |
| Quét bằng tài khoản **khác** | Bị từ chối kèm thông báo, không ghi đè |

Trường hợp cuối là chốt chặn quan trọng: quét nhầm tài khoản mà vẫn ghi đè sẽ làm mọi contact và hội thoại của inbox trỏ sai người.

---

## 11. Khởi động lại

```bash
overmind restart zalo
```

Worker phải tự hỏi Rails danh sách phiên rồi kết nối lại, không cần quét QR.

```bash
curl -s -H "X-Zalo-Worker-Secret: $ZALO_WORKER_SECRET" http://127.0.0.1:3100/health
```

Cookie được lưu lại mỗi 30 phút và lúc tắt. Kiểm tra `channel_zalo_personal.updated_at` có nhích lên theo thời gian không.

---

## Tra lỗi nhanh

```bash
# log worker
overmind connect zalo

# job Sidekiq lỗi — mở giao diện Sidekiq
open http://localhost:3000/sidekiq

# phiên QR đang chờ
redis-cli --scan --pattern 'alfred:ZALO_PERSONAL_QR_SESSION*'

# khoá theo thread (kẹt thì tin sẽ dồn)
redis-cli --scan --pattern 'alfred:ZALO_PERSONAL_MESSAGE_CREATE_LOCK*'

# tin gửi thất bại
```

```sql
SELECT id, content, external_error FROM messages
  WHERE status = 3 ORDER BY id DESC LIMIT 10;
```

## Bốn chỗ chưa được kiểm chứng

| Chỗ | Rủi ro | Bài test |
|---|---|---|
| Zalo đẩy bù tin sau khi nối lại | **Cao** — có thể mất tin | Mục 9 |
| Thứ tự field multipart | Trung bình — gửi tệp có thể hỏng | Mục 5 |
| "Upload không có msgId = tệp bị từ chối" | Trung bình — suy luận, không copy từ bridge | Gửi tệp quá lớn hoặc định dạng lạ |
| Phiên sống được bao lâu | Thấp — chỉ ảnh hưởng kế hoạch vận hành | Ghi lại ngày quét QR và ngày hết hạn |
