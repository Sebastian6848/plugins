<?php

/*
    Copyright (C) 2026
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    1. Redistributions of source code must retain the above copyright notice,
       this list of conditions and the following disclaimer.

    2. Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.

    THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
    INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
    AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
    OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
    SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
    INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
    CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
    ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
*/

function antivirus_enabled()
{
    global $config;

    return isset($config['OPNsense']['antivirus']['general']['enabled']) &&
        $config['OPNsense']['antivirus']['general']['enabled'] == 1;
}

function antivirus_configure()
{
    return [
        'webproxy' => ['antivirus_configure_do'],
    ];
}

function antivirus_configure_do($verbose = false)
{
    $response = configd_run('template reload OPNsense/Antivirus');
    if ($verbose) {
        printf("template reload OPNsense/Antivirus: %s\n", trim($response));
    }
}

function antivirus_install()
{
    $path = '/usr/local/etc/squid/pre-auth';
    $filename = "{$path}/00-antivirus-icap.conf";

    if (!is_dir($path)) {
        mkdir($path, 0755, true);
    }
    if (!file_exists($filename)) {
        touch($filename);
    }
}
