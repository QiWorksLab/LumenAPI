<?php
namespace app;

use think\db\exception\DataNotFoundException;
use think\db\exception\ModelNotFoundException;
use think\exception\Handle;
use think\exception\HttpException;
use think\exception\HttpResponseException;
use think\exception\ValidateException;
use think\Response;
use Throwable;

/**
 * 应用异常处理类
 */
class ExceptionHandle extends Handle
{
    /**
     * 不需要记录信息（日志）的异常类列表
     * @var array
     */
    protected $ignoreReport = [
        HttpException::class,
        HttpResponseException::class,
        ModelNotFoundException::class,
        DataNotFoundException::class,
        ValidateException::class,
    ];

    /**
     * 记录异常信息（包括日志或者其它方式记录）
     *
     * @access public
     * @param  Throwable $exception
     * @return void
     */
    public function report(Throwable $exception): void
    {
        // 使用内置的方式记录异常日志
        parent::report($exception);
    }

    /**
     * Render an exception into an HTTP response.
     *
     * @access public
     * @param \think\Request   $request
     * @param Throwable $e
     * @return Response
     */
    public function render($request, Throwable $e): Response
    {
        if ($request->isJson() || str_starts_with($request->pathinfo(), 'v1/')) {
            return parent::render($request, $e);
        }

        $status = $e instanceof HttpException ? $e->getStatusCode() : 500;
        if ($status < 400 || $status > 599) $status = 500;
        $messages = [
            400 => '请求参数有误', 401 => '请先登录', 403 => '没有访问权限',
            404 => '页面不存在', 405 => '请求方式不支持', 429 => '请求过于频繁',
            500 => '服务器内部错误', 502 => '上游服务异常',
            503 => '服务暂时不可用', 504 => '上游服务响应超时',
        ];
        $message = $messages[$status] ?? '请求处理失败';
        $html = '<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>'
            . $status . ' · LumenAPI</title><style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#07111f;color:#eaf2ff;font-family:Arial,"Microsoft YaHei",sans-serif}.box{text-align:center;padding:32px}.code{font-size:100px;font-weight:800;color:#79d7ff}.text{color:#a5b6cd;margin:12px 0 28px}.btn{display:inline-block;padding:12px 20px;border-radius:10px;background:#39bdf8;color:#04111e;text-decoration:none}</style></head><body><main class="box"><div class="code">'
            . $status . '</div><h2>' . htmlspecialchars($message, ENT_QUOTES, 'UTF-8')
            . '</h2><p class="text">请稍后重试，或联系管理员查看服务器日志。</p><a class="btn" href="/admin/login">返回登录页</a></main></body></html>';
        return response($html, $status)->contentType('text/html; charset=utf-8');
    }
}
