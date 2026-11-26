<?php
namespace app\controller;

use app\BaseController;
use think\facade\View;
use think\facade\Session;

class Install extends BaseController
{
    private function lockFile(): string { return root_path().'storage/install/install.lock'; }
    private function configuredDatabase(): array {
        $file=root_path().'storage/install/database.json';
        if(is_file($file)){$saved=json_decode((string)file_get_contents($file),true);if(is_array($saved))return $saved;}
        return ['host'=>(string)env('DB_HOST',''),'port'=>(int)env('DB_PORT',3306),'database'=>(string)env('DB_NAME',''),'username'=>(string)env('DB_USER',''),'password'=>(string)env('DB_PASS',''),'prefix'=>'api_'];
    }
    private function connect(array $db): \PDO {
        if($db['host']===''||$db['database']===''||$db['username']==='') throw new \RuntimeException('请在安装向导中填写数据库配置。');
        return new \PDO(sprintf('mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4',$db['host'],$db['port'],$db['database']),$db['username'],$db['password'],[\PDO::ATTR_ERRMODE=>\PDO::ERRMODE_EXCEPTION,\PDO::ATTR_TIMEOUT=>5,\PDO::ATTR_DEFAULT_FETCH_MODE=>\PDO::FETCH_ASSOC,\PDO::MYSQL_ATTR_MULTI_STATEMENTS=>true]);
    }
    private function databaseStatus(): array {
        $db=$this->configuredDatabase(); $pdo=$this->connect($db);
        $db['mysql_version']=(string)$pdo->query('SELECT VERSION()')->fetchColumn();
        $db['table_count']=(int)$pdo->query('SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE()')->fetchColumn();
        return $db;
    }
    public function index() {
        if(is_file($this->lockFile()))return response('LumenAPI 已完成安装。',403);
        $checks=[
            ['name'=>'PHP 版本 >= 8.2','value'=>PHP_VERSION,'ok'=>version_compare(PHP_VERSION,'8.2.0','>=')],
            ['name'=>'PDO MySQL','value'=>extension_loaded('pdo_mysql')?'已启用':'未启用','ok'=>extension_loaded('pdo_mysql')],
            ['name'=>'OpenSSL','value'=>extension_loaded('openssl')?'已启用':'未启用','ok'=>extension_loaded('openssl')],
            ['name'=>'cURL','value'=>extension_loaded('curl')?'已启用':'未启用','ok'=>extension_loaded('curl')],
            ['name'=>'runtime 可写','value'=>is_writable(runtime_path())?'可写':'不可写','ok'=>is_writable(runtime_path())],
            ['name'=>'storage/install 可写','value'=>is_writable(root_path().'storage/install')?'可写':'不可写','ok'=>is_writable(root_path().'storage/install')],
        ];
        View::assign('checks',$checks);View::assign('allPassed',!in_array(false,array_column($checks,'ok'),true));View::assign('phpVersion',PHP_VERSION);View::assign('frameworkVersion',\think\facade\App::version());
        return View::fetch(root_path().'view/install/index.html');
    }
    public function database() {
        if(is_file($this->lockFile()))return response('LumenAPI 已完成安装。',403);
        $db=$this->configuredDatabase();
        View::assign('dbHost',$db['host']);View::assign('dbPort',$db['port']);View::assign('dbName',$db['database']);View::assign('dbUser',$db['username']);View::assign('dockerHost','host.docker.internal');
        return View::fetch(root_path().'view/install/database.html');
    }
    public function admin() {
        if(is_file($this->lockFile()))return response('LumenAPI 已完成安装。',403);
        try{$db=$this->databaseStatus();}catch(\Throwable $e){return response('数据库连接失败，请检查安装时填写的 MySQL 配置。',503);}
        if($db['table_count']!==0)return response('安全保护：目标数据库不是空库，安装停止。',409);
        Session::set('lumen_install_db',$db+['verified_at'=>time()]);
        View::assign('database',$db['database']);View::assign('mysqlVersion',$db['mysql_version']);View::assign('tableCount',$db['table_count']);
        return View::fetch(root_path().'view/install/admin.html');
    }
    public function initializeInstall() {
        if(is_file($this->lockFile()))return response('LumenAPI 已完成安装。',403);
        $u=trim((string)input('post.username',''));$p=(string)input('post.password','');$c=(string)input('post.password_confirm','');
        if(!preg_match('/^[A-Za-z0-9_]{3,32}$/',$u))return response('管理员用户名格式不正确。',422);
        if(strlen($p)<10||$p!==$c)return response('密码至少 10 位且两次输入必须一致。',422);
        try{
            $db=$this->databaseStatus();
            if($db['table_count']!==0)return response('安全保护：目标数据库不是空库，安装停止。',409);
            if($db['prefix']!=='api_')return response('当前版本固定使用 api_ 表前缀。',409);
            $pdo=$this->connect($db);
            $schema=root_path().'storage/migrations/001_complete_schema.sql';
            if(!is_file($schema))throw new \RuntimeException('Installer schema file is missing');
            $sql=(string)file_get_contents($schema);
            preg_match_all('/CREATE TABLE IF NOT EXISTS `[^`]+` \([\s\S]*?\) ENGINE=[^;]+;/',$sql,$matches);
            if(count($matches[0])!==16)throw new \RuntimeException('Installer schema is incomplete');
            foreach($matches[0] as $statement)$pdo->exec($statement);
            // Never mark an incomplete schema as installed. The required migrations must be bundled.
            $required=['api_admins','api_audit_logs','api_billing_logs','api_channels','api_endpoint_params','api_endpoints','api_keys','api_model_mappings','api_payment_events','api_quota_ledger','api_quota_lots','api_recharge_orders','api_refund_orders','api_request_logs','api_settings','api_users'];
            $present=$pdo->query('SHOW TABLES')->fetchAll(\PDO::FETCH_COLUMN);
            $missing=array_values(array_diff($required,$present));
            if($missing)throw new \RuntimeException('Missing database schema: '.implode(',',$missing));
            $st=$pdo->prepare("INSERT INTO api_admins (username,password_hash,role,status,created_at,updated_at) VALUES (?,?,'owner',1,NOW(),NOW())");$st->execute([$u,password_hash($p,PASSWORD_DEFAULT)]);
            $defaults=[
                'app.name'=>'LumenAPI',
                'redis.enabled'=>'1','redis.host'=>'127.0.0.1','redis.port'=>'6379','redis.password'=>'','redis.database'=>'0',
                'ratelimit.enabled'=>'0','ratelimit.key_rpm'=>'120','ratelimit.user_rpm'=>'300','ratelimit.ip_rpm'=>'300',
                'concurrency.enabled'=>'0','concurrency.key_max'=>'5','concurrency.user_max'=>'10',
                'recharge.quota_per_yuan'=>'100','recharge.bonus_enabled'=>'0','recharge.bonus_percent'=>'100',
                'alipay.enabled'=>'0','alipay.app_id'=>'','alipay.seller_id'=>'','alipay.public_key'=>'','alipay.private_key'=>'',
                'alipay.gateway'=>'https://openapi.alipay.com/gateway.do','alipay.notify_url'=>'','alipay.return_url'=>'','alipay.sign_type'=>'RSA2',
                'user.initial_quota'=>'0','user.registration_enabled'=>'1',
            ];
            $setting=$pdo->prepare("INSERT INTO api_settings (`key`,value,type,created_at,updated_at) VALUES (?,?,'string',NOW(),NOW()) ON DUPLICATE KEY UPDATE `key`=VALUES(`key`)");
            foreach($defaults as $key=>$value)$setting->execute([$key,$value]);
        }catch(\Throwable $e){return response('初始化失败。为保护数据，安装器不会自动删除或回滚数据库对象；请查看服务日志并使用新的空数据库重试。',500);}
        file_put_contents($this->lockFile(),json_encode(['installed_at'=>date(DATE_ATOM),'version'=>'0.1.0']),LOCK_EX);@chmod($this->lockFile(),0640);Session::delete('lumen_install_db');
        Session::clear();return redirect('/admin?installed=1');
    }
    public function testDatabase(){
        if(is_file($this->lockFile()))return response('已安装',403);
        $db=['host'=>trim((string)input('post.host','')),'port'=>(int)input('post.port',3306),'database'=>trim((string)input('post.database','')),'username'=>trim((string)input('post.username','')),'password'=>(string)input('post.password',''),'prefix'=>'api_'];
        if(!preg_match('/^[a-zA-Z0-9._-]{1,253}$/',$db['host'])||$db['port']<1||$db['port']>65535||!preg_match('/^[a-zA-Z0-9_]{1,64}$/',$db['database'])||!preg_match('/^[a-zA-Z0-9_]{1,32}$/',$db['username']))return response('数据库参数格式不正确',422);
        try{$pdo=$this->connect($db);$count=(int)$pdo->query('SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE()')->fetchColumn();if($count!==0)return response('安全保护：目标数据库不是空库，禁止覆盖。',409);}
        catch(\Throwable $e){return response('数据库连接失败，请检查地址、库名、账号、密码及权限。',422);}
        $path=root_path().'storage/install/database.json';
        $json=json_encode($db,JSON_UNESCAPED_SLASHES|JSON_THROW_ON_ERROR);
        if(file_put_contents($path,$json,LOCK_EX)===false)return response('配置保存失败',500);
        chmod($path,0600);
        Session::set('lumen_install_db',['verified_at'=>time()]);
        return redirect('/install/admin');
    }
}
