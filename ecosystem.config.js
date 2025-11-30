module.exports = {
  apps: [{
    name: 'proxy-node',
    script: 'index.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      PORT: process.env.PORT || 3002,  // 动态从 env 取，默认 3002
      UUID: process.env.UUID || 'd5646919-1638-4dc6-9799-d795595c6b65',
      ARGO_AUTH: process.env.ARGO_AUTH || ''
    },
    error_file: './.pm2logs/err.log',
    out_file: './.pm2logs/out.log',
    log_file: './.pm2logs/combined.log',
    time: true
  }]
};
