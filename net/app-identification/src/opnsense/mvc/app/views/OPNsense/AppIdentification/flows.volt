{#

Copyright (C) 2026 Deciso B.V.
All rights reserved.

#}

<style>
/* 修复操作列下拉菜单被表格裁切的问题 */
.bootgrid-table {
	overflow: visible !important;
}
.bootgrid-table td {
	overflow: visible !important;
}
.table-responsive {
	overflow: visible !important;
}
#flow_filters,
#flow_filters .content-box,
#flow_filters .bootgrid-header,
#flow_filters .bootgrid-footer {
	overflow: visible !important;
}
/* 确保下拉菜单始终在最顶层 */
.dropdown-menu {
	z-index: 1035 !important;
}
.flow-dropdown-menu-detached {
	display: block !important;
	position: absolute !important;
	z-index: 1035 !important;
}
.flow-actions-dropdown {
	display: inline-block;
}
.flow-actions-menu,
.flow-dropdown-menu-detached.flow-actions-menu {
	float: none !important;
	min-width: 116px !important;
	width: auto !important;
	max-width: 150px !important;
	padding: 4px 0 !important;
	font-size: 12px;
	line-height: 1.4;
	border-radius: 4px;
	box-shadow: 0 2px 8px rgba(0, 0, 0, 0.18);
}
.flow-actions-menu > li > a {
	padding: 5px 12px !important;
	white-space: nowrap;
}
.flow-actions-menu > li.disabled > a,
.flow-actions-menu > li.disabled > a:hover,
.flow-actions-menu > li.disabled > a:focus {
	color: #999;
	cursor: not-allowed;
	background: transparent;
}
.flow-detail-dialog .modal-dialog {
	width: calc(100vw - 80px);
	max-width: 1280px;
}
.flow-detail-dialog .modal-body {
	max-height: calc(100vh - 170px);
	overflow: auto;
	padding: 0;
}
.flow-detail-title {
	font-weight: 600;
}
.flow-detail-wrap {
	padding: 8px 10px 12px;
}
.flow-detail-table {
	width: 100%;
	border-collapse: collapse;
	table-layout: fixed;
}
.flow-detail-table th,
.flow-detail-table td {
	border: 1px solid #ddd;
	padding: 8px;
	vertical-align: top;
	word-break: break-word;
}
.flow-detail-table th {
	width: 210px;
	background: #f1f1f1;
	color: #111;
}
.flow-detail-table td {
	background: #fff;
}
.flow-detail-table tr:nth-child(even) td {
	background: #f7f7f7;
}
.flow-detail-peer {
	color: #06f;
}
.flow-detail-badge {
	display: inline-block;
	min-width: 18px;
	padding: 1px 5px;
	margin-left: 4px;
	border-radius: 3px;
	background: #159957;
	color: #fff;
	font-size: 11px;
	text-align: center;
}
.flow-detail-bar {
	display: flex;
	height: 14px;
	margin-top: 6px;
	overflow: hidden;
	border-radius: 4px;
	background: #e5e5e5;
}
.flow-detail-bar span {
	color: #fff;
	font-size: 10px;
	line-height: 14px;
	text-align: center;
	white-space: nowrap;
}
.flow-detail-bar-client {
	background: #f0ad00;
}
.flow-detail-bar-server {
	background: #159957;
}
</style>

<script>
	$(document).ready(function () {
		'use strict';

		let autoRefreshTimer = null;
		let customApplicationRules = [];

		function showApiError(title, message, retryFn) {
			const buttons = [{
				label: "{{ lang._('Close') }}",
				action: function (dialog) {
					dialog.close();
				}
			}];

			if (typeof retryFn === 'function') {
				buttons.unshift({
					label: "{{ lang._('Retry') }}",
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
				message: bootstrapSafe(message || "{{ lang._('Unknown error') }}"),
				buttons: buttons
			});
		}

		function readFilters() {
			return {
				host: $('#flow_filter_host').val() || '',
				protocol: $('#flow_filter_protocol').val() || '',
				l7_proto: $('#flow_filter_application').val() || '',
				status: $('#flow_filter_status').val() || '',
				traffic_type: $('#flow_filter_traffic_type').val() || '',
				host_pool: $('#flow_filter_host_pool').val() || '',
				network: $('#flow_filter_network').val() || ''
			};
		}

		function setAutoRefresh(enabled) {
			if (autoRefreshTimer !== null) {
				clearInterval(autoRefreshTimer);
				autoRefreshTimer = null;
			}

			if (enabled) {
				autoRefreshTimer = setInterval(function () {
					$('#grid-flows').bootgrid('reload');
				}, 5000);
			}
		}

		function bootstrapSafe(value) {
			return $('<div/>').text(value === null || value === undefined ? '' : String(value)).html();
		}

		function humanBytes(bytes) {
			let value = Number(bytes || 0);
			const units = ['B', 'KB', 'MB', 'GB', 'TB'];
			let idx = 0;
			while (value >= 1024 && idx < units.length - 1) {
				value /= 1024;
				idx += 1;
			}
			return value.toFixed(idx === 0 ? 0 : 2) + ' ' + units[idx];
		}

		function humanDuration(seconds) {
			let value = Number(seconds || 0);
			if (value < 1) {
				return '< 1 sec';
			}
			value = Math.round(value);
			const hours = Math.floor(value / 3600);
			const minutes = Math.floor((value % 3600) / 60);
			const remain = value % 60;
			if (hours > 0) {
				return hours + 'h ' + minutes + 'm ' + remain + 's';
			}
			if (minutes > 0) {
				return minutes + 'm ' + remain + 's';
			}
			return remain + ' sec';
		}

		function humanTime(timestamp) {
			const value = Number(timestamp || 0);
			if (value <= 0) {
				return '';
			}
			return new Date(value * 1000).toLocaleString();
		}

		function loadCustomApplicationRules() {
			ajaxCall('/api/appidentification/rule/list', {}, function (data) {
				customApplicationRules = data && Array.isArray(data.rules) ? data.rules : [];
				if ($('#grid-flows').data('bootgrid')) {
					$('#grid-flows').bootgrid('reload');
				}
			});
		}

		function ipv4ToNumber(ip) {
			const parts = String(ip || '').split('.');
			if (parts.length !== 4) {
				return null;
			}

			let value = 0;
			for (let idx = 0; idx < parts.length; idx++) {
				if (!/^\d+$/.test(parts[idx])) {
					return null;
				}
				const octet = Number(parts[idx]);
				if (octet < 0 || octet > 255) {
					return null;
				}
				value = (value * 256) + octet;
			}

			return value >>> 0;
		}

		function ipInCidr(ip, cidr) {
			const bits = String(cidr || '').split('/');
			if (bits.length !== 2 || !/^\d+$/.test(bits[1])) {
				return false;
			}

			const ipValue = ipv4ToNumber(ip);
			const networkValue = ipv4ToNumber(bits[0]);
			const prefix = Number(bits[1]);
			if (ipValue === null || networkValue === null || prefix < 0 || prefix > 32) {
				return false;
			}

			const mask = prefix === 0 ? 0 : (0xffffffff << (32 - prefix)) >>> 0;
			return (ipValue & mask) === (networkValue & mask);
		}

		function matchCustomRule(row) {
			const serverName = String(row.server_name || '').toLowerCase();
			const serverIp = String(row.server_ip || '');
			const clientIp = String(row.client_ip || '');
			const serverPort = String(row.server_port || '');

			for (let idx = 0; idx < customApplicationRules.length; idx++) {
				const rule = customApplicationRules[idx] || {};
				const type = String(rule.match_type || '');
				const value = String(rule.match_value || '').trim();
				if (value === '') {
					continue;
				}

				if (type === 'domain' && serverName.indexOf(value.toLowerCase()) !== -1) {
					return rule;
				}
				if (type === 'ip' && (serverIp === value || clientIp === value)) {
					return rule;
				}
				if (type === 'cidr' && (ipInCidr(serverIp, value) || ipInCidr(clientIp, value))) {
					return rule;
				}
				if (type === 'port' && serverPort === value) {
					return rule;
				}
			}

			return null;
		}

		function renderProtocol(row) {
			const original = row.l7_proto || row.info || row.protocol || '';
			const rule = matchCustomRule(row);
			if (!rule) {
				return bootstrapSafe(row.protocol || original || '-');
			}

			const l4 = row.l4_proto ? bootstrapSafe(row.l4_proto) + ':' : '';
			return l4 +
				'<span class="label label-primary" title="{{ lang._('底层协议') }}: ' + bootstrapSafe(original || '-') + '">' +
				bootstrapSafe(rule.app_label || '') +
				'</span> <small class="text-muted">' + bootstrapSafe(original || '-') + '</small>';
		}

		function endpointLabel(endpoint) {
			if (!endpoint || typeof endpoint !== 'object') {
				return '';
			}
			const name = endpoint.name || endpoint.ip || '';
			const port = endpoint.port ? ':' + endpoint.port : '';
			return bootstrapSafe(name + port);
		}

		function restoreDetachedFlowMenu(dropdown) {
			if (!dropdown || dropdown.length === 0) {
				return;
			}

			const menu = dropdown.data('detached-menu');
			const placeholder = dropdown.data('menu-placeholder');
			if (menu && menu.length > 0 && placeholder && placeholder.length > 0) {
				menu.removeClass('flow-dropdown-menu-detached').removeAttr('style');
				menu.removeData('owning-dropdown');
				placeholder.replaceWith(menu);
			}

			dropdown.removeClass('open');
			dropdown.removeData('detached-menu');
			dropdown.removeData('menu-placeholder');
		}

		function closeFlowActionMenu(link) {
			const owner = $(link).closest('.dropdown-menu').data('owning-dropdown');
			if (owner && owner.length > 0) {
				restoreDetachedFlowMenu(owner);
			}
		}

		function closeAllFlowActionMenus() {
			gridFlows.find('.dropdown.open').each(function () {
				restoreDetachedFlowMenu($(this));
			});
			$('body > .flow-dropdown-menu-detached').each(function () {
				const owner = $(this).data('owning-dropdown');
				if (owner && owner.length > 0) {
					restoreDetachedFlowMenu(owner);
				} else {
					$(this).remove();
				}
			});
		}

		function positionDetachedFlowMenu(dropdown) {
			const menu = dropdown.data('detached-menu');
			if (!menu || menu.length === 0) {
				return;
			}

			const button = dropdown.find('.dropdown-toggle');
			const offset = button.offset();
			const menuWidth = menu.outerWidth();
			const left = Math.max(8, offset.left + button.outerWidth() - menuWidth);

			menu.css({
				top: offset.top + button.outerHeight(),
				left: left
			});
		}

		function installDetachedFlowDropdowns() {
			gridFlows.off('show.bs.dropdown.flowmenu').on('show.bs.dropdown.flowmenu', '.dropdown', function () {
				const dropdown = $(this);
				const menu = dropdown.children('.dropdown-menu');
				const placeholder = $('<span class="flow-dropdown-placeholder" style="display:none;"></span>');

				dropdown.data('menu-placeholder', placeholder);
				dropdown.data('detached-menu', menu);
				menu.data('owning-dropdown', dropdown);
				menu.after(placeholder);
				menu.addClass('flow-dropdown-menu-detached').appendTo('body');
				positionDetachedFlowMenu(dropdown);
			});

			gridFlows.off('hidden.bs.dropdown.flowmenu').on('hidden.bs.dropdown.flowmenu', '.dropdown', function () {
				restoreDetachedFlowMenu($(this));
			});
		}

		function renderFlowDetail(data) {
			const detail = data.detail || {};
			const row = data.row || {};
			const client = detail.client || {};
			const server = detail.server || {};
			const protocol = detail.protocol || {};
			const thpt = detail.thpt || {};
			const breakdown = detail.breakdown || {};
			const clientPct = Math.max(0, Math.min(100, Number(breakdown.cli2srv || 0)));
			const serverPct = Math.max(0, Math.min(100, Number(breakdown.srv2cli || (100 - clientPct))));
			const totalBytes = Number(detail.bytes || row.bytes_raw || 0);
			const l4 = protocol.l4 || row.l4_proto || '';
			const l7 = protocol.l7 || row.l7_proto || row.info || '';
			const title = (endpointLabel(client) || row.client || '') + ' ⇄ ' + (endpointLabel(server) || row.server || '');
			const clientBytes = Math.round(totalBytes * clientPct / 100);
			const serverBytes = Math.max(0, totalBytes - clientBytes);

			let html = '';
			html += '<div class="flow-detail-wrap">';
			html += '<table class="flow-detail-table">';
			html += '<tbody>';
			html += '<tr><th>{{ lang._("流 Peers [客户端/服务器]") }}</th><td colspan="2"><span class="flow-detail-peer">' + title + '</span></td></tr>';
			html += '<tr><th>{{ lang._("协议 / 应用程序") }}</th><td colspan="2">' + bootstrapSafe(l4 || '-') + ' / <span class="flow-detail-peer">' + bootstrapSafe(l7 || '-') + '</span><span class="flow-detail-badge">DPI</span></td></tr>';
			html += '<tr><th>{{ lang._("首先/最后查看") }}</th><td>' + bootstrapSafe(humanTime(detail.first_seen)) + '</td><td>' + bootstrapSafe(humanTime(detail.last_seen)) + '</td></tr>';
			html += '<tr><th>Flow Duration</th><td colspan="2">' + bootstrapSafe(humanDuration(detail.duration)) + '</td></tr>';
			html += '<tr><th>{{ lang._("总流量") }}</th><td>{{ lang._("总计") }}: ' + bootstrapSafe(humanBytes(totalBytes)) + '</td><td>' + bootstrapSafe(Number(thpt.bps || 0).toFixed(2)) + ' bps</td></tr>';
			html += '<tr><th></th><td>{{ lang._("客户端") }} ➜ {{ lang._("服务器") }}: ' + bootstrapSafe(humanBytes(clientBytes)) + '</td><td>{{ lang._("服务器") }} ➜ {{ lang._("客户端") }}: ' + bootstrapSafe(humanBytes(serverBytes)) + '</td></tr>';
			html += '<tr><th></th><td colspan="2"><div class="flow-detail-bar">';
			html += '<span class="flow-detail-bar-client" style="width:' + clientPct + '%">' + bootstrapSafe(endpointLabel(client) || row.client || '') + '</span>';
			html += '<span class="flow-detail-bar-server" style="width:' + serverPct + '%">' + bootstrapSafe(endpointLabel(server) || row.server || '') + '</span>';
			html += '</div></td></tr>';
			html += '<tr><th>VLAN / Hash</th><td>' + bootstrapSafe(detail.vlan || 0) + '</td><td>' + bootstrapSafe(detail.hash_id || detail.key || row.flow_key || '') + '</td></tr>';
			html += '<tr><th>{{ lang._("吞吐量") }}</th><td colspan="2">' + bootstrapSafe(row.throughput || (Number(thpt.bps || 0).toFixed(2) + ' bps')) + ' / ' + bootstrapSafe(Number(thpt.pps || 0).toFixed(2)) + ' pps</td></tr>';
			html += '<tr><th>TCP Flags</th><td colspan="2">' + bootstrapSafe(detail.tcp_flags || '-') + '</td></tr>';
			html += '<tr><th>{{ lang._("客户端") }}</th><td colspan="2">' + endpointLabel(client) + ' | IP: ' + bootstrapSafe(client.ip || '') + ' | Port: ' + bootstrapSafe(client.port || '') + '</td></tr>';
			html += '<tr><th>{{ lang._("服务器") }}</th><td colspan="2">' + endpointLabel(server) + ' | IP: ' + bootstrapSafe(server.ip || '') + ' | Port: ' + bootstrapSafe(server.port || '') + '</td></tr>';
			html += '</tbody>';
			html += '</table>';
			html += '</div>';
			return {
				title: '<span class="flow-detail-title"><span class="fa fa-navicon"></span> {{ lang._("流") }}: ' + title + ' | {{ lang._("概述") }}</span>',
				body: html
			};
		}

		function loadApplicationOptions() {
			ajaxCall('/api/appidentification/applications/list', {}, function (data) {
				if (!data || data.status === 'error') {
					showApiError("{{ lang._('加载应用筛选失败') }}", (data && data.message) ? data.message : "{{ lang._('Unable to load application options') }}", loadApplicationOptions);
					return;
				}

				const select = $('#flow_filter_application');
				const current = select.val() || '';
				select.find('option:not([value=""])').remove();

				if (data && data.status === 'ok' && Array.isArray(data.rows)) {
					const known = {};
					data.rows.forEach(function (row) {
						const appName = (row.name || '').trim();
						if (appName !== '' && !known[appName]) {
							known[appName] = true;
							select.append('<option value="' + bootstrapSafe(appName) + '">' + bootstrapSafe(appName) + '</option>');
						}
					});
				}

				select.val(current);
				$('.selectpicker').selectpicker('refresh');
			});
		}

		function showFlowDetail(flowKey) {
			if (!flowKey) {
				showApiError("{{ lang._('获取流详情失败') }}", "{{ lang._('流已过期') }}");
				return;
			}

			closeAllFlowActionMenus();
			ajaxCall('/api/appidentification/flows/getFlowDetail', {flow_key: flowKey}, function (data) {
				if (!data || data.status === 'error') {
					const backendMessage = (data && data.message) ? data.message : "{{ lang._('Unable to retrieve flow details') }}";
					const userMessage = backendMessage.indexOf('expired') !== -1 ? "{{ lang._('流已过期') }}" : backendMessage;
					showApiError("{{ lang._('获取流详情失败') }}", userMessage);
					return;
				}

				const detailView = renderFlowDetail(data);
				BootstrapDialog.show({
					type: BootstrapDialog.TYPE_INFO,
					cssClass: 'flow-detail-dialog',
					title: detailView.title,
					message: detailView.body,
					buttons: [{
						label: "{{ lang._('Close') }}",
						action: function (dialog) {
							dialog.close();
						}
					}]
				});
			});
		}

		const gridFlows = $('#grid-flows').UIBootgrid({
			search: '/api/appidentification/flows/search',
			commands: {
				refresh: {
					footer: false,
					classname: 'fa fa-fw fa-refresh',
					title: "{{ lang._('Refresh') }}",
					method: function (event) {
						event.preventDefault();
						$('#grid-flows').bootgrid('reload');
					},
					sequence: 40
				}
			},
			options: {
				ajax: true,
				selection: false,
				rowSelect: false,
				multiSelect: false,
				keepSelection: false,
				rowCount: [10, 25, 50, 100],
				searchSettings: {
					delay: 300,
					characters: 1
				},
				requestHandler: function (request) {
					const filters = readFilters();
					request.host = filters.host;
					request.l7_proto = filters.l7_proto;
					request.traffic_type = filters.traffic_type;
					request.host_pool = filters.host_pool;
					request.network = filters.network;

					if (filters.protocol !== '') {
						request.searchPhrase = ((request.searchPhrase || '') + ' ' + filters.protocol).trim();
					}
					if (filters.status !== '') {
						request.searchPhrase = ((request.searchPhrase || '') + ' ' + filters.status).trim();
					}

					return request;
				},
				formatters: {
					commands: function (column, row) {
						const flowKey = bootstrapSafe(row.flow_key || '');
						let buttons = '';
						buttons += '<div class="dropdown flow-actions-dropdown">';
						buttons += '<button class="btn btn-default btn-xs dropdown-toggle" type="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">';
						buttons += '<span class="fa fa-navicon"></span> <span class="caret"></span>';
						buttons += '</button>';
						buttons += '<ul class="dropdown-menu flow-actions-menu" role="menu">';
						if (flowKey !== '') {
							buttons += '<li><a href="#" class="flow-info-btn" data-action="detail" data-flow-key="' + flowKey + '"><span class="fa fa-info-circle"></span> {{ lang._("信息") }}</a></li>';
							buttons += '<li class="disabled"><a href="#" class="flow-chart-btn" data-action="chart" data-flow-key="' + flowKey + '"><span class="fa fa-bar-chart"></span> {{ lang._("图表") }}</a></li>';
						} else {
							buttons += '<li><a href="#" data-action="expired"><span class="fa fa-clock-o"></span> {{ lang._("流已过期") }}</a></li>';
						}
						buttons += '</ul>';
						buttons += '</div>';
						return buttons;
					},
					flow_path: function (column, row) {
						return '<span>' + bootstrapSafe(row.client || '') + '</span> <span class="fa fa-exchange"></span> <span>' + bootstrapSafe(row.server || '') + '</span>';
					},
					protocol: function (column, row) {
						return renderProtocol(row);
					}
				}
			}
		}).on('loaded.rs.jquery.bootgrid', function () {
			$(this).closest('.table-responsive').css('overflow', 'visible');
			$(this).closest('.bootgrid-table').css('overflow', 'visible');
			installDetachedFlowDropdowns();

			gridFlows.find('a[data-action=detail]').off('click').on('click', function (event) {
				event.preventDefault();
				closeFlowActionMenu(this);
				showFlowDetail($(this).data('flow-key'));
			});

			gridFlows.find('a[data-action=chart]').off('click').on('click', function (event) {
				event.preventDefault();
				if ($(this).parent().hasClass('disabled')) {
					return;
				}
				const flowKey = $(this).data('flow-key');
				closeFlowActionMenu(this);
				BootstrapDialog.show({
					type: BootstrapDialog.TYPE_INFO,
					title: "{{ lang._('图表') }}",
					message: "{{ lang._('此流的图表视图将在后续版本提供。') }}<br/>" + bootstrapSafe(flowKey),
					buttons: [{
						label: "{{ lang._('Close') }}",
						action: function (dialog) {
							dialog.close();
						}
					}]
				});
			});

			gridFlows.find('a[data-action=expired]').off('click').on('click', function (event) {
				event.preventDefault();
				closeFlowActionMenu(this);
				showApiError("{{ lang._('获取流详情失败') }}", "{{ lang._('流已过期') }}");
			});
		});

		$(window).on('scroll.flowmenu resize.flowmenu', function () {
			gridFlows.find('.dropdown.open').each(function () {
				positionDetachedFlowMenu($(this));
			});
		});

		$('#flow_apply_filters').on('click', function () {
			$('#grid-flows').bootgrid('reload');
		});

		$('#flow_reset_filters').on('click', function () {
			$('#flow_filter_host').val('');
			$('#flow_filter_protocol').val('');
			$('#flow_filter_application').val('');
			$('#flow_filter_status').val('');
			$('#flow_filter_traffic_type').val('');
			$('#flow_filter_host_pool').val('');
			$('#flow_filter_network').val('');
			$('.selectpicker').selectpicker('refresh');
			$('#grid-flows').bootgrid('reload');
		});

		$('#flow_refresh').on('click', function () {
			$('#grid-flows').bootgrid('reload');
		});

		$('#flow_auto_refresh').on('change', function () {
			setAutoRefresh($(this).is(':checked'));
		});

		$('#flow_filters input').on('keypress', function (event) {
			if (event.which === 13) {
				event.preventDefault();
				$('#grid-flows').bootgrid('reload');
			}
		});

		$('#flow_filters select').on('change', function () {
			$('#grid-flows').bootgrid('reload');
		});

		loadCustomApplicationRules();
		loadApplicationOptions();
		$('.selectpicker').selectpicker('refresh');
		setAutoRefresh(true);

		$(document).ajaxError(function (event, xhr, settings) {
			if (settings && settings.url && settings.url.indexOf('/api/appidentification/') === 0) {
				const msg = xhr.responseJSON ? xhr.responseJSON.message : "{{ lang._('网络请求失败') }}";
				showApiError("{{ lang._('加载失败') }}", msg);
			}
		});
	});
</script>

<div class="content-box" id="flow_filters">
	<div class="row">
		<div class="col-md-12">
			<div class="form-inline" style="margin-bottom: 10px;">
				<div class="form-group" style="margin-right: 8px; margin-bottom: 6px;">
					<label for="flow_filter_host">{{ lang._('Host') }}</label>
					<input id="flow_filter_host" type="text" class="form-control" placeholder="{{ lang._('Host/IP') }}" style="width: 140px;"/>
				</div>
				<div class="form-group" style="margin-right: 8px; margin-bottom: 6px;">
					<label for="flow_filter_protocol">{{ lang._('Protocol') }}</label>
					<select id="flow_filter_protocol" class="selectpicker" data-width="120px">
						<option value="">{{ lang._('All') }}</option>
						<option value="TCP">TCP</option>
						<option value="UDP">UDP</option>
						<option value="ICMP">ICMP</option>
					</select>
				</div>
				<div class="form-group" style="margin-right: 8px; margin-bottom: 6px;">
					<label for="flow_filter_application">{{ lang._('Application') }}</label>
					<select id="flow_filter_application" class="selectpicker" data-live-search="true" data-width="160px">
						<option value="">{{ lang._('All') }}</option>
					</select>
				</div>
				<div class="form-group" style="margin-right: 8px; margin-bottom: 6px;">
					<label for="flow_filter_status">{{ lang._('Status') }}</label>
					<select id="flow_filter_status" class="selectpicker" data-width="120px">
						<option value="">{{ lang._('All') }}</option>
						<option value="OK">OK</option>
						<option value="ALERT">ALERT</option>
					</select>
				</div>
				<div class="form-group" style="margin-right: 8px; margin-bottom: 6px;">
					<label for="flow_filter_traffic_type">{{ lang._('Traffic Type') }}</label>
					<select id="flow_filter_traffic_type" class="selectpicker" data-width="130px">
						<option value="">{{ lang._('All') }}</option>
						<option value="local">{{ lang._('Local') }}</option>
						<option value="remote">{{ lang._('Remote') }}</option>
					</select>
				</div>
				<div class="form-group" style="margin-right: 8px; margin-bottom: 6px;">
					<label for="flow_filter_host_pool">{{ lang._('Host Pools') }}</label>
					<input id="flow_filter_host_pool" type="text" class="form-control" placeholder="Pool" style="width: 120px;"/>
				</div>
				<div class="form-group" style="margin-right: 8px; margin-bottom: 6px;">
					<label for="flow_filter_network">{{ lang._('Networks') }}</label>
					<input id="flow_filter_network" type="text" class="form-control" placeholder="Network" style="width: 120px;"/>
				</div>
				<div class="form-group" style="margin-right: 6px; margin-bottom: 6px;">
					<button id="flow_apply_filters" class="btn btn-primary" type="button">{{ lang._('Apply') }}</button>
				</div>
				<div class="form-group" style="margin-right: 6px; margin-bottom: 6px;">
					<button id="flow_reset_filters" class="btn btn-default" type="button">{{ lang._('Reset') }}</button>
				</div>
				<div class="form-group" style="margin-right: 6px; margin-bottom: 6px;">
					<button id="flow_refresh" class="btn btn-default" type="button" title="{{ lang._('Refresh') }}">
						<span class="fa fa-refresh"></span>
					</button>
				</div>
				<div class="form-group" style="margin-bottom: 6px;">
					<label class="btn btn-default" style="font-weight: normal; margin-bottom: 0;">
						<input type="checkbox" id="flow_auto_refresh" checked="checked"/> {{ lang._('Auto refresh') }}
					</label>
				</div>
			</div>
		</div>
	</div>

	<div class="row">
		<div class="col-md-12">
			<table id="grid-flows" class="table table-condensed table-hover table-striped table-responsive">
				<thead>
				<tr>
					<th data-column-id="commands" data-formatter="commands" data-sortable="false" data-width="70">{{ lang._('操作') }}</th>
					<th data-column-id="last_seen" data-type="string">{{ lang._('最后见到') }}</th>
					<th data-column-id="duration" data-type="string">{{ lang._('持续时间') }}</th>
					<th data-column-id="protocol" data-formatter="protocol" data-type="string">{{ lang._('协议') }}</th>
					<th data-column-id="score" data-type="numeric">{{ lang._('分数') }}</th>
					<th data-column-id="flow_path" data-formatter="flow_path" data-sortable="false">{{ lang._('流（客户端→服务器）') }}</th>
					<th data-column-id="throughput" data-type="string">{{ lang._('实际值') }}</th>
					<th data-column-id="total_bytes" data-type="string">{{ lang._('总字节数') }}</th>
					<th data-column-id="info" data-type="string">{{ lang._('信息') }}</th>
					<th data-column-id="client" data-visible="false">client</th>
					<th data-column-id="server" data-visible="false">server</th>
					<th data-column-id="client_ip" data-visible="false">client_ip</th>
					<th data-column-id="server_ip" data-visible="false">server_ip</th>
					<th data-column-id="server_name" data-visible="false">server_name</th>
					<th data-column-id="server_port" data-visible="false">server_port</th>
				</tr>
				</thead>
				<tbody></tbody>
			</table>
		</div>
	</div>
</div>
