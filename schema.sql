-- ============================================================
-- GitHub 加速代理站点 - 数据库初始化脚本 v2.0
-- 新增: 邮箱注册、套餐/订单、管理员后台、使用教程
-- 数据库: MySQL 8.0+ | 字符集: utf8mb4
-- ============================================================

CREATE DATABASE IF NOT EXISTS `github_proxy`
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

USE `github_proxy`;

-- ============================================================
-- 1. 用户表 (邮箱注册 + 管理员角色)
-- ============================================================
CREATE TABLE IF NOT EXISTS `users` (
    `id`            BIGINT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `email`         VARCHAR(255)       NOT NULL COMMENT '邮箱（登录账号）',
    `username`      VARCHAR(100)       NOT NULL DEFAULT '' COMMENT '用户名/昵称',
    `phone`         VARCHAR(20)        NOT NULL DEFAULT '' COMMENT '手机号',
    `password_hash` VARCHAR(255)       NOT NULL COMMENT 'bcrypt 密码哈希',
    `unique_token`  VARCHAR(64)        NOT NULL COMMENT '代理令牌（URL安全）',
    `role`          VARCHAR(20)        NOT NULL DEFAULT 'user' COMMENT '角色: user | admin',
    `status`        TINYINT UNSIGNED   NOT NULL DEFAULT 1 COMMENT '状态: 1=正常, 0=封禁/禁用',
    `ban_reason`    VARCHAR(500)       NOT NULL DEFAULT '' COMMENT '封禁原因',
    `ban_expire_at` DATETIME           NULL COMMENT '封禁到期时间(NULL=永久)',
    `plan_id`       BIGINT UNSIGNED    NULL COMMENT '当前生效套餐ID',
    `plan_expire_at` DATETIME          NULL COMMENT '套餐到期时间',
    `daily_quota`   BIGINT UNSIGNED    NOT NULL DEFAULT 0 COMMENT '每日流量配额(字节)',
    `daily_used`    BIGINT UNSIGNED    NOT NULL DEFAULT 0 COMMENT '今日已用流量(字节)',
    `quota_date`    DATE               NOT NULL DEFAULT (CURRENT_DATE) COMMENT '配额日期',
    `registered_ip` VARCHAR(45)        NOT NULL DEFAULT '' COMMENT '注册IP',
    `last_login_ip` VARCHAR(45)        NOT NULL DEFAULT '' COMMENT '最后登录IP',
    `last_login_at` DATETIME           NULL COMMENT '最后登录时间',
    `created_at`    DATETIME           NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`    DATETIME           NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_email` (`email`),
    UNIQUE KEY `uk_token` (`unique_token`),
    KEY `idx_role` (`role`),
    KEY `idx_status` (`status`),
    KEY `idx_plan_id` (`plan_id`),
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户表';

-- ============================================================
-- 2. 套餐表（管理员可编辑）
-- ============================================================
CREATE TABLE IF NOT EXISTS `plans` (
    `id`            BIGINT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `name`          VARCHAR(100)       NOT NULL COMMENT '套餐名称（如: 基础版/专业版/企业版）',
    `description`   VARCHAR(500)       NOT NULL DEFAULT '' COMMENT '套餐描述',
    `price_cents`   INT UNSIGNED       NOT NULL COMMENT '价格(分), 如 1999 = 19.99元',
    `duration_days` INT UNSIGNED       NOT NULL COMMENT '有效期(天)',
    `daily_quota`   BIGINT UNSIGNED    NOT NULL COMMENT '每日流量配额(字节)',
    `max_file_size` BIGINT UNSIGNED    NOT NULL DEFAULT 5368709120 COMMENT '单文件最大(字节), 默认5GB',
    `concurrent`    INT UNSIGNED       NOT NULL DEFAULT 3 COMMENT '最大并发连接数',
    `features`      JSON               NULL COMMENT '功能特性列表 ["高速下载","独立令牌",...]',
    `sort_order`    INT UNSIGNED       NOT NULL DEFAULT 0 COMMENT '排序（越小越前）',
    `is_active`     TINYINT UNSIGNED   NOT NULL DEFAULT 1 COMMENT '是否启用: 1=启用, 0=停用',
    `created_at`    DATETIME           NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`    DATETIME           NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_active_order` (`is_active`, `sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='套餐表';

-- ============================================================
-- 3. 使用教程表（管理员可编辑，按操作系统分类）
-- ============================================================
CREATE TABLE IF NOT EXISTS `usage_guides` (
    `id`            BIGINT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `os_name`       VARCHAR(50)        NOT NULL COMMENT '操作系统 (ubuntu/debian/centos/arch/macos/windows)',
    `os_label`      VARCHAR(100)       NOT NULL COMMENT '显示名称 (Ubuntu 22.04 / Debian 12)',
    `os_icon`       VARCHAR(30)        NOT NULL DEFAULT '🐧' COMMENT '图标emoji',
    `guide_content` TEXT               NOT NULL COMMENT '教程内容(Markdown/HTML)',
    `sort_order`    INT UNSIGNED       NOT NULL DEFAULT 0 COMMENT '排序',
    `is_active`     TINYINT UNSIGNED   NOT NULL DEFAULT 1 COMMENT '是否启用',
    `created_at`    DATETIME           NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`    DATETIME           NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_os_name` (`os_name`),
    KEY `idx_active_order` (`is_active`, `sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='使用教程表';

-- ============================================================
-- 4. 订单表
-- ============================================================
CREATE TABLE IF NOT EXISTS `orders` (
    `id`            BIGINT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `order_no`      VARCHAR(32)        NOT NULL COMMENT '订单号（唯一）',
    `user_id`       BIGINT UNSIGNED    NOT NULL COMMENT '用户ID',
    `plan_id`       BIGINT UNSIGNED    NOT NULL COMMENT '套餐ID',
    `plan_name`     VARCHAR(100)       NOT NULL COMMENT '套餐名称(冗余)',
    `amount_cents`  INT UNSIGNED       NOT NULL COMMENT '实付金额(分)',
    `status`        VARCHAR(20)        NOT NULL DEFAULT 'pending' COMMENT '状态: pending|paid|cancelled|expired',
    `payment_method` VARCHAR(30)       NULL COMMENT '支付方式: alipay|wechat|manual',
    `paid_at`       DATETIME           NULL COMMENT '支付时间',
    `created_at`    DATETIME           NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_order_no` (`order_no`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_status` (`status`),
    KEY `idx_created_at` (`created_at`),
    CONSTRAINT `fk_order_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_order_plan` FOREIGN KEY (`plan_id`) REFERENCES `plans` (`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单表';

-- ============================================================
-- ===========================================================
-- 4.5 收款方式配置表
-- ===========================================================
CREATE TABLE IF NOT EXISTS `payment_methods` (
    `id`            BIGINT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `method_type`   VARCHAR(30)        NOT NULL COMMENT '方式类型: manual|alipay|wepay|stripe',
    `name`          VARCHAR(50)        NOT NULL COMMENT '显示名称',
    `description`   VARCHAR(200)       DEFAULT '' COMMENT '描述',
    `config`        TEXT               NULL COMMENT 'JSON配置（API密钥等）',
    `fee_rate`      DECIMAL(5,2)      DEFAULT 0.00 COMMENT '手续费率(%)',
    `min_amount`    INT UNSIGNED       DEFAULT 0 COMMENT '最小支付金额(分)',
    `max_amount`    INT UNSIGNED       DEFAULT 0 COMMENT '最大支付金额(分), 0=无限制',
    `sort_order`    INT                DEFAULT 0,
    `is_active`     TINYINT            DEFAULT 1,
    `created_at`    DATETIME           NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_method_type` (`method_type`),
    KEY `idx_active_order` (`is_active`, `sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='收款方式配置表';


-- 5. 支付记录表
-- ============================================================
CREATE TABLE IF NOT EXISTS `payments` (
    `id`              BIGINT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `order_id`        BIGINT UNSIGNED    NOT NULL COMMENT '关联订单ID',
    `transaction_id`  VARCHAR(64)        NOT NULL DEFAULT '' COMMENT '第三方交易号',
    `payment_method`  VARCHAR(30)        NOT NULL COMMENT '支付方式',
    `amount_cents`    INT UNSIGNED       NOT NULL COMMENT '支付金额(分)',
    `status`          VARCHAR(20)        NOT NULL DEFAULT 'pending' COMMENT '状态: pending|success|failed|refunded',
    `callback_raw`    TEXT               NULL COMMENT '支付回调原始数据(JSON)',
    `paid_at`         DATETIME           NULL COMMENT '支付完成时间',
    `created_at`      DATETIME           NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_order_id` (`order_id`),
    KEY `idx_transaction_id` (`transaction_id`),
    KEY `idx_status` (`status`),
    CONSTRAINT `fk_payment_order` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='支付记录表';

-- ============================================================
-- 6. 下载日志表（代理访问记录）
-- ============================================================
CREATE TABLE IF NOT EXISTS `download_logs` (
    `id`          BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
    `user_id`     BIGINT UNSIGNED  NOT NULL COMMENT '用户ID',
    `github_url`  VARCHAR(2048)    NOT NULL COMMENT '原始 GitHub 地址',
    `file_size`   BIGINT UNSIGNED  NOT NULL DEFAULT 0 COMMENT '文件大小(字节)',
    `http_status` SMALLINT UNSIGNED NOT NULL DEFAULT 200 COMMENT 'HTTP 状态码',
    `ip_address`  VARCHAR(45)      NOT NULL DEFAULT '' COMMENT '客户端IP',
    `user_agent`  VARCHAR(512)     NOT NULL DEFAULT '' COMMENT 'User-Agent',
    `duration_ms` INT UNSIGNED     NOT NULL DEFAULT 0 COMMENT '请求耗时(毫秒)',
    `created_at`  DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_ip_address` (`ip_address`),
    CONSTRAINT `fk_download_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='下载日志表';

-- ============================================================
-- 7. 限流记录表
-- ============================================================
CREATE TABLE IF NOT EXISTS `rate_limits` (
    `id`           BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
    `identifier`   VARCHAR(128)     NOT NULL,
    `action`       VARCHAR(64)      NOT NULL,
    `request_count` INT UNSIGNED    NOT NULL DEFAULT 1,
    `window_start` DATETIME         NOT NULL,
    `created_at`   DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_identifier_action_window` (`identifier`, `action`, `window_start`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='限流记录表';

-- ============================================================
-- 8. 代理节点表 (多节点管理)
-- ============================================================
CREATE TABLE IF NOT EXISTS `proxy_nodes` (
    `id`              BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
    `node_name`       VARCHAR(50)      NOT NULL COMMENT '节点名称 (唯一)',
    `node_host`       VARCHAR(100)     NOT NULL COMMENT '节点IP/域名',
    `node_port`       INT UNSIGNED     NOT NULL DEFAULT 8000 COMMENT '节点端口',
    `node_api_base`   VARCHAR(255)     DEFAULT '' COMMENT '对外API地址 (https://node1.example.com)',
    `node_role`       VARCHAR(20)      NOT NULL DEFAULT 'worker' COMMENT '角色: master|worker',
    `status`          VARCHAR(20)      NOT NULL DEFAULT 'online' COMMENT '状态: online|offline|disabled',
    `last_heartbeat`  DATETIME         NULL COMMENT '最后心跳时间',
    `created_at`      DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`      DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_node_name` (`node_name`),
    KEY `idx_status` (`status`),
    KEY `idx_role` (`node_role`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='代理节点注册表';

-- ============================================================
-- 默认数据
-- ============================================================

-- 默认管理员 (密码: Admin@123456, bcrypt cost=12)
-- 首次部署后请立即修改密码
INSERT INTO `users` (`email`, `password_hash`, `unique_token`, `role`, `status`, `daily_quota`)
VALUES ('admin@github-proxy.local',
        '$2b$12$LJ3m4ys3Lk0TSwHCpNqrNe3BBM5H1qFm5t0KjE3lLkVjMxJvOgZOa',
        REPLACE(UUID(), '-', ''), 'admin', 1, 107374182400)
ON DUPLICATE KEY UPDATE `email`=`email`;

-- 默认套餐: 基础版
INSERT INTO `plans` (`name`, `description`, `price_cents`, `duration_days`, `daily_quota`,
    `max_file_size`, `concurrent`, `features`, `sort_order`, `is_active`)
VALUES ('基础版', '适合个人开发者日常使用', 999, 30, 10737418240,
        2147483648, 3, '["高速下载","独立代理令牌","每日10GB流量","最大2GB单文件","30天有效期"]', 1, 1)
ON DUPLICATE KEY UPDATE `name`=`name`;

-- 默认套餐: 专业版
INSERT INTO `plans` (`name`, `description`, `price_cents`, `duration_days`, `daily_quota`,
    `max_file_size`, `concurrent`, `features`, `sort_order`, `is_active`)
VALUES ('专业版', '适合团队和重度用户', 2499, 90, 53687091200,
        5368709120, 10, '["极速下载","独立代理令牌","每日50GB流量","最大5GB单文件","90天有效期","10个并发连接"]', 2, 1)
ON DUPLICATE KEY UPDATE `name`=`name`;

-- 默认套餐: 企业版
INSERT INTO `plans` (`name`, `description`, `price_cents`, `duration_days`, `daily_quota`,
    `max_file_size`, `concurrent`, `features`, `sort_order`, `is_active`)
VALUES ('企业版', '适合企业和重度CI/CD场景', 9999, 365, 214748364800,
        21474836480, 50, '["企业级极速通道","独立代理令牌","每日200GB流量","最大20GB单文件","365天有效期","50个并发连接","优先技术支持"]', 3, 1)
ON DUPLICATE KEY UPDATE `name`=`name`;

-- 默认使用教程
INSERT INTO `usage_guides` (`os_name`, `os_label`, `os_icon`, `guide_content`, `sort_order`, `is_active`) VALUES
('ubuntu', 'Ubuntu / Debian', '🟠', '<h3>Ubuntu / Debian 使用教程</h3>
<p>在终端中使用以下命令配置 GitHub 加速代理：</p>
<pre><code># 设置代理别名（替换 YOUR_TOKEN 为您的令牌）
export GHPROXY="https://你的域名/proxy/YOUR_TOKEN"

# 方式1: wget 下载 Release 文件
wget $GHPROXY/用户名/仓库名/releases/download/v1.0/file.tar.gz

# 方式2: 下载仓库源码
wget $GHPROXY/用户名/仓库名/archive/refs/heads/main.zip

# 方式3: 下载 raw 文件
wget $GHPROXY/raw/用户名/仓库名/main/README.md

# 写入 ~/.bashrc 永久生效
echo ''export GHPROXY="https://你的域名/proxy/YOUR_TOKEN"'' >> ~/.bashrc
source ~/.bashrc</code></pre>
<p><strong>提示：</strong>将 <code>YOUR_TOKEN</code> 替换为您控制台中显示的代理令牌。</p>', 1, 1),

('debian', 'Debian 专属', '🔴', '<h3>Debian 专属配置</h3>
<p>Debian 用户可以通过以下方式优化体验：</p>
<pre><code># 安装必要工具
sudo apt update && sudo apt install -y wget curl

# 配置代理环境变量
export GHPROXY="https://你的域名/proxy/YOUR_TOKEN"

# 下载示例：获取 Docker 安装脚本
wget $GHPROXY/raw/docker/docker-install/master/install.sh

# 使用 curl 下载
curl -L -o file.tar.gz $GHPROXY/用户名/仓库名/releases/download/v1.0/file.tar.gz

# 持久化配置
cat >> ~/.profile << EOF
export GHPROXY="https://你的域名/proxy/YOUR_TOKEN"
EOF</code></pre>
<p><strong>注意：</strong>Debian 默认使用 dash 而非 bash，请确保用 <code>bash</code> 执行命令。</p>', 2, 1),

('centos', 'CentOS / RHEL / Fedora', '🔵', '<h3>CentOS / RHEL / Fedora 使用教程</h3>
<pre><code># 设置代理地址
export GHPROXY="https://你的域名/proxy/YOUR_TOKEN"

# 使用 wget
wget $GHPROXY/用户名/仓库名/releases/download/v1.0/file.tar.gz

# 使用 curl
curl -LO $GHPROXY/用户名/仓库名/archive/refs/tags/v1.0.tar.gz

# 永久生效
echo "export GHPROXY=\"https://你的域名/proxy/YOUR_TOKEN\"" >> ~/.bashrc
source ~/.bashrc

# 如果在 SELinux 环境下遇到问题：
sudo setenforce 0  # 临时关闭（仅调试用）</code></pre>', 3, 1),

('arch', 'Arch Linux / Manjaro', '🟣', '<h3>Arch Linux / Manjaro 使用教程</h3>
<pre><code># 安装依赖
sudo pacman -S wget curl

# 设置代理
export GHPROXY="https://你的域名/proxy/YOUR_TOKEN"

# 下载 AUR 源码包
wget $GHPROXY/用户名/仓库名/archive/refs/heads/main.tar.gz

# 写入 shell 配置
echo "export GHPROXY=\"https://你的域名/proxy/YOUR_TOKEN\"" >> ~/.zshrc
source ~/.zshrc</code></pre>', 4, 1),

('macos', 'macOS', '🍎', '<h3>macOS 使用教程</h3>
<pre><code># 使用 Homebrew 安装 wget（如果没有）
brew install wget

# 设置代理
export GHPROXY="https://你的域名/proxy/YOUR_TOKEN"

# 下载文件
wget $GHPROXY/用户名/仓库名/releases/download/v1.0/file.dmg

# 写入 shell 配置（zsh 是 macOS 默认 shell）
echo "export GHPROXY=\"https://你的域名/proxy/YOUR_TOKEN\"" >> ~/.zshrc
source ~/.zshrc</code></pre>', 5, 1),

('windows', 'Windows', '🪟', '<h3>Windows 使用教程</h3>
<p>在 PowerShell 或 CMD 中：</p>
<pre><code># PowerShell
$env:GHPROXY = "https://你的域名/proxy/YOUR_TOKEN"
Invoke-WebRequest -Uri "$env:GHPROXY/用户名/仓库名/releases/download/v1.0/file.zip" -OutFile "file.zip"

# 或使用 curl (Windows 10+ 内置)
curl -Lo file.zip "https://你的域名/proxy/YOUR_TOKEN/用户名/仓库名/releases/download/v1.0/file.zip"</code></pre>
<p>也可以直接在浏览器中打开链接下载。</p>', 6, 1)
ON DUPLICATE KEY UPDATE `os_name`=`os_name`;

-- ============================================================
-- 9. 访问日志表（五元组 + 代理详情）
-- ============================================================
CREATE TABLE IF NOT EXISTS `access_logs` (
    `id`            BIGINT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `user_id`       BIGINT UNSIGNED    NULL COMMENT '关联用户ID(匿名访问可为NULL)',
    `src_ip`        VARCHAR(45)        NOT NULL COMMENT '源IP',
    `dst_ip`        VARCHAR(45)        NOT NULL DEFAULT '' COMMENT '目标IP(GitHub IP)',
    `src_port`      INT UNSIGNED       NOT NULL DEFAULT 0 COMMENT '源端口',
    `dst_port`      INT UNSIGNED       NOT NULL DEFAULT 0 COMMENT '目标端口',
    `protocol`      VARCHAR(10)        NOT NULL DEFAULT 'TCP' COMMENT '协议: TCP/UDP/HTTP/HTTPS',
    `method`        VARCHAR(10)        NOT NULL DEFAULT 'GET' COMMENT 'HTTP 方法',
    `path`          VARCHAR(2048)      NOT NULL DEFAULT '' COMMENT '请求路径',
    `http_status`   SMALLINT UNSIGNED  NOT NULL DEFAULT 0 COMMENT 'HTTP 状态码',
    `file_size`     BIGINT UNSIGNED    NOT NULL DEFAULT 0 COMMENT '传输字节数',
    `duration_ms`   INT UNSIGNED       NOT NULL DEFAULT 0 COMMENT '耗时(毫秒)',
    `user_agent`    VARCHAR(512)       NOT NULL DEFAULT '' COMMENT 'User-Agent',
    `referer`       VARCHAR(1024)      NOT NULL DEFAULT '' COMMENT 'Referer',
    `blocked`       TINYINT UNSIGNED   NOT NULL DEFAULT 0 COMMENT '是否被拦截: 0=放行, 1=限流拦截, 2=黑名单拦截',
    `block_reason`  VARCHAR(200)       NOT NULL DEFAULT '' COMMENT '拦截原因',
    `created_at`    DATETIME           NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '访问时间',
    PRIMARY KEY (`id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_src_ip` (`src_ip`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_blocked` (`blocked`),
    KEY `idx_user_created` (`user_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='五元组访问日志表';

-- ============================================================
-- 10. 用户操作审计日志表
-- ============================================================
CREATE TABLE IF NOT EXISTS `audit_logs` (
    `id`            BIGINT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `user_id`       BIGINT UNSIGNED    NULL COMMENT '操作用户ID(系统操作可为NULL)',
    `email`         VARCHAR(255)       NOT NULL DEFAULT '' COMMENT '操作用户邮箱(冗余)',
    `action`        VARCHAR(50)        NOT NULL COMMENT '操作类型: register|login|logout|purchase|use_proxy|ban|unban|delete_user|manual_pay|refund|regenerate_token|update_profile|create_order|security_config',
    `target_type`   VARCHAR(50)        NOT NULL DEFAULT '' COMMENT '目标类型: user|order|plan|proxy|config|ip',
    `target_id`     VARCHAR(100)       NOT NULL DEFAULT '' COMMENT '目标ID',
    `detail`        JSON               NULL COMMENT '操作详情(JSON)',
    `ip_address`    VARCHAR(45)        NOT NULL DEFAULT '' COMMENT '操作来源IP',
    `user_agent`    VARCHAR(512)       NOT NULL DEFAULT '' COMMENT 'User-Agent',
    `result`        VARCHAR(20)        NOT NULL DEFAULT 'success' COMMENT '操作结果: success|failure|blocked',
    `error_msg`     VARCHAR(500)       NOT NULL DEFAULT '' COMMENT '失败原因',
    `created_at`    DATETIME           NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '操作时间',
    PRIMARY KEY (`id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_action` (`action`),
    KEY `idx_target` (`target_type`, `target_id`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_user_action` (`user_id`, `action`),
    KEY `idx_ip` (`ip_address`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户操作审计日志表';

-- ============================================================
-- 11. 安全配置表
-- ============================================================
CREATE TABLE IF NOT EXISTS `security_config` (
    `id`            BIGINT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `config_key`    VARCHAR(100)       NOT NULL COMMENT '配置键名',
    `config_value`  TEXT               NOT NULL COMMENT '配置值(JSON或字符串)',
    `value_type`    VARCHAR(20)        NOT NULL DEFAULT 'string' COMMENT '值类型: int|float|string|json|bool',
    `description`   VARCHAR(500)       NOT NULL DEFAULT '' COMMENT '配置说明',
    `is_active`     TINYINT UNSIGNED   NOT NULL DEFAULT 1 COMMENT '是否启用',
    `updated_by`    BIGINT UNSIGNED    NULL COMMENT '最后修改人',
    `updated_at`    DATETIME           NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `created_at`    DATETIME           NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_config_key` (`config_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='安全配置表';

-- ============================================================
-- 12. IP 黑名单表（持久化）
-- ============================================================
CREATE TABLE IF NOT EXISTS `ip_blacklist` (
    `id`            BIGINT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `ip_address`    VARCHAR(45)        NOT NULL COMMENT 'IP地址',
    `ip_range`      TINYINT UNSIGNED   NOT NULL DEFAULT 0 COMMENT '是否CIDR范围: 0=单IP, 1=CIDR',
    `reason`        VARCHAR(500)       NOT NULL DEFAULT '' COMMENT '拉黑原因',
    `source`        VARCHAR(20)        NOT NULL DEFAULT 'manual' COMMENT '来源: manual|auto_rate|auto_login_fail',
    `blocked_until` DATETIME           NULL COMMENT '解封时间(NULL=永久)',
    `blocked_by`    BIGINT UNSIGNED    NULL COMMENT '操作人(管理员ID)',
    `is_active`     TINYINT UNSIGNED   NOT NULL DEFAULT 1 COMMENT '是否生效',
    `hit_count`     INT UNSIGNED       NOT NULL DEFAULT 0 COMMENT '命中次数',
    `created_at`    DATETIME           NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`    DATETIME           NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_ip` (`ip_address`),
    KEY `idx_active_until` (`is_active`, `blocked_until`),
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='IP黑名单表';

-- ============================================================
-- 13. 更新用户表：添加封禁字段（兼容 MySQL 5.7+）
-- ============================================================
DROP PROCEDURE IF EXISTS add_users_cols;
DELIMITER //
CREATE PROCEDURE add_users_cols()
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS
                 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'ban_reason') THEN
    ALTER TABLE `users` ADD COLUMN `ban_reason` VARCHAR(500) NOT NULL DEFAULT '' COMMENT '封禁原因' AFTER `status`;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS
                 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'ban_expire_at') THEN
    ALTER TABLE `users` ADD COLUMN `ban_expire_at` DATETIME NULL COMMENT '封禁到期时间' AFTER `ban_reason`;
  END IF;
END//
DELIMITER ;
CALL add_users_cols();
DROP PROCEDURE add_users_cols;

-- ============================================================
-- 14. 更新下载日志表：添加五元组字段（兼容 MySQL 5.7+）
-- ============================================================
DROP PROCEDURE IF EXISTS add_dl_cols;
DELIMITER //
CREATE PROCEDURE add_dl_cols()
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS
                 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'download_logs' AND COLUMN_NAME = 'src_port') THEN
    ALTER TABLE `download_logs` ADD COLUMN `src_port` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '源端口' AFTER `ip_address`;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS
                 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'download_logs' AND COLUMN_NAME = 'dst_ip') THEN
    ALTER TABLE `download_logs` ADD COLUMN `dst_ip` VARCHAR(45) NOT NULL DEFAULT '' COMMENT '目标IP' AFTER `src_port`;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS
                 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'download_logs' AND COLUMN_NAME = 'dst_port') THEN
    ALTER TABLE `download_logs` ADD COLUMN `dst_port` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '目标端口' AFTER `dst_ip`;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS
                 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'download_logs' AND COLUMN_NAME = 'protocol') THEN
    ALTER TABLE `download_logs` ADD COLUMN `protocol` VARCHAR(10) NOT NULL DEFAULT 'TCP' COMMENT '协议' AFTER `dst_port`;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS
                 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'download_logs' AND COLUMN_NAME = 'method') THEN
    ALTER TABLE `download_logs` ADD COLUMN `method` VARCHAR(10) NOT NULL DEFAULT 'GET' COMMENT 'HTTP方法' AFTER `protocol`;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS
                 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'download_logs' AND COLUMN_NAME = 'referer') THEN
    ALTER TABLE `download_logs` ADD COLUMN `referer` VARCHAR(1024) NOT NULL DEFAULT '' COMMENT 'Referer' AFTER `user_agent`;
  END IF;
END//
DELIMITER ;
CALL add_dl_cols();
DROP PROCEDURE add_dl_cols;

-- ============================================================
-- 14. 默认安全配置
-- ============================================================
INSERT INTO `security_config` (`config_key`, `config_value`, `value_type`, `description`, `is_active`) VALUES
('rate_limit_per_second', '10', 'int', '每秒最大请求数(超过则触发限流)', 1),
('rate_limit_window_seconds', '60', 'int', '限流统计窗口(秒)', 1),
('rate_limit_max_per_window', '100', 'int', '时间窗口内最大请求数', 1),
('auto_block_threshold', '3', 'int', '触发限流次数达到该值时自动封禁IP', 1),
('auto_block_duration_minutes', '30', 'int', '自动封禁时长(分钟)', 1),
('login_fail_max', '5', 'int', '登录失败最大次数(超出封IP)', 1),
('login_fail_block_minutes', '30', 'int', '登录失败封禁时长(分钟)', 1),
('log_retention_days', '90', 'int', '日志保留天数', 1),
('enable_access_log', 'true', 'bool', '是否开启五元组访问日志', 1),
('enable_audit_log', 'true', 'bool', '是否开启操作审计日志', 1)
ON DUPLICATE KEY UPDATE `config_key`=`config_key`;

-- ============================================================
-- 定时任务
-- ============================================================

-- 每日重置流量配额
CREATE EVENT IF NOT EXISTS `reset_daily_quota`
    ON SCHEDULE EVERY 1 DAY
    STARTS CONCAT(CURRENT_DATE, ' 00:00:01')
    DO
        UPDATE `users` SET `daily_used` = 0, `quota_date` = CURRENT_DATE
        WHERE `quota_date` < CURRENT_DATE;

-- 自动清理过期套餐用户
CREATE EVENT IF NOT EXISTS `clear_expired_plans`
    ON SCHEDULE EVERY 1 HOUR
    DO
        UPDATE `users` SET `plan_id` = NULL, `daily_quota` = 0
        WHERE `plan_expire_at` IS NOT NULL
          AND `plan_expire_at` < NOW()
          AND `plan_id` IS NOT NULL;

-- 定期清理旧下载日志（保留90天）
CREATE EVENT IF NOT EXISTS `cleanup_old_download_logs`
    ON SCHEDULE EVERY 1 DAY
    DO
        DELETE FROM `download_logs` WHERE `created_at` < DATE_SUB(NOW(), INTERVAL 90 DAY);

-- 定期清理旧访问日志（保留90天）
CREATE EVENT IF NOT EXISTS `cleanup_old_access_logs`
    ON SCHEDULE EVERY 1 DAY
    DO
        DELETE FROM `access_logs` WHERE `created_at` < DATE_SUB(NOW(), INTERVAL 90 DAY);

-- 定期清理旧审计日志（保留180天）
CREATE EVENT IF NOT EXISTS `cleanup_old_audit_logs`
    ON SCHEDULE EVERY 1 DAY
    DO
        DELETE FROM `audit_logs` WHERE `created_at` < DATE_SUB(NOW(), INTERVAL 180 DAY);

-- 每小时自动解封到期用户
CREATE EVENT IF NOT EXISTS `auto_unban_expired_users`
    ON SCHEDULE EVERY 1 HOUR
    DO
        UPDATE `users` SET `status` = 1, `ban_reason` = '', `ban_expire_at` = NULL
        WHERE `status` = 0 AND `ban_expire_at` IS NOT NULL AND `ban_expire_at` < NOW();

-- 每小时清理过期 IP 黑名单
CREATE EVENT IF NOT EXISTS `cleanup_expired_ip_blacklist`
    ON SCHEDULE EVERY 1 HOUR
    DO
        UPDATE `ip_blacklist` SET `is_active` = 0
        WHERE `is_active` = 1 AND `blocked_until` IS NOT NULL AND `blocked_until` < NOW();
