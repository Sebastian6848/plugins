<?php

function industrialwhitelist_enabled()
{
    global $config;

    return !empty($config['OPNsense']['IndustrialWhitelist']['general']['enabled']);
}

function industrialwhitelist_protocol_port($protocol)
{
    if ($protocol === 's7comm') {
        return '102';
    }

    return '502';
}

function industrialwhitelist_address($value)
{
    if (empty($value) || strtolower($value) === 'any') {
        return 'any';
    }

    if (preg_match('/^[A-Za-z_][A-Za-z0-9_\-]*$/', $value)) {
        return '<' . $value . '>';
    }

    return $value;
}

function industrialwhitelist_firewall($fw)
{
    global $config;

    if (!industrialwhitelist_enabled()) {
        return;
    }

    $general = $config['OPNsense']['IndustrialWhitelist']['general'] ?? [];
    $rules = $config['OPNsense']['IndustrialWhitelist']['rules']['rule'] ?? [];

    if (!is_array($rules)) {
        $rules = [];
    }

    if (isset($rules['enabled'])) {
        $rules = [$rules];
    }

    usort($rules, function ($a, $b) {
        return intval($a['sequence'] ?? 0) <=> intval($b['sequence'] ?? 0);
    });

    foreach ($rules as $rule) {
        if (empty($rule['enabled'])) {
            continue;
        }

        $fw->registerFilterRule(
            210,
            [
                'type' => 'pass',
                'quick' => true,
                'protocol' => 'tcp',
                'from' => industrialwhitelist_address((string)($rule['source'] ?? 'any')),
                'to' => industrialwhitelist_address((string)($rule['destination'] ?? 'any')),
                'to_port' => industrialwhitelist_protocol_port((string)($rule['protocol'] ?? 'modbus_tcp')),
                'log' => false,
                'descr' => 'IndustrialWhitelist allow ' . (string)($rule['description'] ?? ''),
            ]
        );
    }

    $defaultAction = $general['default_action'] ?? 'log_only';
    foreach (['502', '102'] as $port) {
        $fw->registerFilterRule(
            290,
            [
                'type' => $defaultAction === 'block' ? 'block' : 'pass',
                'quick' => true,
                'protocol' => 'tcp',
                'from' => 'any',
                'to' => 'any',
                'to_port' => $port,
                'log' => true,
                'descr' => 'IndustrialWhitelist default ' . $defaultAction . ' tcp/' . $port,
            ]
        );
    }
}
