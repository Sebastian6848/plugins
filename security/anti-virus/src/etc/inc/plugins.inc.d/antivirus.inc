<?php

function antivirus_enabled()
{
    global $config;

    return !empty($config['OPNsense']['antivirus']['general']['enabled']) &&
        (string)$config['OPNsense']['antivirus']['general']['enabled'] === '1';
}

function antivirus_services()
{
    $services = array();

    if (antivirus_enabled()) {
        $services[] = array(
            'description' => gettext('Antivirus proxy scanner'),
            'configd' => array(
                'restart' => array('antivirus restart'),
                'start' => array('antivirus start'),
                'stop' => array('antivirus stop'),
            ),
            'name' => 'antivirus',
            'pidfile' => '/var/run/c-icap/c-icap.pid'
        );
    }

    return $services;
}

function antivirus_configure()
{
    return array(
        'antivirus' => array('antivirus_reload'),
        'newwanip' => array('antivirus_reload'),
        'interface' => array('antivirus_reload'),
        'antivirus_install' => array('antivirus_install'),
        'antivirus_uninstall' => array('antivirus_uninstall'),
    );
}

function antivirus_reload($verbose = false)
{
    configd_run('template reload OPNsense/Antivirus');
    configd_run('antivirus reload');
}

function antivirus_install($verbose = false)
{
    mwexecf('/usr/local/opnsense/scripts/OPNsense/Antivirus/db_init.py');
    mwexecf('/bin/mkdir -p %s', '/var/log/c-icap');
    mwexecf('/bin/mkdir -p %s', '/var/db/antivirus');
    mwexecf('/bin/chmod 750 %s', '/var/db/antivirus');
    mwexecf('/bin/chmod 755 %s', '/var/log/c-icap');
    mwexecf('/usr/sbin/chown -R c_icap:c_icap %s', '/var/log/c-icap');

    if (mwexecf('/usr/sbin/pkg info -e %s', 'os-squid') != 0) {
        log_error('Antivirus plugin installed, but os-squid is not installed.');
    }

    if (mwexecf('/usr/sbin/pkg info -e %s', 'os-clamav') == 0) {
        log_error('Antivirus plugin conflict warning: os-clamav is installed.');
    }

    if (mwexecf('/usr/sbin/pkg info -e %s', 'os-c-icap') == 0) {
        log_error('Antivirus plugin conflict warning: os-c-icap is installed and may overwrite c-icap.conf.');
    }

    configd_run('template reload OPNsense/Antivirus');
}

function antivirus_uninstall($verbose = false)
{
    global $config;

    mwexecf('/usr/local/opnsense/scripts/OPNsense/Antivirus/stop.sh');
    mwexecf('/bin/mkdir -p %s', '/usr/local/etc/squid/post-auth');
    file_put_contents('/usr/local/etc/squid/post-auth/antivirus_icap.conf', '');
    configd_run('proxy restart');
    mwexecf('/bin/rm -rf %s', '/var/db/antivirus');
    mwexecf('/bin/rm -f %s', '/var/log/c-icap/access.log');
    mwexecf('/bin/rm -f %s', '/var/log/c-icap/server.log');

    if (isset($config['OPNsense']['antivirus'])) {
        unset($config['OPNsense']['antivirus']);
        write_config('Removed antivirus plugin configuration');
    }
}
