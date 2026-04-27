<?php

/*
 * Copyright (C) 2026 Deciso B.V.
 * All rights reserved.
 */

namespace OPNsense\AppIdentification\Api;

use OPNsense\Base\ApiMutableModelControllerBase;
use OPNsense\Core\Config;

/**
 * Class RuleController
 *
 * CRUD endpoints for custom application identification rules.
 */
class RuleController extends ApiMutableModelControllerBase
{
	protected static $internalModelName = 'appidentification';
	protected static $internalModelClass = '\OPNsense\AppIdentification\AppIdentification';

	private const IMPORT_FIELDS = ['enabled', 'description', 'match_type', 'match_value', 'app_label'];
	private const MATCH_TYPES = ['domain', 'ip', 'cidr', 'port', 'protocol'];
	private const IMPORT_LIMIT = 5000;

	public function searchRulesAction()
	{
		return $this->searchBase('rules.rule', ['enabled', 'description', 'match_type', 'match_value', 'app_label']);
	}

	public function getRuleAction($uuid = null)
	{
		return $this->getBase('rule', 'rules.rule', $uuid);
	}

	public function addRuleAction()
	{
		return $this->addBase('rule', 'rules.rule');
	}

	public function setRuleAction($uuid)
	{
		return $this->setBase('rule', 'rules.rule', $uuid);
	}

	public function delRuleAction($uuid)
	{
		return $this->delBase('rules.rule', $uuid);
	}

	public function toggleRuleAction($uuid)
	{
		return $this->toggleBase('rules.rule', $uuid);
	}

	public function listAction(): array
	{
		return ['rules' => array_values(array_filter($this->collectRules(), function ($rule) {
			return (string)$rule['enabled'] === '1';
		}))];
	}

	public function statsAction(): array
	{
		$rules = $this->collectRules();
		$enabled = 0;
		foreach ($rules as $rule) {
			if ((string)$rule['enabled'] === '1') {
				$enabled++;
			}
		}

		return [
			'status' => 'ok',
			'total' => count($rules),
			'enabled' => $enabled,
			'limit' => self::IMPORT_LIMIT
		];
	}

	public function importAction(): array
	{
		if (!$this->request->isPost()) {
			return ['status' => 'error', 'message' => 'Import requires a POST request.'];
		}

		$format = strtolower(trim((string)$this->request->getPost('format', null, '')));
		$mode = strtolower(trim((string)$this->request->getPost('mode', null, 'append')));
		if (!in_array($format, ['csv', 'json'], true)) {
			return ['status' => 'error', 'message' => 'Import format must be csv or json.'];
		}
		if (!in_array($mode, ['append', 'replace'], true)) {
			return ['status' => 'error', 'message' => 'Import mode must be append or replace.'];
		}

		$payload = $this->readImportPayload();
		if (trim($payload) === '') {
			return ['status' => 'error', 'message' => 'Import data is empty.', 'errors' => ['Import data is empty.']];
		}

		$parsed = $format === 'csv' ? $this->parseCsvPayload($payload) : $this->parseJsonPayload($payload);
		if (!empty($parsed['errors'])) {
			return ['status' => 'error', 'message' => 'Import data is invalid.', 'errors' => $parsed['errors']];
		}

		$rows = $parsed['rows'];
		if (count($rows) === 0) {
			return ['status' => 'error', 'message' => 'Import data does not contain any rules.', 'errors' => ['Import data does not contain any rules.']];
		}
		if (count($rows) > self::IMPORT_LIMIT) {
			return ['status' => 'error', 'message' => sprintf('Import is limited to %d rules.', self::IMPORT_LIMIT)];
		}

		$validated = $this->validateImportRows($rows);
		if (!empty($validated['errors'])) {
			return ['status' => 'error', 'message' => 'Import data is invalid.', 'errors' => $validated['errors']];
		}

		$model = $this->getModel();
		$existingKeys = $mode === 'append' ? $this->ruleKeys($this->collectRules()) : [];
		$seenKeys = [];
		$skipped = 0;
		$rulesToImport = [];
		foreach ($validated['rows'] as $row) {
			$key = $this->ruleKey($row);
			if (isset($seenKeys[$key]) || isset($existingKeys[$key])) {
				$skipped++;
				continue;
			}
			$seenKeys[$key] = true;
			$rulesToImport[] = $row;
		}

		if ($mode === 'replace') {
			$uuids = [];
			foreach ($model->rules->rule->iterateItems() as $uuid => $rule) {
				$uuids[] = $uuid;
			}
			foreach ($uuids as $uuid) {
				$model->rules->rule->del($uuid);
			}
		}

		foreach ($rulesToImport as $row) {
			$node = $model->rules->rule->add();
			$node->enabled = $row['enabled'];
			$node->description = $row['description'];
			$node->match_type = $row['match_type'];
			$node->match_value = $row['match_value'];
			$node->app_label = $row['app_label'];
		}

		$validationMessages = $model->performValidation();
		if ($validationMessages->count() > 0) {
			$errors = [];
			foreach ($validationMessages as $message) {
				$errors[] = $message->getField() . ': ' . $message->getMessage();
			}
			return ['status' => 'error', 'message' => 'Imported rules failed model validation.', 'errors' => $errors];
		}

		$model->serializeToConfig();
		Config::getInstance()->save();
		if ($mode === 'replace') {
			syslog(LOG_NOTICE, sprintf('AppIdentification: replaced custom rules via bulk import, imported=%d skipped=%d', count($rulesToImport), $skipped));
		}

		return [
			'status' => 'ok',
			'imported' => count($rulesToImport),
			'skipped' => $skipped,
			'total' => count($this->collectRules()),
			'message' => sprintf('Successfully imported %d rules.', count($rulesToImport))
		];
	}

	public function templateAction(string $format = ''): array|string
	{
		$format = strtolower(trim($format));
		if ($format === 'csv') {
			return $this->downloadText($this->csvTemplate(), 'app_rules_template.csv', 'text/csv; charset=utf-8');
		}
		if ($format === 'json') {
			return $this->downloadText($this->jsonTemplate(), 'app_rules_template.json', 'application/json; charset=utf-8');
		}
		return ['status' => 'error', 'message' => 'Template format must be csv or json.'];
	}

	public function exportAction(string $format = ''): array|string
	{
		$format = strtolower(trim($format));
		$rules = $this->collectRules();
		$stamp = date('Ymd_His');
		if ($format === 'csv') {
			return $this->downloadText($this->rulesToCsv($rules), "app_rules_{$stamp}.csv", 'text/csv; charset=utf-8');
		}
		if ($format === 'json') {
			$json = json_encode(array_map([$this, 'exportRule'], $rules), JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
			return $this->downloadText($json . "\n", "app_rules_{$stamp}.json", 'application/json; charset=utf-8');
		}
		return ['status' => 'error', 'message' => 'Export format must be csv or json.'];
	}

	private function collectRules(): array
	{
		$model = $this->getModel();
		$rules = [];

		foreach ($model->rules->rule->iterateItems() as $uuid => $rule) {
			$rules[] = [
				'uuid' => (string)$uuid,
				'enabled' => (string)$rule->enabled,
				'description' => (string)$rule->description,
				'match_type' => (string)$rule->match_type,
				'match_value' => (string)$rule->match_value,
				'app_label' => (string)$rule->app_label
			];
		}

		return $rules;
	}

	private function readImportPayload(): string
	{
		$payload = (string)$this->request->getPost('payload', null, '');
		if ($payload !== '') {
			return $payload;
		}

		foreach ($this->request->getUploadedFiles() as $file) {
			if ($file->getError() === UPLOAD_ERR_OK && is_readable($file->getTempName())) {
				return (string)file_get_contents($file->getTempName());
			}
		}

		return '';
	}

	private function parseCsvPayload(string $payload): array
	{
		$payload = preg_replace('/^\xEF\xBB\xBF/', '', $payload);
		$handle = fopen('php://temp', 'r+');
		fwrite($handle, $payload);
		rewind($handle);

		$header = null;
		$rows = [];
		$errors = [];
		$line = 0;
		while (($fields = fgetcsv($handle)) !== false) {
			$line++;
			if ($fields === [null] || $fields === false) {
				continue;
			}
			if ($header === null) {
				$header = array_map('trim', $fields);
				$missing = array_diff(['match_type', 'match_value', 'app_label'], $header);
				if (!empty($missing)) {
					$errors[] = 'CSV header is missing required fields: ' . implode(', ', $missing);
					break;
				}
				continue;
			}
			if (count($fields) !== count($header)) {
				$errors[] = sprintf('Line %d: column count does not match the header.', $line);
				continue;
			}
			$row = array_combine($header, $fields);
			$row['_line'] = $line;
			$rows[] = $row;
		}
		fclose($handle);

		if ($header === null) {
			$errors[] = 'CSV file is empty.';
		}

		return ['rows' => $rows, 'errors' => $errors];
	}

	private function parseJsonPayload(string $payload): array
	{
		$payload = preg_replace('/^\xEF\xBB\xBF/', '', $payload);
		$data = json_decode($payload, true);
		if (json_last_error() !== JSON_ERROR_NONE) {
			return ['rows' => [], 'errors' => ['JSON parse error: ' . json_last_error_msg()]];
		}
		if (!is_array($data)) {
			return ['rows' => [], 'errors' => ['JSON root must be an array of rule objects.']];
		}

		$rows = [];
		$errors = [];
		foreach ($data as $idx => $row) {
			if (!is_array($row)) {
				$errors[] = sprintf('Item %d: rule must be an object.', $idx + 1);
				continue;
			}
			$row['_line'] = $idx + 1;
			$rows[] = $row;
		}
		return ['rows' => $rows, 'errors' => $errors];
	}

	private function validateImportRows(array $rows): array
	{
		$cleanRows = [];
		$errors = [];
		foreach ($rows as $idx => $row) {
			$line = (int)($row['_line'] ?? ($idx + 1));
			$clean = [];
			foreach (self::IMPORT_FIELDS as $field) {
				$clean[$field] = trim((string)($row[$field] ?? ''));
			}
			$clean['enabled'] = $this->normalizeEnabled($clean['enabled']);

			foreach (['match_type', 'match_value', 'app_label'] as $required) {
				if ($clean[$required] === '') {
					$errors[] = sprintf('Line %d: %s is required.', $line, $required);
				}
			}
			if ($clean['match_type'] !== '' && !in_array($clean['match_type'], self::MATCH_TYPES, true)) {
				$errors[] = sprintf('Line %d: match_type is invalid.', $line);
			}
			$valueError = $this->validateMatchValue($clean['match_type'], $clean['match_value']);
			if ($valueError !== '') {
				$errors[] = sprintf('Line %d: %s', $line, $valueError);
			}
			$cleanRows[] = $clean;
		}

		return ['rows' => $cleanRows, 'errors' => $errors];
	}

	private function normalizeEnabled(string $enabled): string
	{
		$value = strtolower($enabled);
		if ($value === '' || in_array($value, ['1', 'true', 'yes', 'on', 'enabled'], true)) {
			return '1';
		}
		return '0';
	}

	private function validateMatchValue(string $type, string $value): string
	{
		if ($value === '') {
			return '';
		}
		if ($type === 'ip' && filter_var($value, FILTER_VALIDATE_IP) === false) {
			return 'match_value must be a valid IP address.';
		}
		if ($type === 'cidr') {
			$parts = explode('/', $value, 2);
			if (count($parts) !== 2 || filter_var($parts[0], FILTER_VALIDATE_IP, FILTER_FLAG_IPV4) === false || !ctype_digit($parts[1]) || (int)$parts[1] < 0 || (int)$parts[1] > 32) {
				return 'match_value must be a valid IPv4 CIDR network.';
			}
		}
		if ($type === 'port' && (!ctype_digit($value) || (int)$value < 1 || (int)$value > 65535)) {
			return 'match_value must be a TCP/UDP port between 1 and 65535.';
		}
		if ($type === 'domain' && !preg_match('/^[A-Za-z0-9*_.-]+$/', $value)) {
			return 'match_value must be a valid domain substring.';
		}
		if ($type === 'protocol' && !preg_match('/^[A-Za-z0-9_.+-]+$/', $value)) {
			return 'match_value must be a valid protocol name.';
		}
		return '';
	}

	private function ruleKeys(array $rules): array
	{
		$keys = [];
		foreach ($rules as $rule) {
			$keys[$this->ruleKey($rule)] = true;
		}
		return $keys;
	}

	private function ruleKey(array $rule): string
	{
		return strtolower(trim((string)$rule['match_type'])) . "\n" . strtolower(trim((string)$rule['match_value']));
	}

	private function exportRule(array $rule): array
	{
		return array_intersect_key($rule, array_flip(self::IMPORT_FIELDS));
	}

	private function rulesToCsv(array $rules): string
	{
		$handle = fopen('php://temp', 'r+');
		fputcsv($handle, self::IMPORT_FIELDS);
		foreach ($rules as $rule) {
			fputcsv($handle, array_values($this->exportRule($rule)));
		}
		rewind($handle);
		$content = stream_get_contents($handle);
		fclose($handle);
		return $content;
	}

	private function csvTemplate(): string
	{
		return "enabled,description,match_type,match_value,app_label\n"
			. "1,微信流量,domain,weixin.qq.com,微信\n"
			. "1,QQ服务,domain,qq.com,QQ\n"
			. "1,办公网段,cidr,10.10.0.0/16,内网办公\n"
			. "0,临时停用,port,8080,测试服务\n";
	}

	private function jsonTemplate(): string
	{
		return "[\n"
			. "  {\"enabled\":\"1\",\"description\":\"微信流量\",\"match_type\":\"domain\",\"match_value\":\"weixin.qq.com\",\"app_label\":\"微信\"},\n"
			. "  {\"enabled\":\"1\",\"description\":\"QQ服务\",\"match_type\":\"domain\",\"match_value\":\"qq.com\",\"app_label\":\"QQ\"}\n"
			. "]\n";
	}

	private function downloadText(string $content, string $filename, string $contentType): string
	{
		$this->response->setHeader('Content-Type', $contentType);
		$this->response->setHeader('Content-Transfer-Encoding', 'binary');
		$this->response->setHeader('Pragma', 'no-cache');
		$this->response->setHeader('Expires', '0');
		$this->response->setHeader('Content-Disposition', 'attachment; filename="' . $filename . '"');
		return $content;
	}
}
