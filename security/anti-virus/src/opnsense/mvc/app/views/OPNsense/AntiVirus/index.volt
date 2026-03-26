<script>
    $(document).ready(function () {
        const statsPriority = [
            'infected', 'blocked_ips', 'alert_only_actions', 'drop_only_actions',
            'scanned', 'clean', 'queued', 'dropped_queue_full',
            'dropped_oversize', 'dropped_cached', 'dropped_errors',
            'started_at', 'updated_at'
        ];

        const statsLabels = {
            infected: '{{ lang._('Infected') }}',
            blocked_ips: '{{ lang._('Blocked Sources') }}',
            alert_only_actions: '{{ lang._('Alert-Only Actions') }}',
            drop_only_actions: '{{ lang._('Drop-Only Actions') }}',
            scanned: '{{ lang._('Scanned') }}',
            clean: '{{ lang._('Clean') }}',
            queued: '{{ lang._('Queued') }}',
            dropped_queue_full: '{{ lang._('Dropped (Queue Full)') }}',
            dropped_oversize: '{{ lang._('Dropped (Oversize)') }}',
            dropped_cached: '{{ lang._('Dropped (Cached Safe)') }}',
            dropped_errors: '{{ lang._('Dropped (Errors)') }}',
            started_at: '{{ lang._('Started At') }}',
            updated_at: '{{ lang._('Updated At') }}'
        };

        function metricClass(key, value) {
            const number = Number(value);
            if (key === 'infected') {
                return number > 0 ? 'label label-danger' : 'label label-default';
            }
            if (key === 'dropped_queue_full' || key === 'dropped_errors' || key === 'dropped_oversize') {
                return number > 0 ? 'label label-warning' : 'label label-default';
            }
            if (key === 'clean' || key === 'scanned') {
                return 'label label-success';
            }
            if (key === 'blocked_ips') {
                return number > 0 ? 'label label-danger' : 'label label-default';
            }
            if (key === 'alert_only_actions' || key === 'drop_only_actions') {
                return number > 0 ? 'label label-info' : 'label label-default';
            }
            return 'label label-default';
        }

        function renderStats(stats) {
            const rendered = new Set();
            let rows = '';

            statsPriority.forEach(function (key) {
                if (typeof stats[key] === 'undefined') {
                    return;
                }
                rendered.add(key);
                const value = stats[key];
                rows += '<tr><td>' + (statsLabels[key] || key) + '</td><td><span class="' + metricClass(key, value) + '">' + value + '</span></td></tr>';
            });

            Object.keys(stats).forEach(function (key) {
                if (rendered.has(key)) {
                    return;
                }
                rows += '<tr><td>' + key + '</td><td><span class="label label-default">' + stats[key] + '</span></td></tr>';
            });

            if (rows === '') {
                rows = '<tr><td colspan="2">{{ lang._('No runtime stats available yet.') }}</td></tr>';
            }

            $('#av-stats-table tbody').html(rows);
        }

        function renderBlocks(items) {
            let rows = '';
            if (!items || items.length === 0) {
                rows = '<tr><td colspan="2">{{ lang._('No active blocked source IPs.') }}</td></tr>';
            } else {
                items.forEach(function (item) {
                    const ip = item.ip || '';
                    rows += '<tr>' +
                        '<td><span class="label label-danger">' + ip + '</span></td>' +
                        '<td><button type="button" class="btn btn-xs btn-default av-unblock-btn" data-ip="' + ip + '">{{ lang._('Unblock') }}</button></td>' +
                        '</tr>';
                });
            }
            $('#av-active-blocks-table tbody').html(rows);
            $('#av-active-block-count').text(items ? items.length : 0);
        }

        mapDataToFormUI({
            'frm_general': '/api/antivirus/general/get'
        }).done(function () {
            $('.selectpicker').selectpicker('refresh');
        });

        $('#{{ formGridHash["table_id"] }}').UIBootgrid({
            search: '/api/antivirus/hashes/search_item/',
            get: '/api/antivirus/hashes/get_item/',
            set: '/api/antivirus/hashes/set_item/',
            add: '/api/antivirus/hashes/add_item/',
            del: '/api/antivirus/hashes/del_item/',
            toggle: '/api/antivirus/hashes/toggle_item/'
        });

        $('#reconfigureAct').SimpleActionButton({
            onPreAction: function () {
                const deferred = new $.Deferred();

                saveFormToEndpoint('/api/antivirus/general/set', 'frm_general', function () {
                    deferred.resolve();
                });

                return deferred;
            }
        });

        const loadStats = function () {
            ajaxGet('/api/antivirus/logs/stats', {}, function (data) {
                const stats = (data && data.stats) ? data.stats : {};
                renderStats(stats);
            });
        };

        const loadActiveBlocks = function () {
            ajaxGet('/api/antivirus/service/list_blocks', {}, function (data) {
                const items = (data && data.items) ? data.items : [];
                renderBlocks(items);
            });
        };

        $('#av-active-blocks-table').on('click', '.av-unblock-btn', function () {
            const ip = $(this).data('ip');
            if (!ip) {
                return;
            }
            ajaxCall('/api/antivirus/service/unblock_ip', {ip: ip}, function () {
                loadActiveBlocks();
            });
        });

        $('#btnReloadBlocks').on('click', function () {
            loadActiveBlocks();
        });

        loadStats();
        loadActiveBlocks();
        setInterval(loadStats, 10000);
        setInterval(loadActiveBlocks, 15000);
    });
</script>

<ul class="nav nav-tabs" data-tabs="tabs" id="maintabs">
    <li class="active"><a data-toggle="tab" href="#tab_general">{{ lang._('General Settings') }}</a></li>
    <li><a data-toggle="tab" href="#tab_hashes">{{ lang._('SHA256 Whitelist') }}</a></li>
    <li><a data-toggle="tab" href="#tab_stats">{{ lang._('Runtime Stats') }}</a></li>
    <li><a data-toggle="tab" href="#tab_blocks">{{ lang._('Active Blocks') }}</a></li>
</ul>

<div class="tab-content content-box">
    <div id="tab_general" class="tab-pane fade in active">
        <div class="alert alert-info" style="margin-top: 10px;">
            {{ lang._('Fail-open sidecar mode: forwarding path is never blocked. Only plaintext extraction traffic (HTTP/FTP/SMB) is scanned.') }}
        </div>
        {{ partial('layout_partials/base_form', ['fields': formGeneral, 'id': 'frm_general']) }}
    </div>
    <div id="tab_hashes" class="tab-pane fade in">
        {{ partial('layout_partials/base_bootgrid_table', formGridHash) }}
    </div>
    <div id="tab_stats" class="tab-pane fade in">
        <table id="av-stats-table" class="table table-striped table-condensed" style="margin-top: 10px;">
            <thead>
                <tr>
                    <th>{{ lang._('Metric') }}</th>
                    <th>{{ lang._('Value') }}</th>
                </tr>
            </thead>
            <tbody></tbody>
        </table>
    </div>
    <div id="tab_blocks" class="tab-pane fade in">
        <div class="clearfix" style="margin-top: 10px; margin-bottom: 10px;">
            <div class="pull-left">
                <strong>{{ lang._('Current blocked sources') }}:</strong>
                <span id="av-active-block-count" class="label label-danger">0</span>
            </div>
            <div class="pull-right">
                <button type="button" id="btnReloadBlocks" class="btn btn-default btn-xs">
                    <span class="fa fa-refresh"></span> {{ lang._('Refresh') }}
                </button>
            </div>
        </div>
        <table id="av-active-blocks-table" class="table table-striped table-condensed">
            <thead>
                <tr>
                    <th>{{ lang._('Source IP') }}</th>
                    <th>{{ lang._('Action') }}</th>
                </tr>
            </thead>
            <tbody></tbody>
        </table>
    </div>
</div>

{{ partial('layout_partials/base_apply_button', {'data_endpoint': '/api/antivirus/service/reconfigure'}) }}
{{ partial('layout_partials/base_dialog', ['fields': formDialogHash, 'id': formGridHash['edit_dialog_id'], 'label': lang._('Edit Whitelist Entry')]) }}