============================================================
  U-Hermes 便携版 · 使用说明
  AI Coding Agent，装在 U 盘里，插上即用，完全离线
============================================================

【3 步上手】

  1. 把这个 U 盘插到电脑上（Windows 或 Mac 都行）。

  2. 双击启动：
       Windows → 双击  Windows-Start.bat
       Mac     → 双击  Mac-Start.command
                （第一次若提示"无法打开"，右键 → 打开 → 打开）

  3. 第一次启动会弹出一个文本编辑器，让你填 API Key：
       - 找到其中一行，比如  # DEEPSEEK_API_KEY=sk-xxx
       - 删掉行首的  #  号
       - 把  sk-xxx  换成你自己的 Key
       - 保存，关闭编辑器
     程序就会自动继续启动。


【没有 API Key 怎么办？】

  最简单：注册 DeepSeek（国内直连、便宜）
    https://platform.deepseek.com/api_keys
  拿到 Key 后按上面第 3 步填进去即可。

  或者完全本地、不花钱：在本机装 Ollama，按 .env 里
  "本地 Ollama" 那一段的说明配置。


【常见问题】

  Q: 换了一台电脑，还能用吗？
  A: 能。所有程序和你的数据都在 U 盘里，换电脑直接插上双击就行，
     不用重装。你的配置和会话记录都保存在 U 盘的 data\ 目录里。

  Q: Windows 杀毒软件报警 / Mac 提示"已损坏""无法验证开发者"？
  A: 这是便携程序的常见误报。Windows 选择"仍要运行"；
     Mac 右键 → 打开，或在"系统设置 → 隐私与安全性"里点"仍要打开"。

  Q: 想用网页界面，不想用命令行？
  A: 用文本编辑器打开启动脚本，把最后那行的  hermes  改成
     hermes gateway run，保存后双击启动，然后浏览器访问：
       http://127.0.0.1:8648   （Web 界面）
       http://127.0.0.1:8642   （Gateway API）

  Q: 速度慢？
  A: U 盘读写比硬盘慢，首次启动尤其慢，属正常。若长期使用，
     可以把整个 U-Hermes 文件夹拷到电脑硬盘上，再双击启动脚本。


【我的数据在哪？】

  全部在 U 盘的  data\  目录：
    data\.env        你的 API Key 和配置
    data\sessions\   对话历史
    data\logs\       运行日志
  备份只要拷走 data\ 目录即可。


本程序基于开源项目 Hermes Agent (NousResearch, MIT 协议) 打包。
官网与教程：https://u-hermes.org  ·  https://study.u-hermes.org
============================================================
