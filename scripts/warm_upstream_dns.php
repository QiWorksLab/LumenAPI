<?php
// Refresh public upstream DNS off the request path. No parsing calls or quota writes.
if(PHP_SAPI!=='cli')exit(1);
chdir(dirname(__DIR__));require 'vendor/autoload.php';$app=new \think\App();$app->initialize();
$r=\app\service\RedisService::connect();if(!$r)exit(0);
$seen=[];$ok=0;$failed=0;
foreach(\think\facade\Db::name('endpoints')->where('status',1)->column('target_url') as $url){
 if(!is_string($url)||$url===''||str_contains($url,'{'))continue;
 $p=parse_url($url);if(!$p||empty($p['host']))continue;
 $key=strtolower($p['host']).':'.($p['port']??(($p['scheme']??'')==='https'?443:80));if(isset($seen[$key]))continue;$seen[$key]=true;
 try{if(\app\service\UpstreamHttpService::resolvePublic($url,true))$ok++;else $failed++;}catch(\Throwable $e){$failed++;}
}
echo 'DNS warmed='.$ok.' failed='.$failed.PHP_EOL;
