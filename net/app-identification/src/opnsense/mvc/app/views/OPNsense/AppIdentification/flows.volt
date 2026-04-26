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
	z-index: 9999 !important;
}
.flow-dropdown-menu-detached {
	display: block !important;
	position: absolute !important;
	z-index: 9999 !important;
}
</style>

<script>
	$(document).ready(function () {
		'use strict';

		let autoRefreshTimer = null;

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
				const dropdown = $(this);
				const menu = dropdown.data('detached-menu');
				const placeholder = dropdown.data('menu-placeholder');

				if (menu && menu.length > 0 && placeholder && placeholder.length > 0) {
					menu.removeClass('flow-dropdown-menu-detached').removeAttr('style');
					menu.removeData('owning-dropdown');
					placeholder.replaceWith(menu);
				}

				dropdown.removeData('detached-menu');
				dropdown.removeData('menu-placeholder');
			});
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

			ajaxCall('/api/appidentification/flows/getFlowDetail', {flow_key: flowKey}, function (data) {
				if (!data || data.status === 'error') {
					const backendMessage = (data && data.message) ? data.message : "{{ lang._('Unable to retrieve flow details') }}";
					const userMessage = backendMessage.indexOf('expired') !== -1 ? "{{ lang._('流已过期') }}" : backendMessage;
					showApiError("{{ lang._('获取流详情失败') }}", userMessage);
					return;
				}

				const detailText = JSON.stringify(data.detail || data, null, 2);
				BootstrapDialog.show({
					type: BootstrapDialog.TYPE_INFO,
					title: "{{ lang._('Flow Detail') }}",
					message: '<pre style="max-height:420px; overflow:auto;">' + bootstrapSafe(detailText) + '</pre>',
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
						buttons += '<div class="dropdown">';
						buttons += '<button class="btn btn-default btn-xs dropdown-toggle" type="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">';
						buttons += '<span class="fa fa-navicon"></span> <span class="caret"></span>';
						buttons += '</button>';
						buttons += '<ul class="dropdown-menu dropdown-menu-right pull-right" role="menu">';
						if (flowKey !== '') {
							buttons += '<li><a href="#" class="flow-info-btn" data-action="detail" data-flow-key="' + flowKey + '"><span class="fa fa-info-circle"></span> {{ lang._("信息") }}</a></li>';
							buttons += '<li><a href="#" class="flow-chart-btn" data-action="chart" data-flow-key="' + flowKey + '"><span class="fa fa-bar-chart"></span> {{ lang._("图表") }}</a></li>';
						} else {
							buttons += '<li><a href="#" data-action="expired"><span class="fa fa-clock-o"></span> {{ lang._("流已过期") }}</a></li>';
						}
						buttons += '</ul>';
						buttons += '</div>';
						return buttons;
					},
					flow_path: function (column, row) {
						return '<span>' + bootstrapSafe(row.client || '') + '</span> <span class="fa fa-exchange"></span> <span>' + bootstrapSafe(row.server || '') + '</span>';
					}
				}
			}
		}).on('loaded.rs.jquery.bootgrid', function () {
			$(this).closest('.table-responsive').css('overflow', 'visible');
			$(this).closest('.bootgrid-table').css('overflow', 'visible');
			installDetachedFlowDropdowns();

			gridFlows.find('a[data-action=detail]').off('click').on('click', function (event) {
				event.preventDefault();
				const owner = $(this).closest('.dropdown-menu').data('owning-dropdown');
				if (owner && owner.length > 0) {
					owner.find('.dropdown-toggle').dropdown('toggle');
				}
				showFlowDetail($(this).data('flow-key'));
			});

			gridFlows.find('a[data-action=chart]').off('click').on('click', function (event) {
				event.preventDefault();
				const flowKey = $(this).data('flow-key');
				const owner = $(this).closest('.dropdown-menu').data('owning-dropdown');
				if (owner && owner.length > 0) {
					owner.find('.dropdown-toggle').dropdown('toggle');
				}
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
				const owner = $(this).closest('.dropdown-menu').data('owning-dropdown');
				if (owner && owner.length > 0) {
					owner.find('.dropdown-toggle').dropdown('toggle');
				}
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
					<th data-column-id="protocol" data-type="string">{{ lang._('协议') }}</th>
					<th data-column-id="score" data-type="numeric">{{ lang._('分数') }}</th>
					<th data-column-id="flow_path" data-formatter="flow_path" data-sortable="false">{{ lang._('流（客户端→服务器）') }}</th>
					<th data-column-id="throughput" data-type="string">{{ lang._('实际值') }}</th>
					<th data-column-id="total_bytes" data-type="string">{{ lang._('总字节数') }}</th>
					<th data-column-id="info" data-type="string">{{ lang._('信息') }}</th>
					<th data-column-id="client" data-visible="false">client</th>
					<th data-column-id="server" data-visible="false">server</th>
				</tr>
				</thead>
				<tbody></tbody>
			</table>
		</div>
	</div>
</div>
