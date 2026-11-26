<?php
namespace app\api\handlers;

class HandlerRegistry
{
    private static bool $registered = false;

    private static function registerPrivateLoader(): void
    {
        if (self::$registered) return;
        self::$registered = true;
        spl_autoload_register(static function (string $class): void {
            $prefix = __NAMESPACE__ . '\\';
            if (!str_starts_with($class, $prefix)) return;
            $relative = str_replace('\\', '/', substr($class, strlen($prefix)));
            if (!preg_match('#^[A-Za-z][A-Za-z0-9_]{0,80}(?:/[A-Za-z][A-Za-z0-9_]{0,80})*$#D', $relative)) return;
            $root = realpath('/opt/lumenapi/private-handlers');
            if ($root === false) return;
            $file = realpath($root . '/' . $relative . '.php');
            if ($file !== false && str_starts_with($file, $root . DIRECTORY_SEPARATOR) && is_file($file)) {
                require_once $file;
            }
        });
    }

    public static function make(string $name): ApiHandlerInterface
    {
        if (!preg_match('#^[A-Za-z][A-Za-z0-9_]{0,80}(?:/[A-Za-z][A-Za-z0-9_]{0,80})*$#D', $name)) {
            throw new \RuntimeException('invalid_handler');
        }
        self::registerPrivateLoader();
        $class = __NAMESPACE__ . '\\' . str_replace('/', '\\', $name);
        if (!class_exists($class)) throw new \RuntimeException('handler_not_found');
        if (!is_subclass_of($class, ApiHandlerInterface::class)) throw new \RuntimeException('invalid_handler');
        return new $class();
    }
}
