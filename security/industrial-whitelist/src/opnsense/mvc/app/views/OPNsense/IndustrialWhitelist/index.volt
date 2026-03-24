<script>
    $(document).ready(function () {
        const getMap = {'frm_settings': '/api/industrialwhitelist/settings/get'};

        mapDataToFormUI(getMap).done(function () {
            $('.selectpicker').selectpicker('refresh');
        });

        $('#{{ formGridRule["table_id"] }}').UIBootgrid({
            search: '/api/industrialwhitelist/rules/search_item/',
            get: '/api/industrialwhitelist/rules/get_item/',
            set: '/api/industrialwhitelist/rules/set_item/',
            add: '/api/industrialwhitelist/rules/add_item/',
            del: '/api/industrialwhitelist/rules/del_item/',
            toggle: '/api/industrialwhitelist/rules/toggle_item/',
            options: {
                sorting: false,
                rowCount: [-1, 10, 25, 50]
            }
        }).on('loaded.rs.jquery.bootgrid', function () {
            const table = $('#{{ formGridRule["table_id"] }}').closest('.tabulator').find('.tabulator-table');
            if (!table.length || table.data('iw-sortable')) {
                return;
            }

            table.data('iw-sortable', true);
            table.sortable({
                items: '.tabulator-row',
                update: function () {
                    const uuids = [];
                    table.find('.tabulator-row').each(function () {
                        const rowId = $(this).find('.command-edit').first().data('row-id');
                        if (rowId) {
                            uuids.push(rowId);
                        }
                    });

                    if (uuids.length > 0) {
                        ajaxCall('/api/industrialwhitelist/rules/set_sequence', {uuids: uuids}, function () {
                            $('#{{ formGridRule["table_id"] }}').bootgrid('reload');
                        });
                    }
                }
            });
        });

        $('#reconfigureAct').SimpleActionButton({
            onPreAction: function () {
                const deferred = new $.Deferred();
                saveFormToEndpoint('/api/industrialwhitelist/settings/set', 'frm_settings', function () {
                    deferred.resolve();
                });
                return deferred;
            }
        });

        const normalizeLogField = function (record, keys) {
            for (let i = 0; i < keys.length; i++) {
                if (record[keys[i]] !== undefined && record[keys[i]] !== null && record[keys[i]] !== '') {
                    return record[keys[i]];
                }
            }
            return '-';
        };

        const renderIndustrialLogs = function () {
            const tbody = $('#industrial-log-table tbody');
            tbody.empty();

            ajaxGet('/api/diagnostics/firewall/log?limit=500', {}, function (data, status) {
                if (status !== 'success' || !Array.isArray(data)) {
                    tbody.append('<tr><td colspan="5">{{ lang._("Failed to load logs") }}</td></tr>');
                    return;
                }

                const filtered = data.filter(function (item) {
                    const payload = JSON.stringify(item).toLowerCase();
                    return payload.indexOf('industrialwhitelist') !== -1;
                });

                if (filtered.length === 0) {
                    tbody.append('<tr><td colspan="5">{{ lang._("No Industrial Whitelist log entries found") }}</td></tr>');
                    return;
                }

                filtered.slice(0, 200).forEach(function (item) {
                    const timestamp = normalizeLogField(item, ['__timestamp', 'timestamp', 'time']);
                    const src = normalizeLogField(item, ['src', 'src_ip', 'srcip']);
                    const dst = normalizeLogField(item, ['dst', 'dest', 'dst_ip', 'dstip']);
                    const protoPort = [
                        normalizeLogField(item, ['proto', 'protocol']),
                        normalizeLogField(item, ['dstport', 'dest_port', 'port'])
                    ].join('/');
                    const action = normalizeLogField(item, ['action', 'act', 'label', 'description']);

                    tbody.append(
                        '<tr>' +
                        '<td>' + timestamp + '</td>' +
                        '<td>' + src + '</td>' +
                        '<td>' + dst + '</td>' +
                        '<td>' + protoPort + '</td>' +
                        '<td>' + action + '</td>' +
                        '</tr>'
                    );
                });
            });
        };

        $('#refreshIndustrialLog').on('click', function () {
            renderIndustrialLogs();
        });

        $('a[href="#tab_logs"]').on('shown.bs.tab', function () {
            renderIndustrialLogs();
        });
    });
</script>

<ul class="nav nav-tabs" data-tabs="tabs" id="maintabs">
    <li class="active"><a data-toggle="tab" href="#tab_config">{{ lang._('配置') }}</a></li>
    <li><a data-toggle="tab" href="#tab_logs">{{ lang._('日志') }}</a></li>
</ul>

<div class="tab-content content-box">
    <div id="tab_config" class="tab-pane fade in active">
        <h4>{{ lang._('General Settings') }}</h4>
        {{ partial('layout_partials/base_form', ['fields': formSettings, 'id': 'frm_settings']) }}
        <hr/>
        <h4>{{ lang._('Rules') }}</h4>
        {{ partial('layout_partials/base_bootgrid_table', formGridRule) }}
    </div>
    <div id="tab_logs" class="tab-pane fade in">
        <div class="row">
            <div class="col-md-12">
                <button class="btn btn-default btn-xs" id="refreshIndustrialLog" type="button">
                    <span class="fa fa-refresh"></span> {{ lang._('Refresh') }}
                </button>
                <br/><br/>
                <table id="industrial-log-table" class="table table-condensed table-hover table-striped table-responsive">
                    <thead>
                    <tr>
                        <th>{{ lang._('Timestamp') }}</th>
                        <th>{{ lang._('Source') }}</th>
                        <th>{{ lang._('Destination') }}</th>
                        <th>{{ lang._('Protocol/Port') }}</th>
                        <th>{{ lang._('Action') }}</th>
                    </tr>
                    </thead>
                    <tbody>
                    <tr>
                        <td colspan="5">{{ lang._('Open this tab or click Refresh to load logs') }}</td>
                    </tr>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>

<section class="page-content-main">
    <div class="content-box">
        <div class="col-md-12">
            <hr/>
            <div class="alert alert-info" role="alert">
                {{ lang._('Tip: drag rows in Rules tab to change matching priority, then click Apply.') }}
            </div>
            <button class="btn btn-primary" id="reconfigureAct"
                    data-endpoint="/api/industrialwhitelist/service/reconfigure"
                    data-label="{{ lang._('Apply') }}"
                    data-error-title="{{ lang._('Error applying industrial whitelist') }}"
                    type="button"></button>
            <br/><br/>
        </div>
    </div>
</section>

{{ partial('layout_partials/base_dialog', ['fields': formDialogRule, 'id': formGridRule['edit_dialog_id'], 'label': lang._('Edit Rule')]) }}
