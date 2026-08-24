# NVM 全局 CLI 逐版本盘点

仅当全局 CLI 迁移影响集包含 NVM initializer、`NVM_DIR`、NVM Node `bin`，或用户明确要求盘点 NVM 时加载本引用。本文件只补充 NVM 专项决策；通用安全边界、schema、写入时序和确认门沿用调用它的全局 CLI 迁移协议。

## 盘点范围

1. 从已确认的源配置解析 NVM 根；未自定义时使用 `~/.nvm`。
2. 枚举 `versions/node/` 的全部直接子目录。不得只检查当前 `node`、`alias/default` 指向或版本号最大的 prefix。
3. 对每个 Node prefix，只读取 `lib/node_modules` 的顶层及 scoped 顶层 `package.json`、包的 `bin` 映射和 prefix `bin` symlink，确认直接全局包、精确版本与 binaries。
4. 读取一级 NVM alias 只用于解释原激活顺序。排除 npm、Corepack、包管理器本体以及通用协议已排除的项目。

## 形成迁移计划

- 本机 TSV 按 Node prefix 保留每个受影响来源行，包括同一 package/binaries 的多版本来源。
- 同一 package/binaries 的 public TOML 只保留一个经用户确认的规范迁移意图；其他来源不重复生成 public 条目。
- 目标 owner 已有相同 package/binaries 但版本不同时，不得静默忽略源项。只有用户确认目标新版取代旧版后，才在 TSV 中标为 `skipped`；否则保持 `pending` 或 `manual`。
- 不能安全遍历某个 prefix 或无法确认直接安装关系时，按通用协议阻止该 NVM owner 的退役，不得用默认版本的结果代替。
