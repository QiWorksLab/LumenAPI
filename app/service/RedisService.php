<?php
namespace app\service;
use think\facade\Db;
class RedisService{
 public static function status():string{
  $enabled=false;
  try{
   $s=self::settings();
   $envEnabled=getenv('REDIS_ENABLED');
   $envComplete=getenv('REDIS_HOST')!==false&&getenv('REDIS_PORT')!==false&&getenv('REDIS_PASSWORD')!==false&&getenv('REDIS_DATABASE')!==false;
   $enabled=array_key_exists('redis.enabled',$s)?$s['redis.enabled']==='1':($envEnabled!==false?in_array(strtolower((string)$envEnabled),['1','true','yes','on'],true):$envComplete);
  }catch(\Throwable $e){
   return 'error';
  }
  if(!extension_loaded('redis'))return self::resolveStatus($enabled,false);
  try{
   $host=(string)(getenv('REDIS_HOST')?:($s['redis.host']??'127.0.0.1'));
   $port=(int)(getenv('REDIS_PORT')?:($s['redis.port']??6379));
   $password=getenv('REDIS_PASSWORD');if($password===false)$password=(string)($s['redis.password']??'');
   $db=(int)(getenv('REDIS_DATABASE')?:($s['redis.database']??0));
   $r=new \Redis();$r->connect($host,$port,0.35);
   if($password!=='')$r->auth($password);
   if($db!==0)$r->select($db);
   $ok=$r->ping();$r->close();
   return self::resolveStatus($enabled,(bool)$ok);
  }catch(\Throwable $e){return self::resolveStatus($enabled,false);}
 }
 private static function resolveStatus(bool $enabled,bool $available):string{
  if($enabled)return $available?'active':'error';
  return $available?'pending':'disabled';
 }

 private static ?\Redis $client=null; private static bool $attempted=false; private static ?array $settings=null; private static float $settingsMs=0.0;
 private static function settings():array{if(self::$settings!==null)return self::$settings;$t=microtime(true);$rows=Db::name('settings')->where('key','like','redis.%')->field('key,value')->select()->toArray();self::$settingsMs=(microtime(true)-$t)*1000;$s=[];foreach($rows as $x)$s[$x['key']]=$x['value'];return self::$settings=$s;}
 public static function settingsQueryMs():float{return self::$settingsMs;} public static function connect():?\Redis{if(self::$client instanceof \Redis)return self::$client;if(self::$attempted||!extension_loaded('redis'))return null;self::$attempted=true;$envEnabled=getenv('REDIS_ENABLED');$envHost=getenv('REDIS_HOST');$envPort=getenv('REDIS_PORT');$envPassword=getenv('REDIS_PASSWORD');$envDatabase=getenv('REDIS_DATABASE');$envComplete=$envHost!==false&&$envPort!==false&&$envPassword!==false&&$envDatabase!==false;$s=self::settings();if(array_key_exists('redis.enabled',$s)){$enabled=$s['redis.enabled']==='1';}elseif($envEnabled!==false){$enabled=in_array(strtolower((string)$envEnabled),['1','true','yes','on'],true);}else{$enabled=$envComplete;}if(!$enabled)return null;try{$host=(string)(getenv('REDIS_HOST')?:($s['redis.host']??'127.0.0.1'));$port=(int)(getenv('REDIS_PORT')?:($s['redis.port']??6379));$password=getenv('REDIS_PASSWORD');if($password===false)$password=(string)($s['redis.password']??'');$db=(int)(getenv('REDIS_DATABASE')?:($s['redis.database']??0));$r=new \Redis();$r->pconnect($host,$port,0.35,'lumenapi-gateway');if($password!=='')$r->auth($password);if($db!==0)$r->select($db);return self::$client=$r;}catch(\Throwable $e){return null;}}
}
