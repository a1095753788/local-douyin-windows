# 本地抖音 · Windows 桌面版

把本地视频用「一条一屏、上下滑」的方式刷。移植自 Android 版
[`lxkongjian/local_douyin`](https://github.com/a1095753788/lxkongjian/tree/master/local_douyin)，
功能对齐，但交互按桌面重做了一遍。

---

## 下载 / 安装

两种形态，功能完全一样：

**① 安装版（推荐）** —— 双击 `LocalDouyin-Setup-1.0.0.exe` 走安装向导：

- 可选「为所有用户安装」（装到 `C:\Program Files`，需管理员）或「仅为我安装」
  （装到 `%LOCALAPPDATA%\Programs`，不需要管理员）
- 自动创建开始菜单项 + 桌面快捷方式
- 出现在「设置 → 应用」里，可以正常卸载
- 卸载时会问要不要一并清除使用记录（视频文件本身永远不会动）

**② 绿色版** —— 解压 `LocalDouyin.zip`，直接跑 `local_douyin_win.exe`。

整个 `LocalDouyin` 文件夹拷到任何 Windows 10/11 x64 机器上都能跑，
不需要装 .NET / VC 运行库 / ffmpeg。

> 两个版本共用同一份数据目录，可以随时互换，记录不会丢。

## 从源码构建

```bat
flutter pub get
flutter build windows --release
tool\package.bat            :: 产出 dist\LocalDouyin（含内置 ffmpeg）
tool\build-installer.bat    :: 再打成 dist\LocalDouyin-Setup-1.0.0.exe
```

环境：Flutter 3.47+ / Dart 3.13+ / Visual Studio 2022（Desktop development with C++）。
打安装包还需要 [Inno Setup 6](https://jrsoftware.org/isdl.php)。

> 仓库里不含 `libmpv-2.dll`（30MB）和 `ffmpeg.exe`（87MB）。
> `package.bat` 会从 `C:\FFmpeg\...\bin` 或 `vendor\ffmpeg\` 自动找 ffmpeg 拷进去；
> `libmpv-2.dll` 由 `media_kit_libs_windows_video` 在 `flutter build` 时自动带入。

---

## 功能

### 1. 文件夹管理

- 添加任意目录，**递归**扫描子目录
- 支持 **39 种容器格式**（手机版 12 种）：

  `mp4 m4v mov qt mkv webm avi divx wmv asf flv f4v swf ts m2ts mts
  mpg mpeg mpe m1v m2v vob 3gp 3g2 ogv ogm rm rmvb mxf wtv nut dv
  mj2 amv ivf h264 h265 hevc y4m`

- 自动生成缩略图（ffmpeg 截帧，并发 8 路）
- 删除时可选「只移除记录」或「连文件一起删（进回收站）」
- 文件监视：往目录里丢新视频，5 秒后自动入库
- 启动时自动清理「文件已经不在了」的记录（只处理路径还在的文件夹，
  移动硬盘没插不会误删）

### 2. 播放

- 一条一屏竖向切换：**滚轮 / ↑↓ / J K / 鼠标上下拖**
- 软解 + 硬解都行，默认 **auto-safe**（能硬解就硬解，不行自动回落软解）
- 0.5 ~ 2.0 倍速
- 窗口失焦 / 切页 自动暂停
- **断点续播**：看到一半退出，下次从断点继续（距结尾 3 秒内不算）
- 只在播放时防息屏
- 播完默认自动下一条（也可设成单条循环 / 播完暂停）

### 3. 交互

- 点赞、收藏、不感兴趣（可在「我的」一键重置全部）
- 评论 + 弹幕：评论勾上「作为弹幕」就会在对应时间点从画面飘过
- 右键菜单：在资源管理器显示、用系统播放器打开、复制路径、删除……

### 4. 推荐算法

与手机版公式一致，修了 6 个 bug：

| 环节 | 规则 |
|---|---|
| 过滤层 | 不感兴趣、**已收藏** 直接排除（收藏只在收藏页出现） |
| 打分 | 点赞 ×2；播放次数 ×0.5 |
| | 观看进度 <20% −10 / 20~50% +2 / 50~90% +5 / ≥90% +15 |
| | 加入时间 24h 内 +20 / 7 天内 +10 / 30 天内 +5 |
| | 文件夹亲和度 0~10（该文件夹平均播放热度归一化） |
| | 从未播放过 +10；随机扰动 0~2 |
| 排序 | 按分数降序，前 70% 为利用池，后 30% 为探索池 |
| 探索 | ε-greedy，15% 概率从探索池取 |
| 多样性 | 同一文件夹连续不超过 2 条 |

修掉的 bug：

1. `(len * 0.7).clamp(5, len)` 在候选 <5 条时抛 `ArgumentError`
2. 会话去重队列只进不出 → 池子耗尽后永久锁死（`_noMore`）
3. 「收藏 +10」是死代码（过滤层已排除收藏，永远走不到）
4. 收藏页只在 `initState` 加载一次，取消收藏后不刷新
5. 界面显示 `folderId`（UUID）而不是文件夹名
6. 新鲜度锚点用 `addedAt`，导致首次全量导入时所有老视频都「刚加的 +20」

### 5. 页面

首页（推荐 / 收藏）· 文件夹（左列表 + 右网格）· 发现（搜索 + 筛选）· 我的（统计 + 全部设置 + 维护）

---

## 快捷键

| 键 | 作用 |
|---|---|
| `空格` / 单击画面 | 播放 / 暂停 |
| `↓` `J` / 滚轮下滚 | 下一条 |
| `↑` `K` / 滚轮上滚 | 上一条 |
| `←` `→` | 后退 / 前进 10 秒 |
| `L` | 点赞 |
| `F` | 收藏 |
| `I` | 不感兴趣 |
| `C` | 评论 / 弹幕面板 |
| `D` | 弹幕开关 |
| `Tab` | 视频信息面板 |
| `M` | 静音 |
| `[` `]` | 减速 / 加速 0.1x |
| `1`~`6` | 倍速 0.5 / 0.75 / 1.0 / 1.25 / 1.5 / 2.0 |
| `F11` | 全屏 |
| `Ctrl+O` | 添加文件夹 |
| `Ctrl+R` | 重扫全部 |
| `Esc` | 关闭面板 |

---

## 数据位置

```
%APPDATA%\com.localdouyin\local_douyin_win\LocalDouyin\
├── local_douyin.db       SQLite（schema v6，兼容手机版 v2~v5 直接升级）
├── thumbnails\           缩略图（约 12KB/张）
└── app.log               运行日志（出问题发这个）
```

全部本机，不联网、不上传。

---

## 为什么不需要转码

libmpv 内部就是一份完整 FFmpeg（`libmpv-2.dll` 里静态链着），
所有容器和编码它都能直接解。手机版用 `video_compress` 转码是因为
Android 的 `video_player` 只认 mp4/h264，桌面上这个限制不存在。

实测 5 种容器全部解码成功（见 `PLAN.md` 第 16 章）：

| 文件 | 容器 | 编码 | 实际解码器 |
|---|---|---|---|
| t_h264.mp4 | mov/mp4 | h264 | d3d11va-copy（硬解） |
| t_mpeg4.avi | avi | mpeg4 | no（软解回落） |
| t_h264.flv | flv | h264 | d3d11va-copy |
| t_h264.ts | mpegts | h264 | d3d11va-copy |
| t_mpeg2.vob | mpeg | mpeg2video | no（软解回落） |

`auto-safe` 的自动回落是这套方案能成立的关键——强制硬解的话
mpeg4 / mpeg2video 会直接失败。

---

## ffmpeg 的定位

只用于两件跟播放无关的事：**读时长/分辨率**、**截缩略图**。

查找顺序：`程序目录\ffmpeg\ffmpeg.exe` → `程序目录\ffmpeg.exe` → `PATH` → 用户在设置里指定。

找不到也能正常播放，只是没有缩略图、时长要等首次播放时由播放器补上。

---

## 测试

```bat
flutter test
```

- `recommendation_test.dart` —— 推荐算法 9 项（过滤 / 打分 / 探索 / 多样性 / 池枯竭）
- `layout_test.dart` —— 1280×800、900×600、开面板等场景无布局溢出
- `platform_test.dart` —— 回收站 FFI、字节格式化
- `ffmpeg_smoke_test.dart` —— 真实调用 ffmpeg 做定位 / 探测 / 截帧体检

---

## 与手机版刻意不同的地方

| 项 | 手机版 | 桌面版 | 原因 |
|---|---|---|---|
| 窗口 | 竖屏全屏 | 1280×800 横向，记忆位置 | 桌面横向空间够 |
| 解码 | 强制软解 | `auto-safe` 自动判断 | 硬解省电、省 CPU |
| 删文件 | `File.delete()` 不可逆 | 回收站 | 一次可能删几百个 |
| 转码 | 有代码无入口（死代码） | 整个删掉 | 不需要 |
| 切换视频 | dispose + new Player，黑屏 200~400ms | 单 Player 复用 | 秒切 |
| 播完 | `PlaylistMode.loop` 死循环同一条 | 默认下一条 | 手机版是 bug |
| 播放计数 | 一可见就 +1 | 看满 3 秒或 10% 才 +1 | 一可见就 +1 会让推荐失真 |
| 息屏 | 一开 App 就永久不休眠 | 只在播放时 | — |
| 断点续播 | README 说有，代码没有 | 真的实现了 | — |
| 扫描 | 同步阻塞，串行缩略图 | 先入库后补图，全程进度 | — |
| 查重 | 只比 path | `path + size + mtime` 三元组 | 识别换盘符 |

---

## 目录结构

```
lib/
├── core/          常量、主题、路径、日志
├── data/          SQLite（schema v6）、模型、仓储
├── platform/      ffmpeg 封装、回收站（裸 FFI）、窗口
├── services/      扫描、推荐算法、文件监视
├── providers/     Provider 状态层
├── screens/       外壳 + 四个页面
└── widgets/       视频舞台、弹幕层、播放条、卡片……
tool/
├── package.bat            编译 + 打包绿色版
├── build-installer.bat    打安装包
├── installer.iss          Inno Setup 脚本
└── ChineseSimplified.isl  简体中文语言包（281 条，全译）
test/               推荐算法 / 布局 / 平台 / ffmpeg 体检，共 21 项
```

## 许可

[MIT](LICENSE)

原 Android 版：[a1095753788/lxkongjian](https://github.com/a1095753788/lxkongjian/tree/master/local_douyin)
