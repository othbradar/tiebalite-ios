# Resources 与 Fixture 约束

- 生产资源使用语义命名和正确浅/深色变体；不使用百度官方商标、图标或误导性品牌素材。
- 测试 fixture 与生产资源分目录，Release target 不打包无必要的大型 fixture/录屏。
- 图片/Proto/JSON fixture 必须有来源、用途、脱敏和更新说明；未知版权素材不得加入。
- 资源名称、顺序和内容保持确定性，不嵌入用户绝对路径、设备标识或真实账号信息。
- 修改资源后验证 target membership、包体影响和缺失资源失败路径。
