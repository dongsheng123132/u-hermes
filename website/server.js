const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 8650; // U-Hermes网站端口
const WEBSITE_DIR = path.join(__dirname, 'website');

const server = http.createServer((req, res) => {
    // 处理CORS
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    // 处理预检请求
    if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }

    // 路由处理
    let filePath = req.url === '/' ? '/index.html' : req.url;
    filePath = path.join(WEBSITE_DIR, filePath);

    // 默认文件扩展名
    const extname = path.extname(filePath);
    let contentType = 'text/html';
    
    switch (extname) {
        case '.js':
            contentType = 'text/javascript';
            break;
        case '.css':
            contentType = 'text/css';
            break;
        case '.json':
            contentType = 'application/json';
            break;
        case '.png':
            contentType = 'image/png';
            break;
        case '.jpg':
            contentType = 'image/jpg';
            break;
        case '.ico':
            contentType = 'image/x-icon';
            break;
    }

    // 读取文件
    fs.readFile(filePath, (error, content) => {
        if (error) {
            if (error.code === 'ENOENT') {
                // 文件不存在，返回404
                fs.readFile(path.join(WEBSITE_DIR, '404.html'), (err, content) => {
                    if (err) {
                        res.writeHead(404, { 'Content-Type': 'text/html' });
                        res.end('<h1>404 Not Found</h1>');
                    } else {
                        res.writeHead(404, { 'Content-Type': 'text/html' });
                        res.end(content, 'utf-8');
                    }
                });
            } else {
                // 服务器错误
                res.writeHead(500);
                res.end(`Server Error: ${error.code}`);
            }
        } else {
            // 成功响应
            res.writeHead(200, { 'Content-Type': contentType });
            res.end(content, 'utf-8');
        }
    });
});

// API端点
const apiServer = http.createServer((req, res) => {
    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Access-Control-Allow-Origin', '*');

    if (req.url === '/api/status' && req.method === 'GET') {
        // 检查Hermes Agent状态
        const status = {
            hermesAgent: checkPort(8642),
            webUI: checkPort(8648),
            timestamp: new Date().toISOString()
        };
        
        res.writeHead(200);
        res.end(JSON.stringify(status));
    } else if (req.url === '/api/balance' && req.method === 'GET') {
        // 模拟余额查询
        const balance = {
            amount: 128.50,
            currency: 'CNY',
            lastUpdated: new Date().toISOString()
        };
        
        res.writeHead(200);
        res.end(JSON.stringify(balance));
    } else {
        res.writeHead(404);
        res.end(JSON.stringify({ error: 'Not Found' }));
    }
});

// 检查端口是否被占用
function checkPort(port) {
    // 这里可以添加实际的端口检查逻辑
    // 目前返回模拟数据
    return {
        running: true,
        port: port,
        pid: Math.floor(Math.random() * 10000) + 1000
    };
}

// 启动服务器
server.listen(PORT, () => {
    console.log(`U-Hermes网站服务器运行在 http://localhost:${PORT}`);
    console.log(`网站目录: ${WEBSITE_DIR}`);
});

apiServer.listen(8651, () => {
    console.log(`U-Hermes API服务器运行在 http://localhost:8651`);
});

// 优雅关闭
process.on('SIGINT', () => {
    console.log('\n正在关闭服务器...');
    server.close(() => {
        console.log('网站服务器已关闭');
        apiServer.close(() => {
            console.log('API服务器已关闭');
            process.exit(0);
        });
    });
});

module.exports = { server, apiServer };