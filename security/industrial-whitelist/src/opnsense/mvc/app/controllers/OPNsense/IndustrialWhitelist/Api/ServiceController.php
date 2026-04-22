<?php

namespace OPNsense\IndustrialWhitelist\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Backend;
use OPNsense\Core\Config;
use OPNsense\IndustrialWhitelist\IndustrialWhitelist;

class ServiceController extends ApiControllerBase
{
    private function hasError(string $output): bool
    {
        return stripos($output, 'error') !== false || stripos($output, 'failed') !== false;
    }

    private function generateRevision(): string
    {
        return gmdate('YmdHis') . '-' . bin2hex(random_bytes(3));
    }

    private function persistRevision(string $revision): void
    {
        $model = new IndustrialWhitelist();
        $model->general->last_apply_revision = $revision;
        $model->general->last_apply_timestamp = gmdate('c');
        $model->serializeToConfig();
        Config::getInstance()->save();
    }

    private function recordStage(array &$stages, string $name, string $output, bool $ok): void
    {
        $stages[] = [
            'stage' => $name,
            'ok' => $ok,
            'output' => $output,
        ];
    }

    private function runStage(Backend $backend, array &$stages, string $stageName, string $command, callable $validator = null): bool
    {
        $output = trim($backend->configdRun($command));
        $ok = $validator === null ? !$this->hasError($output) : (bool)$validator($output);
        $this->recordStage($stages, $stageName, $output, $ok);

        return $ok;
    }

    private function idsStatusIsHealthy(string $output): bool
    {
        if ($this->hasError($output)) {
            return false;
        }

        return stripos($output, 'running') !== false;
    }

    public function reconfigureAction()
    {
        $stages = [];
        $revision = $this->generateRevision();
        $this->persistRevision($revision);

        $backend = new Backend();
        if (!$this->runStage($backend, $stages, 'generate_rules', 'industrialwhitelist generate')) {
            return ['status' => 'failed', 'revision' => $revision, 'stages' => $stages];
        }

        if (!$this->runStage($backend, $stages, 'reload_pf', 'filter reload')) {
            return ['status' => 'failed', 'revision' => $revision, 'stages' => $stages];
        }

        if (!$this->runStage($backend, $stages, 'flush_managed_states', 'industrialwhitelist flush_states')) {
            return ['status' => 'failed', 'revision' => $revision, 'stages' => $stages];
        }

        if (!$this->runStage($backend, $stages, 'reload_ids', 'ids reload')) {
            return ['status' => 'failed', 'revision' => $revision, 'stages' => $stages];
        }

        if (!$this->runStage($backend, $stages, 'verify_ids_status', 'ids status', [$this, 'idsStatusIsHealthy'])) {
            return ['status' => 'failed', 'revision' => $revision, 'stages' => $stages];
        }

        return ['status' => 'ok', 'revision' => $revision, 'stages' => $stages];
    }

    public function prereqStatusAction()
    {
        $config = Config::getInstance()->object();
        $idsGeneral = $config['OPNsense']['IDS']['general'] ?? [];

        $enabled = !empty($idsGeneral['enabled']);
        $mode = (string)($idsGeneral['mode'] ?? 'pcap');
        $ipsMode = in_array($mode, ['netmap', 'divert'], true);

        $interfacesRaw = $idsGeneral['interfaces'] ?? '';
        if (is_array($interfacesRaw)) {
            $interfaces = array_values(array_filter(array_map('strval', $interfacesRaw), function ($item) {
                return trim($item) !== '';
            }));
        } else {
            $interfaces = array_values(array_filter(array_map('trim', explode(',', (string)$interfacesRaw)), function ($item) {
                return $item !== '';
            }));
        }

        return [
            'enabled' => $enabled,
            'mode' => $mode,
            'ips_mode' => $ipsMode,
            'interfaces' => $interfaces,
            'has_interfaces' => count($interfaces) > 0,
            'ready' => $enabled && $ipsMode && count($interfaces) > 0,
        ];
    }
}
