## 仓库目录结构与约定

### 总览

本仓库采用 Monorepo 组织方式，把 Web（官网 + 后台）、Flutter App、后端服务与跨端共享包放在同一个仓库中，便于统一：

- **接口契约**（OpenAPI/Proto）
- **设计 Token**（颜色/字号/间距/圆角）
- **CI/CD 与版本管理**

### 顶层目录

- **`apps/`**：所有客户端应用
  - `apps/web-site/`：官网（面向 C 端、SEO 优先）
  - `apps/web-admin/`：后台（内容运营/管理，权限与表格表单优先）
  - `apps/app/`：Flutter App（iOS/Android，必要时可构建 Web）
- **`services/`**：后端服务（建议 Go-Zero）
  - `gateway/`：网关/聚合层（鉴权、路由、限流、灰度）
  - `user/`：用户/账号/权限（含管理员体系）
  - `cms/`：内容/首页配置/文章等（admin 主要操作）
  - `media/`：上传/图片/附件（简历、封面、头像）
  - `jobs/`：招聘模块
  - `social/`：社交模块
  - `search/`、`notify/`、`realtime/`：按需启用
- **`packages/`**：跨端共享（尽量“无业务”、偏基础设施）
  - `openapi/`：接口契约（单一真源）
  - `sdk-ts/`：给 Web 的 SDK（生成）
  - `sdk-dart/`：给 Flutter 的 SDK（生成）
  - `ui-tokens/`：设计 Token（手工维护或脚本生成）
- **`docs/`**：文档
- **`infra/`**：本地依赖、部署脚本（docker/k8s/terraform）
- **`scripts/`**：仓库级脚本（生成代码、检查、发布）

### 代码放置原则

- **UI 代码放 `apps/`**，业务服务放 `services/`，跨端复用放 `packages/`。
- **接口先行**：优先在 `packages/openapi/` 定义/更新契约，再生成 SDK，客户端只依赖 SDK。
- **设计 Token 先行**：颜色/字号/间距等放 `packages/ui-tokens/`，Web 与 Flutter 各自落地实现但保持一致。

