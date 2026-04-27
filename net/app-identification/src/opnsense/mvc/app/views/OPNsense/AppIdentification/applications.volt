{#

Copyright (C) 2026 Deciso B.V.
All rights reserved.

#}

<script>
	$(document).ready(function () {
		'use strict';

		function showApiError(title, message, retryFn) {
			const buttons = [{
				label: '{{ lang._('Close') }}',
				action: function (dialog) {
					dialog.close();
				}
			}];

			if (typeof retryFn === 'function') {
				buttons.unshift({
					label: '{{ lang._('Retry') }}',
					cssClass: 'btn-primary',
					action: function (dialog) {
						dialog.close();
						retryFn();
					}
				});
			}

			BootstrapDialog.show({
				type: BootstrapDialog.TYPE_DANGER,
				title: title,
				message: esc(message || '{{ lang._('Unknown error') }}'),
				buttons: buttons
			});
		}

		function esc(value) {
			return $('<div/>').text(value === null || value === undefined ? '' : String(value)).html();
		}

		function bytesToSize(bytes) {
			let value = Number(bytes || 0);
			const units = ['B', 'KB', 'MB', 'GB', 'TB'];
			let idx = 0;
			if (value === 0) {
				return '0 B';
			}
			while (value >= 1024 && idx < units.length - 1) {
				value /= 1024;
				idx += 1;
			}
			return value.toFixed(2) + ' ' + units[idx];
		}

		function normalizeColor(color) {
			const value = String(color || '').replace(/cc$/i, '');
			return /^#[0-9a-f]{3,8}$/i.test(value) ? value : '#337ab7';
		}

		function renderL7StatsTable(data) {
			const tbody = $('#l7-stats-body');

			if (!data || !Array.isArray(data.labels) || data.labels.length === 0) {
				tbody.html('<tr><td colspan="4" class="text-center text-muted">{{ lang._('暂无应用流量数据') }}</td></tr>');
				return;
			}

			const labels = data.labels || [];
			const series = Array.isArray(data.series) ? data.series : [];
			const colors = Array.isArray(data.colors) ? data.colors : [];
			const total = series.reduce(function (sum, value) {
				return sum + Number(value || 0);
			}, 0);
			const maxVal = Number(series[0] || 1);
			let rows = '';

			labels.slice(0, 10).forEach(function (label, idx) {
				const bytes = Number(series[idx] || 0);
				const percent = total > 0 ? (bytes / total * 100).toFixed(1) : '0.0';
				const barW = maxVal > 0 ? (bytes / maxVal * 100).toFixed(1) : '0.0';
				const color = normalizeColor(colors[idx]);

				rows += '<tr>' +
					'<td>' + esc(label) + '</td>' +
					'<td>' + esc(bytesToSize(bytes)) + '</td>' +
					'<td>' + esc(percent + '%') + '</td>' +
					'<td style="width:200px;">' +
					'<div style="background:' + color + ';width:' + barW + '%;height:14px;border-radius:3px;min-width:2px;"></div>' +
					'</td>' +
					'</tr>';
			});

			tbody.html(rows);
		}

		function loadL7Stats() {
			ajaxCall('/api/appidentification/applications/getL7Stats', {}, function (response) {
				if (!response || response.status === 'error') {
					$('#l7-stats-body').html('<tr><td colspan="4" class="text-center text-muted">{{ lang._('暂无应用流量数据') }}</td></tr>');
					showApiError('{{ lang._('加载应用数据失败') }}', (response && response.message) ? response.message : '{{ lang._('Unable to load application data') }}', loadL7Stats);
					return;
				}

				const data = response.data || {};
				if (!data.labels) {
					renderL7StatsTable(data);
					return;
				}

				renderL7StatsTable(data);
			});
		}

		function renderHostRole(host) {
			const asClient = Number(host.as_client || 0);
			const asServer = Number(host.as_server || 0);
			if (asClient > 0 && asServer > 0) {
				return '<span class="label label-info">{{ lang._('双向') }}</span>';
			}
			if (asClient > 0) {
				return '<span class="label label-primary">{{ lang._('客户端') }}</span>';
			}
			return '<span class="label label-success">{{ lang._('服务器') }}</span>';
		}

		function loadTopHosts() {
			ajaxCall('/api/appidentification/applications/getTopHosts', {}, function (response) {
				if (!response || response.status !== 'ok' || !Array.isArray(response.data) || response.data.length === 0) {
					$('#top-hosts-body').html('<tr><td colspan="5" class="text-center text-muted">{{ lang._('暂无主机数据') }}</td></tr>');
					return;
				}

				let rows = '';
				response.data.forEach(function (host) {
					const ip = host.ip || '';
					const name = host.name && host.name !== ip ? host.name : '-';
					rows += '<tr>' +
						'<td><code>' + esc(ip) + '</code></td>' +
						'<td>' + esc(name) + '</td>' +
						'<td>' + esc(host.flows || 0) + '</td>' +
						'<td>' + esc(host.bytes_fmt || bytesToSize(host.bytes || 0)) + '</td>' +
						'<td>' + renderHostRole(host) + '</td>' +
						'</tr>';
				});

				$('#top-hosts-body').html(rows);
			});
		}

		function loadRules() {
			$('#grid-custom-rules').bootgrid('reload');
		}

		$('#grid-custom-rules').UIBootgrid({
			search: '/api/appidentification/rule/searchRules',
			get: '/api/appidentification/rule/getRule/',
			set: '/api/appidentification/rule/setRule/',
			add: '/api/appidentification/rule/addRule/',
			del: '/api/appidentification/rule/delRule/',
			toggle: '/api/appidentification/rule/toggleRule/',
			options: {
				selection: false,
				multiSelect: false
			}
		}).on('loaded.rs.jquery.bootgrid', function () {
			loadL7Stats();
			loadTopHosts();
		});

		$('#reload-app-data').on('click', function () {
			loadL7Stats();
			loadTopHosts();
			loadRules();
		});

		loadL7Stats();
		loadTopHosts();
		loadRules();
		setInterval(function () {
			loadL7Stats();
			loadTopHosts();
		}, 30000);

		$(document).ajaxError(function (event, xhr, settings) {
			if (settings && settings.url && settings.url.indexOf('/api/appidentification/') === 0) {
				const msg = xhr.responseJSON ? xhr.responseJSON.message : '{{ lang._('网络请求失败') }}';
				showApiError('{{ lang._('加载失败') }}', msg);
			}
		});
	});
</script>

<div class="content-box">
	<div class="row">
		<div class="col-md-12">
			<h4>{{ lang._('Top 10 应用流量分布') }}</h4>
			<table class="table table-striped table-condensed">
				<thead>
				<tr>
					<th>{{ lang._('应用名称') }}</th>
					<th>{{ lang._('总流量') }}</th>
					<th>{{ lang._('占比') }}</th>
					<th>{{ lang._('流量条') }}</th>
				</tr>
				</thead>
				<tbody id="l7-stats-body">
				<tr>
					<td colspan="4" class="text-center text-muted">{{ lang._('加载中...') }}</td>
				</tr>
				</tbody>
			</table>
		</div>
	</div>

	<hr/>

	<div class="row">
		<div class="col-md-12">
			<div class="pull-right" style="margin-bottom: 8px;">
				<button id="reload-app-data" type="button" class="btn btn-default btn-xs">
					<span class="fa fa-refresh"></span> {{ lang._('Refresh') }}
				</button>
			</div>
			<h4>{{ lang._('Top 10 主机流量排行') }}</h4>
			<table class="table table-condensed table-hover table-striped table-responsive">
				<thead>
				<tr>
					<th>{{ lang._('IP 地址') }}</th>
					<th>{{ lang._('主机名') }}</th>
					<th>{{ lang._('活跃流') }}</th>
					<th>{{ lang._('总流量') }}</th>
					<th>{{ lang._('角色') }}</th>
				</tr>
				</thead>
				<tbody id="top-hosts-body">
				<tr>
					<td colspan="5" class="text-center text-muted">{{ lang._('加载中...') }}</td>
				</tr>
				</tbody>
			</table>
		</div>
	</div>

	<hr/>

	<div class="row">
		<div class="col-md-12">
			<h3>{{ lang._('自定义规则') }}</h3>
			<table id="grid-custom-rules" class="table table-condensed table-hover table-striped table-responsive" data-editDialog="DialogRule">
				<thead>
				<tr>
					<th data-column-id="enabled" data-width="6em" data-type="string" data-formatter="rowtoggle">{{ lang._('启用') }}</th>
					<th data-column-id="description" data-type="string">{{ lang._('描述') }}</th>
					<th data-column-id="match_type" data-type="string">{{ lang._('匹配类型') }}</th>
					<th data-column-id="match_value" data-type="string">{{ lang._('匹配值') }}</th>
					<th data-column-id="app_label" data-type="string">{{ lang._('应用标签') }}</th>
					<th data-column-id="uuid" data-type="string" data-identifier="true" data-visible="false">{{ lang._('ID') }}</th>
					<th data-column-id="commands" data-width="7em" data-formatter="commands" data-sortable="false">{{ lang._('操作') }}</th>
				</tr>
				</thead>
				<tbody></tbody>
				<tfoot>
				<tr>
					<td></td>
					<td>
						<button data-action="add" type="button" class="btn btn-xs btn-default">
							<span class="fa fa-plus"></span>
						</button>
					</td>
				</tr>
				</tfoot>
			</table>
		</div>
	</div>
</div>

{{ partial("layout_partials/base_dialog",['fields':formDialogRule,'id':'DialogRule','label':lang._('Edit Custom Rule')]) }}
