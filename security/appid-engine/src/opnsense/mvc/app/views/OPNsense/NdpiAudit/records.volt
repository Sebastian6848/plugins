<script>
    $(document).ready(function () {
        let liveTimer = null;
        const liveState = {rows: [], page: 1, pageSize: 50, keyword: ''};
        const historyState = {rows: [], page: 1, pageSize: 50, keyword: ''};

        const escapeHtml = function (value) {
            return $('<div/>').text(value == null ? '' : String(value)).html();
        };

        const renderRows = function (tbody, rows, columns, emptyText, state, pagerPrefix) {
            tbody.empty();

            let filtered = rows;
            if (state && state.keyword) {
                const keyword = state.keyword.toLowerCase();
                filtered = rows.filter(function (row) {
                    return columns.some(function (column) {
                        return String(row[column] || '').toLowerCase().indexOf(keyword) !== -1;
                    });
                });
            }

            const total = filtered.length;
            const pageSize = state ? state.pageSize : filtered.length;
            const totalPages = Math.max(1, Math.ceil(total / pageSize));
            if (state && state.page > totalPages) {
                state.page = totalPages;
            }

            const page = state ? state.page : 1;
            const startIndex = (page - 1) * pageSize;
            const pageRows = filtered.slice(startIndex, startIndex + pageSize);

            if (!Array.isArray(pageRows) || pageRows.length === 0) {
                tbody.append('<tr><td colspan="' + columns.length + '">' + emptyText + '</td></tr>');
            } else {
                pageRows.forEach(function (row) {
                    let html = '<tr>';
                    columns.forEach(function (column) {
                        html += '<td>' + escapeHtml(row[column] || '-') + '</td>';
                    });
                    html += '</tr>';
                    tbody.append(html);
                });
            }

            if (pagerPrefix) {
                const from = total === 0 ? 0 : (startIndex + 1);
                const to = Math.min(startIndex + pageSize, total);
                $('#' + pagerPrefix + '-range').text(from + ' - ' + to + ' / ' + total);
                $('#' + pagerPrefix + '-page').text(page + ' / ' + totalPages);
                $('#' + pagerPrefix + '-prev').prop('disabled', page <= 1);
                $('#' + pagerPrefix + '-next').prop('disabled', page >= totalPages);
            }
        };

        const refreshLive = function () {
            ajaxGet('/api/ndpiaudit/audit/live?window=120&limit=200', {}, function (data, status) {
                const tbody = $('#ndpi-live-table tbody');
                if (status !== 'success') {
                    renderRows(tbody, [], ['timestamp'], '{{ lang._("Failed to load live data") }}', liveState, 'ndpi-live');
                    return;
                }
                liveState.rows = data.rows || [];
                renderRows(
                    tbody,
                    liveState.rows,
                    ['timestamp', 'src_ip', 'src_port', 'dst_ip', 'dst_port', 'protocol', 'application', 'category'],
                    '{{ lang._("No active flows") }}',
                    liveState,
                    'ndpi-live'
                );
            });
        };

        const refreshStats = function () {
            ajaxGet('/api/ndpiaudit/audit/stats', {}, function (data, status) {
                const tbody = $('#ndpi-stats-table tbody');
                tbody.empty();

                if (status !== 'success' || !Array.isArray(data.rows) || data.rows.length === 0) {
                    tbody.append('<tr><td colspan="3">{{ lang._("No statistics available") }}</td></tr>');
                    return;
                }

                data.rows.forEach(function (item) {
                    const bar = '<div class="progress" style="margin-bottom:0;">' +
                        '<div class="progress-bar progress-bar-info" role="progressbar" style="width:' + item.percentage + '%;">' +
                        item.percentage + '%</div></div>';

                    tbody.append(
                        '<tr>' +
                        '<td>' + escapeHtml(item.category) + '</td>' +
                        '<td>' + escapeHtml(item.count) + '</td>' +
                        '<td>' + bar + '</td>' +
                        '</tr>'
                    );
                });
            });
        };

        const refreshHistory = function () {
            const ip = encodeURIComponent($('#history_ip').val() || '');
            const app = encodeURIComponent($('#history_app').val() || '');
            const start = encodeURIComponent($('#history_start').val() || '');
            const end = encodeURIComponent($('#history_end').val() || '');
            const limit = encodeURIComponent($('#history_limit').val() || '500');
            const url = '/api/ndpiaudit/audit/search?ip=' + ip + '&app=' + app + '&start=' + start + '&end=' + end + '&limit=' + limit;

            ajaxGet(url, {}, function (data, status) {
                const tbody = $('#ndpi-history-table tbody');
                if (status !== 'success') {
                    renderRows(tbody, [], ['timestamp'], '{{ lang._("Failed to load history") }}', historyState, 'ndpi-history');
                    return;
                }

                historyState.rows = data.rows || [];
                historyState.page = 1;

                renderRows(
                    tbody,
                    historyState.rows,
                    ['timestamp', 'src_ip', 'src_port', 'dst_ip', 'dst_port', 'protocol', 'application', 'category'],
                    '{{ lang._("No records matched current filters") }}',
                    historyState,
                    'ndpi-history'
                );
            });
        };

        const setLiveAutoRefresh = function (enabled) {
            if (liveTimer !== null) {
                clearInterval(liveTimer);
                liveTimer = null;
            }
            if (enabled) {
                liveTimer = setInterval(function () {
                    refreshLive();
                    refreshStats();
                }, 5000);
            }
        };

        $('#refreshLive').on('click', function () {
            refreshLive();
            refreshStats();
        });

        $('#refreshHistoryList').on('click', function () {
            refreshHistory();
        });

        $('#ndpi-live-search').on('input', function () {
            liveState.keyword = ($(this).val() || '').trim();
            liveState.page = 1;
            renderRows(
                $('#ndpi-live-table tbody'),
                liveState.rows,
                ['timestamp', 'src_ip', 'src_port', 'dst_ip', 'dst_port', 'protocol', 'application', 'category'],
                '{{ lang._("No active flows") }}',
                liveState,
                'ndpi-live'
            );
        });

        $('#ndpi-live-page-size').on('change', function () {
            liveState.pageSize = parseInt($(this).val(), 10) || 50;
            liveState.page = 1;
            refreshLive();
        });

        $('#ndpi-live-prev').on('click', function () {
            if (liveState.page > 1) {
                liveState.page--;
                refreshLive();
            }
        });

        $('#ndpi-live-next').on('click', function () {
            liveState.page++;
            refreshLive();
        });

        $('#searchHistory').on('click', function () {
            refreshHistory();
        });

        $('#ndpi-history-search').on('input', function () {
            historyState.keyword = ($(this).val() || '').trim();
            historyState.page = 1;
            renderRows(
                $('#ndpi-history-table tbody'),
                historyState.rows,
                ['timestamp', 'src_ip', 'src_port', 'dst_ip', 'dst_port', 'protocol', 'application', 'category'],
                '{{ lang._("No records matched current filters") }}',
                historyState,
                'ndpi-history'
            );
        });

        $('#ndpi-history-page-size').on('change', function () {
            historyState.pageSize = parseInt($(this).val(), 10) || 50;
            historyState.page = 1;
            renderRows(
                $('#ndpi-history-table tbody'),
                historyState.rows,
                ['timestamp', 'src_ip', 'src_port', 'dst_ip', 'dst_port', 'protocol', 'application', 'category'],
                '{{ lang._("No records matched current filters") }}',
                historyState,
                'ndpi-history'
            );
        });

        $('#ndpi-history-prev').on('click', function () {
            if (historyState.page > 1) {
                historyState.page--;
                renderRows(
                    $('#ndpi-history-table tbody'),
                    historyState.rows,
                    ['timestamp', 'src_ip', 'src_port', 'dst_ip', 'dst_port', 'protocol', 'application', 'category'],
                    '{{ lang._("No records matched current filters") }}',
                    historyState,
                    'ndpi-history'
                );
            }
        });

        $('#ndpi-history-next').on('click', function () {
            historyState.page++;
            renderRows(
                $('#ndpi-history-table tbody'),
                historyState.rows,
                ['timestamp', 'src_ip', 'src_port', 'dst_ip', 'dst_port', 'protocol', 'application', 'category'],
                '{{ lang._("No records matched current filters") }}',
                historyState,
                'ndpi-history'
            );
        });

        $('#liveAutoRefresh').on('change', function () {
            setLiveAutoRefresh($(this).is(':checked'));
        });

        refreshLive();
        refreshStats();
        refreshHistory();
        setLiveAutoRefresh(true);
    });
</script>

<style>
    .ndpi-grid-toolbar {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 6px;
        margin-bottom: 8px;
        flex-wrap: wrap;
    }
    .ndpi-grid-toolbar .form-inline {
        display: flex;
        align-items: center;
        gap: 6px;
    }
    .ndpi-grid-toolbar .toolbar-right {
        margin-left: auto;
    }
    .ndpi-grid-toolbar .form-control.input-sm,
    .ndpi-query-row .form-control {
        height: 30px;
        padding-top: 4px;
        padding-bottom: 4px;
    }
    .ndpi-btn-icon {
        width: 30px;
        height: 30px;
        padding: 4px 0;
    }
    .ndpi-grid-table thead th {
        background: #f7f7f7;
        border-bottom: 1px solid #d9d9d9;
        white-space: nowrap;
    }
    .ndpi-grid-footer {
        display: flex;
        align-items: center;
        justify-content: space-between;
        color: #666;
        margin-top: 6px;
    }
</style>

<ul class="nav nav-tabs" data-tabs="tabs" id="recordtabs">
    <li class="active"><a data-toggle="tab" href="#tab_stats">{{ lang._('Statistics') }}</a></li>
    <li><a data-toggle="tab" href="#tab_search">{{ lang._('Search') }}</a></li>
</ul>

<div class="tab-content content-box">
    <div id="tab_stats" class="tab-pane fade in active">
        <div class="ndpi-grid-toolbar" style="margin-top: 10px;">
            <div class="form-inline">
                <select id="ndpi-live-page-size" class="form-control input-sm">
                    <option value="25">25</option>
                    <option value="50" selected="selected">50</option>
                    <option value="100">100</option>
                </select>
                <label style="margin-left: 8px; font-weight: normal;">
                    <input type="checkbox" id="liveAutoRefresh" checked="checked"/> {{ lang._('Auto refresh (5s)') }}
                </label>
            </div>
            <div class="form-inline toolbar-right">
                <input id="ndpi-live-search" type="search" class="form-control input-sm" placeholder="{{ lang._('Search') }}" style="width: 220px;"/>
                <button class="btn btn-default btn-sm ndpi-btn-icon" id="refreshLive" type="button" title="{{ lang._('Refresh') }}" aria-label="{{ lang._('Refresh') }}">
                    <span class="fa fa-refresh"></span>
                </button>
            </div>
        </div>
        <div class="row" style="margin-top: 10px;">
            <div class="col-md-8">
                <table id="ndpi-live-table" class="table table-condensed table-hover table-striped table-bordered table-responsive ndpi-grid-table">
                    <thead>
                    <tr>
                        <th>{{ lang._('Timestamp') }}</th>
                        <th>{{ lang._('Src IP') }}</th>
                        <th>{{ lang._('Src Port') }}</th>
                        <th>{{ lang._('Dst IP') }}</th>
                        <th>{{ lang._('Dst Port') }}</th>
                        <th>{{ lang._('L4') }}</th>
                        <th>{{ lang._('Application') }}</th>
                        <th>{{ lang._('Category') }}</th>
                    </tr>
                    </thead>
                    <tbody>
                    <tr><td colspan="8">{{ lang._('Loading...') }}</td></tr>
                    </tbody>
                </table>
                <div class="ndpi-grid-footer">
                    <div id="ndpi-live-range">0 - 0 / 0</div>
                    <div class="btn-group btn-group-xs" role="group">
                        <button id="ndpi-live-prev" type="button" class="btn btn-default">&lsaquo;</button>
                        <button id="ndpi-live-next" type="button" class="btn btn-default">&rsaquo;</button>
                    </div>
                    <div id="ndpi-live-page">1 / 1</div>
                </div>
            </div>
            <div class="col-md-4">
                <table id="ndpi-stats-table" class="table table-condensed table-striped table-bordered ndpi-grid-table">
                    <thead>
                    <tr>
                        <th>{{ lang._('Category') }}</th>
                        <th>{{ lang._('Count') }}</th>
                        <th>{{ lang._('Share') }}</th>
                    </tr>
                    </thead>
                    <tbody>
                    <tr><td colspan="3">{{ lang._('Loading...') }}</td></tr>
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <div id="tab_search" class="tab-pane fade in">
        <div class="row ndpi-query-row" style="margin-top: 8px;">
            <div class="col-md-2">
                <label for="history_ip">{{ lang._('IP') }}</label>
                <input type="text" id="history_ip" class="form-control input-sm" placeholder="192.168.1.10"/>
            </div>
            <div class="col-md-2">
                <label for="history_app">{{ lang._('Application') }}</label>
                <input type="text" id="history_app" class="form-control input-sm" placeholder="YouTube"/>
            </div>
            <div class="col-md-3">
                <label for="history_start">{{ lang._('Start Time') }}</label>
                <input type="datetime-local" id="history_start" class="form-control input-sm"/>
            </div>
            <div class="col-md-3">
                <label for="history_end">{{ lang._('End Time') }}</label>
                <input type="datetime-local" id="history_end" class="form-control input-sm"/>
            </div>
            <div class="col-md-1">
                <label for="history_limit">{{ lang._('Limit') }}</label>
                <input type="number" id="history_limit" class="form-control input-sm" value="500" min="1" max="5000"/>
            </div>
            <div class="col-md-1">
                <label>&nbsp;</label>
                <button class="btn btn-primary btn-sm form-control" id="searchHistory" type="button">{{ lang._('Search') }}</button>
            </div>
        </div>
        <div class="ndpi-grid-toolbar" style="margin-top: 10px;">
            <div class="form-inline">
                <select id="ndpi-history-page-size" class="form-control input-sm">
                    <option value="25">25</option>
                    <option value="50" selected="selected">50</option>
                    <option value="100">100</option>
                </select>
            </div>
            <div class="form-inline toolbar-right">
                <input id="ndpi-history-search" type="search" class="form-control input-sm" placeholder="{{ lang._('Search') }}" style="width: 220px;"/>
                <button class="btn btn-default btn-sm ndpi-btn-icon" id="refreshHistoryList" type="button" title="{{ lang._('Refresh') }}" aria-label="{{ lang._('Refresh') }}">
                    <span class="fa fa-refresh"></span>
                </button>
            </div>
        </div>
        <div class="row" style="margin-top: 10px;">
            <div class="col-md-12">
                <table id="ndpi-history-table" class="table table-condensed table-hover table-striped table-bordered table-responsive ndpi-grid-table">
                    <thead>
                    <tr>
                        <th>{{ lang._('Timestamp') }}</th>
                        <th>{{ lang._('Src IP') }}</th>
                        <th>{{ lang._('Src Port') }}</th>
                        <th>{{ lang._('Dst IP') }}</th>
                        <th>{{ lang._('Dst Port') }}</th>
                        <th>{{ lang._('L4') }}</th>
                        <th>{{ lang._('Application') }}</th>
                        <th>{{ lang._('Category') }}</th>
                    </tr>
                    </thead>
                    <tbody>
                    <tr><td colspan="8">{{ lang._('Loading...') }}</td></tr>
                    </tbody>
                </table>
                <div class="ndpi-grid-footer">
                    <div id="ndpi-history-range">0 - 0 / 0</div>
                    <div class="btn-group btn-group-xs" role="group">
                        <button id="ndpi-history-prev" type="button" class="btn btn-default">&lsaquo;</button>
                        <button id="ndpi-history-next" type="button" class="btn btn-default">&rsaquo;</button>
                    </div>
                    <div id="ndpi-history-page">1 / 1</div>
                </div>
            </div>
        </div>
    </div>
</div>
