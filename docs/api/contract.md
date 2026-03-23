## API 契约与 SDK 约定

### 目标

- **一个接口真源**：在 `packages/openapi/` 维护契约（OpenAPI 优先）。
- **多端自动生成 SDK**：
  - Web/Node：`packages/sdk-ts/`
  - Flutter：`packages/sdk-dart/`

### 约定

- **统一错误码**：网关与各服务输出一致的错误结构（code/message/details）。
- **统一鉴权方式**：例如 `Authorization: Bearer <token>`。
- **接口版本**：以路径或 header 管控（例如 `/api/v1/...`）。

### 推荐落地流程

1. 在 `packages/openapi/` 增加/修改接口定义（例如 `openapi.yaml`）。
2. 生成 SDK（后续在 `scripts/` 增加一键脚本）。
3. `apps/*` 只依赖生成的 SDK，不手写请求层（或仅封装重试/拦截器）。

