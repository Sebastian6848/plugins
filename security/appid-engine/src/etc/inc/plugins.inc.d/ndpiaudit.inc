<?php

function ndpiaudit_enabled()
{
    global $config;

    return isset($config['OPNsense']['ndpiaudit']['general']['enabled']) &&
        $config['OPNsense']['ndpiaudit']['general']['enabled'] == 1;
}

function ndpiaudit_firewall($fw)
{
    if (!ndpiaudit_enabled()) {
        return;
    }

    $fw->registerAnchor('ndpi-audit/*', 'fw');
}

function ndpiaudit_services()
{
    $services = [];

    if (!ndpiaudit_enabled()) {
        return $services;
    }

    $services[] = [
        'description' => gettext('nDPI Audit Engine'),
        'configd' => [
            'start' => ['ndpiaudit start'],
            'restart' => ['ndpiaudit restart'],
            'stop' => ['ndpiaudit stop'],
        ],
        'name' => 'ndpiaudit',
        'pidfile' => '/var/run/ndpi_audit.pid'
    ];

    return $services;
}

function ndpiaudit_xmlrpc_sync()
{
    return [[
        'description' => gettext('nDPI Audit Engine'),
        'section' => 'OPNsense.ndpiaudit',
        'id' => 'ndpiaudit',
        'services' => ['ndpiaudit'],
    ]];
}
