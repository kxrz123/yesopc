/// 手机连同一 WiFi 访问本机 **content-api（Go）** 时，填局域网 IP + **8888** 端口。
/// 不要填 Vite/Next 等前端端口；登录接口为 `POST /api/v1/auth/login`。
/// 终端查 IP：`ipconfig getifaddr en0`（无线一般是 en0）
/// 或：`flutter run --dart-define=API_BASE=http://你的IP:8888`
const String defaultApiBaseUrl = 'https://www.yesopc.com';

/// API 基地址（可用 `--dart-define=API_BASE=...` 覆盖）
const String apiBaseUrl = String.fromEnvironment('API_BASE', defaultValue: defaultApiBaseUrl);

