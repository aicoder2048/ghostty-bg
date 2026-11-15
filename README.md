# ghostty-bg

一条命令切换 [Ghostty](https://ghostty.org) 终端的背景图，切完立即生效，不用手动重新加载配置。

Switch the background image of the [Ghostty](https://ghostty.org) terminal with one command — it takes effect immediately, no manual config reload. **macOS only.**

```bash
bgn                 # 换下一张 / next image
ghostty-bg          # 用 fzf 挑一张（带预览）/ pick one with fzf (with preview)
```

---

## 安装

需要：macOS + Ghostty 1.2 或更新版本。

```bash
curl -fsSL https://raw.githubusercontent.com/aicoder2048/ghostty-bg/main/install.sh | bash
```

安装脚本会做三件事：

1. 把 `ghostty-bg` 和 `bgn` 两个命令放到 `~/.local/bin`。
2. 运行 `ghostty-bg init`：先**备份**你的 Ghostty 配置，再在末尾加上一行 `config-file = ?background.ghostty`（外加默认透明度 0.2、铺满窗口；你已经设过的不会重复添加）。
3. 建好图库目录 `backgrounds/`，就在你的 Ghostty 配置文件旁边。

然后加第一张图：

```bash
ghostty-bg add ~/Pictures/some-photo.jpg
```

> 如果提示 `~/.local/bin` 不在 PATH 里，按提示把那行 `export PATH=...` 加进 `~/.zshrc`，再开一个新终端。

不想用 `curl | bash`？手动安装：

```bash
git clone https://github.com/aicoder2048/ghostty-bg.git
cd ghostty-bg && ./install.sh
```

## 用法

| 命令 | 作用 |
|---|---|
| `ghostty-bg add <图片>` | 把图片复制进图库并设为背景（PNG / JPG） |
| `bgn` | 下一张（等于 `ghostty-bg next`） |
| `ghostty-bg next` / `prev` | 下一张 / 上一张 |
| `ghostty-bg random` | 随机一张 |
| `ghostty-bg` | 用 fzf 挑一张，右侧预览图片 |
| `ghostty-bg list` | 列出图库，`*` 是当前这张 |
| `ghostty-bg off` | 关掉背景图 |
| `ghostty-bg where` | 显示用到的配置文件和图库位置 |
| `ghostty-bg init` | 首次设置（安装脚本已自动运行，重复运行也没关系） |

可选依赖：

- [`fzf`](https://github.com/junegunn/fzf)：用来挑图，`brew install fzf`
- [`chafa`](https://hpjansson.org/chafa/)：在 fzf 里预览图片，`brew install chafa`

调透明度、显示方式：直接改你的 Ghostty 配置里的 `background-image-opacity`（0.1–0.3 比较合适）和 `background-image-fit`（`cover` 铺满 / `contain` 完整显示）。

## 原理

- 你的 Ghostty 配置通过 `config-file = ?background.ghostty` 引入一个只有一行的小文件。`ghostty-bg` 只改写这个小文件，不会碰你的主配置。
- 改完后给 Ghostty 发 `SIGUSR2` 信号，Ghostty 收到就会重新加载配置。
- 图片都复制到图库目录里，原图被移动或删除也不影响。

## 卸载

```bash
rm ~/.local/bin/ghostty-bg ~/.local/bin/bgn
```

再从 Ghostty 配置里删掉 `# --- ghostty-bg ---` 下面那几行；图库目录 `backgrounds/` 和 `background.ghostty` 按需删除（`ghostty-bg where` 可以看到它们在哪）。

---

## English

**Install** (macOS, Ghostty 1.2+):

```bash
curl -fsSL https://raw.githubusercontent.com/aicoder2048/ghostty-bg/main/install.sh | bash
ghostty-bg add ~/Pictures/some-photo.jpg
```

The installer puts `ghostty-bg` and `bgn` in `~/.local/bin`, then runs `ghostty-bg init`, which backs up your Ghostty config and appends `config-file = ?background.ghostty` (plus a default opacity of 0.2 and `cover` fit, unless you already set them).

**Commands:** `add <image>`, `next` (or just `bgn`), `prev`, `random`, `list`, `off`, `where`, `init`, and no arguments to pick with fzf (preview via chafa if installed).

**How it works:** `ghostty-bg` rewrites only the one-line `background.ghostty` file, then sends `SIGUSR2` to Ghostty, which reloads its config.

**Uninstall:** remove the two commands from `~/.local/bin` and the `# --- ghostty-bg ---` block from your Ghostty config.

## License

MIT
