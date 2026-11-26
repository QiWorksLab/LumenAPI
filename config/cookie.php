<?php
// +----------------------------------------------------------------------
// | Cookie设置
// +----------------------------------------------------------------------
return [
    // cookie 保存时间
    'expire'    => 0,
    // cookie 保存路径
    'path'      => '/',
    // cookie 有效域名
    'domain'    => '',
    //  cookie 启用安全传输
    // Keep cookies secure by default; allow explicit HTTP-only development override.
    'secure'    => filter_var(env('COOKIE_SECURE', true), FILTER_VALIDATE_BOOLEAN),
    // httponly设置
    'httponly'  => true,
    // 是否使用 setcookie
    'setcookie' => true,
    // samesite 设置，支持 'strict' 'lax'
    'samesite'  => 'lax',
];
