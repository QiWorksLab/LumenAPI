<?php
namespace app\service;
use think\facade\Db;
class QuotaLotService{
 public static function consume(int $uid,int $amount):void{
  if($amount<=0)return;
  $need=$amount;$now=date('Y-m-d H:i:s');
  $lots=Db::name('quota_lots')->where('user_id',$uid)->where('status','active')->whereRaw("((source_type='recharge' AND (paid_remaining>0 OR bonus_remaining>0)) OR (source_type<>'recharge' AND bonus_remaining>0))")->orderRaw("CASE WHEN source_type NOT IN ('recharge') THEN 0 ELSE 1 END, id ASC")->lock(true)->field('id,source_type,paid_remaining,bonus_remaining')->select()->toArray();
  foreach($lots as $lot){if($need<=0)break;
   // Keep the existing refund-sensitive lot order; all selected rows are locked by this transaction.
   $paid=(int)$lot['paid_remaining'];$bonus=(int)$lot['bonus_remaining'];$paidTake=0;$bonusTake=0;
   if($lot['source_type']!=='recharge'){$bonusTake=min($need,$bonus);$need-=$bonusTake;}
   else{$paidTake=min($need,$paid);$need-=$paidTake;if($need>0&&$paid-$paidTake===0){$bonusTake=min($need,$bonus);$need-=$bonusTake;}}
   if($paidTake>0||$bonusTake>0){$changes=['updated_at'=>$now];if($paidTake>0)$changes['paid_remaining']=$paid-$paidTake;if($bonusTake>0)$changes['bonus_remaining']=$bonus-$bonusTake;Db::name('quota_lots')->where('id',$lot['id'])->update($changes);}
  }
  if($need>0)throw new \RuntimeException('quota_lot_insufficient');
 }
 public static function createRechargeLot(array $o,int $paidQuota,int $bonusQuota,?int $refundableCents=null):void{
  if($paidQuota<=0&&$bonusQuota<=0)return;$now=date('Y-m-d H:i:s');
  $exists=Db::name('quota_lots')->where('source_type','recharge')->where('source_id',$o['id'])->find();if($exists)return;
  Db::name('quota_lots')->insert(['user_id'=>$o['user_id'],'source_type'=>'recharge','source_id'=>$o['id'],'paid_quota'=>$paidQuota,'bonus_quota'=>$bonusQuota,'paid_remaining'=>$paidQuota,'bonus_remaining'=>$bonusQuota,'paid_amount_cents'=>$refundableCents??(int)$o['amount_cents'],'refundable'=>$paidQuota>0?1:0,'status'=>'active','created_at'=>$now,'updated_at'=>$now]);
 }
 public static function createFreeLot(int $uid,string $type,?int $sourceId,int $amount):void{
  if($amount<=0)return;$now=date('Y-m-d H:i:s');Db::name('quota_lots')->insert(['user_id'=>$uid,'source_type'=>$type,'source_id'=>$sourceId,'paid_quota'=>0,'bonus_quota'=>$amount,'paid_remaining'=>0,'bonus_remaining'=>$amount,'paid_amount_cents'=>0,'refundable'=>0,'status'=>'active','created_at'=>$now,'updated_at'=>$now]);
 }
}