
-- LumenAPI schema-only migration from user backup. No historical records or DROP statements.

CREATE TABLE IF NOT EXISTS `api_admins` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned DEFAULT NULL,
  `username` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password_hash` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `role` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'admin',
  `status` tinyint(3) unsigned NOT NULL DEFAULT '1',
  `last_login_at` datetime DEFAULT NULL,
  `last_login_ip` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_username` (`username`) USING BTREE,
  UNIQUE KEY `uq_admin_user_id` (`user_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `api_audit_logs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `admin_id` bigint(20) unsigned DEFAULT NULL,
  `action` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `target_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `target_id` bigint(20) unsigned DEFAULT NULL,
  `detail` text COLLATE utf8mb4_unicode_ci,
  `ip` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_admin` (`admin_id`) USING BTREE,
  KEY `idx_created` (`created_at`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `api_billing_logs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `request_id` varchar(64) NOT NULL,
  `user_id` bigint(20) unsigned NOT NULL,
  `key_id` bigint(20) unsigned NOT NULL,
  `endpoint_id` bigint(20) unsigned NOT NULL,
  `amount` bigint(20) unsigned NOT NULL,
  `balance_before` bigint(20) unsigned DEFAULT NULL,
  `balance_after` bigint(20) unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_request_id` (`request_id`) USING BTREE,
  KEY `idx_user_time` (`user_id`,`created_at`) USING BTREE,
  KEY `idx_endpoint_time` (`endpoint_id`,`created_at`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `api_channels` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `base_url` varchar(500) NOT NULL,
  `api_key_cipher` text,
  `status` tinyint(4) NOT NULL DEFAULT '1',
  `priority` int(11) NOT NULL DEFAULT '100',
  `weight` int(11) NOT NULL DEFAULT '100',
  `timeout_seconds` int(11) NOT NULL DEFAULT '120',
  `max_concurrency` int(11) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_status_priority` (`status`,`priority`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `api_endpoint_params` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `endpoint_id` bigint(20) unsigned NOT NULL,
  `name` varchar(100) NOT NULL,
  `location` varchar(20) NOT NULL DEFAULT 'query',
  `data_type` varchar(20) NOT NULL DEFAULT 'string',
  `required` tinyint(1) NOT NULL DEFAULT '0',
  `default_value` text,
  `description` varchar(500) DEFAULT NULL,
  `sort_order` int(11) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_endpoint_param` (`endpoint_id`,`location`,`name`) USING BTREE,
  KEY `idx_endpoint` (`endpoint_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `api_endpoints` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `slug` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `method` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'POST',
  `driver` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'http',
  `handler_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `request_mode` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'passthrough',
  `auth_mode` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'both',
  `access_level` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'public',
  `cost_per_call` bigint(20) unsigned NOT NULL DEFAULT '0',
  `success_mode` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'http_2xx',
  `success_json_field` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `success_json_value` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `target_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `upstream_auth_type` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'none',
  `upstream_auth_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `upstream_auth_secret` text COLLATE utf8mb4_unicode_ci,
  `upstream_headers` text COLLATE utf8mb4_unicode_ci,
  `status` tinyint(3) unsigned NOT NULL DEFAULT '1',
  `timeout_seconds` int(10) unsigned NOT NULL DEFAULT '30',
  `description` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_slug` (`slug`) USING BTREE,
  KEY `idx_status` (`status`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `api_keys` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned DEFAULT NULL,
  `admin_id` bigint(20) unsigned DEFAULT NULL,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `key_prefix` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `key_hash` char(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` tinyint(3) unsigned NOT NULL DEFAULT '1',
  `ban_source` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ban_reason` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `banned_at` datetime DEFAULT NULL,
  `quota_total` bigint(20) unsigned DEFAULT NULL,
  `quota_used` bigint(20) unsigned NOT NULL DEFAULT '0',
  `expires_at` datetime DEFAULT NULL,
  `last_used_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_key_hash` (`key_hash`) USING BTREE,
  KEY `idx_status` (`status`) USING BTREE,
  KEY `idx_user_id` (`user_id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `api_model_mappings` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `public_model` varchar(150) NOT NULL,
  `channel_id` bigint(20) unsigned NOT NULL,
  `upstream_model` varchar(150) NOT NULL,
  `status` tinyint(4) NOT NULL DEFAULT '1',
  `priority` int(11) NOT NULL DEFAULT '100',
  `weight` int(11) NOT NULL DEFAULT '100',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_model_channel` (`public_model`,`channel_id`) USING BTREE,
  KEY `idx_public_status_priority` (`public_model`,`status`,`priority`) USING BTREE,
  KEY `idx_channel` (`channel_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `api_payment_events` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `order_id` bigint(20) unsigned DEFAULT NULL,
  `order_no` varchar(40) DEFAULT NULL,
  `provider` varchar(20) NOT NULL,
  `provider_trade_no` varchar(100) DEFAULT NULL,
  `event_type` varchar(40) NOT NULL,
  `trade_status` varchar(40) DEFAULT NULL,
  `verified` tinyint(1) NOT NULL DEFAULT '0',
  `payload_hash` char(64) NOT NULL,
  `detail` varchar(500) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  KEY `idx_payment_event_order` (`order_id`,`created_at`) USING BTREE,
  KEY `idx_payment_event_trade` (`provider`,`provider_trade_no`) USING BTREE,
  KEY `idx_payment_event_hash` (`payload_hash`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `api_quota_ledger` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `direction` varchar(10) NOT NULL,
  `amount` bigint(20) unsigned NOT NULL,
  `source_type` varchar(30) NOT NULL,
  `source_id` bigint(20) unsigned DEFAULT NULL,
  `request_id` varchar(64) DEFAULT NULL,
  `balance_before` bigint(20) unsigned DEFAULT NULL,
  `balance_after` bigint(20) unsigned DEFAULT NULL,
  `remark` varchar(500) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_request_id` (`request_id`) USING BTREE,
  KEY `idx_user_time` (`user_id`,`created_at`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `api_quota_lots` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `source_type` varchar(30) NOT NULL,
  `source_id` bigint(20) unsigned DEFAULT NULL,
  `paid_quota` bigint(20) unsigned NOT NULL DEFAULT '0',
  `bonus_quota` bigint(20) unsigned NOT NULL DEFAULT '0',
  `paid_remaining` bigint(20) unsigned NOT NULL DEFAULT '0',
  `bonus_remaining` bigint(20) unsigned NOT NULL DEFAULT '0',
  `paid_amount_cents` bigint(20) unsigned NOT NULL DEFAULT '0',
  `refundable` tinyint(1) NOT NULL DEFAULT '0',
  `status` varchar(20) NOT NULL DEFAULT 'active',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_quota_lot_source` (`source_type`,`source_id`) USING BTREE,
  KEY `idx_quota_lot_user` (`user_id`,`status`,`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `api_recharge_orders` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `order_no` varchar(40) NOT NULL,
  `user_id` bigint(20) unsigned NOT NULL,
  `provider` varchar(20) NOT NULL DEFAULT 'alipay',
  `amount_cents` bigint(20) unsigned NOT NULL,
  `quota_amount` bigint(20) unsigned NOT NULL,
  `bonus_quota` bigint(20) unsigned NOT NULL DEFAULT '0',
  `refund_amount_cents` bigint(20) unsigned NOT NULL DEFAULT '0',
  `refunded_quota` bigint(20) unsigned NOT NULL DEFAULT '0',
  `status` varchar(20) NOT NULL DEFAULT 'pending',
  `provider_trade_no` varchar(100) DEFAULT NULL,
  `paid_at` datetime DEFAULT NULL,
  `credited_at` datetime DEFAULT NULL,
  `expired_at` datetime DEFAULT NULL,
  `last_notify_at` datetime DEFAULT NULL,
  `notify_payload_hash` char(64) DEFAULT NULL,
  `failure_reason` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_recharge_order_no` (`order_no`) USING BTREE,
  UNIQUE KEY `uk_recharge_provider_trade` (`provider`,`provider_trade_no`) USING BTREE,
  KEY `idx_recharge_user_created` (`user_id`,`created_at`) USING BTREE,
  KEY `idx_recharge_status` (`status`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `api_refund_orders` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `refund_no` varchar(50) NOT NULL,
  `recharge_order_id` bigint(20) unsigned NOT NULL,
  `user_id` bigint(20) unsigned NOT NULL,
  `provider` varchar(20) NOT NULL DEFAULT 'alipay',
  `provider_trade_no` varchar(100) NOT NULL,
  `amount_cents` bigint(20) unsigned NOT NULL,
  `quota_to_recover` bigint(20) unsigned NOT NULL DEFAULT '0',
  `bonus_to_recover` bigint(20) unsigned NOT NULL DEFAULT '0',
  `status` varchar(30) NOT NULL DEFAULT 'created',
  `failure_reason` varchar(255) DEFAULT NULL,
  `requested_by` bigint(20) unsigned DEFAULT NULL,
  `request_source` varchar(20) NOT NULL DEFAULT 'admin',
  `user_reason` varchar(500) DEFAULT NULL,
  `reviewed_by` bigint(20) unsigned DEFAULT NULL,
  `reviewed_at` datetime DEFAULT NULL,
  `provider_response_hash` char(64) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `succeeded_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_refund_no` (`refund_no`) USING BTREE,
  KEY `idx_refund_recharge` (`recharge_order_id`,`id`) USING BTREE,
  KEY `idx_refund_user` (`user_id`,`created_at`) USING BTREE,
  KEY `idx_refund_status` (`status`) USING BTREE,
  KEY `idx_refund_review` (`status`,`request_source`,`created_at`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `api_request_logs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `request_id` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `endpoint_id` bigint(20) unsigned DEFAULT NULL,
  `user_id` bigint(20) unsigned DEFAULT NULL,
  `key_id` bigint(20) unsigned DEFAULT NULL,
  `method` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL,
  `path` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status_code` smallint(5) unsigned DEFAULT NULL,
  `duration_ms` int(10) unsigned DEFAULT NULL,
  `ip` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_request_id` (`request_id`) USING BTREE,
  KEY `idx_endpoint_created` (`endpoint_id`,`created_at`) USING BTREE,
  KEY `idx_request_logs_user_created` (`user_id`,`created_at`) USING BTREE,
  KEY `idx_request_logs_key_created` (`key_id`,`created_at`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `api_settings` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `key` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `value` text COLLATE utf8mb4_unicode_ci,
  `type` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'string',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_key` (`key`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `api_users` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `email` varchar(190) DEFAULT NULL,
  `password_hash` varchar(255) NOT NULL,
  `status` tinyint(3) unsigned NOT NULL DEFAULT '1',
  `ban_reason` varchar(500) DEFAULT NULL,
  `key_status` tinyint(3) unsigned NOT NULL DEFAULT '1',
  `key_ban_reason` varchar(500) DEFAULT NULL,
  `integrity_locked` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `integrity_reason` varchar(500) DEFAULT NULL,
  `integrity_locked_at` datetime DEFAULT NULL,
  `integrity_violation_count` int(10) unsigned NOT NULL DEFAULT '0',
  `penalty_debt` bigint(20) unsigned NOT NULL DEFAULT '0',
  `quota_total` bigint(20) unsigned DEFAULT NULL,
  `quota_used` bigint(20) unsigned NOT NULL DEFAULT '0',
  `quota_integrity_hash` char(64) DEFAULT NULL,
  `trusted_quota_total` bigint(20) unsigned DEFAULT NULL,
  `trusted_quota_used` bigint(20) unsigned NOT NULL DEFAULT '0',
  `last_login_at` datetime DEFAULT NULL,
  `last_login_ip` varchar(45) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `uk_username` (`username`) USING BTREE,
  UNIQUE KEY `uk_email` (`email`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;
