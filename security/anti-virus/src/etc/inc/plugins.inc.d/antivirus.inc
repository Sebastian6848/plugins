<?php

function antivirus_enabled()
{
    global $config;

    return !empty($config['OPNsense']['antivirus']['general']['enabled']);
}

function antivirus_block_table()
{
    return 'industrial_av_block';
}

function antivirus_firewall($fw)
{
    if (!antivirus_enabled()) {
        return;
    }

    $fw->registerFilterRule(
        6000,
        [
            'type' => 'block',
            'quick' => true,
            'direction' => 'in',
            'ipprotocol' => 'inet46',
            'from' => '<' . antivirus_block_table() . '>',
            'log' => true,
            'descr' => 'AV-HOOK dynamic source block list',
        ]
    );
}

function antivirus_services()
{
    $services = [];
    if (!antivirus_enabled()) {
        return $services;
    }

    $services[] = [
        'description' => gettext('Industrial AntiVirus Engine'),
        'configd' => [
            'start' => ['antivirus start'],
            'restart' => ['antivirus restart'],
            'stop' => ['antivirus stop'],
        ],
        'name' => 'antivirus',
        'pidfile' => '/var/run/antivirus/antivirusd.pid'
    ];

    return $services;
}

function antivirus_xmlrpc_sync()
{
    return [[
        'description' => gettext('Industrial AntiVirus Engine'),
        'section' => 'OPNsense.antivirus',
        'id' => 'antivirus',
        'services' => ['antivirus'],
    ]];
}