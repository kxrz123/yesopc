## 本地开发指南

### 先决条件

- Flutter（用于 `apps/app`）
- Node.js（用于 `apps/web-site` / `apps/web-admin`，待初始化）
- Go（用于 `services/*`，待初始化）

### Flutter App

```bash
cd apps/app
flutter pub get
flutter run
```

#### 生成应用图标

从 `logo/` 下的图片生成 iOS/Android/macOS 所需各尺寸图标：

```bash
cd apps/app/scripts
./generate_icons.sh logo14.jpg
```

### Web

- `apps/web-site` 当前为静态占位页：直接打开 `index.html` 预览即可。
- `apps/web-admin` 当前仅为目录骨架，后续初始化为 React/Next + Arco。

### 后端服务（规划）

后端服务目录已创建，建议使用 Go-Zero 模板初始化：

- `services/gateway`
- `services/user`
- `services/cms`
- `services/media`
- `services/jobs`
- `services/social`

依赖（建议后续放到 `infra/docker`）：

- MySQL / Postgres
- Redis
- MQ（Kafka/RabbitMQ/NATS 按需）
- 搜索（ES/Meili/OpenSearch 按需）

