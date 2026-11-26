<?php
// +----------------------------------------------------------------------
// | ThinkPHP [ WE CAN DO IT JUST THINK ]
// +----------------------------------------------------------------------
// | Copyright (c) 2006~2018 http://thinkphp.cn All rights reserved.
// +----------------------------------------------------------------------
// | Licensed ( http://www.apache.org/licenses/LICENSE-2.0 )
// +----------------------------------------------------------------------
// | Author: liu21st <liu21st@gmail.com>
// +----------------------------------------------------------------------
use think\facade\Route;

Route::get('/', 'User/home')->completeMatch();

// LumenAPI Gateway skeleton
Route::post('v1/chat/completions', 'Gateway/chatCompletions')->completeMatch();
Route::rule('v1/gateway/:slug', 'Gateway/handle', 'GET|POST|PUT|PATCH|DELETE');
Route::rule('v1/:slug', 'Gateway/handle', 'GET|POST|PUT|PATCH|DELETE');

Route::get('admin/keys', 'Keys/index')->completeMatch();
Route::post('admin/keys/create', 'Keys/create')->completeMatch();
Route::post('admin/keys/:id/toggle', 'Keys/toggle')->completeMatch();
Route::post('admin/keys/:id/quota', 'Keys/quota')->completeMatch();

Route::get('admin/logs', 'Logs/index')->completeMatch();
Route::get('admin/admins', 'AdminUsers/index')->completeMatch();
Route::post('admin/admins/create', 'AdminUsers/create')->completeMatch();
Route::post('admin/admins/:id/toggle', 'AdminUsers/toggle')->completeMatch();

// LumenAPI Admin
Route::get('admin/endpoints', 'Panel/endpoints')->completeMatch();
Route::post('admin/endpoints/save', 'Panel/saveEndpoint')->completeMatch();
Route::get('admin/endpoints/:id/edit', 'Panel/editEndpoint')->completeMatch();
Route::post('admin/endpoints/:id/params', 'Panel/saveEndpointParams')->completeMatch();
Route::post('admin/endpoints/:id/test', 'Panel/testEndpoint')->completeMatch();
Route::post('admin/endpoints/:id/toggle', 'Panel/toggleEndpoint')->completeMatch();
Route::get('admin/settings', 'Panel/settings')->completeMatch();
Route::post('admin/settings/save', 'Panel/saveSettings')->completeMatch();
Route::post('admin/settings/redis/test', 'Panel/testRedis')->completeMatch();
Route::get('admin/payments', 'Panel/payments')->completeMatch();
Route::post('admin/payments/:id/refund', 'RefundAdmin/create')->completeMatch();
Route::post('admin/refunds/:id/reconcile', 'RefundAdmin/reconcile')->completeMatch();
Route::post('admin/refunds/:id/approve', 'RefundAdmin/approve')->completeMatch();
Route::post('admin/refunds/:id/reject', 'RefundAdmin/reject')->completeMatch();
Route::get('admin/audit', 'Panel/audit')->completeMatch();
Route::get('admin/login', 'Admin/login')->completeMatch();
Route::post('admin/login', 'Admin/authenticate')->completeMatch();
Route::post('admin/logout', 'Admin/logout')->completeMatch();
Route::get('admin', 'Admin/dashboard')->completeMatch();


// LumenAPI User
Route::get('user/register', 'User/register')->completeMatch();
Route::post('user/register', 'User/create')->completeMatch();
Route::get('user/login', 'User/login')->completeMatch();
Route::post('user/login', 'User/authenticate')->completeMatch();
Route::post('user/logout', 'User/logout')->completeMatch();
Route::post('user/key/reset', 'User/resetKey')->completeMatch();
Route::post('user/keys/create', 'User/createKey')->completeMatch();
Route::post('user/keys/:id/toggle', 'User/toggleKey')->completeMatch();
Route::post('user/keys/:id/revoke', 'User/revokeKey')->completeMatch();
Route::get('user/api/:slug', 'User/apiDoc')->completeMatch();
Route::get('user/status', 'User/status')->completeMatch();
Route::get('user/recharge', 'Recharge/index')->completeMatch();
Route::post('user/recharge/create', 'Recharge/create')->completeMatch();
Route::post('user/recharge/:id/query', 'Recharge/queryOrder')->completeMatch();
Route::post('user/recharge/:id/refund-request', 'RefundRequest/apply')->completeMatch();
Route::post('user/refunds/:id/cancel', 'RefundRequest/cancel')->completeMatch();
Route::post('payment/alipay/notify', 'Recharge/notify')->completeMatch();
Route::get('payment/alipay/return', 'Recharge/returned')->completeMatch();
Route::get('user', 'User/dashboard')->completeMatch();

// Admin users
Route::get('admin/users', 'Users/index')->completeMatch();
Route::get('admin/users/:id', 'Users/detail')->completeMatch();
Route::post('admin/users/:id/toggle', 'Users/toggle')->completeMatch();
Route::post('admin/users/:id/quota', 'Users/quota')->completeMatch();
Route::post('admin/users/:id/integrity-unlock', 'Users/unlockIntegrity')->completeMatch();
Route::post('admin/users/:id/key/reset', 'Users/resetKey')->completeMatch();
Route::post('admin/users/:id/admin-role', 'Users/adminRole')->completeMatch();


// LumenAPI Installer
Route::post('install/initialize', 'Install/initializeInstall')->completeMatch();
Route::get('install/admin', 'Install/admin')->completeMatch();
Route::get('install/database', 'Install/database')->completeMatch();
Route::post('install/database/test', 'Install/testDatabase')->completeMatch();
Route::get('install', 'Install/index')->completeMatch();
