如何使用 (一行命令)
假设您已经将上述代码保存到了 GitHub 仓库 yourname/sap-bas-proxy 中，文件名为 setup.sh。

在 SAP BAS 的终端中，只需执行以下命令：

bash
# 语法:
# curl -sL <Raw_File_Url> | bash -s -- -t <你的Token> -d <你的域名> [-u 自定义UUID]

curl -sL https://raw.githubusercontent.com/yourname/sap-bas-proxy/main/setup.sh | bash -s -- -t eyJhIjoi... -d sap.example.com -u ee84020a-1323-4c9b-a386-d10742ee1ebd
参数说明：

-t: 必须。Cloudflare Tunnel 的 Token。

-d: 必须。您在 Cloudflare Dashboard 中绑定的完整域名 (例如 sap.test.com)。脚本需要用它来生成 VLESS 链接。

-u: 可选。如果您想指定特定的 UUID，可以使用此参数。如果不填，脚本会自动生成一个随机 UUID。

脚本功能详解
依赖检查：自动下载 xray 和 cloudflared 二进制文件，无需 apt-get (避免权限问题)。

配置生成：自动写入 config.json，监听 0.0.0.0:8080，路径 /ray。

静默运行：创建 run.sh 脚本，使用 nohup 后台运行进程。

自动重启 (.bashrc)：将启动逻辑写入 ~/.bashrc。只要您重新打开终端或重启 Dev Space，服务会自动拉起。

链接生成：脚本最后会根据您的 UUID 和域名，按照 VLESS 标准格式拼接字符串，并高亮打印在终端中，您可以直接复制导入客户端。

⚠️ 安全与合规警告 (再次提醒)
此脚本仅供技术研究和自动化部署测试使用。

脚本中包含了 .bashrc 的修改，如果想卸载，请手动删除 ~/.sap-proxy 目录并清理 ~/.bashrc 中的相关行。

请勿将包含真实 Token 的命令截图分享给他人。

