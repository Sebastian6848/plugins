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
	 * List detected L7 protocols and traffic statistics on current interface.
	 *
	 * @return array
	 */
	public function listAction(): array
	{
		try {
			$params = array_filter([
				'ifid' => $this->requestString('ifid', '')
			], function ($value) {
				return $value !== '';
			});

			$payload = $this->proxyRequest('get/interface/l7/stats.lua', $params);
			if (($payload['status'] ?? '') === 'error') {
				return $payload;
			}

			$rows = [];
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
			$response = trim((new Backend())->configdRun('appidentification apply_rules'));
			return [
				'status' => 'ok',
				'message' => $response !== '' ? $response : 'ntopng restart command executed.'
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
			$payload = $this->proxyRequest('get/l7/category/consts.lua', []);
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
		if (!file_exists(self::CUSTOM_RULES_FILE)) {
			return [];
		}

		$lines = @file(self::CUSTOM_RULES_FILE, FILE_IGNORE_NEW_LINES);
		if ($lines === false) {
			throw new \RuntimeException('Cannot read protos.txt file.');
		}

		return $lines;
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
		$directory = dirname(self::CUSTOM_RULES_FILE);
		if (!is_dir($directory) && !@mkdir($directory, 0755, true) && !is_dir($directory)) {
			throw new \RuntimeException('Cannot create directory for protos.txt.');
		}

		$content = implode("\n", array_map(function ($line) {
			return rtrim((string)$line, "\r\n");
		}, $lines));
		if ($content !== '') {
			$content .= "\n";
		}

		if (@file_put_contents(self::CUSTOM_RULES_FILE, $content, LOCK_EX) === false) {
			throw new \RuntimeException('Cannot write protos.txt file.');
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
}
