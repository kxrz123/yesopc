## 部署到阿里云并使用 `yesopc.com` 域名

本方案目标是：把当前仓库里的

- 后端：`services/content-api`（Go）
- 后台管理：`apps/web-admin`（Vite/React，静态站点）

部署到阿里云 ECS 上，并通过 `yesopc.com` 统一访问：

- `https://yesopc.com/`：web-admin
- `https://yesopc.com/api/*`：content-api（反向代理）

> 说明：Flutter App 属于“客户端发布”。本文会告诉你如何设置 `API_BASE`，但不会在服务器上直接构建发布 App（除非你另外建立 CI/CD）。

---

## 1. 部署前准备

### 1.1 你需要的资源

- 阿里云 ECS 一台（推荐系统：Ubuntu 22.04/24.04 或 CentOS 9）
- 已在阿里云上解析的域名：`yesopc.com`
- Supabase（托管 Postgres + Storage）
- 你当前项目代码（本机已存在）

### 1.2 网络与安全组

请在 ECS 安全组放行：

- `22/tcp`（SSH，来源建议限制你的 IP）
- `80/tcp`、`443/tcp`（给域名访问和证书申请用）

`content-api` 监听端口默认是 `8888`，建议只让 Nginx 反代访问（即不在安全组对外开放 `8888`）。

---

## 2. 准备 Supabase（数据库 + Storage）

### 2.1 数据库迁移

请确保 Supabase 已执行过本仓库的这些迁移文件（至少包含与“收藏/关注/文章扩展字段/用户关注”相关的）：

- `docs/supabase-migration-user-article-favorites.sql`
- `docs/supabase-migration-article-summary-meta.sql`
- `docs/supabase-migration-user-follows.sql`

如果你的表结构已经完整创建，可跳过此步骤。

> 操作建议：Supabase 控制台 → SQL Editor → 依次粘贴并执行上述 SQL。

### 2.2 Storage Bucket：`covers`

后端上传接口在 `services/content-api/internal/handler/upload.go` 中：

- 上传到：`storage/v1/object/covers/<objectName>`
- 返回公开 URL：`storage/v1/object/public/covers/<objectName>`

因此你需要：

- 确保 Supabase Storage 存储桶（Bucket）存在：`covers`
- 确保 Bucket 的公开读取策略允许 public read（让已上传的封面图片能被 `Image.network(url)` 正常访问）

如果封面图加载失败，优先检查这里。

---

## 3. 准备阿里云服务器环境

在 ECS 上安装运行依赖（以下示例以 Ubuntu 为例，具体命令按你服务器系统替换）：

1. 安装 Go（用于构建 `services/content-api`）
2. 安装 Node.js（用于构建 `apps/web-admin`）
3. 安装 Nginx（用于反向代理与 TLS）

推荐安装后检查：

- `go version`
- `node -v && npm -v`
- `nginx -v`

---

## 4. 部署后端 `services/content-api`

### 4.1 上传并准备代码

在服务器上创建一个目录，例如：

```bash
sudo mkdir -p /opt/yesopc.com
sudo chown -R $USER:$USER /opt/yesopc.com
```

把仓库代码上传到 `/opt/yesopc.com`（方式不限，比如 `scp -r`）。

### 4.2 配置环境变量

后端环境变量文件在 `services/content-api/.env`。

你可以从示例复制一份，然后填入你自己的 Supabase 信息：

1. 复制：`services/content-api/.env.example` → `services/content-api/.env`
2. 修改以下字段（至少这些是必需的）：
   - `DATABASE_URL`：Supabase Postgres 连接串（后端直连数据库）
   - `SUPABASE_URL`：例如 `https://xxxx.supabase.co`
   - `SUPABASE_SERVICE_ROLE_KEY`：用于 Storage 上传的 service role key
   - `CORS_ALLOW_ORIGIN`：建议填 `https://yesopc.com`（逗号分隔多个也可以）

建议在服务器上把 `services/content-api/.env` 放到不可随意读取的位置（例如保证文件权限 600）。

### 4.3 执行迁移（可选）

如果你不确定 Supabase 表结构是否就绪，这一步可以在 Supabase 控制台完成（见第 2 节）。

### 4.4 构建并运行 Go 服务

在服务器上执行：

```bash
cd /opt/yesopc.com/services/content-api
go mod download
go build -o content-api .
```

content-api 默认启动参数是 `-f` 指向配置文件：

- `services/content-api/etc/content-api.yaml`（默认相对路径）

你可以直接先手动跑起来验证：

```bash
./content-api -f etc/content-api.yaml
```

验证方法：

```bash
curl -s http://127.0.0.1:8888/api/v1/health
curl -s http://127.0.0.1:8888/
```

期望看到：

- `GET /api/v1/health` 返回 `ok: true`
- `GET /` 返回 `service: yesopc-content-api`

> 如果你手动验证通过，再进入 systemd 部署。

### 4.5 用 systemd 常驻启动

创建服务文件：

```bash
sudo tee /etc/systemd/system/content-api.service > /dev/null <<'EOF'
[Unit]
Description=yesopc content-api
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/yesopc.com/services/content-api
EnvironmentFile=/opt/yesopc.com/services/content-api/.env
ExecStart=/opt/yesopc.com/services/content-api/content-api -f /opt/yesopc.com/services/content-api/etc/content-api.yaml
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
```

然后启用并启动：

```bash
sudo systemctl daemon-reload
sudo systemctl enable content-api
sudo systemctl start content-api
sudo systemctl status content-api --no-pager
```

---

## 5. 部署后台管理 `apps/web-admin`

### 5.1 构建 web-admin

在服务器上执行：

```bash
cd /opt/yesopc.com/apps/web-admin
npm ci
npm run build
```

构建产物默认在 `apps/web-admin/dist/`。

### 5.2 安装到 Nginx 静态目录

建议准备目录，例如：

```bash
sudo mkdir -p /var/www/yesopc.com/web-admin
sudo chown -R $USER:$USER /var/www/yesopc.com/web-admin
```

把 dist 内容复制过去：

```bash
sudo rm -rf /var/www/yesopc.com/web-admin/*
sudo cp -r dist/* /var/www/yesopc.com/web-admin/
```

---

## 6. 配置 Nginx：反向代理与 SPA 回退

### 6.1 Nginx 站点配置（示例）

创建配置文件（按你的域名填）：

```bash
sudo tee /etc/nginx/conf.d/yesopc.com.conf > /dev/null <<'EOF'
server {
  listen 80;
  server_name yesopc.com www.yesopc.com;
  return 301 https://$host$request_uri;
}

server {
  listen 443 ssl http2;
  server_name yesopc.com www.yesopc.com;

  # TLS 证书路径：用你自己的证书文件替换下面两行
  ssl_certificate     /etc/letsencrypt/live/yesopc.com/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/yesopc.com/privkey.pem;

  # web-admin 静态站点
  root /var/www/yesopc.com/web-admin;
  index index.html;

  # 上传封面图：后端限制 5MB（见 upload.go），建议 Nginx 放大一些
  client_max_body_size 10m;

  # API 反代（保留 /api 前缀）
  location /api/ {
    proxy_pass http://127.0.0.1:8888;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
  }

  # SPA：history 模式回退到 index.html
  location / {
    try_files $uri $uri/ /index.html;
  }
}
EOF
```

### 6.2 检查并重载 Nginx

```bash
sudo nginx -t
sudo systemctl reload nginx
```

---

## 7. 域名 DNS 与 TLS 证书

### 7.1 DNS 解析

在阿里云 DNS 中添加记录：

- `A` 记录：`yesopc.com` → 你的 ECS 公网 IP
- （可选）`A` 记录：`www.yesopc.com` → 同一个 ECS 公网 IP

等待 DNS 生效后继续 TLS。

### 7.2 申请证书（示例：Let’s Encrypt）

如果你使用 certbot，通常步骤是：

1. 安装 `certbot`（按你系统）
2. 运行 `certbot --nginx -d yesopc.com -d www.yesopc.com`
3. 确保证书文件路径与 Nginx 配置一致（上文示例用 `/etc/letsencrypt/...`）

---

## 8. 上线验证清单

### 8.1 基础可达性

1. `https://yesopc.com/` 能打开 web-admin 页面
2. `https://yesopc.com/api/v1/health` 返回健康状态 JSON

### 8.2 登录与接口权限

1. 打开 web-admin → 登录（使用你在 content-api 中注册/创建的账号）
2. 登录成功后进入首页/文章页

### 8.3 封面上传与预览

在 web-admin 的文章新增/编辑中上传或粘贴封面：

1. 点击上传按钮上传图片
2. 保存后检查封面在列表/文章详情展示是否正常

如果封面不显示，优先检查：

- Supabase Storage bucket `covers` 的 public read 策略
- content-api 的 `SUPABASE_URL`、`SUPABASE_SERVICE_ROLE_KEY` 配置是否正确

### 8.4 API CORS（通常同源不需要）

由于我们使用 Nginx 同域名下的 `/api/*`，web-admin 对 API 属于同源请求，CORS 通常不会触发。

但如果你后续把 web-admin 部署到不同子域名/不同端口，才需要你同步修改 `CORS_ALLOW_ORIGIN`。

---

## 9. Flutter App 的生产配置（设置 `API_BASE`）

Flutter 客户端的 API 基地址来自 `apps/app/lib/constants.dart`：

- 默认是本地局域网 `http://192.168.31.137:8888`
- 也支持编译时覆盖：`--dart-define=API_BASE=...`

如果你采用本方案的 Nginx 反代方式，推荐把 API 基地址设置为：

- `API_BASE=https://yesopc.com`

构建示例（Android）：

```bash
cd /opt/yesopc.com/apps/app
flutter build apk --release --dart-define=API_BASE=https://yesopc.com
```

iOS 构建同理（按你的发布流程进行）。

---

## 10. 更新与回滚建议

更新 web-admin：

1. 重新在服务器上构建 `apps/web-admin`
2. 覆盖 ` /var/www/yesopc.com/web-admin/`
3. 不一定需要重启 Nginx（重载静态即可；若缓存策略影响，可调整 Nginx cache）

更新 content-api：

1. 重新构建 `content-api`
2. 覆盖二进制文件
3. `sudo systemctl restart content-api`

回滚：

- 保留旧的 `content-api` 二进制与旧的 web-admin `dist`，出现问题时快速切回即可。

---

## 11. 常见问题定位（快速）

1. `502/504`：多半是 Nginx 到 `127.0.0.1:8888` 反代失败，检查 `content-api` 是否启动成功
2. `/api/v1/health` 404：可能是反代路径写错，检查 Nginx `location /api/` 的 `proxy_pass`
3. 上传成功但图片不显示：检查 Supabase Storage bucket `covers` 是否允许 public read
4. 浏览器端 `CORS` 报错：检查 `CORS_ALLOW_ORIGIN` 是否包含 `Origin` 对应的 `https://yesopc.com`（精确匹配，支持逗号分隔多源）

