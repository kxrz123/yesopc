## services（后端服务）

该目录存放后端微服务（建议 Go-Zero）。

### 建议服务划分

- `gateway`：统一鉴权、路由、限流、灰度、（可选）BFF 聚合
- `user`：用户体系与管理员体系（RBAC）
- `cms`：内容与首页配置（后台主要操作）
- `media`：上传/素材/附件
- `jobs`：招聘模块
- `social`：社交模块
- `search` / `notify` / `realtime`：按需启用（搜索/通知/实时）

### 约定

- 服务接口契约建议统一放到 `packages/openapi/`，由契约生成 SDK 给前端/客户端使用。

