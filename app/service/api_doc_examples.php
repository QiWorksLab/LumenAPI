<?php

$exampleBase='__LUMENAPI_ORIGIN__/v1/'.$api['slug'];
$exampleQuery=[];$exampleBody=[];$exampleHeaders=[];$hasPath=false;
foreach($params as $param){
$name=(string)$param['name'];$type=$param['data_type'];$value=$param['default_value']??null;
if($value===null||$value===''){$value=match($type){'integer'=>1,'number'=>1.0,'boolean'=>true,'json'=>[],default=>($name==='url'?'https://example.com/video':'YOUR_'.strtoupper($name))};}
elseif($type==='integer')$value=(int)$value;elseif($type==='number')$value=(float)$value;elseif($type==='boolean')$value=filter_var($value,FILTER_VALIDATE_BOOLEAN);elseif($type==='json'){$decoded=json_decode((string)$value,true);$value=json_last_error()===JSON_ERROR_NONE?$decoded:[];}
if($param['location']==='query')$exampleQuery[$name]=$value;
elseif($param['location']==='body')$exampleBody[$name]=$value;
elseif($param['location']==='header')$exampleHeaders[]=$name.': '.(is_scalar($value)?(string)$value:json_encode($value,JSON_UNESCAPED_UNICODE));
elseif($param['location']==='path')$hasPath=true;
}
$mode=$api['auth_mode'];if($mode==='query')$exampleQuery=['key'=>'YOUR_API_KEY']+$exampleQuery;
$exampleUrl=$exampleBase.($exampleQuery?'?'.http_build_query($exampleQuery,'','&',PHP_QUERY_RFC3986):'');
$exampleMethod=$api['method']==='AUTO'?($exampleBody?'POST':'GET'):$api['method'];
$quoteShell=static fn($text)=>"'".str_replace("'","'\\''",$text)."'";
$lines=['curl --request '.$exampleMethod.' '.$quoteShell($exampleUrl),'  --header '.$quoteShell('Accept: application/json')];
if(in_array($mode,['both','bearer']))$lines[]='  --header '.$quoteShell('Authorization: Bearer YOUR_API_KEY');
foreach($exampleHeaders as $line)$lines[]='  --header '.$quoteShell($line);
if($exampleBody){$lines[]='  --header '.$quoteShell('Content-Type: application/json');$lines[]='  --data-raw '.$quoteShell(json_encode($exampleBody,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES));}
$advancedExample=implode(" ".chr(92).chr(10),$lines);
$simplePossible=$exampleMethod==='GET'&&!$exampleBody&&!$exampleHeaders&&!$hasPath&&in_array($mode,['both','query','none']);
$simpleUrl=$exampleBase;$simpleQuery=$exampleQuery;if($mode==='both')$simpleQuery=['key'=>'YOUR_API_KEY']+$simpleQuery;
$simpleUrl.=($simpleQuery?'?'.http_build_query($simpleQuery,'','&',PHP_QUERY_RFC3986):'');

