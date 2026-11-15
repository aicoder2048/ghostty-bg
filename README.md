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
bgh                 # 隐藏 / 显示背景图 / hide or show the background
bga                 # 自动轮播：每 5 秒随机换一张，按任意键停 / auto slideshow, any key stops
bgv                 # 欣赏模式：清屏只看图，画面慢慢动 / viewing mode: just the picture, slowly moving
bgf snow            # 动态特效 72 种（8 类 × 9）/ 72 animated effects in 8 sets of 9 (bgf off to stop)
bgm                 # 列出所有命令 / menu of all commands
```

`bgs` 是 `ghostty-bg` 的简写，两个名字是同一个命令。/ `bgs` is short for `ghostty-bg` — same command.

---

## 安装

需要：macOS + Ghostty 1.2 或更新版本。

```bash
curl -fsSL https://raw.githubusercontent.com/aicoder2048/ghostty-bg/main/install.sh | bash
```

安装脚本会做三件事：

1. 把 `ghostty-bg`（简写 `bgs`）和快捷命令 `bgn`、`bgp`、`bgr`、`bg+`、`bg-`、`bgw`、`bgd`、`bgh`、`bgm`、`bga`、`bgf`、`bgv` 放到 `~/.local/bin`；72 个特效文件放到 `~/.local/share/ghostty-bg/fx/`。
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
| `bgh` | 隐藏背景图；再按一次恢复成刚才那张（= `bgs off` / `bgs on`） |
| `bga` | 自动轮播：在当前终端里每隔几秒随机换一张，按任意键停。默认 5 秒，也可以 `bga 30s`、`bga 5m`。它在前台运行，不留后台进程，关掉标签页也就结束了 |
| `bgv` | 欣赏模式：切到一个空白屏幕，只剩背景图（完全不透明），画面像纪录片镜头一样慢慢推近、平移；开着的特效照常。`n` / `p` / `r` 或方向键换图，其他任意键退出，浓度、特效、屏幕内容全部恢复原样 |
| `bgf <名字>` | 动态特效，叠在背景上，8 类共 72 种（见下面「动态特效」）。`bgf` 列出全部，`bgf 动物` 只看一类，`bgf next` / `bgf random` 换，`bgf off` 关掉 |
| `bgm` | 命令菜单：一屏列出所有快捷命令和当前状态 |
| `bgs rm <名字>` | 把图库里的图移到废纸篓，名字见 `bgs list`；不写名字就用 fzf 多选（Tab）。只删图库里的副本，你的原图不受影响 |
| `bgd` | 删掉当前这张，自动换到下一张 |
| `bg+` / `bg-` | 背景图浓一点 / 淡一点（每次 ±0.05） |
| `bgs opacity` | 查看当前浓度；`bgs opacity 0.3` 直接设成 0.3 |
| `bgw` | 显示用到的配置文件和图库位置（= `bgs where`） |
| `bgs init` | 首次设置（安装脚本已自动运行，重复运行也没关系） |
| `bgs help` | 查看帮助 |

### 缩写速记

所有命令都是 `bg`（**b**ack**g**round，背景）加一个字母，字母就是动作的英文首字母：

| 命令 | 字母的意思 | 作用 |
|---|---|---|
| `bgs` | **s**elect | 挑图（也是 `ghostty-bg` 的简写） |
| `bgn` | **n**ext | 下一张 |
| `bgp` | **p**revious | 上一张 |
| `bgr` | **r**andom | 随机一张 |
| `bgh` | **h**ide | 隐藏 / 显示 |
| `bgd` | **d**elete | 删掉当前这张 |
| `bgw` | **w**here | 文件在哪 |
| `bgm` | **m**enu | 命令菜单 |
| `bga` | **a**uto | 自动轮播 |
| `bgf` | e**f**fects | 动态特效 |
| `bgv` | **v**iew | 欣赏模式 |
| `bg+` / `bg-` | 多一点 / 少一点 | 背景图浓一点 / 淡一点 |

忘了也没关系：敲 `bgm`，菜单最下面就有这张速记。

### 动态特效

`bgf <名字>` 会在背景上叠一层会动的效果，`bgf off` 关掉。一共 8 类、每类 9 种，共 72 种：

| 类别 | 特效 |
|---|---|
| 天气 | `drizzle` 细雨 · `hail` 冰雹 · `leaves` 秋叶 · `lightning` 闪电 · `rainbow` 彩虹 · `snow` 雪 · `sunbeams` 阳光 · `tornado` 龙卷风 · `wind` 风 |
| 自然 | `aurora` 极光 · `dandelion` 蒲公英 · `dew` 露珠 · `embers` 火星 · `grass` 草浪 · `lotus` 荷花 · `petals` 花瓣 · `ripples` 涟漪 · `sunflowers` 向日葵 |
| 动物 | `ants` 蚂蚁 · `bats` 蝙蝠 · `bees` 蜜蜂 · `birds` 飞鸟 · `butterflies` 蝴蝶 · `cat` 猫 · `dragonflies` 蜻蜓 · `fireflies` 萤火虫 · `rabbit` 兔子 |
| 海洋 | `bubbles` 气泡 · `dolphins` 海豚 · `fish` 鱼群 · `jellyfish` 水母 · `seahorse` 海马 · `seaweed` 海草 · `shark` 鲨鱼 · `turtle` 海龟 · `whale` 鲸鱼 |
| 节日 | `balloons` 气球 · `confetti` 彩纸 · `fireworks` 烟花 · `gifts` 礼物 · `hearts` 爱心 · `lanterns` 孔明灯 · `lights` 彩灯 · `pumpkins` 南瓜灯 · `sparklers` 仙女棒 |
| 太空 | `blackhole` 黑洞 · `comet` 彗星 · `meteors` 流星 · `nebula` 星云 · `planet` 行星 · `rocket` 火箭 · `satellite` 卫星 · `ufo` 飞碟 · `warp` 星河穿梭 |
| 极客 | `binary` 二进制 · `blocks` 方块 · `circuit` 电路 · `coderain` 代码雨 · `neongrid` 霓虹网格 · `pixels` 像素 · `radar` 雷达 · `snake` 贪吃蛇 · `waveform` 示波器 |
| 奇幻 | `crystals` 水晶 · `dragon` 龙 · `fairies` 小精灵 · `magiccircle` 魔法阵 · `phoenix` 凤凰 · `portal` 传送门 · `runes` 符文 · `sparkles` 魔法火花 · `wisps` 鬼火 |

- `bgf`：按类列出全部；`bgf 动物`（或 `bgf animals`）：只看一类，带说明
- `bgf next` / `bgf prev`：一个个换着看；`bgf random`：随机来一个

- 特效是 Ghostty 用显卡跑的 shader，只往画面上叠加图案，不会扭曲文字。
- 只在当前聚焦的窗口里动，会多用一点 CPU / 显卡；不想要随时 `bgf off`。
- 和你自己配置里的 `custom-shader`（比如光标特效）可以同时用。
- 想自己写：把 `.glsl` 文件放进 `~/.local/share/ghostty-bg/fx/`，`bgf` 就能列出来。每个特效文件开头的 `INTENSITY` 可以调亮度。

### 竖图怎么显示

终端窗口是横的，竖图（宽高比小于 1.2，方图也算）如果铺满窗口，会被上下裁掉一大半。所以：

- **装了 [ImageMagick](https://imagemagick.org)**（`brew install imagemagick`）：`bgs add` 会把竖图做成 16:10 的横版存进图库——照片放中间，两边用同一张图放大、模糊、调暗后填满。你的原图不动。
- **没装，或者设了 `GHOSTTY_BG_BLUR=0`**：原图照常加入，显示时自动改成完整显示（两边是终端底色），不会被裁。

同一张竖图重复添加，会认出来并跳过。

可选依赖：

- [`fzf`](https://github.com/junegunn/fzf)：用来挑图，`brew install fzf`
- [`chafa`](https://hpjansson.org/chafa/)：在 fzf 里预览图片，`brew install chafa`
- [`ImageMagick`](https://imagemagick.org)：把竖图做成两边模糊的横版，`brew install imagemagick`

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
rm ~/.local/bin/{ghostty-bg,bgs,bgn,bgp,bgr,bg+,bg-,bgw,bgd,bgh,bgm,bga,bgf,bgv}
rm -r ~/.local/share/ghostty-bg
```

再从 Ghostty 配置里删掉 `# --- ghostty-bg ---` 下面那几行；图库目录 `backgrounds/` 和 `background.ghostty` 按需删除（`bgw` 可以看到它们在哪）。

---

## English

**Install** (macOS, Ghostty 1.2+):

```bash
curl -fsSL https://raw.githubusercontent.com/aicoder2048/ghostty-bg/main/install.sh | bash
bgs add ~/Pictures/some-photo.jpg
```

The installer puts `ghostty-bg` (short name `bgs`) and the shortcuts `bgn` / `bgp` / `bgr` / `bg+` / `bg-` / `bgw` / `bgd` / `bgh` / `bgm` / `bga` / `bgf` / `bgv` in `~/.local/bin` (and 72 effect shaders in `~/.local/share/ghostty-bg/fx`), then runs `ghostty-bg init`, which backs up your Ghostty config and appends `config-file = ?background.ghostty` (plus a default opacity of 0.2 and `cover` fit, unless you already set them). If your image library is empty, it also adds three AI-generated sample images (see [`samples/`](samples/)) so `bgn` works right away; remove them any time with `bgs rm`.

**Commands** (`bgs` = `ghostty-bg`): `bgs add <image|folder> [...]` (a folder adds every PNG/JPG in it; images already in the library are skipped), `bgs list`, `bgs off` / `bgs on`, `bgs rm <name>...` (moves library images to the Trash; no name = pick with fzf), `bgs init`, and plain `bgs` to pick with fzf (preview via chafa if installed). Shortcuts: `bgn` next, `bgp` previous, `bgr` random, `bg+` / `bg-` image opacity ±0.05 (or `bgs opacity 0.3`), `bgw` where the files are, `bgd` delete the current image, `bgh` hide / show the background, `bgm` menu of all commands, `bga` auto slideshow in the foreground (a random image every 5s, or `bga 30s` / `bga 5m`; any key stops, no background process).

**Effects:** `bgf <name>` layers an animated shader over the background; `bgf off` stops it. `bgf` lists them by category, `bgf <category>` shows one category with descriptions, `bgf next` / `bgf prev` / `bgf random` switch. 72 effects in 8 sets of 9 — weather: `drizzle`, `hail`, `leaves`, `lightning`, `rainbow`, `snow`, `sunbeams`, `tornado`, `wind`; nature: `aurora`, `dandelion`, `dew`, `embers`, `grass`, `lotus`, `petals`, `ripples`, `sunflowers`; animals: `ants`, `bats`, `bees`, `birds`, `butterflies`, `cat`, `dragonflies`, `fireflies`, `rabbit`; ocean: `bubbles`, `dolphins`, `fish`, `jellyfish`, `seahorse`, `seaweed`, `shark`, `turtle`, `whale`; festival: `balloons`, `confetti`, `fireworks`, `gifts`, `hearts`, `lanterns`, `lights`, `pumpkins`, `sparklers`; space: `blackhole`, `comet`, `meteors`, `nebula`, `planet`, `rocket`, `satellite`, `ufo`, `warp`; geek: `binary`, `blocks`, `circuit`, `coderain`, `neongrid`, `pixels`, `radar`, `snake`, `waveform`; fantasy: `crystals`, `dragon`, `fairies`, `magiccircle`, `phoenix`, `portal`, `runes`, `sparkles`, `wisps`. The shaders only draw on top, so text stays sharp; they animate in the focused window and work alongside your own `custom-shader` lines. Add your own `.glsl` files to `~/.local/share/ghostty-bg/fx/`.

**Viewing mode:** `bgv` switches to a blank screen showing only the picture at full opacity, with a slow camera-like push and drift (a motion shader that is safe only because no text is on screen). `n` / `p` / `r` or the arrow keys change the image; any other key leaves and restores opacity, effect and screen.

**Portrait images:** anything narrower than 1.2:1 would be cropped heavily in a wide terminal. With ImageMagick installed, `bgs add` stores a 16:10 version with the photo centered and blurred sides (your original is untouched); without it, or with `GHOSTTY_BG_BLUR=0`, the image is added as is and shown whole (`background-image-fit = contain`).

**Glossary** — every name is `bg` (background) plus one letter for the action: `bgs` **s**elect, `bgn` **n**ext, `bgp` **p**revious, `bgr` **r**andom, `bgh` **h**ide, `bgd` **d**elete, `bgw` **w**here, `bgm` **m**enu, `bga` **a**uto (slideshow), `bgf` e**f**fects, `bgv` **v**iew, `bg+` / `bg-` more / less opacity. Forgot one? `bgm` shows them all.

**Language:** messages are in Chinese when `LANG` starts with `zh`, English otherwise. Override with `export GHOSTTY_BG_LANG=en` (or `zh`).

**How it works:** `ghostty-bg` rewrites only the one-line `background.ghostty` file, then sends `SIGUSR2` to Ghostty, which reloads its config.

**Uninstall:** `rm ~/.local/bin/{ghostty-bg,bgs,bgn,bgp,bgr,bg+,bg-,bgw,bgd,bgh,bgm,bga,bgf,bgv}` and `rm -r ~/.local/share/ghostty-bg`, then remove the `# --- ghostty-bg ---` block from your Ghostty config.

## License

Code: MIT. The sample images in `samples/` (sunset over the sea, atoll aerial view, African savanna) are AI-generated with Black Forest Labs' FLUX models.

代码：MIT。`samples/` 里的三张样图（海上日落、环礁航拍、非洲草原）是用 Black Forest Labs 的 FLUX 模型 AI 生成的。
