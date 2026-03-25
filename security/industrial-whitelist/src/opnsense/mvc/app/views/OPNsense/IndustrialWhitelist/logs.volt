<script>
    $(document).ready(function () {
        let logRows = [];

        const escapeHtml = function (value) {
            return $('<div/>').text(value == null ? '' : String(value)).html();
        };

        const filterRowsByPhrase = function (rows, phrase) {
            if (!phrase) {
                return rows;
            }
            const token = phrase.toLowerCase();
            return rows.filter(function (row) {
                return [row.timestamp, row.source, row.destination, row.protocol_port, row.action]
                    .join(' ')
                    .toLowerCase()
                    .indexOf(token) !== -1;
            });
        };

        const exportCsv = function (filename, rows) {
            const header = ['Timestamp', 'Source', 'Destination', 'Protocol/Port', 'Action'];
            const lines = [header.join(',')];

            rows.forEach(function (row) {
                const cols = [row.timestamp, row.source, row.destination, row.protocol_port, row.action].map(function (value) {
                    const text = String(value == null ? '' : value).replace(/"/g, '""');
                    return '"' + text + '"';
                });
                lines.push(cols.join(','));
            });

            const blob = new Blob(["\uFEFF" + lines.join('\n')], {type: 'text/csv;charset=utf-8;'});
            const url = URL.createObjectURL(blob);
            const link = document.createElement('a');
            link.href = url;
            link.download = filename;
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            URL.revokeObjectURL(url);
        };

        const attachFooterActions = function () {
            const footer = $('#industrial-log-table-footer .pagination');
            if (!footer.length) {
                return;
            }
            if (!$('#iw-log-export').length) {
                footer.before(
                    '<div class="btn-group btn-group-xs" style="margin-right:8px;">' +
                    '  <button id="iw-log-export" class="btn btn-default" type="button" title="{{ lang._("Export") }}">' +
                    '    <span class="fa fa-download"></span>' +
                    '  </button>' +
                    '</div>'
                );

                $('#iw-log-export').on('click', function () {
                    const phrase = ($('#industrial-log-table-header .search-field').val() || '').trim();
                    const rows = filterRowsByPhrase(logRows, phrase);
                    exportCsv('industrial-whitelist-logs.csv', rows);
                });
            }
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
                navigation: 3,
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
                attachFooterActions();
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

                logRows = data.filter(function (item) {
                    const payload = JSON.stringify(item).toLowerCase();
                    return payload.indexOf('industrialwhitelist') !== -1;
                }).map(function (item) {
                    return {
                        timestamp: normalizeLogField(item, ['__timestamp', 'timestamp', 'time']),
                        source: normalizeLogField(item, ['src', 'src_ip', 'srcip']),
                        destination: normalizeLogField(item, ['dst', 'dest', 'dst_ip', 'dstip']),
                        protocol_port: [
                            normalizeLogField(item, ['proto', 'protocol']),
                            normalizeLogField(item, ['dstport', 'dest_port', 'port'])
                        ].join('/'),
                        action: normalizeLogField(item, ['action', 'act', 'label', 'description'])
                    };
                });

                tbody.empty();
                logRows.forEach(function (item, index) {
                    tbody.append(
                        '<tr data-row-id="' + index + '">' +
                        '<td>' + escapeHtml(item.timestamp) + '</td>' +
                        '<td>' + escapeHtml(item.source) + '</td>' +
                        '<td>' + escapeHtml(item.destination) + '</td>' +
                        '<td>' + escapeHtml(item.protocol_port) + '</td>' +
                        '<td>' + escapeHtml(item.action) + '</td>' +
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
