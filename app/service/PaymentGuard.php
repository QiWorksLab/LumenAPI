<?php
namespace app\service;
class PaymentGuard{public static function allow(int $uid,string $action,int $limit,int $seconds):bool{if($uid<1)return false;$r=RedisService::connect();if(!$r)return true;$bucket=(int)floor(time()/$seconds);$key='lumen:payguard:'.$action.':'.$uid.':'.$bucket;$n=$r->incr($key);if($n===1)$r->expire($key,$seconds+30);return$n<=$limit;}}
