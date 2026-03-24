<?php

function industrialwhitelist_enabled()
{
    global $config;

    return !empty($config['OPNsense']['IndustrialWhitelist']['general']['enabled']);
}

function industrialwhitelist_protocol_port($protocol)
{
    $map = industrialwhitelist_protocol_map();
    if (empty($map[$protocol])) {
        $protocol = 'modbus_tcp';
    }

    return (string)$map[$protocol]['tuples'][0]['port'];
}

function industrialwhitelist_protocol_map()
{
    return [
        'modbus_tcp' => [
            'tuples' => [
                ['proto' => 'tcp', 'port' => '502']
            ]
        ],
        's7comm' => [
            'tuples' => [
                ['proto' => 'tcp', 'port' => '102']
            ]
        ],
        'eip' => [
            'tuples' => [
                ['proto' => 'tcp', 'port' => '44818'],
                ['proto' => 'udp', 'port' => '44818'],
                ['proto' => 'udp', 'port' => '2222']
            ]
        ],
        'iec104' => [
            'tuples' => [
                ['proto' => 'tcp', 'port' => '2404']
            ]
        ],
        'dnp3' => [
            'tuples' => [
                ['proto' => 'tcp', 'port' => '20000'],
                ['proto' => 'udp', 'port' => '20000']
            ]
        ],
        'bacnet' => [
            'tuples' => [
                ['proto' => 'udp', 'port' => '47808']
            ]
        ]
    ];
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

    $protocolMap = industrialwhitelist_protocol_map();

    usort($rules, function ($a, $b) {
        return intval($a['sequence'] ?? 0) <=> intval($b['sequence'] ?? 0);
    });

    foreach ($rules as $rule) {
        if (empty($rule['enabled'])) {
            continue;
        }

        $protocol = (string)($rule['protocol'] ?? 'modbus_tcp');
        if (empty($protocolMap[$protocol])) {
            $protocol = 'modbus_tcp';
        }

        foreach ($protocolMap[$protocol]['tuples'] as $tuple) {
            $fw->registerFilterRule(
                10000,
                [
                    'type' => 'pass',
                    'quick' => true,
                    'direction' => 'in',
                    'ipprotocol' => 'inet46',
                    'protocol' => $tuple['proto'],
                    'from' => industrialwhitelist_address((string)($rule['source'] ?? 'any')),
                    'to' => industrialwhitelist_address((string)($rule['destination'] ?? 'any')),
                    'to_port' => (string)$tuple['port'],
                    'log' => false,
                    'descr' => 'IW-HOOK industrialwhitelist allow ' . $protocol . ' ' . $tuple['proto'] . '/' . $tuple['port'] . ' ' . (string)($rule['description'] ?? ''),
                ]
            );
        }
    }

    $defaultAction = $general['default_action'] ?? 'log_only';

    $defaultTuples = [];
    foreach ($protocolMap as $spec) {
        foreach ($spec['tuples'] as $tuple) {
            $tupleKey = $tuple['proto'] . '/' . $tuple['port'];
            $defaultTuples[$tupleKey] = $tuple;
        }
    }

    foreach ($defaultTuples as $tuple) {
        $fw->registerFilterRule(
            15000,
            [
                'type' => $defaultAction === 'block' ? 'block' : 'pass',
                'quick' => true,
                'direction' => 'in',
                'ipprotocol' => 'inet46',
                'protocol' => $tuple['proto'],
                'from' => 'any',
                'to' => 'any',
                'to_port' => (string)$tuple['port'],
                'log' => true,
                'descr' => 'IW-HOOK industrialwhitelist default ' . $defaultAction . ' ' . $tuple['proto'] . '/' . $tuple['port'],
            ]
        );
    }
}
