<?php

/*
 * Copyright (C) 2026 Deciso B.V.
 * All rights reserved.
 */

/**
 * Check if App Identification managed ntopng service is enabled.
 *
 * @return bool
 */
function ntopng_proxy_enabled()
{
	$model = new \OPNsense\AppIdentification\AppIdentification();
	return (string)$model->enabled === '1';
}

/**
 * Register configuration hooks.
 *
 * @return array
 */
function ntopng_proxy_configure()
{
	return [
		'bootup' => ['ntopng_proxy_reconfigure'],
		'newwanip' => ['ntopng_proxy_reconfigure'],
	];
}

/**
 * Reconfigure templates and restart ntopng service.
 *
 * @param bool $verbose
 * @return void
 */
function ntopng_proxy_reconfigure($verbose = false)
{
	if (!ntopng_proxy_enabled()) {
		return;
	}

	$response = configd_run('appidentification ntopng_generate 1 "" 3000 "" 0 "" 200000 100000 "" ""');
	if ($verbose) {
		printf("appidentification ntopng_generate: %s\n", trim((string)$response));
	}

	configd_run('appidentification ntopng_restart');
}

/**
 * Register service control metadata.
 *
 * @return array
 */
function ntopng_proxy_services()
{
	$services = [];

	if (!ntopng_proxy_enabled()) {
		return $services;
	}

	$services[] = [
		'name' => 'ntopng',
		'description' => gettext('Application Identification (ntopng)'),
		'configd' => [
			'restart' => ['appidentification ntopng_restart'],
			'start' => ['ntopng start'],
			'stop' => ['ntopng stop'],
		],
		'pid' => '/var/run/ntopng/ntopng.pid',
	];

	return $services;
}

/**
 * Register menu structure in case hook-based menu collection is used.
 *
 * @return array
 */
function ntopng_proxy_menu()
{
	return [
		'Services' => [
			'ApplicationIdentification' => [
				'label' => gettext('Application Identification'),
				'url' => '/ui/appidentification',
				'items' => [
					[
						'label' => gettext('Settings'),
						'url' => '/ui/appidentification',
					],
					[
						'label' => gettext('Active Flows'),
						'url' => '/ui/appidentification/flows',
					],
					[
						'label' => gettext('Applications'),
						'url' => '/ui/appidentification/applications',
					],
				],
			],
		],
	];
}
