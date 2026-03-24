<?php

namespace OPNsense\IndustrialWhitelist\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Backend;
use OPNsense\Core\Config;
use OPNsense\Firewall\Alias;
use OPNsense\Firewall\Filter;
use OPNsense\IndustrialWhitelist\IndustrialWhitelist;

class ServiceController extends ApiControllerBase
{
    private const MANAGED_TAG = 'IW-MANAGED';

    private function protocolPort(string $protocol): string
    {
        return $protocol === 's7comm' ? '102' : '502';
    }

    private function normalizeAddress(string $value): string
    {
        $value = trim($value);
        if ($value === '' || strtolower($value) === 'any') {
            return 'any';
        }
        if (filter_var($value, FILTER_VALIDATE_IP)) {
            return $value . (strpos($value, ':') === false ? '/32' : '/128');
        }
        return $value;
    }

    private function isNamedReference(string $value): bool
    {
        return (bool)preg_match('/^[A-Za-z_][A-Za-z0-9_\-]*$/', $value);
    }

    private function clearManagedRules(Filter $filterModel): void
    {
        foreach ($filterModel->rules->rule->iterateItems() as $nodeKey => $rule) {
            if (strpos((string)$rule->description, self::MANAGED_TAG) === 0) {
                $filterModel->rules->rule->Del($nodeKey);
            }
        }
    }

    private function clearManagedAliases(Alias $aliasModel): void
    {
        foreach ($aliasModel->aliases->alias->iterateItems() as $nodeKey => $alias) {
            if (strpos((string)$alias->description, self::MANAGED_TAG) === 0) {
                $aliasModel->aliases->alias->Del($nodeKey);
            }
        }
    }

    private function ensureAlias(Alias $aliasModel, string $name, string $value): string
    {
        if ($value === 'any') {
            return 'any';
        }
        if ($this->isNamedReference($value)) {
            return $value;
        }

        $node = null;
        foreach ($aliasModel->aliases->alias->iterateItems() as $alias) {
            if ((string)$alias->name === $name) {
                $node = $alias;
                break;
            }
        }
        if ($node === null) {
            $node = $aliasModel->aliases->alias->Add();
            $node->name = $name;
        }

        $node->enabled = '1';
        $node->type = 'network';
        $node->content = $value;
        $node->description = self::MANAGED_TAG . ' alias ' . $name;

        return $name;
    }

    private function addManagedRule(
        Filter $filterModel,
        int $sequence,
        string $action,
        string $source,
        string $destination,
        string $port,
        bool $log,
        string $description
    ): void {
        $rule = $filterModel->rules->rule->Add();
        $rule->enabled = '1';
        $rule->sequence = (string)$sequence;
        $rule->action = $action;
        $rule->quick = '1';
        $rule->direction = 'any';
        $rule->ipprotocol = 'inet46';
        $rule->protocol = 'tcp';
        $rule->source_net = $source;
        $rule->destination_net = $destination;
        $rule->destination_port = $port;
        $rule->log = $log ? '1' : '0';
        $rule->description = self::MANAGED_TAG . ' ' . $description;
    }

    private function syncManagedNativeRules(): void
    {
        $iwModel = new IndustrialWhitelist();
        $filterModel = new Filter();
        $aliasModel = new Alias();

        $this->clearManagedRules($filterModel);
        $this->clearManagedAliases($aliasModel);

        if ((string)$iwModel->general->enabled !== '1') {
            $aliasModel->serializeToConfig();
            $filterModel->serializeToConfig();
            Config::getInstance()->save();
            return;
        }

        $ruleSeq = 700000;
        foreach ($iwModel->rules->rule->sortedBy(['sequence']) as $rule) {
            if ((string)$rule->enabled !== '1') {
                continue;
            }

            $uuid = (string)$rule->getAttribute('uuid');
            $shortUuid = preg_replace('/[^a-z0-9]/', '', strtolower($uuid));
            $shortUuid = substr($shortUuid, 0, 12);

            $sourceValue = $this->normalizeAddress((string)$rule->source);
            $destinationValue = $this->normalizeAddress((string)$rule->destination);

            $source = $this->ensureAlias($aliasModel, 'iw_src_' . $shortUuid, $sourceValue);
            $destination = $this->ensureAlias($aliasModel, 'iw_dst_' . $shortUuid, $destinationValue);

            $protocol = (string)$rule->protocol;
            $port = $this->protocolPort($protocol);

            $this->addManagedRule(
                $filterModel,
                $ruleSeq,
                'pass',
                $source,
                $destination,
                $port,
                false,
                'allow ' . $protocol . ' ' . (string)$rule->description
            );
            $ruleSeq += 10;
        }

        $defaultAction = (string)$iwModel->general->default_action;
        foreach (['502', '102'] as $port) {
            $this->addManagedRule(
                $filterModel,
                $ruleSeq,
                $defaultAction === 'block' ? 'block' : 'pass',
                'any',
                'any',
                $port,
                true,
                'default ' . $defaultAction . ' tcp/' . $port
            );
            $ruleSeq += 10;
        }

        $aliasModel->serializeToConfig();
        $filterModel->serializeToConfig();
        Config::getInstance()->save();
    }

    public function reconfigureAction()
    {
        $this->syncManagedNativeRules();

        $backend = new Backend();
        $result = trim($backend->configdRun('filter reload'));

        if (stripos($result, 'error') !== false) {
            return ['status' => 'failed', 'message' => $result];
        }

        return ['status' => 'ok', 'message' => $result];
    }
}
