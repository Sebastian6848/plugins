<?php

namespace OPNsense\Antivirus\Backend;

class BackendResult
{
    public static function ok(array $data = [], string $message = 'ok'): array
    {
        return array_merge(['status' => 'ok', 'message' => $message], $data);
    }

    public static function error(string $message, array $data = []): array
    {
        return array_merge(['status' => 'error', 'message' => $message], $data);
    }
}

class CapabilityProbe
{
    public function probe(): array
    {
        $items = [
            'squid' => $this->command('squid') || is_executable('/usr/local/sbin/squid'),
            'clamd' => $this->command('clamd') || is_executable('/usr/local/sbin/clamd'),
            'freshclam' => $this->command('freshclam') || is_executable('/usr/local/bin/freshclam'),
            'c_icap' => $this->command('c-icap') || is_executable('/usr/local/bin/c-icap'),
            'c_icap_module_clamd' => $this->existsAny([
                '/usr/local/lib/c_icap/clamd_mod.so',
                '/usr/local/lib/c_icap/clamd_mod.so.0',
            ]),
            'c_icap_module_virus_scan' => $this->existsAny([
                '/usr/local/lib/c_icap/virus_scan.so',
                '/usr/local/lib/c_icap/virus_scan.so.0',
            ]),
            'rc_squid' => is_executable('/usr/local/etc/rc.d/squid'),
            'rc_clamd' => is_executable('/usr/local/etc/rc.d/clamav_clamd'),
            'rc_freshclam' => is_executable('/usr/local/etc/rc.d/clamav_freshclam'),
            'rc_cicap' => is_executable('/usr/local/etc/rc.d/c-icap'),
            'squid_pre_auth_writable' => $this->dirWritable('/usr/local/etc/squid/pre-auth'),
            'cicap_conf_writable' => $this->dirWritable('/usr/local/etc/c-icap'),
        ];
        return [
            'available' => $items,
            'missing' => array_keys(array_filter($items, static fn($ok) => !$ok)),
        ];
    }

    private function command(string $command): bool
    {
        $result = trim((string)shell_exec('command -v ' . escapeshellarg($command) . ' 2>/dev/null'));
        return $result !== '';
    }

    private function existsAny(array $paths): bool
    {
        foreach ($paths as $path) {
            if (file_exists($path)) {
                return true;
            }
        }
        return false;
    }

    private function dirWritable(string $path): bool
    {
        return is_dir($path) ? is_writable($path) : is_writable(dirname($path));
    }
}

class ConflictDetector
{
    public function detect(): array
    {
        $conflicts = [];
        foreach (['os-squid', 'os-clamav', 'os-c-icap'] as $pkg) {
            if ($this->pkgInstalled($pkg)) {
                $conflicts[] = ['type' => 'plugin', 'name' => $pkg, 'message' => "{$pkg} is installed; managed configuration will not be overwritten outside antivirus-owned files."];
            }
        }
        foreach (glob('/usr/local/etc/squid/pre-auth/*.conf') ?: [] as $file) {
            if (basename($file) !== '00-antivirus-icap.conf') {
                $conflicts[] = ['type' => 'config', 'path' => $file, 'message' => 'additional Squid pre-auth include detected'];
            }
        }
        return $conflicts;
    }

    private function pkgInstalled(string $pkg): bool
    {
        exec('/usr/local/sbin/pkg info -e ' . escapeshellarg($pkg) . ' 2>/dev/null', $out, $code);
        return $code === 0;
    }
}

class ConfigManager
{
    public function apply(): array
    {
        $this->run('/usr/local/sbin/configctl template reload OPNsense/Antivirus');
        $this->run('/usr/local/opnsense/scripts/OPNsense/Antivirus/setup.sh');
        return BackendResult::ok([], 'configuration applied');
    }

    public function disableSquidIcap(): void
    {
        $path = '/usr/local/etc/squid/pre-auth';
        if (!is_dir($path)) {
            mkdir($path, 0755, true);
        }
        file_put_contents($path . '/00-antivirus-icap.conf', '');
    }

    private function run(string $command): void
    {
        exec($command . ' 2>&1', $output, $code);
        if ($code !== 0) {
            throw new \RuntimeException(trim(implode("\n", $output)) ?: "command failed: {$command}");
        }
    }
}

class ServiceManager
{
    public function start(): array
    {
        (new ConfigManager())->apply();
        if (!is_dir('/var/log/c-icap')) {
            mkdir('/var/log/c-icap', 0755, true);
        }
        $this->service('clamav_freshclam', 'onestart', false);
        $this->service('clamav_clamd', 'onestart', false);
        $this->waitForSocket('/var/run/clamav/clamd.sock', 120);
        $this->service('c-icap', 'onestart', true);
        $this->restartProxy();
        return BackendResult::ok([], 'antivirus started');
    }

    public function stop(): array
    {
        $this->service('c-icap', 'onestop', false);
        (new ConfigManager())->disableSquidIcap();
        $this->restartProxy();
        return BackendResult::ok([], 'antivirus stopped');
    }

    public function restart(): array
    {
        (new ConfigManager())->apply();
        $this->service('clamav_freshclam', 'onerestart', true);
        $this->service('clamav_clamd', 'onerestart', true);
        $this->service('c-icap', 'onerestart', true);
        $this->restartProxy();
        return BackendResult::ok([], 'antivirus restarted');
    }

    public function reload(): array
    {
        return $this->restart();
    }

    public function startComponent(string $service): array
    {
        $map = [
            'clamd' => ['clamav_clamd', 'onestart'],
            'freshclam' => ['clamav_freshclam', 'onestart'],
            'cicap' => ['c-icap', 'onestart'],
            'squid_icap' => null,
        ];
        if (!array_key_exists($service, $map)) {
            return BackendResult::error('unsupported service');
        }
        if ($service === 'squid_icap') {
            (new ConfigManager())->apply();
            $this->restartProxy();
            return BackendResult::ok([], 'Squid ICAP include applied');
        }
        $this->service($map[$service][0], $map[$service][1], true);
        return BackendResult::ok([], "{$service} started");
    }

    public function componentStatus(): array
    {
        $components = [
            'clamd' => is_file('/var/run/clamav/clamd.sock') || is_link('/var/run/clamav/clamd.sock') ? 'running' : 'stopped',
            'cicap' => $this->listening('1344') ? 'running' : 'stopped',
            'squid_icap' => $this->squidIcapActive() ? 'active' : 'inactive',
            'freshclam' => file_exists('/var/run/clamav/freshclam.pid') ? 'running' : 'stopped',
        ];
        return $components;
    }

    private function service(string $service, string $action, bool $strict): void
    {
        exec('/usr/sbin/service ' . escapeshellarg($service) . ' ' . escapeshellarg($action) . ' 2>&1', $output, $code);
        if ($strict && $code !== 0) {
            throw new \RuntimeException(trim(implode("\n", $output)) ?: "{$service} {$action} failed");
        }
    }

    private function waitForSocket(string $path, int $seconds): void
    {
        for ($i = 0; $i < $seconds; $i++) {
            if (file_exists($path)) {
                return;
            }
            sleep(1);
        }
        throw new \RuntimeException("timeout waiting for {$path}");
    }

    private function restartProxy(): void
    {
        exec('/usr/local/sbin/configctl proxy restart 2>&1', $output, $code);
        if ($code !== 0) {
            throw new \RuntimeException(trim(implode("\n", $output)) ?: 'proxy restart failed');
        }
    }

    private function listening(string $port): bool
    {
        exec('/usr/bin/sockstat -l 2>/dev/null', $output);
        return strpos(implode("\n", $output), ':' . $port) !== false || strpos(implode("\n", $output), ' ' . $port) !== false;
    }

    private function squidIcapActive(): bool
    {
        $file = '/usr/local/etc/squid/pre-auth/00-antivirus-icap.conf';
        return is_file($file) && preg_match('/^icap_service .*avscan/m', (string)file_get_contents($file));
    }
}

class ScannerPipeline
{
    public function status(): array
    {
        $components = (new ServiceManager())->componentStatus();
        $capabilities = (new CapabilityProbe())->probe();
        $conflicts = (new ConflictDetector())->detect();
        $running = $components['clamd'] === 'running' && $components['cicap'] === 'running' && $components['squid_icap'] === 'active';
        $status = $running ? 'running' : (!empty($capabilities['missing']) ? 'degraded' : 'stopped');
        return [
            'status' => $status,
            'components' => $components,
            'capabilities' => $capabilities,
            'conflicts' => $conflicts,
            'message' => $running ? 'antivirus pipeline is running' : 'antivirus pipeline is not fully active',
        ] + $components + $this->signatureInfo();
    }

    public function versions(): array
    {
        exec('/usr/local/bin/clamconf 2>/dev/null', $output, $code);
        $result = [];
        foreach ($output as $line) {
            if (strpos($line, ':') !== false) {
                [$key, $value] = explode(':', $line, 2);
                $result[trim($key)] = trim($value);
            }
        }
        return $result;
    }

    private function signatureInfo(): array
    {
        $db = file_exists('/var/db/clamav/daily.cld') ? '/var/db/clamav/daily.cld' : (file_exists('/var/db/clamav/daily.cvd') ? '/var/db/clamav/daily.cvd' : '');
        if ($db === '' || trim((string)shell_exec('command -v sigtool 2>/dev/null')) === '') {
            return ['sig_version' => '', 'sig_updated' => ''];
        }
        exec('/usr/local/bin/sigtool --info ' . escapeshellarg($db) . ' 2>/dev/null', $output);
        $info = ['sig_version' => '', 'sig_updated' => ''];
        foreach ($output as $line) {
            if (preg_match('/^Version:\s*(.+)$/', $line, $m)) {
                $info['sig_version'] = $m[1];
            } elseif (preg_match('/^Build time:\s*(.+)$/', $line, $m)) {
                $info['sig_updated'] = $m[1];
            }
        }
        return $info;
    }
}

class BackendCore
{
    public function dispatch(array $argv): array
    {
        $action = $argv[1] ?? 'status';
        try {
            switch ($action) {
                case 'start':
                    return (new ServiceManager())->start();
                case 'stop':
                    return (new ServiceManager())->stop();
                case 'restart':
                case 'reload':
                    return (new ServiceManager())->restart();
                case 'start_service':
                    return (new ServiceManager())->startComponent($argv[2] ?? '');
                case 'status':
                    return (new ScannerPipeline())->status();
                case 'version':
                    return (new ScannerPipeline())->versions();
                case 'freshclam':
                    exec('/usr/local/opnsense/scripts/OPNsense/Antivirus/freshclam.sh ' . escapeshellarg($argv[2] ?? '') . ' 2>&1', $output, $code);
                    $state = trim(implode("\n", $output));
                    return $code === 0 ? ['status' => $state !== '' ? $state : 'missing'] : BackendResult::error($state ?: 'freshclam failed');
                case 'logs':
                    $mode = $argv[2] ?? 'all';
                    exec('/usr/local/opnsense/scripts/OPNsense/Antivirus/logs.php ' . escapeshellarg($mode) . ' 2>&1', $output, $code);
                    $payload = json_decode(implode("\n", $output), true);
                    if (is_array($payload)) {
                        return $payload;
                    }
                    return $code === 0 ? BackendResult::ok(['rows' => [], 'total' => 0], 'logs read') : BackendResult::error(trim(implode("\n", $output)) ?: 'logs read failed');
                default:
                    return BackendResult::error('unsupported action');
            }
        } catch (\Throwable $e) {
            return BackendResult::error($e->getMessage());
        }
    }
}
