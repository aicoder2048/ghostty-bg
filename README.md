# ghostty-bg

一条命令切换 [Ghostty](https://ghostty.org) 终端的背景图，切完立即生效，不用手动重新加载配置。

Switch the background image of the [Ghostty](https://ghostty.org) terminal with one command — it takes effect immediately, no manual config reload. **macOS only.**

```bash
bgn                 # 下一张 / next image
bgp                 # 上一张 / previous image
bgr                 # 随机一张 / random image
bgs                 # 用 fzf 挑一张（带预览）/ pick one with fzf (with preview)
bg+ / bg-           # 背景图浓一点 / 淡一点 / stronger / fainter
bgw                 # 配置文件和图库在哪 / where the files are
bgd                 # 删掉当前这张（移到废纸篓）/ delete the current image (to Trash)
```

`bgs` 是 `ghostty-bg` 的简写，两个名字是同一个命令。/ `bgs` is short for `ghostty-bg` — same command.

---

## 安装

需要：macOS + Ghostty 1.2 或更新版本。

```bash
curl -fsSL https://raw.githubusercontent.com/aicoder2048/ghostty-bg/main/install.sh | bash
```

安装脚本会做三件事：

1. 把 `ghostty-bg`（简写 `bgs`）和快捷命令 `bgn`、`bgp`、`bgr`、`bg+`、`bg-`、`bgw`、`bgd` 放到 `~/.local/bin`。
2. 运行 `ghostty-bg init`：先**备份**你的 Ghostty 配置，再在末尾加上一行 `config-file = ?background.ghostty`（外加默认透明度 0.2、铺满窗口；你已经设过的不会重复添加）。
3. 建好图库目录 `backgrounds/`，就在你的 Ghostty 配置文件旁边。
4. 如果图库是空的，自动放进 3 张样图（AI 生成的风景，见 [`samples/`](samples/)），装完马上就能 `bgn` 体验。已经有图的话不会动。

加你自己的图（可以是单张、多张，或者整个文件夹）：

```bash
bgs add ~/Pictures/some-photo.jpg
bgs add ~/Pictures/壁纸/          # 加入文件夹里所有 PNG/JPG（不含子文件夹）
```

样图不需要的话：`bgs rm sunset-sea.jpg atoll-aerial.jpg savanna.jpg`（移到废纸篓）。

> 如果提示 `~/.local/bin` 不在 PATH 里，按提示把那行 `export PATH=...` 加进 `~/.zshrc`，再开一个新终端。

不想用 `curl | bash`？手动安装：

```bash
git clone https://github.com/aicoder2048/ghostty-bg.git
cd ghostty-bg && ./install.sh
```

## 用法

下表里的 `bgs` 都可以写成全名 `ghostty-bg`。

| 命令 | 作用 |
|---|---|
| `bgs add <图片或文件夹>` | 复制进图库并设为背景（PNG / JPG）；文件夹会加入里面所有图片，可以一次给多个；图库里已有的同一张图会自动跳过 |
| `bgn` | 下一张（= `bgs next`） |
| `bgp` | 上一张（= `bgs prev`） |
| `bgr` | 随机一张（= `bgs random`） |
| `bgs` | 用 fzf 挑一张，右侧预览图片 |
| `bgs list` | 列出图库，`*` 是当前这张 |
| `bgs off` | 关掉背景图 |
| `bgs rm <名字>` | 把图库里的图移到废纸篓，名字见 `bgs list`；不写名字就用 fzf 多选（Tab）。只删图库里的副本，你的原图不受影响 |
| `bgd` | 删掉当前这张，自动换到下一张 |
| `bg+` / `bg-` | 背景图浓一点 / 淡一点（每次 ±0.05） |
| `bgs opacity` | 查看当前浓度；`bgs opacity 0.3` 直接设成 0.3 |
| `bgw` | 显示用到的配置文件和图库位置（= `bgs where`） |
| `bgs init` | 首次设置（安装脚本已自动运行，重复运行也没关系） |
| `bgs help` | 查看帮助 |

可选依赖：

- [`fzf`](https://github.com/junegunn/fzf)：用来挑图，`brew install fzf`
- [`chafa`](https://hpjansson.org/chafa/)：在 fzf 里预览图片，`brew install chafa`

提示语言：中文环境（`LANG` 以 `zh` 开头）自动显示中文，否则显示英文。也可以在 `~/.zshrc` 里指定：

```bash
export GHOSTTY_BG_LANG=zh   # 或 en
```

浓度：用 `bg+` / `bg-` 或 `bgs opacity 0.3` 调整，0.1–0.3 比较合适（浅色图调低，深色图可以调高）。设的值写在 `background.ghostty` 里，会覆盖主配置的 `background-image-opacity`。

显示方式：改你的 Ghostty 配置里的 `background-image-fit`（`cover` 铺满 / `contain` 完整显示）。

## 原理

- 你的 Ghostty 配置通过 `config-file = ?background.ghostty` 引入一个只有一行的小文件。`ghostty-bg` 只改写这个小文件，不会碰你的主配置。
- 改完后给 Ghostty 发 `SIGUSR2` 信号，Ghostty 收到就会重新加载配置。
- 图片都复制到图库目录里，原图被移动或删除也不影响。

## 卸载

```bash
rm ~/.local/bin/{ghostty-bg,bgs,bgn,bgp,bgr,bg+,bg-,bgw,bgd}
```

再从 Ghostty 配置里删掉 `# --- ghostty-bg ---` 下面那几行；图库目录 `backgrounds/` 和 `background.ghostty` 按需删除（`bgw` 可以看到它们在哪）。

---

## English

**Install** (macOS, Ghostty 1.2+):

```bash
curl -fsSL https://raw.githubusercontent.com/aicoder2048/ghostty-bg/main/install.sh | bash
bgs add ~/Pictures/some-photo.jpg
```

The installer puts `ghostty-bg` (short name `bgs`) and the shortcuts `bgn` / `bgp` / `bgr` / `bg+` / `bg-` / `bgw` / `bgd` in `~/.local/bin`, then runs `ghostty-bg init`, which backs up your Ghostty config and appends `config-file = ?background.ghostty` (plus a default opacity of 0.2 and `cover` fit, unless you already set them). If your image library is empty, it also adds three AI-generated sample images (see [`samples/`](samples/)) so `bgn` works right away; remove them any time with `bgs rm`.

**Commands** (`bgs` = `ghostty-bg`): `bgs add <image|folder> [...]` (a folder adds every PNG/JPG in it; images already in the library are skipped), `bgs list`, `bgs off`, `bgs rm <name>...` (moves library images to the Trash; no name = pick with fzf), `bgs init`, and plain `bgs` to pick with fzf (preview via chafa if installed). Shortcuts: `bgn` next, `bgp` previous, `bgr` random, `bg+` / `bg-` image opacity ±0.05 (or `bgs opacity 0.3`), `bgw` where the files are, `bgd` delete the current image.

**Language:** messages are in Chinese when `LANG` starts with `zh`, English otherwise. Override with `export GHOSTTY_BG_LANG=en` (or `zh`).

**How it works:** `ghostty-bg` rewrites only the one-line `background.ghostty` file, then sends `SIGUSR2` to Ghostty, which reloads its config.

**Uninstall:** `rm ~/.local/bin/{ghostty-bg,bgs,bgn,bgp,bgr,bg+,bg-,bgw,bgd}`, then remove the `# --- ghostty-bg ---` block from your Ghostty config.

## License

Code: MIT. The sample images in `samples/` (sunset over the sea, atoll aerial view, African savanna) are AI-generated with Black Forest Labs' FLUX models.

代码：MIT。`samples/` 里的三张样图（海上日落、环礁航拍、非洲草原）是用 Black Forest Labs 的 FLUX 模型 AI 生成的。
