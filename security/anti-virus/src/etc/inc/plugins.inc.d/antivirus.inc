<?php

function antivirus_enabled()
{
    global $config;

    return !empty($config['OPNsense']['antivirus']['enabled']);
}

function antivirus_services()
{
    $services = [];

    $services[] = [
        'description' => gettext('Antivirus'),
        'configd' => [
            'start' => ['antivirus start'],
            'restart' => ['antivirus restart'],
            'stop' => ['antivirus stop'],
        ],
        'name' => 'antivirus',
    ];

    return $services;
}

function antivirus_xmlrpc_sync()
{
    return [[
        'description' => gettext('Antivirus'),
        'section' => 'OPNsense.antivirus',
        'id' => 'antivirus',
        'services' => ['antivirus'],
    ]];
}
