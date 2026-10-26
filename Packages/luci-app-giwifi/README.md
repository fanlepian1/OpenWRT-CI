# luci-app-giwifi

GIWIFI 校园网自动登录（FanWRT 自用）。

- 菜单：服务 → GIWIFI 自动登录
- 配置：`/etc/config/giwifi`
- 主程序：`/usr/sbin/giwifi-login`（`--once` 单次认证，`--daemon` 常驻）
- 日志：`/var/log/giwifi.log`

实现方式：GET 门户登录页 → 抓取 `#loginForm` 内所有 `input` 的 name/value → 用门户前端同一套
AES-128-CBC（zero padding + base64，密钥默认 `1234567887654321`，IV 取隐藏域 `iv`）加密
`user_account` / `user_password` 表单 → POST `/gportal/Web/loginAction`。

依赖：`curl`、`openssl-util`（AES 由 `openssl enc` 完成，无需额外运行时）。
