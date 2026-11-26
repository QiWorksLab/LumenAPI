<?php
namespace app\service;

use think\facade\Db;
use think\facade\Session;

class AdminAccess
{
    public static function current(): ?array
    {
        $id=(int)Session::get('lumen_admin_id',0);
        if($id<=0)return null;
        $admin=Db::name('admins')->where('id',$id)->where('status',1)->find();
        if(!$admin){
            Session::clear();
            return null;
        }
        return $admin;
    }

    public static function guard()
    {
        return self::current() ? null : redirect('/admin');
    }

    public static function ownerGuard()
    {
        $admin=self::current();
        if(!$admin)return redirect('/admin');
        return (($admin['role']??'admin')==='owner') ? null : response('仅 Owner 可执行此操作',403);
    }

    public static function isOwner(): bool
    {
        $admin=self::current();
        return $admin && (($admin['role']??'admin')==='owner');
    }
}
