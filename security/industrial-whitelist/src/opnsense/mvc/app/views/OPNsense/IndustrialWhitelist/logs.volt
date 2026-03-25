<script>
    $(document).ready(function () {
        const state = {
            rows: [],
            page: 1,
            pageSize: 50,
            keyword: ''
        };

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

        const filteredRows = function () {
            if (!state.keyword) {
                return state.rows;
            }
            const keyword = state.keyword.toLowerCase();
            return state.rows.filter(function (item) {
                return (
                    String(item.timestamp).toLowerCase().indexOf(keyword) !== -1 ||
                    String(item.src).toLowerCase().indexOf(keyword) !== -1 ||
                    String(item.dst).toLowerCase().indexOf(keyword) !== -1 ||
                    String(item.protoPort).toLowerCase().indexOf(keyword) !== -1 ||
                    String(item.action).toLowerCase().indexOf(keyword) !== -1
                );
            });
        };

        const renderIndustrialLogs = function () {
            const tbody = $('#industrial-log-table tbody');
            const rows = filteredRows();
            const total = rows.length;
            const totalPages = Math.max(1, Math.ceil(total / state.pageSize));

            if (state.page > totalPages) {
                state.page = totalPages;
            }

            const startIndex = (state.page - 1) * state.pageSize;
            const pageRows = rows.slice(startIndex, startIndex + state.pageSize);

            tbody.empty();
            if (pageRows.length === 0) {
                tbody.append('<tr><td colspan="5" class="text-center text-muted">{{ lang._("No Industrial Whitelist log entries found") }}</td></tr>');
            } else {
                pageRows.forEach(function (item) {
                    tbody.append(
                        '<tr>' +
                        '<td>' + escapeHtml(item.timestamp) + '</td>' +
                        '<td>' + escapeHtml(item.src) + '</td>' +
                        '<td>' + escapeHtml(item.dst) + '</td>' +
                        '<td>' + escapeHtml(item.protoPort) + '</td>' +
                        '<td>' + escapeHtml(item.action) + '</td>' +
                        '</tr>'
                    );
                });
            }

            const from = total === 0 ? 0 : (startIndex + 1);
            const to = Math.min(startIndex + state.pageSize, total);
            $('#iw-log-range').text(from + ' - ' + to + ' / ' + total);
            $('#iw-log-page').text(state.page + ' / ' + totalPages);
            $('#iw-log-prev').prop('disabled', state.page <= 1);
            $('#iw-log-next').prop('disabled', state.page >= totalPages);
        };

        const loadIndustrialLogs = function () {
            const tbody = $('#industrial-log-table tbody');
            tbody.html('<tr><td colspan="5" class="text-center text-muted">{{ lang._("Loading logs...") }}</td></tr>');

            ajaxGet('/api/diagnostics/firewall/log?limit=800', {}, function (data, status) {
                if (status !== 'success' || !Array.isArray(data)) {
                    tbody.html('<tr><td colspan="5" class="text-center text-danger">{{ lang._("Failed to load logs") }}</td></tr>');
                    return;
                }

                state.rows = data.filter(function (item) {
                    const payload = JSON.stringify(item).toLowerCase();
                    return payload.indexOf('industrialwhitelist') !== -1;
                }).map(function (item) {
                    return {
                        timestamp: normalizeLogField(item, ['__timestamp', 'timestamp', 'time']),
                        src: normalizeLogField(item, ['src', 'src_ip', 'srcip']),
                        dst: normalizeLogField(item, ['dst', 'dest', 'dst_ip', 'dstip']),
                        protoPort: [
                            normalizeLogField(item, ['proto', 'protocol']),
                            normalizeLogField(item, ['dstport', 'dest_port', 'port'])
                        ].join('/'),
                        action: normalizeLogField(item, ['action', 'act', 'label', 'description'])
                    };
                });

                state.page = 1;
                renderIndustrialLogs();
            });
        };

        $('#refreshIndustrialLog').on('click', function () { loadIndustrialLogs(); });
        $('#iw-log-search').on('input', function () {
            state.keyword = ($(this).val() || '').trim();
            state.page = 1;
            renderIndustrialLogs();
        });
        $('#iw-log-page-size').on('change', function () {
            state.pageSize = parseInt($(this).val(), 10) || 50;
            state.page = 1;
            renderIndustrialLogs();
        });
        $('#iw-log-prev').on('click', function () {
            if (state.page > 1) {
                state.page--;
                renderIndustrialLogs();
            }
        });
        $('#iw-log-next').on('click', function () {
            state.page++;
            renderIndustrialLogs();
        });

        loadIndustrialLogs();
    });
</script>

<style>
    .iw-log-toolbar {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 6px;
        margin-bottom: 8px;
        flex-wrap: wrap;
    }
    .iw-log-toolbar .form-inline {
        display: flex;
        align-items: center;
        gap: 6px;
    }
    .iw-log-toolbar .toolbar-right {
        margin-left: auto;
    }
    .iw-log-toolbar .form-control.input-sm {
        height: 30px;
        padding-top: 4px;
        padding-bottom: 4px;
    }
    .iw-btn-icon {
        width: 30px;
        height: 30px;
        padding: 4px 0;
    }
    #industrial-log-table {
        margin-bottom: 8px;
    }
    #industrial-log-table thead th {
        background: #f7f7f7;
        border-bottom: 1px solid #d9d9d9;
        white-space: nowrap;
    }
    .iw-log-footer {
        display: flex;
        align-items: center;
        justify-content: space-between;
        color: #666;
    }
</style>

<div class="content-box">
    <div class="iw-log-toolbar">
        <div class="form-inline">
            <select id="iw-log-page-size" class="form-control input-sm">
                <option value="25">25</option>
                <option value="50" selected="selected">50</option>
                <option value="100">100</option>
            </select>
        </div>
        <div class="form-inline toolbar-right">
            <input id="iw-log-search" type="search" class="form-control input-sm" placeholder="{{ lang._('Search') }}" style="width: 220px;"/>
            <button class="btn btn-default btn-sm iw-btn-icon" id="refreshIndustrialLog" type="button" title="{{ lang._('Refresh') }}" aria-label="{{ lang._('Refresh') }}">
                <span class="fa fa-refresh"></span>
            </button>
        </div>
    </div>

    <table id="industrial-log-table" class="table table-condensed table-hover table-striped table-bordered table-responsive">
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
            <td colspan="5" class="text-center text-muted">{{ lang._('Loading logs...') }}</td>
        </tr>
        </tbody>
    </table>

    <div class="iw-log-footer">
        <div id="iw-log-range">0 - 0 / 0</div>
        <div class="btn-group btn-group-xs" role="group">
            <button id="iw-log-prev" type="button" class="btn btn-default">&lsaquo;</button>
            <button id="iw-log-next" type="button" class="btn btn-default">&rsaquo;</button>
        </div>
        <div id="iw-log-page">1 / 1</div>
    </div>
</div>
