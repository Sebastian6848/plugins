<?php

/*
 * Copyright (C) 2026 Deciso B.V.
 * All rights reserved.
 */

namespace OPNsense\AppIdentification\Api;

use OPNsense\Core\Backend;

/**
 * Class ApplicationsController
 *
 * API endpoints for L7 application and custom protocol rule management.
 */
class ApplicationsController extends GeneralController
{
	/**
	 * Custom nDPI protocol rules file path.
	 */
	private const CUSTOM_RULES_FILE = '/var/lib/ntopng/protos.txt';

	/**
	 * Backend action namespace.
	 */
	private const BACKEND_NAMESPACE = 'appidentification';

	/**
	 * List detected L7 protocols and traffic statistics on current interface.
	 *
	 * @return array
	 */
	public function listAction(): array
	{
		try {
			$payload = $this->fetchL7Stats();
			if (($payload['status'] ?? '') === 'error' || (($payload['rc'] ?? 0) !== 0)) {
				$flowPayload = $this->proxyRequest('flow/active.lua', [
					'ifid' => $this->getIfid(),
					'perPage' => 100
				]);
				if (($flowPayload['status'] ?? '') === 'error') {
					return $flowPayload;
				}
				$payload = $this->aggregateL7FromFlows($flowPayload['rsp']['data'] ?? []);
			}

			$rows = [];
			if (isset($payload['rsp']['labels']) && is_array($payload['rsp']['labels'])) {
				$series = is_array($payload['rsp']['series'] ?? null) ? $payload['rsp']['series'] : [];
				$totalBytes = 0;
				foreach ($series as $value) {
					$totalBytes += (int)$value;
				}

				foreach ($payload['rsp']['labels'] as $idx => $label) {
					$bytes = (int)($series[$idx] ?? 0);
					$rows[] = [
						'name' => (string)$label,
						'category' => 'L7',
						'bytes' => $bytes,
						'flows' => 0,
						'up_bytes' => 0,
						'down_bytes' => 0,
						'percentage' => $totalBytes > 0 ? round($bytes / $totalBytes * 100, 1) : 0.0
					];
				}

				return [
					'status' => 'ok',
					'rows' => $rows,
					'total' => count($rows),
					'data' => $payload
				];
			}

			foreach ($this->extractApplicationRows($payload) as $item) {
				$totalBytes = (int)$this->firstNumericValue([
					$item['bytes'] ?? null,
					$item['tot_bytes'] ?? null,
					$item['value'] ?? null
				]);
				$upBytes = (int)$this->firstNumericValue([
					$item['sent_bytes'] ?? null,
					$item['src2dst_bytes'] ?? null,
					$item['up_bytes'] ?? null
				]);
				$downBytes = (int)$this->firstNumericValue([
					$item['rcvd_bytes'] ?? null,
					$item['dst2src_bytes'] ?? null,
					$item['down_bytes'] ?? null
				]);

				if ($upBytes === 0 && $downBytes === 0 && $totalBytes > 0) {
					$upBytes = (int)round($totalBytes / 2);
					$downBytes = $totalBytes - $upBytes;
				}

				$rows[] = [
					'name' => $this->firstStringValue([
						$item['label'] ?? null,
						$item['name'] ?? null,
						$item['proto'] ?? null,
						$item['protocol'] ?? null,
						$item['l7_proto'] ?? null
					]),
					'category' => $this->firstStringValue([
						$item['category'] ?? null,
						$item['cat'] ?? null,
						'Uncategorized'
					]),
					'bytes' => $totalBytes,
					'flows' => (int)$this->firstNumericValue([
						$item['flows'] ?? null,
						$item['num_flows'] ?? null,
						$item['count'] ?? null
					]),
					'up_bytes' => $upBytes,
					'down_bytes' => $downBytes,
					'percentage' => (float)$this->firstNumericValue([
						$item['percentage'] ?? null,
						$item['perc'] ?? null,
						$item['ratio'] ?? null
					])
				];
			}

			return [
				'status' => 'ok',
				'rows' => $rows,
				'total' => count($rows),
				'data' => $payload
			];
		} catch (\Throwable $e) {
			return [
				'status' => 'error',
				'message' => sprintf('Unable to list application statistics: %s', $e->getMessage())
			];
		}
	}

	/**
	 * Return ntopng L7 statistics in ApexCharts-compatible format.
	 *
	 * @return array
	 */
	public function getL7StatsAction(): array
	{
		try {
			$result = $this->fetchL7Stats();
			if (($result['status'] ?? '') === 'error') {
				return $result;
			}

			if (($result['rc'] ?? -1) !== 0) {
				return [
					'status' => 'error',
					'message' => (string)($result['rc_str_hr'] ?? $result['rc_str'] ?? 'Unable to load L7 statistics.'),
					'data' => $result
				];
			}

			return [
				'status' => 'ok',
				'data' => $result['rsp'] ?? []
			];
		} catch (\Throwable $e) {
			return [
				'status' => 'error',
				'message' => sprintf('Unable to retrieve L7 statistics: %s', $e->getMessage())
			];
		}
	}

	/**
	 * Return Top applications aggregated from active flows and custom rules.
	 *
	 * When no custom rules are enabled, this endpoint falls back to ntopng's
	 * native L7 statistics to preserve the historical/cumulative behaviour.
	 *
	 * @return array
	 */
	public function topApplicationsAction(): array
	{
		try {
			$rules = $this->getEnabledRules();
			if (empty($rules)) {
				return $this->topApplicationsFromL7Stats();
			}

			$flowResult = $this->proxyRequest('flow/active.lua', [
				'ifid' => $this->getIfid(),
				'perPage' => 1000
			]);
			if (($flowResult['status'] ?? '') === 'error') {
				return [
					'status' => 'error',
					'message' => (string)($flowResult['message'] ?? 'Unable to load active flows.')
				];
			}

			$stats = [];
			foreach ($this->extractFlowRows($flowResult) as $flow) {
				if (!is_array($flow)) {
					continue;
				}

				$matchedRule = $this->matchFlowRule($flow, $rules);
				$name = $matchedRule !== null ? (string)$matchedRule['app_label'] : trim((string)($flow['protocol']['l7'] ?? ''));
				if ($name === '') {
					$name = 'Unidentified';
				}

				if (!isset($stats[$name])) {
					$stats[$name] = [
						'name' => $name,
						'bytes' => 0,
						'flows' => 0,
						'is_custom' => $matchedRule !== null
					];
				}

				$stats[$name]['bytes'] += (int)($flow['bytes'] ?? 0);
				$stats[$name]['flows'] += 1;
				$stats[$name]['is_custom'] = $stats[$name]['is_custom'] || $matchedRule !== null;
			}

			$applications = array_values($stats);
			usort($applications, function ($left, $right) {
				return (int)$right['bytes'] <=> (int)$left['bytes'];
			});
			$applications = array_slice($applications, 0, 10);

			return $this->formatTopApplicationsResponse($applications, true);
		} catch (\Throwable $e) {
			syslog(LOG_ERR, 'AppIdentification: unable to aggregate top applications: ' . $e->getMessage());
			return [
				'status' => 'error',
				'message' => 'Unable to aggregate top applications.'
			];
		}
	}

	/**
	 * Return Top 10 hosts aggregated from active flows.
	 *
	 * @return array
	 */
	public function getTopHostsAction(): array
	{
		try {
			$appFilter = $this->requestString('app_filter', 'all');
			$rules = $appFilter !== 'all' ? $this->getEnabledRules() : [];
			$flowResult = $this->proxyRequest('flow/active.lua', [
				'ifid' => $this->getIfid(),
				'perPage' => 200
			]);
			if (($flowResult['status'] ?? '') === 'error') {
				return $flowResult;
			}

			$flows = $flowResult['rsp']['data'] ?? [];
			$hosts = [];

			foreach ($flows as $flow) {
				if (!is_array($flow)) {
					continue;
				}

				if ($appFilter !== 'all') {
					$matchedRule = $this->matchFlowRule($flow, $rules);
					if ($appFilter === 'custom_only') {
						if ($matchedRule === null) {
							continue;
						}
					} elseif (strpos($appFilter, 'custom:') === 0) {
						$label = substr($appFilter, 7);
						if ($matchedRule === null || (string)$matchedRule['app_label'] !== $label) {
							continue;
						}
					}
				}

				$bytes = (int)($flow['bytes'] ?? 0);

				foreach (['client', 'server'] as $role) {
					$endpoint = is_array($flow[$role] ?? null) ? $flow[$role] : [];
					$ip = trim((string)($endpoint['ip'] ?? ''));
					$name = trim((string)($endpoint['name'] ?? $ip));
					if ($ip === '') {
						continue;
					}

					if (!isset($hosts[$ip])) {
						$hosts[$ip] = [
							'ip' => $ip,
							'name' => $name !== '' ? $name : $ip,
							'bytes' => 0,
							'flows' => 0,
							'as_client' => 0,
							'as_server' => 0,
						];
					}

					$hosts[$ip]['bytes'] += $bytes;
					$hosts[$ip]['flows'] += 1;
					if ($role === 'client') {
						$hosts[$ip]['as_client']++;
					} else {
						$hosts[$ip]['as_server']++;
					}
				}
			}

			usort($hosts, function ($left, $right) {
				return $right['bytes'] <=> $left['bytes'];
			});
			$hosts = array_slice(array_values($hosts), 0, 10);

			foreach ($hosts as &$host) {
				$host['bytes_fmt'] = $this->formatBytes((int)$host['bytes']);
			}
			unset($host);

			return [
				'status' => 'ok',
				'data' => $hosts
			];
		} catch (\Throwable $e) {
			return [
				'status' => 'error',
				'message' => sprintf('Unable to retrieve top hosts: %s', $e->getMessage())
			];
		}
	}

	/**
	 * Get one custom rule for dialog form editing.
	 *
	 * @param string $index
	 * @return array
	 */
	public function getCustomRuleAction(string $index = ''): array
	{
		try {
			$rules = $this->readCustomRules();
			$idx = is_numeric($index) ? (int)$index : -1;

			if ($idx >= 0 && isset($rules[$idx])) {
				$parts = $this->parseRule($rules[$idx]['rule'] ?? '');
				return [
					'rule' => [
						'host' => $parts['host'],
						'application' => $parts['application'],
						'index' => (string)$idx,
						'action' => 'update'
					]
				];
			}

			return [
				'rule' => [
					'host' => '',
					'application' => '',
					'index' => '-1',
					'action' => 'add'
				]
			];
		} catch (\Throwable $e) {
			return [
				'rule' => [
					'host' => '',
					'application' => '',
					'index' => '-1',
					'action' => 'add'
				],
				'status' => 'error',
				'message' => sprintf('Unable to get custom rule: %s', $e->getMessage())
			];
		}
	}

	/**
	 * Save custom rule from base dialog form payload.
	 *
	 * @return array
	 */
	public function saveCustomRuleFormAction(): array
	{
		try {
			$ruleData = $this->request->getPost('rule', null, []);
			if (!is_array($ruleData)) {
				$ruleData = [];
			}

			$host = trim((string)($ruleData['host'] ?? ''));
			$application = trim((string)($ruleData['application'] ?? ''));
			$action = strtolower(trim((string)($ruleData['action'] ?? 'add')));
			$index = isset($ruleData['index']) && is_numeric($ruleData['index']) ? (int)$ruleData['index'] : -1;

			if ($host === '' || $application === '') {
				return [
					'result' => 'failed',
					'status' => 'error',
					'message' => 'Host and application name are required.'
				];
			}

			$composedRule = $this->composeRule($host, $application);
			$saveAction = $action === 'update' ? 'update' : 'add';

			$response = $this->saveCustomRuleInternal($saveAction, $composedRule, $index);
			if (($response['status'] ?? '') === 'error') {
				$response['result'] = 'failed';
				return $response;
			}

			return [
				'result' => 'saved',
				'status' => 'ok',
				'message' => 'Rule saved successfully.',
				'rows' => $response['rows'] ?? []
			];
		} catch (\Throwable $e) {
			return [
				'result' => 'failed',
				'status' => 'error',
				'message' => sprintf('Unable to save rule form: %s', $e->getMessage())
			];
		}
	}

	/**
	 * Apply custom rules by restarting ntopng service.
	 *
	 * @return array
	 */
	public function applyRulesAction(): array
	{
		try {
			$response = trim((new Backend())->configdRun(self::BACKEND_NAMESPACE . ' reload'));
			return [
				'status' => 'ok',
				'message' => $response !== '' ? $response : 'ntopng reload command executed.'
			];
		} catch (\Throwable $e) {
			return [
				'status' => 'error',
				'message' => sprintf('Unable to apply rules: %s', $e->getMessage())
			];
		}
	}

	/**
	 * List available L7 application categories.
	 *
	 * @return array
	 */
	public function categoriesAction(): array
	{
		try {
			$payload = $this->proxyRequest('l7/category/consts.lua', []);
			if (($payload['status'] ?? '') === 'error') {
				return $payload;
			}

			$rows = [];
			foreach ($this->extractApplicationRows($payload) as $item) {
				if (is_array($item)) {
					$rows[] = $item;
				}
			}

			return [
				'status' => 'ok',
				'rows' => $rows,
				'total' => count($rows),
				'data' => $payload
			];
		} catch (\Throwable $e) {
			return [
				'status' => 'error',
				'message' => sprintf('Unable to retrieve application categories: %s', $e->getMessage())
			];
		}
	}

	/**
	 * Read custom ntopng application rules from protos.txt.
	 *
	 * @return array
	 */
	public function customRulesAction(): array
	{
		try {
			$rules = $this->readCustomRules();
			return [
				'status' => 'ok',
				'rows' => $rules,
				'total' => count($rules),
				'file' => self::CUSTOM_RULES_FILE
			];
		} catch (\Throwable $e) {
			return [
				'status' => 'error',
				'message' => sprintf('Unable to read custom rules: %s', $e->getMessage())
			];
		}
	}

	/**
	 * Save custom ntopng application rules into protos.txt.
	 *
	 * Supported actions:
	 * - add: requires rule
	 * - update: requires index and rule
	 * - delete: requires index
	 *
	 * @return array
	 */
	public function saveCustomRuleAction(): array
	{
		try {
			$action = strtolower($this->requestString('action', 'add'));
			$rule = $this->requestString('rule', '');
			$index = $this->requestInt('index', -1);

			return $this->saveCustomRuleInternal($action, $rule, $index);
		} catch (\Throwable $e) {
			return [
				'status' => 'error',
				'message' => sprintf('Unable to save custom rule: %s', $e->getMessage())
			];
		}
	}

	/**
	 * Read rules as displayable entries.
	 *
	 * @return array
	 */
	private function readCustomRules(): array
	{
		return $this->buildRuleEntries($this->readRawRuleLines());
	}

	/**
	 * Fetch L7 protocol statistics from ntopng.
	 *
	 * @return array
	 */
	private function fetchL7Stats(): array
	{
		return $this->proxyRequest('interface/l7/stats.lua', [
			'ifid' => $this->getIfid(),
			'ndpistats_mode' => 'sinceStartup',
		]);
	}

	/**
	 * Format ntopng L7 statistics as the topApplications response.
	 *
	 * @return array
	 */
	private function topApplicationsFromL7Stats(): array
	{
		$result = $this->fetchL7Stats();
		if (($result['status'] ?? '') === 'error') {
			return $result;
		}
		if (($result['rc'] ?? -1) !== 0) {
			return [
				'status' => 'error',
				'message' => (string)($result['rc_str_hr'] ?? $result['rc_str'] ?? 'Unable to load L7 statistics.')
			];
		}

		$labels = is_array($result['rsp']['labels'] ?? null) ? $result['rsp']['labels'] : [];
		$series = is_array($result['rsp']['series'] ?? null) ? $result['rsp']['series'] : [];
		$applications = [];
		foreach ($labels as $idx => $label) {
			$applications[] = [
				'name' => (string)$label,
				'bytes' => (int)($series[$idx] ?? 0),
				'flows' => 0,
				'is_custom' => false
			];
		}

		usort($applications, function ($left, $right) {
			return (int)$right['bytes'] <=> (int)$left['bytes'];
		});

		return $this->formatTopApplicationsResponse(array_slice($applications, 0, 10), false);
	}

	/**
	 * Build response payload compatible with the existing table renderer.
	 *
	 * @param array $applications
	 * @param bool $realtime
	 * @return array
	 */
	private function formatTopApplicationsResponse(array $applications, bool $realtime): array
	{
		$labels = [];
		$series = [];
		$colors = [];
		foreach ($applications as &$application) {
			$application['bytes'] = (int)($application['bytes'] ?? 0);
			$application['flows'] = (int)($application['flows'] ?? 0);
			$application['is_custom'] = !empty($application['is_custom']);
			$application['bytes_fmt'] = $this->formatBytes($application['bytes']);
			$labels[] = (string)$application['name'];
			$series[] = $application['bytes'];
			$colors[] = $application['is_custom'] ? '#d9534f' : '#337ab7';
		}
		unset($application);

		return [
			'status' => 'ok',
			'data' => [
				'applications' => $applications,
				'labels' => $labels,
				'series' => $series,
				'colors' => $colors,
				'mode' => $realtime ? 'realtime' : 'l7stats'
			]
		];
	}

	/**
	 * Return enabled custom rules from the persistent model.
	 *
	 * @return array
	 */
	private function getEnabledRules(): array
	{
		$model = $this->getModel();
		$rules = [];
		foreach ($model->rules->rule->iterateItems() as $uuid => $rule) {
			if ((string)$rule->enabled !== '1') {
				continue;
			}
			$rules[] = [
				'uuid' => (string)$uuid,
				'match_type' => (string)$rule->match_type,
				'match_value' => trim((string)$rule->match_value),
				'app_label' => trim((string)$rule->app_label)
			];
		}
		return $rules;
	}

	/**
	 * Extract active flow rows from ntopng response.
	 *
	 * @param array $payload
	 * @return array
	 */
	private function extractFlowRows(array $payload): array
	{
		$candidates = [
			$payload['rsp']['data'] ?? null,
			$payload['rsp']['flows'] ?? null,
			$payload['data'] ?? null,
			$payload['flows'] ?? null,
			$payload['response']['flows'] ?? null,
			$payload['response'] ?? null
		];

		foreach ($candidates as $candidate) {
			if (!is_array($candidate)) {
				continue;
			}
			$flows = array_values(array_filter($candidate, function ($item) {
				return is_array($item) && (isset($item['client']) || isset($item['server']) || isset($item['protocol']));
			}));
			if (!empty($flows)) {
				return $flows;
			}
		}

		return [];
	}

	/**
	 * Match a flow against custom rules using the same priority as the frontend.
	 *
	 * @param array $flow
	 * @param array $rules
	 * @return array|null
	 */
	private function matchFlowRule(array $flow, array $rules): ?array
	{
		$client = is_array($flow['client'] ?? null) ? $flow['client'] : [];
		$server = is_array($flow['server'] ?? null) ? $flow['server'] : [];
		$serverName = strtolower((string)($server['name'] ?? ''));
		$serverIp = (string)($server['ip'] ?? '');
		$clientIp = (string)($client['ip'] ?? '');
		$serverPort = (string)($server['port'] ?? '');
		$protocol = strtolower((string)($flow['protocol']['l7'] ?? $flow['l7_proto'] ?? ''));

		foreach ($rules as $rule) {
			$value = trim((string)($rule['match_value'] ?? ''));
			if ($value === '') {
				continue;
			}
			switch ((string)($rule['match_type'] ?? '')) {
				case 'domain':
					if ($serverName !== '' && strpos($serverName, strtolower($value)) !== false) {
						return $rule;
					}
					break;
				case 'ip':
					if ($serverIp === $value || $clientIp === $value) {
						return $rule;
					}
					break;
				case 'cidr':
					if ($this->ipInCidr($serverIp, $value) || $this->ipInCidr($clientIp, $value)) {
						return $rule;
					}
					break;
				case 'port':
					if ($serverPort === $value) {
						return $rule;
					}
					break;
				case 'protocol':
					if ($protocol !== '' && strpos($protocol, strtolower($value)) !== false) {
						return $rule;
					}
					break;
			}
		}

		return null;
	}

	/**
	 * Check IPv4 address membership in CIDR notation.
	 *
	 * @param string $ip
	 * @param string $cidr
	 * @return bool
	 */
	private function ipInCidr(string $ip, string $cidr): bool
	{
		$parts = explode('/', $cidr, 2);
		if (count($parts) !== 2 || !is_numeric($parts[1])) {
			return false;
		}
		$ipLong = ip2long($ip);
		$networkLong = ip2long($parts[0]);
		$prefix = (int)$parts[1];
		if ($ipLong === false || $networkLong === false || $prefix < 0 || $prefix > 32) {
			return false;
		}
		$mask = $prefix === 0 ? 0 : (-1 << (32 - $prefix));
		return (($ipLong & $mask) === ($networkLong & $mask));
	}

	/**
	 * Save rule with add/update/delete action.
	 *
	 * @param string $action
	 * @param string $rule
	 * @param int $index
	 * @return array
	 */
	private function saveCustomRuleInternal(string $action, string $rule, int $index): array
	{
		$rawLines = $this->readRawRuleLines();
		$ruleEntries = $this->buildRuleEntries($rawLines);

		switch ($action) {
			case 'add':
				if ($rule === '') {
					return ['status' => 'error', 'message' => 'Rule content cannot be empty.'];
				}
				$rawLines[] = $rule;
				break;

			case 'update':
				if ($index < 0 || !isset($ruleEntries[$index])) {
					return ['status' => 'error', 'message' => 'Invalid rule index for update.'];
				}
				if ($rule === '') {
					return ['status' => 'error', 'message' => 'Rule content cannot be empty.'];
				}
				$rawLineIndex = $ruleEntries[$index]['raw_index'];
				$rawLines[$rawLineIndex] = $rule;
				break;

			case 'delete':
				if ($index < 0 || !isset($ruleEntries[$index])) {
					return ['status' => 'error', 'message' => 'Invalid rule index for delete.'];
				}
				$rawLineIndex = $ruleEntries[$index]['raw_index'];
				unset($rawLines[$rawLineIndex]);
				$rawLines = array_values($rawLines);
				break;

			default:
				return ['status' => 'error', 'message' => 'Unsupported action.'];
		}

		$this->writeRawRuleLines($rawLines);
		$this->reloadRules();
		$updatedRules = $this->readCustomRules();

		return [
			'status' => 'ok',
			'rows' => $updatedRules,
			'total' => count($updatedRules)
		];
	}

	/**
	 * Parse stored rule into host and application components.
	 *
	 * @param string $rule
	 * @return array
	 */
	private function parseRule(string $rule): array
	{
		$rule = trim($rule);
		if ($rule === '') {
			return ['host' => '', 'application' => ''];
		}

		if (strpos($rule, "\t") !== false) {
			$parts = explode("\t", $rule, 2);
			return [
				'host' => trim((string)$parts[0]),
				'application' => trim((string)($parts[1] ?? ''))
			];
		}

		if (strpos($rule, ':') !== false) {
			$parts = explode(':', $rule, 2);
			return [
				'host' => trim((string)$parts[0]),
				'application' => trim((string)($parts[1] ?? ''))
			];
		}

		return ['host' => $rule, 'application' => ''];
	}

	/**
	 * Compose host and application into storage format.
	 *
	 * @param string $host
	 * @param string $application
	 * @return string
	 */
	private function composeRule(string $host, string $application): string
	{
		return sprintf('%s\t%s', trim($host), trim($application));
	}

	/**
	 * Read raw rule file lines while preserving comments and empty lines.
	 *
	 * @return array
	 */
	private function readRawRuleLines(): array
	{
		$raw = trim((new Backend())->configdRun(self::BACKEND_NAMESPACE . ' read_rules'));
		if ($raw === '') {
			return [];
		}

		$payload = json_decode($raw, true);
		if (!is_array($payload)) {
			throw new \RuntimeException('Cannot decode backend read_rules response.');
		}
		if (($payload['status'] ?? '') !== 'ok') {
			throw new \RuntimeException((string)($payload['message'] ?? 'Cannot read protos.txt file.'));
		}

		$lines = $payload['data'] ?? [];
		if (!is_array($lines)) {
			return [];
		}

		return array_values(array_map(function ($line) {
			return rtrim((string)$line, "\r\n");
		}, $lines));
	}

	/**
	 * Convert raw lines to indexed rule rows.
	 *
	 * @param array $rawLines
	 * @return array
	 */
	private function buildRuleEntries(array $rawLines): array
	{
		$rows = [];
		foreach ($rawLines as $rawIndex => $line) {
			$trimmed = trim((string)$line);
			if ($trimmed === '' || strpos($trimmed, '#') === 0) {
				continue;
			}

			$rows[] = [
				'index' => count($rows),
				'rule' => $trimmed,
				'raw_index' => (int)$rawIndex
			];
		}

		return $rows;
	}

	/**
	 * Write raw lines back to protos.txt.
	 *
	 * @param array $lines
	 * @return void
	 */
	private function writeRawRuleLines(array $lines): void
	{
		$payloadLines = array_values(array_map(function ($line) {
			return rtrim((string)$line, "\r\n");
		}, $lines));

		$payload = json_encode(['rules' => $payloadLines]);
		if (!is_string($payload)) {
			throw new \RuntimeException('Cannot encode custom rules payload.');
		}

		$backend = new Backend();
		$responseRaw = trim($backend->configdpRun(self::BACKEND_NAMESPACE, ['write_rules', $payload]));
		if ($responseRaw === '') {
			throw new \RuntimeException('Empty response when writing protos.txt via backend.');
		}

		$response = json_decode($responseRaw, true);
		if (!is_array($response) || ($response['status'] ?? '') !== 'ok') {
			$message = is_array($response) ? (string)($response['message'] ?? 'unknown backend failure') : $responseRaw;
			throw new \RuntimeException('Cannot write protos.txt file: ' . $message);
		}
	}

	/**
	 * Reload ntopng after custom protocol rule changes.
	 *
	 * @return void
	 */
	private function reloadRules(): void
	{
		$responseRaw = trim((new Backend())->configdRun(self::BACKEND_NAMESPACE . ' reload'));
		if ($responseRaw === '') {
			return;
		}

		$response = json_decode($responseRaw, true);
		if (is_array($response) && ($response['status'] ?? '') === 'error') {
			throw new \RuntimeException((string)($response['message'] ?? 'Unable to reload ntopng.'));
		}
	}

	/**
	 * Parse string from request query/post.
	 *
	 * @param string $name
	 * @param string $default
	 * @return string
	 */
	private function requestString(string $name, string $default): string
	{
		$value = $this->request->getPost($name, null, null);
		if ($value === null || $value === '') {
			$value = $this->request->getQuery($name, null, $default);
		}

		return is_scalar($value) ? trim((string)$value) : $default;
	}

	/**
	 * Parse integer from request query/post.
	 *
	 * @param string $name
	 * @param int $default
	 * @return int
	 */
	private function requestInt(string $name, int $default): int
	{
		$value = $this->request->getPost($name, null, null);
		if ($value === null || $value === '') {
			$value = $this->request->getQuery($name, null, $default);
		}

		return is_numeric($value) ? (int)$value : $default;
	}

	/**
	 * Extract a list of rows from different ntopng payload formats.
	 *
	 * @param array $payload
	 * @return array
	 */
	private function extractApplicationRows(array $payload): array
	{
		$candidates = [
			$payload['rows'] ?? null,
			$payload['data'] ?? null,
			$payload['stats'] ?? null,
			$payload['rsp'] ?? null,
			$payload['rsp']['data'] ?? null,
			$payload['response'] ?? null
		];

		foreach ($candidates as $candidate) {
			if (is_array($candidate) && $this->isRowList($candidate)) {
				return array_values($candidate);
			}
		}

		if ($this->isRowList($payload)) {
			return array_values($payload);
		}

		foreach ($payload as $value) {
			if (is_array($value) && $this->isRowList($value)) {
				return array_values($value);
			}
		}

		return [];
	}

	/**
	 * Check whether value looks like a row list.
	 *
	 * @param array $items
	 * @return bool
	 */
	private function isRowList(array $items): bool
	{
		if ($items === []) {
			return true;
		}

		$sample = reset($items);
		return is_array($sample);
	}

	/**
	 * Pick first non-empty scalar value.
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
	 * Pick first numeric-like value.
	 *
	 * @param array $values
	 * @return float
	 */
	private function firstNumericValue(array $values): float
	{
		foreach ($values as $value) {
			if (is_numeric($value)) {
				return (float)$value;
			}
		}

		return 0.0;
	}

	/**
	 * Format bytes to a compact human-readable string.
	 *
	 * @param int $bytes
	 * @return string
	 */
	private function formatBytes(int $bytes): string
	{
		if ($bytes >= 1099511627776) {
			return round($bytes / 1099511627776, 2) . ' TB';
		}
		if ($bytes >= 1073741824) {
			return round($bytes / 1073741824, 2) . ' GB';
		}
		if ($bytes >= 1048576) {
			return round($bytes / 1048576, 2) . ' MB';
		}
		if ($bytes >= 1024) {
			return round($bytes / 1024, 2) . ' KB';
		}
		return $bytes . ' B';
	}

	/**
	 * Build application statistics from active flow data when ntopng L7 stats endpoint is unavailable.
	 *
	 * @param array $flows
	 * @return array
	 */
	private function aggregateL7FromFlows(array $flows): array
	{
		$stats = [];
		foreach ($flows as $flow) {
			if (!is_array($flow)) {
				continue;
			}

			$l7 = trim((string)($flow['protocol']['l7'] ?? ''));
			if ($l7 === '') {
				$l7 = 'Unknown';
			}

			if (!isset($stats[$l7])) {
				$stats[$l7] = [
					'protocol' => $l7,
					'flows' => 0,
					'bytes' => 0,
					'up_bytes' => 0,
					'down_bytes' => 0,
					'category' => 'Active Flows'
				];
			}

			$bytes = (int)($flow['bytes'] ?? 0);
			$breakdown = is_array($flow['breakdown'] ?? null) ? $flow['breakdown'] : [];
			$upRatio = (float)($breakdown['cli2srv'] ?? 50) / 100;
			$upBytes = (int)round($bytes * $upRatio);

			$stats[$l7]['flows']++;
			$stats[$l7]['bytes'] += $bytes;
			$stats[$l7]['up_bytes'] += $upBytes;
			$stats[$l7]['down_bytes'] += max(0, $bytes - $upBytes);
		}

		usort($stats, function ($left, $right) {
			return $right['bytes'] <=> $left['bytes'];
		});

		return [
			'rc' => 0,
			'rsp' => array_values($stats)
		];
	}
}
