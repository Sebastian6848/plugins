<?php

/*
 * Copyright (C) 2026 Deciso B.V.
 * All rights reserved.
 */

namespace OPNsense\AppIdentification\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Backend;
use OPNsense\Core\Config;
use OPNsense\AppIdentification\AppIdentification;

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
			$response = trim((new Backend())->configdRun('appidentification ntopng_restart'));
			return [
				'status' => 'ok',
				'message' => $response !== '' ? $response : 'ntopng restarted.'
			];
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
	protected function proxyRequest(string $endpoint, array $params): array
	{
		try {
			$endpoint = ltrim($endpoint, '/');
			$url = $this->getRestBaseUrl() . $endpoint;

			if (!empty($params)) {
				$separator = strpos($url, '?') === false ? '?' : '&';
				$url .= $separator . http_build_query($params);
			}

			$ch = curl_init();
			if ($ch === false) {
				return [
					'status' => 'error',
					'message' => 'Unable to initialize cURL client.'
				];
			}

			$headers = ['Accept: application/json'];
			$auth = $this->getAuthSettings();

			curl_setopt($ch, CURLOPT_URL, $url);
			curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
			curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 10);
			curl_setopt($ch, CURLOPT_TIMEOUT, 10);
			curl_setopt($ch, CURLOPT_FAILONERROR, false);

			if (!empty($auth['token'])) {
				$headers[] = 'Authorization: Bearer ' . $auth['token'];
			} elseif (!empty($auth['username'])) {
				curl_setopt($ch, CURLOPT_HTTPAUTH, CURLAUTH_BASIC);
				curl_setopt($ch, CURLOPT_USERPWD, $auth['username'] . ':' . $auth['password']);
			}

			if (!empty($auth['cookie'])) {
				curl_setopt($ch, CURLOPT_COOKIE, $auth['cookie']);
			}

			curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);

			$responseRaw = curl_exec($ch);
			$httpCode = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);

			if ($responseRaw === false) {
				$errorMessage = curl_error($ch);
				curl_close($ch);
				return [
					'status' => 'error',
					'message' => sprintf('ntopng request failed: %s', $errorMessage)
				];
			}

			curl_close($ch);

			$decoded = json_decode($responseRaw, true);
			if (!is_array($decoded)) {
				return [
					'status' => 'error',
					'message' => 'Invalid JSON returned by ntopng.',
					'http_code' => $httpCode
				];
			}

			if ($httpCode >= 400) {
				return [
					'status' => 'error',
					'message' => 'ntopng returned HTTP error.',
					'http_code' => $httpCode,
					'response' => $decoded
				];
			}

			return $decoded;
		} catch (\Throwable $e) {
			return [
				'status' => 'error',
				'message' => sprintf('Unhandled proxy error: %s', $e->getMessage())
			];
		}
	}

	/**
	 * Get status information from ntopng.
	 *
	 * @return array
	 */
	public function statusAction(): array
	{
		try {
			$payload = $this->proxyRequest('get/system/info.lua', []);
			if (($payload['status'] ?? '') === 'error') {
				return $payload;
			}

			return [
				'status' => 'ok',
				'version' => $this->extractVersion($payload),
				'running' => true,
				'interfaces' => $this->extractInterfaces($payload),
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
	 * Read ntopng authentication settings from OPNsense config.
	 *
	 * @return array
	 */
	private function getAuthSettings(): array
	{
		$auth = [
			'username' => '',
			'password' => '',
			'token' => '',
			'cookie' => ''
		];

		try {
			$model = $this->getModel();
			$mode = strtolower(trim((string)$model->auth_mode));

			switch ($mode) {
				case 'basic':
					$auth['username'] = trim((string)$model->auth_username);
					$auth['password'] = trim((string)$model->auth_password);
					break;

				case 'token':
					$auth['token'] = trim((string)$model->auth_token);
					break;

				case 'cookie':
					$auth['cookie'] = trim((string)$model->auth_cookie);
					break;

				default:
					break;
			}
		} catch (\Throwable $e) {
			return $auth;
		}

		return $auth;
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

	/**
	 * Build ntopng REST base URL from model settings.
	 *
	 * @return string
	 */
	private function getRestBaseUrl(): string
	{
		$model = $this->getModel();
		$scheme = strtolower(trim((string)$model->rest_scheme));
		$host = trim((string)$model->rest_host);
		$port = trim((string)$model->rest_port);

		if ($scheme !== 'https') {
			$scheme = 'http';
		}
		if ($host === '') {
			$host = '127.0.0.1';
		}
		if ($port === '' || !is_numeric($port)) {
			$port = '3000';
		}

		return sprintf('%s://%s:%s/lua/rest/v2/', $scheme, $host, $port);
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

			$args = [
				escapeshellarg($config['enabled']),
				escapeshellarg($config['interfaces']),
				escapeshellarg($config['http_port']),
				escapeshellarg($config['https_port']),
				escapeshellarg($config['dns_mode']),
				escapeshellarg($config['certificate']),
				escapeshellarg($config['max_flows']),
				escapeshellarg($config['max_hosts']),
				escapeshellarg($config['local_networks']),
				escapeshellarg($config['extra_options'])
			];

			$response = trim((new Backend())->configdRun('appidentification ntopng_generate ' . implode(' ', $args)));

			return [
				'status' => 'ok',
				'message' => $response !== '' ? $response : 'ntopng.conf generated.'
			];
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

		$restartResult = trim((new Backend())->configdRun('appidentification ntopng_restart'));
		return [
			'status' => 'ok',
			'message' => $restartResult !== '' ? $restartResult : 'ntopng restarted.'
		];
	}
}
