<?php
namespace app\controller;
use app\BaseController;
use app\service\AdminAccess;
use think\facade\Db;
use think\facade\Session;
use think\facade\View;

class AdminUsers extends BaseController
{
    private function ownerGuard()
    {
        return AdminAccess::ownerGuard();
    }

    private function audit(string $action,int $id,string $detail=''):void
    {
        Db::name('audit_logs')->insert(['admin_id'=>Session::get('lumen_admin_id'),'action'=>$action,'target_type'=>'admin','target_id'=>$id,'detail'=>$detail,'ip'=>request()->ip(),'created_at'=>date('Y-m-d H:i:s')]);
    }

    public function index()
    {
        if($r=$this->ownerGuard())return $r;
        View::assign(['items'=>Db::name('admins')->order('id')->select()->toArray(),'username'=>Session::get('lumen_admin_username'),'newPassword'=>Session::pull('lumen_new_admin_password','')]);
        return View::fetch(root_path().'view/admin/admins.html');
    }

    public function create()
    {
        if($r=$this->ownerGuard())return $r;
        $username=trim((string)input('post.username',''));
        $password=(string)input('post.password','');
        if(!preg_match('/^[A-Za-z0-9_]{3,32}$/',$username))return response('管理员用户名需 3-32 位字母、数字或下划线',422);
        if(strlen($password)<10)return response('管理员密码至少 10 位',422);
        if(Db::name('admins')->where('username',$username)->find())return response('管理员用户名已存在',409);
        $now=date('Y-m-d H:i:s');
        $id=Db::name('admins')->insertGetId(['username'=>$username,'password_hash'=>password_hash($password,PASSWORD_DEFAULT),'role'=>'admin','status'=>1,'created_at'=>$now,'updated_at'=>$now]);
        $this->audit('admin.create',$id,'role=admin; username='.$username);
        return redirect('/admin/admins');
    }

    public function toggle($id)
    {
        if($r=$this->ownerGuard())return $r;
        $id=(int)$id;$me=(int)Session::get('lumen_admin_id');
        $a=Db::name('admins')->where('id',$id)->find();
        if(!$a)return response('Not Found',404);
        if(($a['role']??'admin')==='owner'||$id===$me)return response('Owner 账户不能在这里停用',403);
        $status=(int)$a['status']===1?0:1;
        Db::name('admins')->where('id',$id)->update(['status'=>$status,'updated_at'=>date('Y-m-d H:i:s')]);
        if(!$status)Db::name('keys')->where('admin_id',$id)->update(['status'=>0,'ban_source'=>'admin','ban_reason'=>'管理员账户已停用','banned_at'=>date('Y-m-d H:i:s'),'updated_at'=>date('Y-m-d H:i:s')]);
        $this->audit('admin.toggle',$id,'status='.$status);
        return redirect('/admin/admins');
    }
}
