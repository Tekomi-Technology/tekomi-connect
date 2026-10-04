# Tekomi Connect

Nền tảng chăm sóc khách hàng đa kênh của Tekomi, phát triển từ mã nguồn mở [Chatwoot](https://github.com/chatwoot/chatwoot) (bản gốc 4.17.0, xem `VERSION_CW`).

Tekomi Connect gom hội thoại từ website, email, Facebook, Zalo, WhatsApp, SMS và tổng đài về một hộp thư chung, kèm trợ lý AI, báo cáo và đồng bộ CRM.

## Khác gì so với Chatwoot gốc

| Phần | Nội dung | Mã nguồn |
|---|---|---|
| Zalo | Kênh Zalo OA và Zalo cá nhân, chạy qua một worker Node riêng | `zalo_worker/`, `app/controllers/**/zalo_*`, [docs/zalo-personal-proxy.md](docs/zalo-personal-proxy.md) |
| CRM Perfex | Đồng bộ danh bạ, khớp liên hệ, gửi và đọc ticket | `app/services/crm/perfex/`, `app/jobs/crm/perfex/` |
| Cuộc gọi | Nhận sự kiện từ tổng đài, phiên âm ghi âm và phân tích cảm xúc | `call_emotion/` (dịch vụ Python, model Zipformer) |
| Tekomi AI | Trợ lý AI, đổi tên từ Captain của Chatwoot | `enterprise/` |
| Phân quyền | Vai trò supervisor và ma trận quyền của Super Admin | `config/role_matrix.yml` |

Phần mở rộng theo mô hình Enterprise của Chatwoot nằm trong `enterprise/` và ghi đè lên mã ở `app/`.

## Yêu cầu

| Thành phần | Phiên bản |
|---|---|
| Ruby | 3.4.4 (`.ruby-version`) |
| Node.js | 24.x (`.nvmrc`) |
| pnpm | 10.x |
| PostgreSQL | có extension `pgvector` |
| Redis | bất kỳ bản còn hỗ trợ |

Nếu chạy bằng Docker thì chỉ cần Docker Desktop và một PostgreSQL truy cập được.

## Cài đặt

### 1. Lấy mã nguồn và tạo file môi trường

```bash
git clone https://github.com/Tekomi-Technology/tekomi-connect.git
cd tekomi-connect
cp .env.example .env
```

Điền tối thiểu các biến sau trong `.env`: `SECRET_KEY_BASE`, `FRONTEND_URL`, `POSTGRES_HOST`, `POSTGRES_USERNAME`, `POSTGRES_PASSWORD`, `REDIS_URL`, `REDIS_PASSWORD`.

### 2a. Chạy bằng Docker

```bash
docker compose build base
docker compose build rails vite
docker compose up -d rails
docker compose exec rails bundle exec rails db:chatwoot_prepare
```

Phải build `base` trước, vì image của `rails` và `vite` đều dựng từ `chatwoot:development` do `base` tạo ra.

Lệnh `up -d rails` kéo theo `redis`, `vite`, `sidekiq` và `mailhog`. Worker Zalo chạy riêng bằng `docker compose up -d zalo`.

| Dịch vụ | Địa chỉ |
|---|---|
| Ứng dụng | http://localhost:3000 |
| Vite dev server | http://localhost:3036 |
| Mailhog (hộp thư thử) | http://localhost:8025 |
| Redis | localhost:6379 |

**PostgreSQL không có trong `docker-compose.yaml`.** Bạn phải tự chạy một PostgreSQL có `pgvector` (ví dụ image `pgvector/pgvector:pg16`) và trỏ `POSTGRES_HOST` trong `.env` tới nó. Container gọi được máy chủ qua `host.docker.internal`.

**Trên Windows:** đặt `git config core.autocrlf input` trước khi clone. Nếu để mặc định, các script trong `docker/entrypoints/` và `bin/` bị đổi sang CRLF và container báo `no such file or directory` khi khởi động.

### 2b. Chạy trực tiếp trên máy

```bash
bundle install
pnpm install
bundle exec rails db:chatwoot_prepare
pnpm dev
```

`pnpm dev` chạy `overmind start -f ./Procfile.dev`, gồm bốn tiến trình: Rails (cổng 3000), Sidekiq, Vite và worker Zalo. Nếu không có overmind, dùng `pnpm start:dev` (foreman).

### 3. Dữ liệu mẫu

```bash
bundle exec rails db:seed
```

Dữ liệu phong phú hơn cho một tài khoản: vào Super Admin → Accounts → Seed.

## Lệnh thường dùng

| Việc | Lệnh |
|---|---|
| Test JS | `pnpm test` |
| Test Ruby | `bundle exec rspec spec/path/to/file_spec.rb` |
| Lint JS/Vue | `pnpm eslint` hoặc `pnpm eslint:fix` |
| Lint Ruby | `bundle exec rubocop -a` |
| Test worker Zalo | `cd zalo_worker && npm test` |

## Cấu trúc thư mục

| Thư mục | Nội dung |
|---|---|
| `app/` | Rails backend và frontend Vue 3 (`app/javascript/`) |
| `enterprise/` | Phần mở rộng Enterprise, ghi đè lên `app/` |
| `zalo_worker/` | Worker Node/TypeScript cho Zalo cá nhân |
| `call_emotion/` | Dịch vụ phiên âm cuộc gọi (Python, FastAPI) |
| `config/`, `db/`, `lib/` | Cấu hình, schema, thư viện và rake task |
| `spec/` | Test Ruby |
| `docker/`, `deployment/` | Dockerfile, entrypoint, cấu hình triển khai |
| `docs/` | Tài liệu nội bộ |
| `graphify-out/` | Đồ thị mã nguồn (xem bên dưới) |

## Nhánh

| Nhánh | Vai trò |
|---|---|
| `develop` | Nhánh chính, PR nhắm vào đây |
| `customer/gmo-develop` | Bản white-label cho khách hàng GMO |

Để lấy cập nhật từ bản gốc, thêm remote: `git remote add upstream https://github.com/chatwoot/chatwoot.git`.

## Đồ thị mã nguồn (graphify)

Repo có sẵn một đồ thị mã nguồn do [graphify](https://github.com/Graphify-Labs/graphify) tạo, tại `graphify-out/graph.json`. Đồ thị ghi lại class, hàm, file và các quan hệ gọi, import, kế thừa giữa chúng. Công cụ AI (Claude Code, Codex, Cursor) dùng nó để tìm vị trí code và phạm vi ảnh hưởng thay vì grep cả repo.

### Cài trên máy mới

```bash
# Windows
winget install astral-sh.uv
# macOS
brew install uv
```

Mở terminal mới rồi chạy:

```bash
uv tool install graphifyy
graphify explain "ConversationPolicy"
```

Tên gói có hai chữ `y`; tên lệnh là `graphify`. Lệnh thứ hai dùng để kiểm tra: nếu in ra danh sách method là đồ thị dùng được, không cần xây lại.

### Bật cho Claude Code

```bash
graphify install --project
git checkout -- CLAUDE.md
```

Lệnh đầu cài skill `/graphify` và hook nhắc Claude Code tra đồ thị trước khi tìm file. Chúng nằm trong `.claude/`, thư mục này không đi theo repo nên mỗi máy phải chạy một lần. Lệnh thứ hai khôi phục `CLAUDE.md`, vì trình cài ghi thêm nội dung vào đó.

### Tra cứu

```bash
graphify explain "ConversationPolicy"                      # một class nối với những gì
graphify affected "enterprise/app/models/applied_sla.rb"   # sửa file này ảnh hưởng tới đâu
graphify path "ContactIdentifyAction" "ContactMergeAction" # đường đi giữa hai thành phần
graphify god-nodes --top 20                                # các thành phần được nối nhiều nhất
```

### Cập nhật

```bash
graphify update .                 # sau khi sửa code hoặc git pull
graphify extract . --code-only    # xây lại từ đầu, khoảng 4 phút
```

Cả hai lệnh chạy cục bộ, không gọi API. Khi đồ thị thay đổi nhiều, commit lại `graphify-out/graph.json` và `graphify-out/manifest.json`.

### Xem bằng hình

```bash
graphify export html --node-limit 1500
graphify tree
```

Mở `graphify-out/graph.html` hoặc `graphify-out/GRAPH_TREE.html` bằng trình duyệt. Vì dự án có hơn 32.000 node, `graph.html` chỉ hiển thị ở mức cụm; `GRAPH_TREE.html` xem được tới từng class.

### Giới hạn

Đồ thị chỉ ghi quan hệ tĩnh. Nó không thấy callback của model, `authorize` của Pundit, job nền, event/listener, route, và các lời gọi API từ Vue sang Rails. Với những phần đó vẫn phải đọc code.

## Tài liệu cho công cụ AI

| File | Dành cho | Nội dung |
|---|---|---|
| [AGENTS.md](AGENTS.md) | Mọi công cụ AI | Quy tắc code, lệnh build/test, quy ước commit và PR |
| [CLAUDE.md](CLAUDE.md) | Claude Code | Nạp `AGENTS.md` |

## Bảo mật

Báo lỗ hổng theo hướng dẫn trong [SECURITY.md](SECURITY.md).

## Giấy phép

Mã nguồn gốc của Chatwoot dùng giấy phép MIT; nội dung trong `enterprise/` dùng giấy phép riêng tại `enterprise/LICENSE`. Chi tiết xem [LICENSE](LICENSE).
