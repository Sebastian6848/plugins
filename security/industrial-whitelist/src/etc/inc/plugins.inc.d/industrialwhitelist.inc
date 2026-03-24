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

        $protocol = (string)($rule['protocol'] ?? 'modbus_tcp');
        $port = industrialwhitelist_protocol_port($protocol);

        $fw->registerFilterRule(
            10000,
            [
                'type' => 'pass',
                'quick' => true,
                'direction' => 'in',
                'ipprotocol' => 'inet46',
                'protocol' => 'tcp',
                'from' => industrialwhitelist_address((string)($rule['source'] ?? 'any')),
                'to' => industrialwhitelist_address((string)($rule['destination'] ?? 'any')),
                'to_port' => $port,
                'log' => false,
                'descr' => 'industrialwhitelist allow ' . $protocol . ' ' . (string)($rule['description'] ?? ''),
            ]
        );
    }

    $defaultAction = $general['default_action'] ?? 'log_only';
    foreach (['502', '102'] as $port) {
        $fw->registerFilterRule(
            15000,
            [
                'type' => $defaultAction === 'block' ? 'block' : 'pass',
                'quick' => true,
                'direction' => 'in',
                'ipprotocol' => 'inet46',
                'protocol' => 'tcp',
                'from' => 'any',
                'to' => 'any',
                'to_port' => $port,
                'log' => true,
                'descr' => 'industrialwhitelist default ' . $defaultAction . ' tcp/' . $port,
            ]
        );
    }
}
