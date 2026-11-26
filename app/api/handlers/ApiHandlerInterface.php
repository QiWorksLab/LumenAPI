<?php
namespace app\api\handlers;
interface ApiHandlerInterface{
 public function handle(array $endpoint,string $method,array $params=[]):array;
}
