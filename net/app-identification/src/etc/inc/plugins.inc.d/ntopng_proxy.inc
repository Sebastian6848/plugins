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

	$model = new \OPNsense\AppIdentification\AppIdentification();
	$args = ntopng_proxy_generate_args($model);
	$response = configd_run('appidentification ntopng_generate ' . implode(' ', $args));
	if ($verbose) {
		printf("appidentification ntopng_generate: %s\n", trim((string)$response));
	}

	configd_run('appidentification ntopng_restart');
}

/**
 * Build ntopng_generate action arguments from current model values.
 *
 * @param \OPNsense\AppIdentification\AppIdentification $model
 * @return array
 */
function ntopng_proxy_generate_args($model)
{
	$interfaces = [];
	if ($model->interfaces != null) {
		foreach ($model->interfaces->iterateItems() as $item) {
			$ifname = trim((string)$item);
			if ($ifname !== '') {
				$interfaces[] = $ifname;
			}
		}
	}

	return [
		escapeshellarg((string)$model->enabled),
		escapeshellarg(implode(',', $interfaces)),
		escapeshellarg((string)$model->http_port),
		escapeshellarg((string)$model->https_port),
		escapeshellarg((string)$model->dns_mode),
		escapeshellarg((string)$model->certificate),
		escapeshellarg((string)$model->max_flows),
		escapeshellarg((string)$model->max_hosts),
		escapeshellarg((string)$model->local_networks),
		escapeshellarg((string)$model->extra_options),
	];
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
