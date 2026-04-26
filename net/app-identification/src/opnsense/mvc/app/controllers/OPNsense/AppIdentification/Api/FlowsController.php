<?php

/*
 * Copyright (C) 2026 Deciso B.V.
 * All rights reserved.
 */

namespace OPNsense\AppIdentification\Api;

/**
 * Class FlowsController
 *
 * API endpoints for live flow data used by the App Identification frontend.
 */
class FlowsController extends GeneralController
{
	/**
	 * Search active flows for DataTables.
	 *
	 * Accepted request parameters:
	 * - current
	 * - rowCount
	 * - sort
	 * - searchPhrase
	 * - host
	 * - l7_proto
	 * - traffic_type
	 * - host_pool
	 * - network
	 *
	 * @return array
	 */
	public function searchAction(): array
	{
		try {
			$current = max(1, $this->requestInt('current', 1));
			$rowCount = max(1, min(500, $this->requestInt('rowCount', 25)));
			$searchPhrase = trim($this->requestString('searchPhrase', ''));
			$sort = $this->requestSort();

			$params = array_filter([
				'host' => $this->requestString('host', ''),
				'l7_proto' => $this->requestString('l7_proto', ''),
				'traffic_type' => $this->requestString('traffic_type', ''),
				'host_pool' => $this->requestString('host_pool', ''),
				'network' => $this->requestString('network', '')
			], function ($value) {
				return $value !== '';
			});

			$payload = $this->proxyRequest('get/flow/active.lua', $params);
			if (($payload['status'] ?? '') === 'error') {
				return [
					'rows' => [],
					'total' => 0,
					'rowCount' => $rowCount,
					'current' => $current,
					'status' => 'error',
					'message' => (string)($payload['message'] ?? 'Failed to fetch active flows.')
				];
			}

			$records = [];
			foreach ($this->extractFlowRecords($payload) as $record) {
				$records[] = $this->mapFlowRecord($record);
			}

			if ($searchPhrase !== '') {
				$records = $this->filterBySearchPhrase($records, $searchPhrase);
			}

			$records = $this->applySort($records, $sort);
			$total = count($records);

			$offset = ($current - 1) * $rowCount;
			$rows = array_slice($records, $offset, $rowCount);

			return [
				'rows' => $rows,
				'total' => $total,
				'rowCount' => $rowCount,
				'current' => $current
			];
		} catch (\Throwable $e) {
			return [
				'rows' => [],
				'total' => 0,
				'rowCount' => max(1, $this->requestInt('rowCount', 25)),
				'current' => max(1, $this->requestInt('current', 1)),
				'status' => 'error',
				'message' => sprintf('Unable to search active flows: %s', $e->getMessage())
			];
		}
	}

	/**
	 * Get one flow detail by flow key.
	 *
	 * @param string $flow_key Flow identifier used by ntopng
	 * @return array
	 */
	public function getFlowDetailAction(string $flow_key = ''): array
	{
		try {
			$flowKey = trim($flow_key);
			if ($flowKey === '') {
				$flowKey = $this->requestString('flow_key', '');
			}

			if ($flowKey === '') {
				return [
					'status' => 'error',
					'message' => 'Flow key not provided or expired'
				];
			}

			$params = ['flow_key' => $flowKey];
			$payload = $this->proxyRequest('get/flow/data.lua', $params);

			if (($payload['status'] ?? '') === 'error') {
				$payload = $this->proxyRequest('get/flow/active.lua', $params);
			}

			if (($payload['status'] ?? '') === 'error') {
				return $payload;
			}

			$records = $this->extractFlowRecords($payload);
			if (empty($records)) {
				return [
					'status' => 'error',
					'message' => 'Flow key not provided or expired'
				];
			}

			$detail = $records[0];

			return [
				'status' => 'ok',
				'flow_key' => $flowKey,
				'detail' => $detail,
				'row' => is_array($detail) ? $this->mapFlowRecord($detail) : []
			];
		} catch (\Throwable $e) {
			return [
				'status' => 'error',
				'message' => sprintf('Unable to retrieve flow detail: %s', $e->getMessage())
			];
		}
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
	 * Parse DataTables sort object from request.
	 *
	 * @return array
	 */
	private function requestSort(): array
	{
		$sort = $this->request->getPost('sort', null, null);
		if ($sort === null || $sort === '') {
			$sort = $this->request->getQuery('sort', null, []);
		}

		if (is_string($sort)) {
			$decoded = json_decode($sort, true);
			if (is_array($decoded)) {
				$sort = $decoded;
			}
		}

		if (!is_array($sort) && isset($_REQUEST['sort']) && is_array($_REQUEST['sort'])) {
			$sort = $_REQUEST['sort'];
		}

		return is_array($sort) ? $sort : [];
	}

	/**
	 * Extract flow record list from various ntopng payload formats.
	 *
	 * @param array $payload
	 * @return array
	 */
	private function extractFlowRecords(array $payload): array
	{
		$candidates = [
			$payload['rows'] ?? null,
			$payload['data'] ?? null,
			$payload['flows'] ?? null,
			$payload['rsp']['flows'] ?? null,
			$payload['response']['flows'] ?? null,
			$payload['response'] ?? null
		];

		foreach ($candidates as $candidate) {
			if (is_array($candidate) && $this->isRecordList($candidate)) {
				return array_values($candidate);
			}
		}

		if ($this->isRecordList($payload)) {
			return array_values($payload);
		}

		foreach ($payload as $value) {
			if (is_array($value) && $this->isRecordList($value)) {
				return array_values($value);
			}
		}

		return [];
	}

	/**
	 * Check if an array looks like a list of flow records.
	 *
	 * @param array $items
	 * @return bool
	 */
	private function isRecordList(array $items): bool
	{
		if ($items === []) {
			return true;
		}

		$sample = reset($items);
		return is_array($sample);
	}

	/**
	 * Map ntopng flow fields to frontend view model.
	 *
	 * @param array $record
	 * @return array
	 */
	private function mapFlowRecord(array $record): array
	{
		$srcIp = $this->firstStringValue([
			$record['client'] ?? null,
			$record['cli_ip'] ?? null,
			$record['src_ip'] ?? null,
			$record['ip.src'] ?? null,
			$record['IPV4_SRC_ADDR'] ?? null,
			$record['IPV6_SRC_ADDR'] ?? null
		]);
		$dstIp = $this->firstStringValue([
			$record['server'] ?? null,
			$record['srv_ip'] ?? null,
			$record['dst_ip'] ?? null,
			$record['ip.dst'] ?? null,
			$record['IPV4_DST_ADDR'] ?? null,
			$record['IPV6_DST_ADDR'] ?? null
		]);

		$srcPort = $this->firstStringValue([
			$record['client_port'] ?? null,
			$record['cli_port'] ?? null,
			$record['src_port'] ?? null,
			$record['sport'] ?? null,
			$record['L4_SRC_PORT'] ?? null
		]);
		$dstPort = $this->firstStringValue([
			$record['server_port'] ?? null,
			$record['srv_port'] ?? null,
			$record['dst_port'] ?? null,
			$record['dport'] ?? null,
			$record['L4_DST_PORT'] ?? null
		]);

		$throughputBps = $this->firstNumericValue([
			$record['throughput_bps'] ?? null,
			$record['bps'] ?? null,
			$record['bytes_rate'] ?? null
		]);

		$totalBytes = $this->firstNumericValue([
			$record['total_bytes'] ?? null,
			$record['bytes'] ?? null,
			$record['TOTAL_BYTES'] ?? null
		]);

		$protocol = $this->firstStringValue([
			$record['protocol'] ?? null,
			$record['l7_proto_name'] ?? null,
			$record['l7_proto'] ?? null,
			$record['L7_PROTO'] ?? null,
			$record['proto'] ?? null
		]);

		$fallbackFlowKey = trim(sprintf('%s-%s-%s', $this->joinEndpoint($srcIp, $srcPort), $this->joinEndpoint($dstIp, $dstPort), $protocol));
		$flowKey = $this->firstStringValue([
			$record['flow_key'] ?? null,
			$record['hash_id'] ?? null,
			$record['key'] ?? null,
			$fallbackFlowKey
		]);

		return [
			'flow_key' => $flowKey,
			'last_seen' => $this->formatTimestamp($this->firstNumericValue([
				$record['last_seen'] ?? null,
				$record['seen.last'] ?? null,
				$record['LAST_SEEN'] ?? null,
				$record['LAST_SWITCHED'] ?? null
			])),
			'duration' => $this->formatDuration($this->firstNumericValue([
				$record['duration'] ?? null,
				$record['flow_duration'] ?? null,
				$record['DURATION'] ?? null
			])),
			'protocol' => $protocol,
			'score' => (int)$this->firstNumericValue([
				$record['score'] ?? null,
				$record['flow_score'] ?? null,
				$record['alert_score'] ?? null
			]),
			'client' => $this->joinEndpoint($srcIp, $srcPort),
			'server' => $this->joinEndpoint($dstIp, $dstPort),
			'throughput' => $this->formatBitsPerSecond($throughputBps),
			'total_bytes' => $this->formatBytes($totalBytes),
			'info' => $this->firstStringValue([
				$record['info'] ?? null,
				$record['application'] ?? null,
				$record['category'] ?? null,
				$record['flow_info'] ?? null
			])
		];
	}

	/**
	 * Apply search phrase to mapped rows.
	 *
	 * @param array $rows
	 * @param string $searchPhrase
	 * @return array
	 */
	private function filterBySearchPhrase(array $rows, string $searchPhrase): array
	{
		$terms = preg_split('/\s+/', trim($searchPhrase));
		if (!is_array($terms) || $terms === []) {
			return $rows;
		}

		return array_values(array_filter($rows, function ($row) use ($terms) {
			$haystack = implode(' ', [
				(string)($row['last_seen'] ?? ''),
				(string)($row['duration'] ?? ''),
				(string)($row['protocol'] ?? ''),
				(string)($row['score'] ?? ''),
				(string)($row['client'] ?? ''),
				(string)($row['server'] ?? ''),
				(string)($row['throughput'] ?? ''),
				(string)($row['total_bytes'] ?? ''),
				(string)($row['info'] ?? '')
			]);

			foreach ($terms as $term) {
				if ($term === '') {
					continue;
				}
				if (stripos($haystack, $term) === false) {
					return false;
				}
			}

			return true;
		}));
	}

	/**
	 * Apply sort map from DataTables.
	 *
	 * @param array $rows
	 * @param array $sort
	 * @return array
	 */
	private function applySort(array $rows, array $sort): array
	{
		if (empty($sort)) {
			return $rows;
		}

		$field = (string)array_key_first($sort);
		$direction = strtolower((string)$sort[$field]);
		$direction = $direction === 'desc' ? 'desc' : 'asc';

		usort($rows, function ($left, $right) use ($field, $direction) {
			$lv = (string)($left[$field] ?? '');
			$rv = (string)($right[$field] ?? '');
			$result = strnatcasecmp($lv, $rv);
			return $direction === 'desc' ? -$result : $result;
		});

		return $rows;
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
	 * Format Unix timestamp to readable date time.
	 *
	 * @param float $timestamp
	 * @return string
	 */
	private function formatTimestamp(float $timestamp): string
	{
		if ($timestamp <= 0) {
			return '';
		}

		if ($timestamp > 9999999999) {
			$timestamp = $timestamp / 1000;
		}

		return date('Y-m-d H:i:s', (int)$timestamp);
	}

	/**
	 * Format duration in seconds to compact string.
	 *
	 * @param float $seconds
	 * @return string
	 */
	private function formatDuration(float $seconds): string
	{
		if ($seconds <= 0) {
			return '0s';
		}

		$seconds = (int)round($seconds);
		$hours = (int)floor($seconds / 3600);
		$minutes = (int)floor(($seconds % 3600) / 60);
		$remainSeconds = $seconds % 60;

		if ($hours > 0) {
			return sprintf('%dh %dm %ds', $hours, $minutes, $remainSeconds);
		}

		if ($minutes > 0) {
			return sprintf('%dm %ds', $minutes, $remainSeconds);
		}

		return sprintf('%ds', $remainSeconds);
	}

	/**
	 * Format throughput in bps to human-readable string.
	 *
	 * @param float $bps
	 * @return string
	 */
	private function formatBitsPerSecond(float $bps): string
	{
		$units = ['bps', 'Kbps', 'Mbps', 'Gbps', 'Tbps'];
		$idx = 0;

		while ($bps >= 1000 && $idx < count($units) - 1) {
			$bps /= 1000;
			$idx++;
		}

		return sprintf('%.2f %s', $bps, $units[$idx]);
	}

	/**
	 * Format bytes to human-readable string.
	 *
	 * @param float $bytes
	 * @return string
	 */
	private function formatBytes(float $bytes): string
	{
		$units = ['B', 'KB', 'MB', 'GB', 'TB'];
		$idx = 0;

		while ($bytes >= 1024 && $idx < count($units) - 1) {
			$bytes /= 1024;
			$idx++;
		}

		return sprintf('%.2f %s', $bytes, $units[$idx]);
	}

	/**
	 * Build host:port endpoint string.
	 *
	 * @param string $host
	 * @param string $port
	 * @return string
	 */
	private function joinEndpoint(string $host, string $port): string
	{
		if ($host === '') {
			return '';
		}

		return $port !== '' ? sprintf('%s:%s', $host, $port) : $host;
	}
}
