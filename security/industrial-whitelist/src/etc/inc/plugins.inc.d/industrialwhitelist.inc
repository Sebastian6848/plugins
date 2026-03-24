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
    return;
}
