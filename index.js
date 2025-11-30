const http = require('http');
const fs = require('fs');
const exec = require("child_process").exec;
const { spawn } = require('child_process');  // 新增：用于 PM2
const subtxt = './.npm/sub.txt';
const PORT = process.env.PORT || 3001;  // 默认 3001 避开冲突

// PM2 启动/恢复逻辑（借鉴 Argosbx 的进程检测）
function startPM2() {
  const pm2 = spawn('pm2', ['start', 'ecosystem.config.js'], { stdio: 'inherit' });
  pm2.on('close', (code) => {
    if (code === 0) console.log('PM2 started successfully');
    else console.error('PM2 start failed:', code);
  });
}

// 检查 sing-box 进程（如果丢失，重启）
function checkAndRestartSingbox() {
  exec('pgrep -f sing-box', (err, stdout) => {
    if (err || !stdout) {
      console.log('Sing-box not running, restarting...');
      exec('nohup ~/.npm/sing-box run -c ~/.npm/config.json > ~/.npm/singbox.log 2>&1 &', (err) => {
        if (err) console.error('Sing-box restart failed:', err);
      });
    }
  });
}

// Run start.sh
fs.chmod("start.sh", 0o777, (err) => {
  if (err) {
    console.error(`start.sh empowerment failed: ${err}`);
    return;
  }
  console.log(`start.sh empowerment successful`);
  const child = exec('bash start.sh');
  child.stdout.on('data', (data) => console.log(data));
  child.stderr.on('data', (data) => console.error(data));
  child.on('close', (code) => {
    console.log(`child process exited with code ${code}`);
    console.clear();
    console.log(`App is running`);
    // 启动后 10s 检查 sing-box（借鉴 Argosbx 延迟）
    setTimeout(checkAndRestartSingbox, 10000);
    // 每 5min 检查一次（循环保活）
    setInterval(checkAndRestartSingbox, 300000);
  });
});

// PM2 自动启动（如果未运行）
exec('pm2 status', (err, stdout) => {
  if (err || stdout.includes('stopped')) startPM2();
});

// create HTTP server
const server = http.createServer((req, res) => {
  if (req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Hello world!');
  }
  if (req.url === '/sub') {
    fs.readFile(subtxt, 'utf8', (err, data) => {
      if (err) {
        console.error(err);
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Error reading sub.txt' }));
      } else {
        res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
        res.end(data);
      }
    });
  }
});
server.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
