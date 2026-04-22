# U-Hermes 网站项目

## 项目概述
为 U-Hermes 便携 AI 助手创建一个展示和控制面板网站。

## 文件说明

### 1. index.html (完整版)
- 功能丰富的控制面板
- 响应式设计，美观的UI
- 包含所有功能：状态监控、API管理、快速入口等
- 使用 Font Awesome 图标

### 2. simple.html (轻量版)
- 简洁的单页应用
- 无外部依赖，纯HTML/CSS/JS
- 适合集成到U盘中
- 基本功能齐全

### 3. 功能特性
- ✅ 服务状态实时显示
- ✅ API Key 复制功能
- ✅ 余额刷新模拟
- ✅ 快速入口链接
- ✅ 使用提示说明
- ✅ 响应式布局
- ✅ 美观的渐变背景

### 4. 部署方式

#### 方式一：本地U盘部署
将 `website/` 目录复制到 U 盘的根目录，通过浏览器打开 `file:///F:/U-Hermes/website/index.html`

#### 方式二：Web服务器部署
1. 安装 Node.js 和 http-server：
   ```bash
   npm install -g http-server
   ```
2. 启动服务器：
   ```bash
   cd website
   http-server -p 8080
   ```
3. 访问：http://localhost:8080

#### 方式三：静态托管服务
- GitHub Pages
- Vercel
- Netlify
- Cloudflare Pages

### 5. 自定义配置

#### 修改端口号
在HTML文件中搜索 `:8642` 和 `:8648` 替换为实际端口

#### 修改U盘路径
搜索 `F:\\U-Hermes` 替换为实际路径

#### 修改API Key
搜索 `sk-eb0c5c4...65c0d6` 替换为实际API Key

### 6. 扩展功能建议

#### 后端集成
创建 `api/` 目录，添加以下文件：
- `status.js` - 检查服务状态
- `balance.js` - 查询虾盘云余额
- `config.js` - 管理配置

#### 实时更新
使用 WebSocket 或 Server-Sent Events 实现：
- 实时服务状态监控
- 余额自动刷新
- 日志实时查看

#### 多语言支持
添加 i18n 支持，支持中英文切换

### 7. 开发说明

#### 技术栈
- HTML5
- CSS3 (Flexbox/Grid)
- Vanilla JavaScript
- 可选：Vue.js/React 用于更复杂功能

#### 浏览器兼容性
- Chrome 60+
- Firefox 55+
- Safari 11+
- Edge 79+

### 8. 测试建议
1. 在不同设备上测试响应式布局
2. 测试所有按钮功能
3. 验证API Key复制功能
4. 检查链接是否正确

### 9. 安全注意事项
1. 不要在前端暴露完整的API Key
2. 使用HTTPS部署生产版本
3. 添加CSP头防止XSS攻击
4. 对用户输入进行验证

### 10. 更新日志
- v1.0.0: 初始版本，包含基本功能
- v1.1.0: 添加响应式设计，优化UI
- v1.2.0: 添加实时状态更新功能

## 快速开始
1. 复制 `website/` 目录到目标位置
2. 根据需要修改配置文件
3. 通过浏览器打开 `index.html` 或部署到服务器

## 联系支持
如有问题，请联系虾盘云技术支持。