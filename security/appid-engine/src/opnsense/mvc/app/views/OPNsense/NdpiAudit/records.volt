<script>
    $(document).ready(function () {
        let liveTimer = null;

        const escapeHtml = function (value) {
            return $('<div/>').text(value == null ? '' : String(value)).html();
        };

        const renderRows = function (tbody, rows, columns, emptyText) {
            tbody.empty();
            if (!Array.isArray(rows) || rows.length === 0) {
                tbody.append('<tr><td colspan="' + columns.length + '">' + emptyText + '</td></tr>');
                return;
            }
            rows.forEach(function (row) {
                let html = '<tr>';
                columns.forEach(function (column) {
                    html += '<td>' + escapeHtml(row[column] || '-') + '</td>';
                });
                html += '</tr>';
                tbody.append(html);
            });
        };

        const refreshLive = function () {
            ajaxGet('/api/ndpiaudit/audit/live?window=120&limit=200', {}, function (data, status) {
                const tbody = $('#ndpi-live-table tbody');
                if (status !== 'success') {
                    renderRows(tbody, [], ['timestamp'], '{{ lang._("Failed to load live data") }}');
                    return;
                }
                renderRows(
                    tbody,
                    data.rows || [],
                    ['timestamp', 'src_ip', 'src_port', 'dst_ip', 'dst_port', 'protocol', 'application', 'category'],
                    '{{ lang._("No active flows") }}'
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
                    renderRows(tbody, [], ['timestamp'], '{{ lang._("Failed to load history") }}');
                    return;
                }

                renderRows(
                    tbody,
                    data.rows || [],
                    ['timestamp', 'src_ip', 'src_port', 'dst_ip', 'dst_port', 'protocol', 'application', 'category'],
                    '{{ lang._("No records matched current filters") }}'
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

        $('#searchHistory').on('click', function () {
            refreshHistory();
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

<ul class="nav nav-tabs" data-tabs="tabs" id="recordtabs">
    <li class="active"><a data-toggle="tab" href="#tab_stats">{{ lang._('Statistics') }}</a></li>
    <li><a data-toggle="tab" href="#tab_search">{{ lang._('Search') }}</a></li>
</ul>

<div class="tab-content content-box">
    <div id="tab_stats" class="tab-pane fade in active">
        <div class="row" style="margin-top: 10px;">
            <div class="col-md-12">
                <button class="btn btn-default btn-xs" id="refreshLive" type="button">
                    <span class="fa fa-refresh"></span> {{ lang._('Refresh') }}
                </button>
                <label style="margin-left: 12px; font-weight: normal;">
                    <input type="checkbox" id="liveAutoRefresh" checked="checked"/> {{ lang._('Auto refresh (5s)') }}
                </label>
            </div>
        </div>
        <div class="row" style="margin-top: 10px;">
            <div class="col-md-8">
                <table id="ndpi-live-table" class="table table-condensed table-hover table-striped table-responsive">
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
            </div>
            <div class="col-md-4">
                <table id="ndpi-stats-table" class="table table-condensed table-striped">
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
        <div class="row" style="margin-top: 10px;">
            <div class="col-md-2">
                <label for="history_ip">{{ lang._('IP') }}</label>
                <input type="text" id="history_ip" class="form-control" placeholder="192.168.1.10"/>
            </div>
            <div class="col-md-2">
                <label for="history_app">{{ lang._('Application') }}</label>
                <input type="text" id="history_app" class="form-control" placeholder="YouTube"/>
            </div>
            <div class="col-md-3">
                <label for="history_start">{{ lang._('Start Time') }}</label>
                <input type="datetime-local" id="history_start" class="form-control"/>
            </div>
            <div class="col-md-3">
                <label for="history_end">{{ lang._('End Time') }}</label>
                <input type="datetime-local" id="history_end" class="form-control"/>
            </div>
            <div class="col-md-1">
                <label for="history_limit">{{ lang._('Limit') }}</label>
                <input type="number" id="history_limit" class="form-control" value="500" min="1" max="5000"/>
            </div>
            <div class="col-md-1">
                <label>&nbsp;</label>
                <button class="btn btn-primary form-control" id="searchHistory" type="button">{{ lang._('Search') }}</button>
            </div>
        </div>
        <div class="row" style="margin-top: 10px;">
            <div class="col-md-12">
                <table id="ndpi-history-table" class="table table-condensed table-hover table-striped table-responsive">
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
            </div>
        </div>
    </div>
</div>
