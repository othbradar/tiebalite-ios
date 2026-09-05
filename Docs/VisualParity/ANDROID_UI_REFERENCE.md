# Android TiebaLite UI 参考锁

## 两种 Android reference

### 协议/API reference

继续使用仓库已有的 `References/TiebaLite-Android` 固定 commit。
不得为了 UI 整改切换其工作树或替换 Proto 来源。

### 最新 UI reference

R00 执行：

```bash
git -C References/TiebaLite-Android fetch origin 4.0-dev
git -C References/TiebaLite-Android rev-parse origin/4.0-dev
```

把 SHA 写入：

```text
Docs/VisualParity/ANDROID_UI_REFERENCE_COMMIT.txt
```

后续只用：

```bash
git -C References/TiebaLite-Android show \
  "$(cat Docs/VisualParity/ANDROID_UI_REFERENCE_COMMIT.txt):<path>"
```

读取最新版 UI 源码。不要 checkout、reset 或修改 submodule。

## 重点源码

- `.../ui/page/main/MainPage.kt`
- `.../ui/page/main/home/HomePage.kt`
- `.../ui/page/main/notifications/NotificationsPage.kt`
- `.../ui/page/main/notifications/list/`
- `.../ui/page/forum/ForumPage.kt`
- `.../ui/page/forum/threadlist/ForumThreadListPage.kt`
- `.../ui/page/forum/threadlist/ForumThreadListViewModel.kt`
- `.../ui/page/thread/ThreadPage.kt`
- `.../ui/page/thread/ThreadViewModel.kt`
- `.../ui/page/subposts/SubPostsPage.kt`
- `.../ui/page/reply/ReplyPage.kt`
- `.../ui/common/` 中的正文、图片和表情 renderer
- `.../ui/widgets/compose/FeedCard.kt`
- `.../utils/` 中头像 URL、表情映射和图片处理

## 许可证边界

Android 项目采用 GPL-3.0，并在 README 中声明仅供学习交流、禁止商业用途。
直接复制的资源、映射或改写代码必须记录来源路径和参考 commit，并在
`THIRD_PARTY_NOTICES.md` 中保留说明。
