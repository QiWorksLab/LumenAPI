#!/usr/bin/env bash
set -Eeuo pipefail
CONTAINER=lumenapi-lumenapi-1
[[ ${1:-} == --help ]] && { echo '用法: sudo lumenapi [--check|--verify|--allow-destructive]'; echo '默认只读；清理/删除等危险操作必须显式传入 --allow-destructive'; exit 0; }
ALLOW_DESTRUCTIVE=0
if [[ ${1:-} == --allow-destructive ]]; then ALLOW_DESTRUCTIVE=1; shift; fi
[[ $EUID -eq 0 ]] || { echo '请使用 sudo lumenapi'; exit 1; }
docker inspect "$CONTAINER" >/dev/null || exit 1
confirm(){ local answer; [[ $ALLOW_DESTRUCTIVE -eq 1 ]] || { echo '危险操作已锁定：请使用 sudo lumenapi --allow-destructive 显式解锁'; return 1; }; [[ -t 0 ]] || { echo '需要 SSH 交互终端'; return 1; }; read -r -p "输入 $1 确认：" answer; [[ "$answer" == "$1" ]]; }
run(){ docker exec -i -e TOOL_ACTION="$1" -e TARGET_USER="${2:-}" "$CONTAINER" php /dev/stdin <<'PHP'
<?php
$db=new PDO('mysql:host='.getenv('DB_HOST').';port='.(getenv('DB_PORT')?:3306).';dbname='.getenv('DB_NAME'),getenv('DB_USER'),getenv('DB_PASS'),[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC]);
$action=getenv('TOOL_ACTION');
$tables=['api_request_logs','api_billing_logs','api_quota_ledger','api_audit_logs','api_payment_events','api_refund_orders','api_recharge_orders'];
if($action==='check'){
 foreach(['api_users','api_keys','api_quota_lots',...$tables] as $t)echo "$t: ".$db->query('SELECT COUNT(*) FROM '.$t)->fetchColumn().PHP_EOL;
 foreach($db->query('SELECT id,username,quota_total,quota_used FROM api_users') as $u)echo "用户 {$u['id']} {$u['username']} 剩余=".($u['quota_total']===null?'无限':max(0,$u['quota_total']-$u['quota_used'])).PHP_EOL;
 exit;
}
if($action==='verify'){
 $bad=0;
 foreach($db->query('SELECT id,username,quota_total,quota_used FROM api_users') as $u){
  $q=$db->prepare("SELECT COALESCE(SUM(paid_remaining+bonus_remaining),0) FROM api_quota_lots WHERE user_id=? AND status='active'");$q->execute([$u['id']]);$lots=(int)$q->fetchColumn();
  $available=$u['quota_total']===null?null:max(0,(int)$u['quota_total']-(int)$u['quota_used']);
  $ok=$available===null||$available===$lots;
  echo "{$u['username']} 余额=".($available??'无限')." 批次=$lots ".($ok?'OK':'不一致').PHP_EOL;
  if(!$ok)$bad++;
 }
 $orphans=(int)$db->query('SELECT COUNT(*) FROM api_keys k LEFT JOIN api_users u ON k.user_id=u.id WHERE k.user_id IS NOT NULL AND u.id IS NULL')->fetchColumn();
 echo "孤立 API Key：$orphans".PHP_EOL;exit(($bad||$orphans)?1:0);
}
if($action==='logs'){$n=$db->exec('DELETE FROM api_request_logs');echo "请求日志删除 $n 条".PHP_EOL;exit;}
if($action==='reset-id'){$next=(int)$db->query('SELECT COALESCE(MAX(id),0)+1 FROM api_users')->fetchColumn();$db->exec('ALTER TABLE api_users AUTO_INCREMENT='.$next);echo "下一个用户 ID：$next".PHP_EOL;exit;}
if($action==='history'){
 $db->beginTransaction();try{
  foreach($db->query('SELECT id,quota_total,quota_used FROM api_users') as $u){
   $q=$db->prepare("SELECT COALESCE(SUM(paid_remaining+bonus_remaining),0) FROM api_quota_lots WHERE user_id=? AND status='active'");$q->execute([$u['id']]);$lots=(int)$q->fetchColumn();
   if($u['quota_total']!==null&&$lots!==max(0,(int)$u['quota_total']-(int)$u['quota_used']))throw new RuntimeException('额度批次不匹配，终止删除：用户 '.$u['id']);
  }
  // Preserve spendable credits; detach them from now-deleted recharge orders.
  $db->exec("UPDATE api_quota_lots SET source_type='admin_adjust',source_id=NULL,bonus_quota=paid_remaining+bonus_remaining,paid_remaining=0,paid_quota=0,refundable=0,paid_amount_cents=0 WHERE source_type='recharge' AND status='active' AND (paid_remaining+bonus_remaining)>0");
  $db->exec("DELETE FROM api_quota_lots WHERE source_type='recharge'");
  foreach($tables as $t)echo "$t: ".$db->exec('DELETE FROM '.$t).PHP_EOL;
  $db->commit();echo '历史清理完成'.PHP_EOL;
 }catch(Throwable $e){$db->rollBack();fwrite(STDERR,$e->getMessage().PHP_EOL);exit(1);}exit;
}
if($action==='delete-user'){
 $name=getenv('TARGET_USER');$db->beginTransaction();try{
  $q=$db->prepare('SELECT id FROM api_users WHERE username=? FOR UPDATE');$q->execute([$name]);$id=$q->fetchColumn();if(!$id)throw new RuntimeException('用户不存在');
  foreach(['api_keys','api_quota_lots','api_billing_logs','api_quota_ledger','api_request_logs','api_refund_orders','api_recharge_orders'] as $t){$q=$db->prepare('DELETE FROM '.$t.' WHERE user_id=?');$q->execute([$id]);}
  $q=$db->prepare('DELETE FROM api_users WHERE id=?');$q->execute([$id]);$db->commit();echo "已删除 $name".PHP_EOL;
 }catch(Throwable $e){$db->rollBack();fwrite(STDERR,$e->getMessage().PHP_EOL);exit(1);}exit;
}
PHP
}
case "${1:-}" in --check) run check; exit;; --verify) run verify; exit;; '') ;; *) echo '未知参数'; exit 2;; esac
[[ -t 0 ]] || { echo '请在 SSH 交互终端运行 sudo lumenapi'; exit 1; }
while true; do
 echo; echo '======== LumenAPI SSH 工具箱 V0.1.1 ========'; [[ $ALLOW_DESTRUCTIVE -eq 1 ]] && echo '注意：危险操作已解锁，操作前请确认备份' || echo '安全模式：危险操作已锁定'; echo '1) 检查状态'; echo '2) 清空请求日志和程序日志'; echo '3) 清空历史计费/额度/充值/退款/审计记录'; echo '4) 删除指定用户及关联记录'; echo '5) 整理下一个用户 ID'; echo '6) 校验余额与额度批次'; echo '0) 退出'
 read -r -p '请选择：' choice || exit 0
 case "$choice" in
 1) run check;;
 2) if confirm CLEAR-LOGS; then run logs; docker exec "$CONTAINER" sh -c 'find /var/www/html/runtime/log -type f -name "*.log" -delete'; echo '程序日志已清空'; fi;;
 3) echo '警告：删除历史订单后无法再按原订单退款。保留现有余额、用户和 API Key。'; confirm CLEAR-HISTORY && run history || true;;
 4) read -r -p '用户名：' name; if [[ "$name" =~ ^[A-Za-z0-9_]{1,50}$ ]]; then confirm "DELETE-$name" && run delete-user "$name" || true; else echo '用户名格式错误'; fi;;
 5) confirm RESET-ID && run reset-id || true;;
 6) run verify;;
 0) exit 0;;
 *) echo '无效选项';;
 esac
done
