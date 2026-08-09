# Stage 3：旧 Intel 软件退役需求

> 状态：轻量阶段需求<br>
> 日期：2026-08-09<br>
> 执行位置：已完成 Stage 2 的 Apple Silicon 机器

## 1. 阶段定位

本阶段根据 personal/company 的 Brewfile、tooling、mise/uv 和插件期望状态，退役已有 ARM 替代或已明确淘汰的旧 Intel 软件与 runtime。它不再只等同于卸载 Intel Homebrew。

Stage 3 必须由用户单独进入，不能由普通 `install.sh` 自动触发。

## 2. 目标

1. 只读盘点仍存在的受管理 Intel 项。
2. 验证对应 ARM 替代的路径、版本和架构。
3. 明确保留未知项目、项目依赖和未处理数据。
4. 通过普通 `y/N` 确认执行已预览的退役动作。
5. 验证最终 Zsh、PATH、软件和残留状态。

## 3. 非目标

- 不安装或重新选择 ARM 替代；替代缺失时返回 Stage 2。
- 不删除项目级 runtime、venv 或依赖。
- 不自动停止服务或迁移数据。
- 不递归删除 `/usr/local`，不整体改变其 owner。
- 不删除未被管理器识别或未在预览中展示的内容。
- 不建立长期状态系统。

## 4. 前置条件

- 当前进程是原生 `arm64`；
- `./install.sh verify` 通过；
- public/company 配置与 Stage 2 安装时一致；
- 关键命令解析到 ARM 或受支持的 Universal 二进制；
- 用户明确要求进入退役阶段。

任何单项不满足时，只阻止对应项目；如果会影响 shell、Homebrew 或全局正确性，则阻止整个退役。

## 5. 只读预览

运行：

```text
./install.sh retire
```

该命令不得产生软件或文件变更。它盘点：

- Intel Homebrew tap、formula、cask 和 service；
- 由旧 Intel Homebrew 安装但已在 personal/company Brewfile 中有 ARM 期望的项目；
- mise 管理的旧 Intel runtime 或全局工具版本；
- uv 管理且明确属于全局工具的旧 Intel Python；
- 旧插件二进制或 helper；
- `/usr/local/var`、`/usr/local/etc` 和其他已知数据路径；
- 项目目录引用的 runtime、venv 和工具版本。

## 6. 退役分类

每个项目只进入以下一种结果：

| 分类 | 含义 | 是否可删除 |
|---|---|---|
| ARM 已替代 | ARM 路径、版本和架构验证通过 | 是 |
| 明确淘汰 | 用户或 Stage 0 已明确不再需要 | 是 |
| 项目依赖 | 仍被项目配置、venv 或任务引用 | 否 |
| 数据待处理 | 存在 service、数据库或 GUI 数据 | 否 |
| 未知 | 所有权、用途或替代关系不清楚 | 否 |

不能只依据同名命令存在就判定“ARM 已替代”；必须检查实际路径和架构。

## 7. 预览内容

`retire` 至少展示：

- 待删除的旧 Intel 项；
- 对应 ARM 替代路径、版本和架构；
- 明确淘汰的理由；
- 保留的项目依赖；
- 未处理的 service/data；
- `/usr/local` 中明确保留和未知的内容；
- 执行后验证命令。

如果没有可安全删除的项目，应成功结束并说明无需执行 `--apply`。

## 8. 正式执行

运行：

```text
./install.sh retire --apply
```

执行要求：

1. stdin/stdout 必须连接真实终端；
2. 重新盘点状态，确认与刚展示的预览一致；
3. 再次展示最终删除和保留摘要；
4. 使用默认 `N` 的普通 `y/N` 确认；
5. 输入不是明确 `y` 时无变更退出；
6. 只执行最终摘要中的退役动作；
7. 使用对应管理器删除旧 Intel 软件或全局 runtime；
8. 需要退役整个 Intel Homebrew 时，使用已审查的 Homebrew 官方卸载机制，不使用 `curl | shell`；
9. 保留所有未知、项目依赖和数据待处理内容；
10. 执行最终验证。

不逐项询问，用户通过最终总清单一次确认。

## 9. 删除边界

- Homebrew：只处理已分类且有 ARM 替代或明确淘汰的 formula/cask；运行中的 service 阻止对应删除。
- mise：只处理全局范围、架构为 Intel 且不被项目引用的旧版本。
- uv：只处理明确属于全局工具且不被项目/venv 引用的旧 Intel Python。
- 插件：只处理由当前插件声明替代、且不再加载的旧二进制或 helper。
- `/usr/local`：只处理管理器明确拥有且已展示的路径；其他内容原地保留。

## 10. 验证

退役后运行与 `install.sh verify` 等价的基础检查，并额外验证：

```text
arch
command -v brew
brew --prefix
command -v <关键命令>
file <关键二进制>
./install.sh verify
./install.sh retire
```

结果必须满足：

- shell 启动无错误；
- PATH 无活动 Intel Homebrew；
- 关键替代命令来自 ARM 或 Universal 路径；
- 已删除项目不再被配置引用；
- 再次 `retire` 只显示保留项、阻断项或“无需退役”；
- 未知和数据目录没有被误删。

## 11. 失败处理

- 执行前状态变化：取消并重新运行只读预览。
- 非 TTY 或用户输入 `N`：无变更退出。
- 单个删除失败：停止后续相关动作，报告已完成和未完成项。
- ARM 替代验证失败：保留旧 Intel 项，返回 Stage 2 修复。
- 部分退役后失败：验证 ARM 环境仍可用，并提供定向人工处理建议；不自动重装 Intel 软件。

## 12. 完成条件

- [ ] 用户先运行了只读 `retire`；
- [ ] 所有待删除项有 ARM 替代或明确淘汰结论；
- [ ] 项目依赖、未知项目和未处理数据均被保留；
- [ ] 正式命令在真实终端使用默认 `N` 的 `y/N` 确认；
- [ ] 没有递归删除或整体修改 `/usr/local`；
- [ ] Homebrew、mise、uv 和插件退役遵守各自边界；
- [ ] 最终 Zsh、PATH、版本和架构验证通过；

完成状态是“已安全退役当前可确认的旧 Intel 软件”；仍被保留的项目应继续显示在下一次预览中。

## 13. 未来 Skill 接口

未来 Skill 名：`stage-3-intel-homebrew-retirement`。

这是低自由度 Skill，只编排 `retire 预览 → 用户 y/N → retire --apply → verify`。它不得把普通安装意图提升为退役意图，也不得绕过未知项目、项目依赖和数据保护。
