<script>
    $(document).ready(function () {
        let liveTimer = null;
        let liveRows = [];
        let historyRows = [];

        const escapeHtml = function (value) {
            return $('<div/>').text(value == null ? '' : String(value)).html();
        };

        const filterRowsByPhrase = function (rows, phrase, columns) {
            if (!phrase) {
                return rows;
            }
            const token = phrase.toLowerCase();
            return rows.filter(function (row) {
                return columns.map(function (column) {
                    return String(row[column] == null ? '' : row[column]);
                }).join(' ').toLowerCase().indexOf(token) !== -1;
            });
        };

        const exportCsv = function (filename, headers, rows, columns) {
            const lines = [headers.join(',')];
            rows.forEach(function (row) {
                const cols = columns.map(function (column) {
                    const text = String(row[column] == null ? '' : row[column]).replace(/"/g, '""');
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

        const attachFooterActions = function (tableSelector, exportButtonId, exportHandler) {
            const footer = $(tableSelector + '-footer .pagination');
            if (!footer.length || $(exportButtonId).length) {
                return;
            }

            footer.before(
                '<div class="btn-group btn-group-xs" style="margin-right:8px;">' +
                '  <button id="' + exportButtonId.substring(1) + '" class="btn btn-default" type="button" title="{{ lang._("Export") }}">' +
                '    <span class="fa fa-download"></span>' +
                '  </button>' +
                '</div>'
            );

            $(exportButtonId).on('click', exportHandler);
        };

        const initBootgrid = function (tableId, noResultsLabel, onLoaded) {
            try {
                $(tableId).bootgrid('destroy');
            } catch (e) {}

            $(tableId).bootgrid({
                caseSensitive: false,
                navigation: 3,
                rowCount: [25, 50, 100, -1],
                templates: {
                    search: '<div class="search form-group"><div class="input-group"><span class="icon input-group-addon fa fa-search"></span><input type="text" class="search-field form-control" placeholder="{{ lang._("Search") }}"></div></div>'
                },
                labels: {
                    noResults: noResultsLabel,
                    infos: '{{ lang._("Showing %s to %s, total %s items") | format("{{ctx.start}}", "{{ctx.end}}", "{{ctx.total}}") }}'
                }
            }).on('loaded.rs.jquery.bootgrid', function () {
                if (typeof onLoaded === 'function') {
                    onLoaded();
                }
            });
        };

        const renderRows = function (tbody, rows, columns, emptyText) {
            tbody.empty();
            if (!Array.isArray(rows) || rows.length === 0) {
                tbody.append('<tr><td colspan="' + columns.length + '">' + emptyText + '</td></tr>');
                return;
            }
            rows.forEach(function (row, index) {
                let html = '<tr data-row-id="' + index + '">';
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

                liveRows = data.rows || [];

                renderRows(
                    tbody,
                    liveRows,
                    ['timestamp', 'src_ip', 'src_port', 'dst_ip', 'dst_port', 'protocol', 'application', 'category'],
                    '{{ lang._("No active flows") }}'
                );

                initBootgrid('#ndpi-live-table', '{{ lang._("No active flows") }}', function () {
                    $('#ndpi-live-header-tools').detach().insertAfter('#ndpi-live-table-header .actionBar .actions');
                    attachFooterActions('#ndpi-live-table', '#ndpi-live-export', function () {
                        const phrase = ($('#ndpi-live-table-header .search-field').val() || '').trim();
                        const rows = filterRowsByPhrase(liveRows, phrase, ['timestamp', 'src_ip', 'src_port', 'dst_ip', 'dst_port', 'protocol', 'application', 'category']);
                        exportCsv(
                            'appid-engine-live.csv',
                            ['Timestamp', 'Src IP', 'Src Port', 'Dst IP', 'Dst Port', 'L4', 'Application', 'Category'],
                            rows,
                            ['timestamp', 'src_ip', 'src_port', 'dst_ip', 'dst_port', 'protocol', 'application', 'category']
                        );
                    });
                });
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

                historyRows = data.rows || [];

                renderRows(
                    tbody,
                    historyRows,
                    ['timestamp', 'src_ip', 'src_port', 'dst_ip', 'dst_port', 'protocol', 'application', 'category'],
                    '{{ lang._("No records matched current filters") }}'
                );

                initBootgrid('#ndpi-history-table', '{{ lang._("No records matched current filters") }}', function () {
                    $('#ndpi-history-header-tools').detach().insertAfter('#ndpi-history-table-header .actionBar .actions');
                    attachFooterActions('#ndpi-history-table', '#ndpi-history-export', function () {
                        const phrase = ($('#ndpi-history-table-header .search-field').val() || '').trim();
                        const rows = filterRowsByPhrase(historyRows, phrase, ['timestamp', 'src_ip', 'src_port', 'dst_ip', 'dst_port', 'protocol', 'application', 'category']);
                        exportCsv(
                            'appid-engine-history.csv',
                            ['Timestamp', 'Src IP', 'Src Port', 'Dst IP', 'Dst Port', 'L4', 'Application', 'Category'],
                            rows,
                            ['timestamp', 'src_ip', 'src_port', 'dst_ip', 'dst_port', 'protocol', 'application', 'category']
                        );
                    });
                });
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
        <div class="hidden">
            <div class="btn-group" id="ndpi-live-header-tools">
                <label style="padding: 6px 8px; font-weight: normal; margin: 0;">
                    <input type="checkbox" id="liveAutoRefresh" checked="checked"/> {{ lang._('Auto refresh (5s)') }}
                </label>
                <button class="btn btn-default" id="refreshLive" type="button" title="{{ lang._('Refresh') }}">
                    <span class="fa fa-refresh"></span>
                </button>
            </div>
        </div>
        <div class="row" style="margin-top: 10px;">
            <div class="col-md-8">
                <table id="ndpi-live-table" class="table table-condensed table-hover table-striped table-responsive">
                    <thead>
                    <tr>
                        <th data-column-id="timestamp" data-type="string">{{ lang._('Timestamp') }}</th>
                        <th data-column-id="src_ip" data-type="string">{{ lang._('Src IP') }}</th>
                        <th data-column-id="src_port" data-type="string">{{ lang._('Src Port') }}</th>
                        <th data-column-id="dst_ip" data-type="string">{{ lang._('Dst IP') }}</th>
                        <th data-column-id="dst_port" data-type="string">{{ lang._('Dst Port') }}</th>
                        <th data-column-id="protocol" data-type="string">{{ lang._('L4') }}</th>
                        <th data-column-id="application" data-type="string">{{ lang._('Application') }}</th>
                        <th data-column-id="category" data-type="string">{{ lang._('Category') }}</th>
                    </tr>
                    </thead>
                    <tbody>
                    <tr><td colspan="8">{{ lang._('Loading...') }}</td></tr>
                    </tbody>
                </table>
            </div>
            <div class="col-md-4">
                <table id="ndpi-stats-table" class="table table-condensed table-striped table-responsive">
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
        <div class="hidden">
            <div class="btn-group" id="ndpi-history-header-tools">
                <button class="btn btn-default" id="refreshHistoryList" type="button" title="{{ lang._('Refresh') }}">
                    <span class="fa fa-refresh"></span>
                </button>
            </div>
        </div>
        <div class="row" style="margin-top: 10px;">
            <div class="col-md-12">
                <table id="ndpi-history-table" class="table table-condensed table-hover table-striped table-responsive">
                    <thead>
                    <tr>
                        <th data-column-id="timestamp" data-type="string">{{ lang._('Timestamp') }}</th>
                        <th data-column-id="src_ip" data-type="string">{{ lang._('Src IP') }}</th>
                        <th data-column-id="src_port" data-type="string">{{ lang._('Src Port') }}</th>
                        <th data-column-id="dst_ip" data-type="string">{{ lang._('Dst IP') }}</th>
                        <th data-column-id="dst_port" data-type="string">{{ lang._('Dst Port') }}</th>
                        <th data-column-id="protocol" data-type="string">{{ lang._('L4') }}</th>
                        <th data-column-id="application" data-type="string">{{ lang._('Application') }}</th>
                        <th data-column-id="category" data-type="string">{{ lang._('Category') }}</th>
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
