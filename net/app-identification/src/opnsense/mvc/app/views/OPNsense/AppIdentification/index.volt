{#

Copyright (C) 2026 Deciso B.V.
All rights reserved.

#}

<ul class="nav nav-tabs" data-tabs="tabs" id="maintabs">
	<li class="active"><a data-toggle="tab" href="#general">{{ lang._('General') }}</a></li>
	<li><a data-toggle="tab" href="#rules">{{ lang._('应用规则') }}</a></li>
</ul>

<div class="tab-content content-box tab-content">
	<div id="general" class="tab-pane fade in active">
		<div class="content-box" style="padding-bottom: 1.5em;">
			{{ partial("layout_partials/base_form",['fields':generalForm,'id':'frm_general_settings'])}}
			<div class="col-md-12">
				<hr />
				<button class="btn btn-primary" id="saveAct" type="button"><b>{{ lang._('Save') }}</b> <i id="saveAct_progress"></i></button>
				<button class="btn btn-default" id="testAct" type="button"><span class="fa fa-plug"></span> {{ lang._('Test Connection') }} <i id="testAct_progress"></i></button>
				<button class="btn btn-default" id="restartAct" type="button"><span class="fa fa-refresh"></span> {{ lang._('Restart ntopng') }} <i id="restartAct_progress"></i></button>
				<button class="btn btn-default" id="openNtopngAct" type="button"><span class="fa fa-external-link"></span> {{ lang._('在 ntopng 中查看') }}</button>
				<button class="btn btn-default" id="ntopngGuideAct" type="button" title="{{ lang._('配置指引') }}"><span class="fa fa-info-circle text-info"></span> {{ lang._('配置指引') }}</button>
			</div>
		</div>
	</div>
	<div id="rules" class="tab-pane fade">
		<div class="content-box" style="padding-bottom: 1.5em;">
			<div class="row" style="margin-bottom: 10px;">
				<div class="col-md-6">
					<button id="rules-import-open" type="button" class="btn btn-primary btn-sm">
						<span class="fa fa-upload"></span> {{ lang._('批量导入') }}
					</button>
					<div class="btn-group">
						<button type="button" class="btn btn-default btn-sm dropdown-toggle" data-toggle="dropdown">
							<span class="fa fa-download"></span> {{ lang._('下载模板') }} <span class="caret"></span>
						</button>
						<ul class="dropdown-menu">
							<li><a href="/api/appidentification/rule/template/csv">{{ lang._('CSV 模板') }}</a></li>
							<li><a href="/api/appidentification/rule/template/json">{{ lang._('JSON 模板') }}</a></li>
						</ul>
					</div>
				</div>
				<div class="col-md-6 text-right">
					<span id="rules-count" class="text-muted">{{ lang._('加载中...') }}</span>
				</div>
			</div>
			<table id="grid-custom-rules" class="table table-condensed table-hover table-striped table-responsive" data-editDialog="DialogRule">
				<thead>
				<tr>
					<th data-column-id="enabled" data-width="6em" data-type="string" data-formatter="rowtoggle">{{ lang._('启用') }}</th>
					<th data-column-id="description" data-type="string">{{ lang._('描述') }}</th>
					<th data-column-id="match_type" data-type="string">{{ lang._('匹配类型') }}</th>
					<th data-column-id="match_value" data-type="string" data-formatter="matchvalues">{{ lang._('匹配值') }}</th>
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

<div class="modal fade" id="ntopngGuideModal" tabindex="-1" role="dialog" aria-labelledby="ntopngGuideModalLabel">
	<div class="modal-dialog modal-lg" role="document">
		<div class="modal-content">
			<div class="modal-header">
				<button type="button" class="close" data-dismiss="modal" aria-label="{{ lang._('Close') }}"><span aria-hidden="true">&times;</span></button>
				<h4 class="modal-title" id="ntopngGuideModalLabel">{{ lang._('ntopng 初次配置指引') }}</h4>
			</div>
			<div class="modal-body">
				<ol>
					<li>
						<p><strong>{{ lang._('第一步：修改默认密码') }}</strong></p>
						<p>{{ lang._('打开 ntopng 页面（可点击上方“在 ntopng 中查看”按钮），使用默认账号 admin / admin 登录，进入') }} <code>Settings &rarr; Users &rarr; admin</code>{{ lang._('，修改密码。') }}</p>
					</li>
					<li>
						<p><strong>{{ lang._('第二步：生成 API Token') }}</strong></p>
						<p>{{ lang._('在 ntopng 页面中进入') }} <code>Settings &rarr; API Tokens</code>{{ lang._('，点击“Generate Token”，复制生成的 Token 字符串。') }}</p>
					</li>
					<li>
						<p><strong>{{ lang._('第三步：填写 Auth Token') }}</strong></p>
						<p>{{ lang._('将复制的 Token 粘贴到本页面“Auth Token”字段中，点击“保存”，然后点击“测试连接”验证配置是否正确。') }}</p>
					</li>
				</ol>
			</div>
			<div class="modal-footer">
				<button type="button" class="btn btn-default" data-dismiss="modal">{{ lang._('我知道了') }}</button>
				<button type="button" class="btn btn-primary" id="ntopngGuideOpenAct"><span class="fa fa-external-link"></span> {{ lang._('直接打开 ntopng') }}</button>
			</div>
		</div>
	</div>
</div>

<script>
$(document).ready(function() {
	function esc(value) {
		return $('<div/>').text(value === null || value === undefined ? '' : String(value)).html();
	}

	function splitMatchValues(rawValue) {
		if (Array.isArray(rawValue)) {
			return rawValue.map(function (value) {
				return $.trim(String(value || ''));
			}).filter(function (value) {
				return value !== '';
			});
		}

		return String(rawValue || '').split(/\r?\n/).map(function (value) {
			return $.trim(String(value || ''));
		}).filter(function (value) {
			return value !== '';
		});
	}

	function normalizeImportMatchValue(rawValue) {
		if (Array.isArray(rawValue)) {
			return splitMatchValues(rawValue).join('\n');
		}
		const value = String(rawValue || '').replace(/\r\n/g, '\n').replace(/\r/g, '\n');
		if (value.indexOf('|') !== -1) {
			return value.split('|').map(function (item) {
				return $.trim(item);
			}).filter(function (item) {
				return item !== '';
			}).join('\n');
		}
		return splitMatchValues(value).join('\n');
	}

	function validateMatchValueLines(matchType, rawValue) {
		const errors = [];
		const lines = splitMatchValues(rawValue);
		if (lines.length === 0) {
			errors.push({line: 0, message: '{{ lang._('至少填写一个匹配值') }}'});
			return errors;
		}

		for (let idx = 0; idx < lines.length; idx++) {
			const lineNo = idx + 1;
			const value = lines[idx];
			if (matchType === 'domain') {
				if (/\s/.test(value)) {
					errors.push({line: lineNo, message: '{{ lang._('Domain 行不能包含空格') }}'});
				}
				continue;
			}
			if (matchType === 'ip') {
				const isIp = /^\d{1,3}(?:\.\d{1,3}){3}$/.test(value) || /^[0-9a-fA-F:]+$/.test(value);
				if (!isIp) {
					errors.push({line: lineNo, message: '{{ lang._('IP 行格式不正确') }}'});
				}
				continue;
			}
			if (matchType === 'cidr') {
				if (!/^([^\/\s]+)\/(\d{1,3})$/.test(value)) {
					errors.push({line: lineNo, message: '{{ lang._('CIDR 行格式不正确') }}'});
				}
				continue;
			}
			if (matchType === 'port') {
				if (!/^\d+$/.test(value) || Number(value) < 1 || Number(value) > 65535) {
					errors.push({line: lineNo, message: '{{ lang._('Port 行必须是 1-65535') }}'});
				}
				continue;
			}
			if (matchType === 'protocol' && value === '') {
				errors.push({line: lineNo, message: '{{ lang._('Protocol 行不能为空') }}'});
			}
		}

		return errors;
	}

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

	function getNtopngBaseUrl() {
		const host = $.trim(window.location.hostname || '');
		if (host === '') {
			return '';
		}
		const port = $.trim($('#general\\.http_port').val() || $('#general\\.rest_port').val() || '3000');
		let url = 'http://' + host;

		if (port !== '') {
			url += ':' + port;
		}

		return url;
	}

	function openNtopngConsole() {
		const url = getNtopngBaseUrl();
		if (url === '') {
			BootstrapDialog.show({
				type: BootstrapDialog.TYPE_WARNING,
				title: '{{ lang._('提示') }}',
				message: esc('{{ lang._('请先填写 ntopng 主机地址') }}'),
				buttons: [{label: '{{ lang._('Close') }}', action: function(d){ d.close(); }}]
			});
			return false;
		}
		window.open(url, '_blank', 'noopener');
		return true;
	}

	function toggleAuthFields() {
		$('#general\\.auth_username').closest('.form-group').show();
		$('#general\\.auth_password').closest('.form-group').show();
		$('#general\\.auth_token').closest('.form-group').show();
		$('#general\\.auth_cookie').closest('.form-group').hide();
	}

	const dataGetMap = {'frm_general_settings': '/api/appidentification/general/get'};
	mapDataToFormUI(dataGetMap).done(function() {
		formatTokenizersUI();
		$('.selectpicker').selectpicker('refresh');
		toggleAuthFields();
	});

	$('#general\\.auth_mode').on('change', function () {
		toggleAuthFields();
	});

	$('#saveAct').click(function() {
		$('#saveAct_progress').addClass('fa fa-spinner fa-pulse');
		saveFormToEndpoint('/api/appidentification/general/set', 'frm_general_settings', function() {
			$('#saveAct_progress').removeClass('fa fa-spinner fa-pulse');
		}, true, function() {
			$('#saveAct_progress').removeClass('fa fa-spinner fa-pulse');
			showApiError('{{ lang._('保存配置失败') }}', '{{ lang._('Unable to save ntopng configuration') }}');
		});
	});

	$('#restartAct').click(function() {
		$('#restartAct_progress').addClass('fa fa-spinner fa-pulse');
		ajaxCall('/api/appidentification/general/ntopngrestart', {}, function() {
			$('#restartAct_progress').removeClass('fa fa-spinner fa-pulse');
		}, function(data) {
			$('#restartAct_progress').removeClass('fa fa-spinner fa-pulse');
			if (!data || data.status === 'error') {
				showApiError('{{ lang._('重启 ntopng 失败') }}', (data && data.message) ? data.message : '{{ lang._('Unable to restart ntopng') }}', function () {
					$('#restartAct').click();
				});
			}
		});
	});

	$('#testAct').click(function() {
		$('#testAct_progress').addClass('fa fa-spinner fa-pulse');
		$.ajax({
			url: '/api/appidentification/general/status',
			method: 'GET',
			dataType: 'json',
			success: function(data) {
				$('#testAct_progress').removeClass('fa fa-spinner fa-pulse');
				if (!data || data.status === 'error') {
					showApiError('{{ lang._('连接测试失败') }}', (data && data.message) ? data.message : '{{ lang._('Unable to connect to ntopng') }}');
					return;
				}
				BootstrapDialog.show({
					type: BootstrapDialog.TYPE_PRIMARY,
					title: '{{ lang._('Success') }}',
					message: $('<div/>').text(data.message || '{{ lang._('连接成功') }}').html(),
					buttons: [{label: '{{ lang._('Close') }}', action: function(d){ d.close(); }}]
				});
			},
			error: function(xhr) {
				$('#testAct_progress').removeClass('fa fa-spinner fa-pulse');
				const msg = xhr.responseJSON ? xhr.responseJSON.message : '{{ lang._('网络请求失败') }}';
				showApiError('{{ lang._('连接测试失败') }}', msg);
			}
		});
	});

	$('#openNtopngAct').on('click', function () {
		openNtopngConsole();
	});

	$('#ntopngGuideAct').on('click', function () {
		$('#ntopngGuideModal').modal('show');
	});

	$('#ntopngGuideOpenAct').on('click', function () {
		openNtopngConsole();
	});

	function activateHashTab() {
		const hash = window.location.hash || '#general';
		const tab = $('#maintabs a[href="' + hash + '"]');
		if (tab.length > 0) {
			tab.tab('show');
		}
	}

	$('#maintabs a[data-toggle="tab"]').on('shown.bs.tab', function (event) {
		window.location.hash = $(event.target).attr('href');
	});
	activateHashTab();

	function refreshRuleStats() {
		ajaxCall('/api/appidentification/rule/stats', {}, function (data) {
			if (!data || data.status === 'error') {
				$('#rules-count').text('{{ lang._('规则数量加载失败') }}');
				return;
			}
			let text = '{{ lang._('共') }} ' + esc(data.total || 0) + ' {{ lang._('条规则，启用') }} ' + esc(data.enabled || 0) + ' {{ lang._('条') }}';
			if (Number(data.total || 0) > 1000) {
				text += ' ({{ lang._('数量较多，页面可能变慢') }})';
			}
			$('#rules-count').html(text);
		});
	}

	function reloadRules() {
		$('#grid-custom-rules').bootgrid('reload');
		refreshRuleStats();
	}

	function bindRulesHeaderExportButton() {
		const exportBtn = $('#grid-custom-rules-reset');
		if (!exportBtn.length || exportBtn.data('export-bound') === true) {
			return;
		}

		exportBtn.data('export-bound', true);
		exportBtn.attr('title', '{{ lang._('导出规则') }}');
		exportBtn.find('span.icon').removeClass('fa-share-square').addClass('fa-download');
		exportBtn.tooltip('destroy').tooltip({container: 'body', trigger: 'hover'});

		exportBtn.off('click').on('click', function (event) {
			event.preventDefault();
			event.stopPropagation();
			BootstrapDialog.show({
				title: '{{ lang._('导出规则') }}',
				message: '{{ lang._('请选择导出格式') }}',
				buttons: [
					{label: 'CSV', cssClass: 'btn-primary', action: function (dialog) {
						dialog.close();
						window.location.href = '/api/appidentification/rule/export/csv';
					}},
					{label: 'JSON', cssClass: 'btn-default', action: function (dialog) {
						dialog.close();
						window.location.href = '/api/appidentification/rule/export/json';
					}},
					{label: '{{ lang._('Cancel') }}', action: function (dialog) { dialog.close(); }}
				]
			});
		});
	}

	function setupRuleDialogUi() {
		const dialog = $('#DialogRule');
		if (!dialog.length || dialog.data('multivalue-bound') === true) {
			return;
		}

		dialog.data('multivalue-bound', true);
		let debounceTimer = null;

		function ensureValidationContainer() {
			const field = $('#rule\\.match_value');
			if (!field.length) {
				return null;
			}

			field.attr('rows', '5');
			field.attr('placeholder', '每行填写一个匹配值，例如：\nweixin.qq.com\nwechat.com\nqpic.cn');

			let container = $('#rule-match-value-validation');
			if (!container.length) {
				container = $('<div id="rule-match-value-validation" style="margin-top:6px;"></div>');
				field.closest('.form-group').append(container);
			}
			return container;
		}

		function validateDialogMatchValue() {
			const field = $('#rule\\.match_value');
			const typeField = $('#rule\\.match_type');
			const container = ensureValidationContainer();
			if (!field.length || !typeField.length || !container) {
				return;
			}

			const errors = validateMatchValueLines(String(typeField.val() || ''), String(field.val() || ''));
			const saveBtn = dialog.find('.modal-footer .btn-primary').first();
			if (errors.length === 0) {
				container.empty();
				field.css('background-color', '');
				saveBtn.prop('disabled', false);
				return;
			}

			let html = '<div class="alert alert-danger" style="margin-bottom:0; padding:6px 10px;">';
			html += '{{ lang._('以下匹配值行不合法：') }}<div style="margin-top:6px;">';
			errors.forEach(function (err) {
				html += '<div style="background:#fbe3e4; color:#a94442; padding:3px 6px; margin-bottom:4px; border-radius:2px;">';
				html += '{{ lang._('第') }} ' + esc(err.line) + ' {{ lang._('行') }}: ' + esc(err.message);
				html += '</div>';
			});
			html += '</div></div>';
			container.html(html);
			field.css('background-color', '#fff7f7');
			saveBtn.prop('disabled', true);
		}

		function scheduleValidation() {
			if (debounceTimer !== null) {
				clearTimeout(debounceTimer);
			}
			debounceTimer = setTimeout(validateDialogMatchValue, 500);
		}

		dialog.on('shown.bs.modal opnsense_bootgrid_mapped', function () {
			ensureValidationContainer();
			scheduleValidation();
		});

		dialog.on('input change', '#rule\\.match_value, #rule\\.match_type', function () {
			scheduleValidation();
		});
	}

	const savedRuleRowCount = Number(window.localStorage.getItem('appidentification.rules.rowCount') || 25);
	const ruleRowCounts = [savedRuleRowCount, 10, 25, 50, 100].filter(function (value, index, list) {
		return value > 0 && list.indexOf(value) === index;
	});

	$('#grid-custom-rules').UIBootgrid({
		search: '/api/appidentification/rule/searchRules',
		get: '/api/appidentification/rule/getRule/',
		set: '/api/appidentification/rule/setRule/',
		add: '/api/appidentification/rule/addRule/',
		del: '/api/appidentification/rule/delRule/',
		toggle: '/api/appidentification/rule/toggleRule/',
		options: {
			selection: false,
			multiSelect: false,
			rowCount: ruleRowCounts,
			formatters: {
				matchvalues: function (column, row) {
					const values = splitMatchValues(row.match_value);
					if (values.length === 0) {
						return '';
					}

					if (values.length === 1) {
						return '<span class="bootgrid-tooltip" title="' + esc(values[0]) + '">' + esc(values[0]) + '</span>';
					}

					const title = values.map(function (item) { return esc(item); }).join('&#10;');
					const extraCount = values.length - 1;
					return '<span class="bootgrid-tooltip" title="' + title + '">' +
						esc(values[0]) +
						' <small class="text-muted">{{ lang._('等') }} ' + esc(extraCount) + ' {{ lang._('个') }}</small>' +
						'</span>';
				}
			}
		}
	}).on('loaded.rs.jquery.bootgrid', function () {
		const count = $('#grid-custom-rules').bootgrid('getRowCount');
		if (count) {
			window.localStorage.setItem('appidentification.rules.rowCount', count);
		}
		bindRulesHeaderExportButton();
		setupRuleDialogUi();
		refreshRuleStats();
	});

	function parseImportPreview(format, text) {
		const errors = [];
		let rows = [];
		if ($.trim(text) === '') {
			return {rows: [], errors: ['{{ lang._('请输入或上传规则数据') }}']};
		}
		if (format === 'json') {
			try {
				const parsed = JSON.parse(text.replace(/^\uFEFF/, ''));
				if (!Array.isArray(parsed)) {
					return {rows: [], errors: ['{{ lang._('JSON 顶层必须是数组') }}']};
				}
				rows = parsed.map(function (row) {
					if (row && typeof row === 'object') {
						row.match_value = normalizeImportMatchValue(row.match_value);
					}
					return row;
				});
			} catch (err) {
				return {rows: [], errors: [err.message]};
			}
		} else {
			const lines = text.replace(/^\uFEFF/, '').split(/\r?\n/).filter(function (line) { return $.trim(line) !== ''; });
			if (lines.length < 2) {
				return {rows: [], errors: ['{{ lang._('CSV 至少需要表头和一行数据') }}']};
			}
			function splitCsv(line) {
				const out = [];
				let cur = '';
				let quoted = false;
				for (let i = 0; i < line.length; i++) {
					const ch = line.charAt(i);
					if (ch === '"' && quoted && line.charAt(i + 1) === '"') {
						cur += '"';
						i++;
					} else if (ch === '"') {
						quoted = !quoted;
					} else if (ch === ',' && !quoted) {
						out.push(cur);
						cur = '';
					} else {
						cur += ch;
					}
				}
				out.push(cur);
				return out;
			}
			const header = splitCsv(lines[0]).map(function (field) { return $.trim(field); });
			lines.slice(1).forEach(function (line, idx) {
				const values = splitCsv(line);
				if (values.length !== header.length) {
					errors.push('{{ lang._('第') }} ' + (idx + 2) + ' {{ lang._('行列数不匹配') }}');
					return;
				}
				const row = {};
				header.forEach(function (field, pos) {
					row[field] = values[pos];
				});
				row.match_value = normalizeImportMatchValue(row.match_value);
				rows.push(row);
			});
		}
		rows.forEach(function (row, idx) {
			['match_type', 'match_value', 'app_label'].forEach(function (field) {
				if (!row || !row[field]) {
					errors.push('{{ lang._('第') }} ' + (idx + 1) + ' {{ lang._('条缺少') }} ' + field);
				}
			});
		});
		return {rows: rows, errors: errors};
	}

	function renderImportPreview(container) {
		const format = container.find('input[name="import_format"]:checked').val();
		const text = container.find('#rules-import-payload').val();
		const result = parseImportPreview(format, text);
		const submit = container.closest('.modal-content').find('.btn-primary');
		if (result.errors.length > 0) {
			container.find('#rules-import-preview').html('<div class="alert alert-danger">' + result.errors.slice(0, 8).map(esc).join('<br>') + '</div>');
			submit.prop('disabled', true);
			return;
		}
		let html = '<div class="alert alert-success">{{ lang._('解析成功，共') }} ' + esc(result.rows.length) + ' {{ lang._('条') }}</div>';
		html += '<table class="table table-condensed"><thead><tr><th>match_type</th><th>match_value</th><th>app_label</th></tr></thead><tbody>';
		result.rows.slice(0, 5).forEach(function (row) {
			html += '<tr><td>' + esc(row.match_type) + '</td><td><pre style="margin:0; border:0; padding:0; background:transparent;">' + esc(row.match_value) + '</pre></td><td>' + esc(row.app_label) + '</td></tr>';
		});
		html += '</tbody></table>';
		container.find('#rules-import-preview').html(html);
		submit.prop('disabled', result.rows.length === 0);
	}

	function submitImport(dialog, container) {
		const formData = new FormData();
		formData.append('format', container.find('input[name="import_format"]:checked').val());
		formData.append('mode', container.find('input[name="import_mode"]:checked').val());
		formData.append('payload', container.find('#rules-import-payload').val());
		const file = container.find('#rules-import-file')[0].files[0];
		if (file) {
			formData.append('file', file);
		}
		container.find('#rules-import-errors').removeClass('alert alert-danger').empty();
		container.find('#rules-import-progress').show();
		$.ajax({
			url: '/api/appidentification/rule/import',
			method: 'POST',
			data: formData,
			processData: false,
			contentType: false,
			global: false,
			dataType: 'json',
			success: function (data) {
				container.find('#rules-import-progress').hide();
				if (!data || data.status !== 'ok') {
					const errors = data && data.errors ? data.errors : [data && data.message ? data.message : '{{ lang._('导入失败') }}'];
					container.find('#rules-import-errors').addClass('alert alert-danger').html(errors.map(esc).join('<br>'));
					return;
				}
				dialog.close();
				reloadRules();
				BootstrapDialog.show({
					type: BootstrapDialog.TYPE_SUCCESS,
					title: '{{ lang._('Success') }}',
					message: esc('{{ lang._('成功导入') }} ' + data.imported + ' {{ lang._('条规则，跳过') }} ' + data.skipped + ' {{ lang._('条重复规则') }}'),
					buttons: [{label: '{{ lang._('Close') }}', action: function(d){ d.close(); }}]
				});
			},
			error: function (xhr) {
				container.find('#rules-import-progress').hide();
				const data = xhr.responseJSON || {};
				const errors = data.errors || [data.message || '{{ lang._('网络请求失败') }}'];
				container.find('#rules-import-errors').addClass('alert alert-danger').html(errors.map(esc).join('<br>'));
			}
		});
	}

	$('#rules-import-open').on('click', function () {
		const body = $('<div>' +
			'<div class="form-group"><label>{{ lang._('格式') }}</label><br>' +
			'<label class="radio-inline"><input type="radio" name="import_format" value="csv" checked> CSV</label>' +
			'<label class="radio-inline"><input type="radio" name="import_format" value="json"> JSON</label></div>' +
			'<div class="form-group"><label>{{ lang._('模式') }}</label><br>' +
			'<label class="radio-inline"><input type="radio" name="import_mode" value="append" checked> {{ lang._('追加') }}</label>' +
			'<label class="radio-inline"><input type="radio" name="import_mode" value="replace"> {{ lang._('替换全部') }}</label></div>' +
			'<div class="form-group"><label>{{ lang._('上传文件') }}</label><input id="rules-import-file" type="file" accept=".csv,.json,text/csv,application/json" class="form-control"></div>' +
			'<div class="form-group"><label>{{ lang._('粘贴文本') }}</label><textarea id="rules-import-payload" class="form-control" rows="5"></textarea></div>' +
			'<div id="rules-import-preview"></div><div id="rules-import-progress" class="progress" style="display:none;"><div class="progress-bar progress-bar-striped active" style="width:100%"></div></div><div id="rules-import-errors"></div>' +
			'</div>');
		const dialog = BootstrapDialog.show({
			title: '{{ lang._('批量导入应用规则') }}',
			message: body,
			buttons: [
				{label: '{{ lang._('Cancel') }}', action: function(d){ d.close(); }},
				{label: '{{ lang._('Import') }}', cssClass: 'btn-primary', action: function(d){
					if (body.find('input[name="import_mode"]:checked').val() === 'replace') {
						ajaxCall('/api/appidentification/rule/stats', {}, function (stats) {
							const total = stats && stats.total ? stats.total : 0;
							BootstrapDialog.confirm('{{ lang._('此操作将清空所有现有规则（共') }} ' + total + ' {{ lang._('条），是否继续？') }}', function (ok) {
								if (ok) {
									submitImport(d, body);
								}
							});
						});
					} else {
						submitImport(d, body);
					}
				}}
			],
			onshown: function () {
				const submit = body.closest('.modal-content').find('.btn-primary');
				submit.prop('disabled', true);
				body.on('change keyup', 'input[name="import_format"], #rules-import-payload', function () {
					renderImportPreview(body);
				});
				body.find('#rules-import-file').on('change', function () {
					const file = this.files[0];
					if (!file) {
						renderImportPreview(body);
						return;
					}
					const reader = new FileReader();
					reader.onload = function (event) {
						body.find('#rules-import-payload').val(event.target.result);
						renderImportPreview(body);
					};
					reader.readAsText(file, 'UTF-8');
				});
			}
		});
	});

	$(document).ajaxError(function(event, xhr, settings) {
		if (settings && settings.url && settings.url.indexOf('/api/appidentification/') === 0) {
			const msg = xhr.responseJSON ? xhr.responseJSON.message : '{{ lang._('网络请求失败') }}';
			showApiError('{{ lang._('加载失败') }}', msg);
		}
	});
});
</script>
