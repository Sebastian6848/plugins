<script>
    $(document).ready(function () {
        const escapeHtml = function (value) {
            return $('<div/>').text(value == null ? '' : String(value)).html();
        };

        const normalizeLogField = function (record, keys) {
            for (let i = 0; i < keys.length; i++) {
                if (record[keys[i]] !== undefined && record[keys[i]] !== null && record[keys[i]] !== '') {
                    return record[keys[i]];
                }
            }
            return '-';
        };

        const initGrid = function () {
            try {
                $('#industrial-log-table').bootgrid('destroy');
            } catch (e) {}

            $('#industrial-log-table').bootgrid({
                caseSensitive: false,
                rowCount: [25, 50, 100, -1],
                templates: {
                    search: '<div class="search form-group"><div class="input-group"><span class="icon input-group-addon fa fa-search"></span><input type="text" class="search-field form-control" placeholder="{{ lang._("Search") }}"></div></div>'
                },
                labels: {
                    noResults: '{{ lang._("No Industrial Whitelist log entries found") }}',
                    infos: '{{ lang._("Showing %s to %s, total %s items") | format("{{ctx.start}}", "{{ctx.end}}", "{{ctx.total}}") }}'
                }
            }).on('loaded.rs.jquery.bootgrid', function () {
                $('#iw-log-refresh-container').detach().insertAfter('#industrial-log-table-header .actionBar .actions');
            });
        };

        const loadIndustrialLogs = function () {
            const tbody = $('#industrial-log-table tbody');
            tbody.html('<tr><td colspan="5">{{ lang._("Loading logs...") }}</td></tr>');

            ajaxGet('/api/diagnostics/firewall/log?limit=800', {}, function (data, status) {
                if (status !== 'success' || !Array.isArray(data)) {
                    tbody.html('<tr><td colspan="5">{{ lang._("Failed to load logs") }}</td></tr>');
                    return;
                }

                const rows = data.filter(function (item) {
                    const payload = JSON.stringify(item).toLowerCase();
                    return payload.indexOf('industrialwhitelist') !== -1;
                });

                tbody.empty();
                rows.forEach(function (item, index) {
                    const timestamp = normalizeLogField(item, ['__timestamp', 'timestamp', 'time']);
                    const src = normalizeLogField(item, ['src', 'src_ip', 'srcip']);
                    const dst = normalizeLogField(item, ['dst', 'dest', 'dst_ip', 'dstip']);
                    const protoPort = [
                        normalizeLogField(item, ['proto', 'protocol']),
                        normalizeLogField(item, ['dstport', 'dest_port', 'port'])
                    ].join('/');
                    const action = normalizeLogField(item, ['action', 'act', 'label', 'description']);

                    tbody.append(
                        '<tr data-row-id="' + index + '">' +
                        '<td>' + escapeHtml(timestamp) + '</td>' +
                        '<td>' + escapeHtml(src) + '</td>' +
                        '<td>' + escapeHtml(dst) + '</td>' +
                        '<td>' + escapeHtml(protoPort) + '</td>' +
                        '<td>' + escapeHtml(action) + '</td>' +
                        '</tr>'
                    );
                });

                initGrid();
            });
        };

        $('#refreshIndustrialLog').on('click', function () {
            loadIndustrialLogs();
        });

        loadIndustrialLogs();
    });
</script>

<div class="content-box">
    <div class="hidden">
        <div id="iw-log-refresh-container" class="btn-group">
            <button class="btn btn-default" id="refreshIndustrialLog" type="button" title="{{ lang._('Refresh') }}">
                <span class="fa fa-refresh"></span>
            </button>
        </div>
    </div>

    <table id="industrial-log-table" class="table table-condensed table-hover table-striped table-responsive">
        <thead>
        <tr>
            <th data-column-id="timestamp" data-type="string">{{ lang._('Timestamp') }}</th>
            <th data-column-id="source" data-type="string">{{ lang._('Source') }}</th>
            <th data-column-id="destination" data-type="string">{{ lang._('Destination') }}</th>
            <th data-column-id="protocol_port" data-type="string">{{ lang._('Protocol/Port') }}</th>
            <th data-column-id="action" data-type="string">{{ lang._('Action') }}</th>
        </tr>
        </thead>
        <tbody>
        <tr><td colspan="5">{{ lang._('Loading logs...') }}</td></tr>
        </tbody>
    </table>
</div>
