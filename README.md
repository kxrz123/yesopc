## YesOPC Monorepo

本仓库包含 YesOPC 的 **Web 官网**、**Web Admin 后台**、**Flutter App** 以及后端服务（规划为 Go-Zero）。

### 目录结构（高层）

- `apps/`
  - `web-site/`: 官网（当前为静态页，占位）
  - `web-admin/`: 后台（待初始化，建议 React/Next + Arco）
  - `app/`: Flutter App（iOS/Android/Web，已实现首页 UI）
- `services/`: 后端服务（规划）
- `packages/`: 跨端共享（OpenAPI、SDK、设计 Token 等，规划）
- `docs/`: 文档（架构、API、开发指南）
- `infra/`: 本地依赖与部署相关（规划）
- `scripts/`: 脚本（预留）

### 快速开始

#### Flutter App

```bash
cd apps/app
flutter pub get
flutter run
```

图标生成脚本（从 `logo/*.jpg` 生成 iOS/Android/macOS 图标）：

```bash
cd apps/app/scripts
./generate_icons.sh logo14.jpg
```

#### Web 官网（当前占位静态页）

直接打开 `apps/web-site/index.html` 预览即可。

### 文档入口

- `docs/repo-structure.md`: 仓库结构与约定
- `docs/architecture/overview.md`: 模块边界与演进建议
- `docs/dev/local-dev.md`: 本地开发（依赖、启动、脚本）
- `docs/api/contract.md`: API 契约与 SDK 生成约定

