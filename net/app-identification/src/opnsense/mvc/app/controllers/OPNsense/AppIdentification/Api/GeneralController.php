<?php

/*
 * Copyright (C) 2026 Deciso B.V.
 * All rights reserved.
 */

namespace OPNsense\AppIdentification\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Config;
use OPNsense\AppIdentification\AppIdentification;
use OPNsense\AppIdentification\Backend\BackendFacade;

/**
 * Class GeneralController
 *
 * Provide a generic ntopng REST API proxy for App Identification.
 */
class GeneralController extends ApiControllerBase
{
	/**
	 * Cached model instance.
	 */
	private $model;
	private $backend;

	/**
	 * Read ntopng settings model.
	 *
	 * @return array
	 */
	public function getAction(): array
	{
		try {
			$model = $this->getModel();
			return [
				'general' => $model->getNodes()
			];
		} catch (\Throwable $e) {
			return [
				'status' => 'error',
				'message' => sprintf('Unable to load ntopng settings: %s', $e->getMessage())
			];
		}
	}

	/**
	 * Save ntopng settings model and generate ntopng.conf.
	 *
	 * @return array
	 */
	public function setAction(): array
	{
		$result = ['result' => 'failed'];

		try {
			if (!$this->request->isPost()) {
				$result['message'] = 'Invalid request method.';
				return $result;
			}

			$model = $this->getModel();
			$model->setNodes($this->request->getPost('general'));

			$valMsgs = $model->performValidation();
			foreach ($valMsgs as $msg) {
				if (!isset($result['validations'])) {
					$result['validations'] = [];
				}
				$result['validations']['general.' . $msg->getField()] = $msg->getMessage();
			}

			if ($valMsgs->count() > 0) {
				return $result;
			}

			$model->serializeToConfig();
			Config::getInstance()->save();

			$applyResult = $this->applyNtopngConfig();
			if (($applyResult['status'] ?? '') === 'error') {
				return [
					'result' => 'failed',
					'status' => 'error',
					'message' => $applyResult['message'] ?? 'Failed to apply ntopng configuration.'
				];
			}

			return [
				'result' => 'saved',
				'status' => 'ok',
				'message' => 'Configuration saved and applied.'
			];
		} catch (\Throwable $e) {
			return [
				'result' => 'failed',
				'status' => 'error',
				'message' => sprintf('Unable to save ntopng settings: %s', $e->getMessage())
			];
		}
	}

	/**
	 * Generate ntopng.conf and restart ntopng service.
	 *
	 * @return array
	 */
	public function reconfigureAction(): array
	{
		try {
			return $this->applyNtopngConfig();
		} catch (\Throwable $e) {
			return [
				'status' => 'error',
				'message' => sprintf('Unable to reconfigure ntopng: %s', $e->getMessage())
			];
		}
	}

	/**
	 * Restart ntopng service.
	 *
	 * @return array
	 */
	public function ntopngrestartAction(): array
	{
		try {
			return $this->backend()->run([
				'action' => 'restart',
				'settings' => $this->backendSettings(),
			]);
		} catch (\Throwable $e) {
			return [
				'status' => 'error',
				'message' => sprintf('Unable to restart ntopng: %s', $e->getMessage())
			];
		}
	}

	/**
	 * Query ntopng REST API endpoint and return decoded JSON.
	 *
	 * @param string $endpoint Relative endpoint under /lua/rest/v2/
	 * @param array $params Query string parameters
	 * @return array
	 */
	protected function proxyRequest(string $endpoint, array $params = []): array
	{
		return $this->backend()->run([
			'action' => 'api_get',
			'settings' => $this->backendSettings(),
			'endpoint' => $endpoint,
			'params' => $params,
		]);
	}

	/**
	 * Get status information from ntopng.
	 *
	 * @return array
	 */
	public function statusAction(): array
	{
		try {
			$payload = $this->proxyRequest('flow/active.lua', [
				'ifid' => $this->getIfid(),
				'perPage' => 1
			]);
			if (($payload['status'] ?? '') === 'error') {
				return $payload;
			}

			$totalRows = (int)($payload['rsp']['totalRows'] ?? 0);

			return [
				'status' => 'ok',
				'message' => sprintf('连接成功，当前活动流 %d 条', $totalRows),
				'active_flows' => $totalRows,
				'running' => true,
				'data' => $payload
			];
		} catch (\Throwable $e) {
			return [
				'status' => 'error',
				'message' => sprintf('Unable to retrieve ntopng status: %s', $e->getMessage())
			];
		}
	}

	/**
	 * Return current plugin model.
	 *
	 * @return AppIdentification
	 */
	protected function getModel(): AppIdentification
	{
		if ($this->model === null) {
			$this->model = new AppIdentification();
		}

		return $this->model;
	}

	private function getRestScheme(): string
	{
		$scheme = strtolower(trim((string)($this->getModel()->rest_scheme ?? 'http')));
		if ($scheme !== 'https') {
			$scheme = 'http';
		}
		return $scheme;
	}

	private function getRestHost(): string
	{
		$host = trim((string)($this->getModel()->rest_host ?? '127.0.0.1'));
		return $host !== '' ? $host : '127.0.0.1';
	}

	private function getRestPort(): string
	{
		$port = trim((string)($this->getModel()->rest_port ?? '3000'));
		return $port !== '' && is_numeric($port) ? $port : '3000';
	}

	protected function getIfid(): int
	{
		$ifid = trim((string)($this->getModel()->ifid ?? '0'));
		return $ifid !== '' ? (int)$ifid : 0;
	}

	/**
	 * Return first non-empty scalar converted to string.
	 *
	 * @param array $values
	 * @return string
	 */
	private function firstStringValue(array $values): string
	{
		foreach ($values as $value) {
			if (is_scalar($value)) {
				$stringValue = trim((string)$value);
				if ($stringValue !== '') {
					return $stringValue;
				}
			}
		}

		return '';
	}

	/**
	 * Extract ntopng version from a payload.
	 *
	 * @param array $payload
	 * @return string
	 */
	private function extractVersion(array $payload): string
	{
		$candidates = [
			$payload['version'] ?? null,
			$payload['ntopng_version'] ?? null,
			$payload['system']['version'] ?? null,
			$payload['system']['ntopng_version'] ?? null
		];

		return $this->firstStringValue($candidates);
	}

	/**
	 * Extract monitored interfaces from a payload.
	 *
	 * @param array $payload
	 * @return array
	 */
	private function extractInterfaces(array $payload): array
	{
		$interfaces = [];

		if (isset($payload['interfaces']) && is_array($payload['interfaces'])) {
			$interfaces = $payload['interfaces'];
		} elseif (isset($payload['system']['interfaces']) && is_array($payload['system']['interfaces'])) {
			$interfaces = $payload['system']['interfaces'];
		}

		return array_values($interfaces);
	}

	/**
	 * Generate /usr/local/etc/ntopng/ntopng.conf via configd script.
	 *
	 * @return array
	 */
	private function generateNtopngConfig(): array
	{
		try {
			$model = $this->getModel();
			$config = [
				'enabled' => (string)$model->enabled,
				'interfaces' => is_object($model->interfaces) ? (string)$model->interfaces : (string)$model->interfaces,
				'http_port' => (string)$model->http_port,
				'https_port' => (string)$model->https_port,
				'dns_mode' => (string)$model->dns_mode,
				'certificate' => (string)$model->certificate,
				'max_flows' => (string)$model->max_flows,
				'max_hosts' => (string)$model->max_hosts,
				'local_networks' => (string)$model->local_networks,
				'extra_options' => (string)$model->extra_options
			];

			$interfaces = [];
			if ($model->interfaces != null) {
				foreach ($model->interfaces->iterateItems() as $item) {
					$ifname = trim((string)$item);
					if ($ifname !== '') {
						$interfaces[] = $ifname;
					}
				}
			}
			$config['interfaces'] = implode(',', $interfaces);

			return $this->backend()->run([
				'action' => 'generate',
				'settings' => $this->backendSettings(),
				'config' => $config,
			]);
		} catch (\Throwable $e) {
			return [
				'status' => 'error',
				'message' => sprintf('Failed to generate ntopng.conf: %s', $e->getMessage())
			];
		}
	}

	/**
	 * Generate and apply ntopng configuration.
	 *
	 * @return array
	 */
	private function applyNtopngConfig(): array
	{
		$generateResult = $this->generateNtopngConfig();
		if (($generateResult['status'] ?? '') === 'error') {
			return $generateResult;
		}

		$model = $this->getModel();
		if ((string)$model->enabled !== '1') {
			$stopResult = $this->backend()->run([
				'action' => 'stop',
				'settings' => $this->backendSettings(),
			]);
			if (($stopResult['status'] ?? '') === 'error') {
				return $stopResult;
			}
			return [
				'status' => 'ok',
				'message' => trim(($generateResult['message'] ?? '') . ' App Identification stopped.')
			];
		}

		$restartResult = $this->backend()->run([
			'action' => 'restart',
			'settings' => $this->backendSettings(),
		]);
		if (($restartResult['status'] ?? '') === 'error') {
			return $restartResult;
		}
		return [
			'status' => 'ok',
			'message' => trim(($generateResult['message'] ?? '') . ' ' . ($restartResult['message'] ?? 'ntopng restarted.'))
		];
	}

	protected function backend(): BackendFacade
	{
		if ($this->backend === null) {
			$this->backend = new BackendFacade();
		}
		return $this->backend;
	}

	protected function backendSettings(): array
	{
		$model = $this->getModel();
		return [
			'rest_scheme' => $this->getRestScheme(),
			'rest_host' => $this->getRestHost(),
			'rest_port' => $this->getRestPort(),
			'auth_token' => trim((string)($model->auth_token ?? '')),
			'auth_username' => trim((string)($model->auth_username ?? 'admin')),
			'auth_password' => (string)($model->auth_password ?? ''),
			'ifid' => $this->getIfid(),
		];
	}
}
