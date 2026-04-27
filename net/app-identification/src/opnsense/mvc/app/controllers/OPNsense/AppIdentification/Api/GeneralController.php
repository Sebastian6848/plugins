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
	protected function proxyRequest(string $endpoint, array $params = []): array
	{
		try {
			$endpoint = ltrim($endpoint, '/');
			$url = $this->getRestBaseUrl() . $endpoint;

			if (!empty($params)) {
				$separator = strpos($url, '?') === false ? '?' : '&';
				$url .= $separator . http_build_query($params);
			}

			$headers = ['Accept: application/json'];
			$token = trim((string)($this->getModel()->auth_token ?? ''));
			$cookieStr = '';

			syslog(LOG_WARNING, 'AppIdentification proxyRequest: url=' . $url . ' token_len=' . strlen($token));

			if ($token !== '') {
				$headers[] = 'Authorization: Token ' . $token;
			} else {
				syslog(LOG_WARNING, 'AppIdentification proxyRequest: no token, trying session auth');
				$cookieStr = $this->getNtopngSession();
				if ($cookieStr === '') {
					syslog(LOG_ERR, 'AppIdentification proxyRequest: session auth failed, empty cookie');
					return [
						'status' => 'error',
						'message' => 'ntopng 认证失败'
					];
				}
				syslog(LOG_WARNING, 'AppIdentification proxyRequest: session cookie acquired len=' . strlen($cookieStr));
			}

			$ch = curl_init($url);
			if ($ch === false) {
				syslog(LOG_ERR, 'AppIdentification proxyRequest: unable to initialize cURL client');
				return [
					'status' => 'error',
					'message' => 'Unable to initialize cURL client.'
				];
			}

			curl_setopt_array($ch, [
				CURLOPT_RETURNTRANSFER => true,
				CURLOPT_CONNECTTIMEOUT => 5,
				CURLOPT_TIMEOUT => 5,
				CURLOPT_FAILONERROR => false,
				CURLOPT_FOLLOWLOCATION => false,
				CURLOPT_HTTPHEADER => $headers,
			]);
			if ($cookieStr !== '') {
				curl_setopt($ch, CURLOPT_COOKIE, $cookieStr);
			}

			$responseRaw = curl_exec($ch);
			$httpCode = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
			$curlErr = curl_error($ch);
			curl_close($ch);

			syslog(LOG_WARNING, 'AppIdentification proxyRequest: httpCode=' . $httpCode . ' curlErr=' . $curlErr . ' bodyLen=' . strlen((string)$responseRaw));
			syslog(LOG_WARNING, 'AppIdentification proxyRequest: bodyPreview=' . substr((string)$responseRaw, 0, 200));

			if ($responseRaw === false) {
				syslog(LOG_ERR, 'AppIdentification: curl exec failed: ' . $curlErr);
				return [
					'status' => 'error',
					'message' => sprintf('curl 请求失败: %s', $curlErr)
				];
			}

			if ($httpCode === 302) {
				syslog(LOG_ERR, 'AppIdentification: auth failed, got 302');
				return [
					'status' => 'error',
					'message' => 'ntopng 认证失败(302)'
				];
			}

			if ($httpCode >= 400) {
				syslog(LOG_ERR, 'AppIdentification: HTTP error ' . $httpCode);
				return [
					'status' => 'error',
					'message' => sprintf('ntopng returned HTTP error %d', $httpCode),
					'http_code' => $httpCode
				];
			}

			if ($httpCode === 0) {
				syslog(LOG_ERR, 'AppIdentification: connection failed, httpCode=0');
				return [
					'status' => 'error',
					'message' => '无法连接到 ntopng，请检查服务是否运行',
					'http_code' => 0
				];
			}

			$decoded = json_decode((string)$responseRaw, true);
			if (json_last_error() !== JSON_ERROR_NONE || !is_array($decoded)) {
				syslog(LOG_ERR, 'AppIdentification: JSON parse failed: ' . json_last_error_msg());
				syslog(LOG_ERR, 'AppIdentification: ntopng 返回非 JSON 内容: ' . substr((string)$responseRaw, 0, 300));
				return [
					'status' => 'error',
					'message' => 'Invalid JSON returned by ntopng',
					'http_code' => $httpCode
				];
			}

			syslog(LOG_WARNING, 'AppIdentification proxyRequest: success, rc=' . ($decoded['rc'] ?? 'N/A'));
			return $decoded;
		} catch (\Throwable $e) {
			syslog(LOG_ERR, 'AppIdentification proxyRequest: unhandled error: ' . $e->getMessage());
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
	 * Create an ntopng session cookie for username/password fallback authentication.
	 *
	 * @return string
	 */
	private function getNtopngSession(): string
	{
		try {
			$model = $this->getModel();
			$host = $this->getRestHost();
			$port = $this->getRestPort();
			$user = trim((string)($model->auth_username ?? 'admin'));
			$pass = (string)($model->auth_password ?? '');

			if ($user === '' || $pass === '') {
				return '';
			}

			$ch = curl_init(sprintf('%s://%s:%s/authorize.html', $this->getRestScheme(), $host, $port));
			if ($ch === false) {
				return '';
			}

			curl_setopt_array($ch, [
				CURLOPT_POST => true,
				CURLOPT_POSTFIELDS => http_build_query(['user' => $user, 'password' => $pass]),
				CURLOPT_RETURNTRANSFER => true,
				CURLOPT_HEADER => true,
				CURLOPT_FOLLOWLOCATION => false,
				CURLOPT_TIMEOUT => 5,
			]);
			$response = curl_exec($ch);
			curl_close($ch);

			if (!is_string($response) || strpos($response, 'wrong-credentials') !== false) {
				syslog(LOG_ERR, 'AppIdentification: ntopng 用户名或密码错误');
				return '';
			}

			preg_match('/Set-Cookie:\s*(session_' . preg_quote($port, '/') . '_\d+=[^;]+)/i', $response, $matches);
			return $matches[1] ?? '';
		} catch (\Throwable $e) {
			syslog(LOG_ERR, 'AppIdentification: ntopng session login failed: ' . $e->getMessage());
			return '';
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

	/**
	 * Build ntopng REST base URL from model settings.
	 *
	 * @return string
	 */
	private function getRestBaseUrl(): string
	{
		return sprintf('%s://%s:%s/lua/rest/v2/get/', $this->getRestScheme(), $this->getRestHost(), $this->getRestPort());
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
