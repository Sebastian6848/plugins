#!/usr/local/bin/php
<?php

require_once('/usr/local/opnsense/mvc/app/library/OPNsense/Antivirus/Backend/BackendCore.php');

$result = (new OPNsense\Antivirus\Backend\BackendCore())->dispatch($argv);
echo json_encode($result, JSON_UNESCAPED_SLASHES) . PHP_EOL;
exit(($result['status'] ?? '') === 'error' ? 1 : 0);
