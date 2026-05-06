<?php

function indproto_enabled()
{
    global $config;

    return isset($config['OPNsense']['IndProto']['general']['enabled']) &&
        (string)$config['OPNsense']['IndProto']['general']['enabled'] === '1';
}

function indproto_configure()
{
    return [
        'indproto_rules' => ['indproto_rules_generate', 0],
    ];
}

function indproto_rules_generate($verbose = false)
{
    $response = configd_run('indproto reload');
    if ($verbose) {
        printf("indproto reload: %s\n", trim($response));
    }
}
