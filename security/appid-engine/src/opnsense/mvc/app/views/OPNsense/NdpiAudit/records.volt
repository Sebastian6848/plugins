<script>
    $(document).ready(function () {
        let liveTimer = null;

        const exportLink = function (baseUrl, params) {
            const parts = [];
            Object.keys(params).forEach(function (key) {
                const value = params[key];
                if (value !== null && value !== undefined && String(value).trim() !== '') {
                    parts.push(encodeURIComponent(key) + '=' + encodeURIComponent(value));
                }
            });

            if (parts.length > 0) {
                window.open(baseUrl + '?' + parts.join('&'));
            } else {
                window.open(baseUrl);
            }
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
                    const bar = '<div class="progress">' +
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

        const liveGrid = $('#ndpi-live-table').UIBootgrid({
            search: '/api/ndpiaudit/audit/search_live',
            options: {
                selection: false,
                rowSelect: false,
                multiSelect: false,
                keepSelection: false,
                rowCount: [25, 50, 100, 200],
                requestHandler: function (request) {
                    request.window = $('#live_window').val() || '120';
                    request.limit = 4000;
                    return request;
                }
            },
            commands: {
                download: {
                    footer: true,
                    classname: 'fa fa-fw fa-table',
                    title: "{{ lang._('Export as csv') }}",
                    method: function (e) {
                        e.preventDefault();
                        exportLink('/api/ndpiaudit/audit/export_live', {
                            window: $('#live_window').val() || '120',
                            searchPhrase: $('#ndpi-live-table-header .search-field').val() || ''
                        });
                    },
                    sequence: 500
                }
            }
        });

        const historyGrid = $('#ndpi-history-table').UIBootgrid({
            search: '/api/ndpiaudit/audit/search_history',
            options: {
                selection: false,
                rowSelect: false,
                multiSelect: false,
                keepSelection: false,
                rowCount: [25, 50, 100, 200, 500],
                requestHandler: function (request) {
                    request.ip = $('#history_ip').val() || '';
                    request.app = $('#history_app').val() || '';
                    request.start = $('#history_start').val() || '';
                    request.end = $('#history_end').val() || '';
                    request.limit = $('#history_limit').val() || '5000';
                    return request;
                }
            },
            commands: {
                download: {
                    footer: true,
                    classname: 'fa fa-fw fa-table',
                    title: "{{ lang._('Export as csv') }}",
                    method: function (e) {
                        e.preventDefault();
                        exportLink('/api/ndpiaudit/audit/export_history', {
                            ip: $('#history_ip').val() || '',
                            app: $('#history_app').val() || '',
                            start: $('#history_start').val() || '',
                            end: $('#history_end').val() || '',
                            limit: $('#history_limit').val() || '5000',
                            searchPhrase: $('#ndpi-history-table-header .search-field').val() || ''
                        });
                    },
                    sequence: 500
                }
            }
        });

        liveGrid.on('loaded.rs.jquery.bootgrid', function () {
            $('#live_toolbar').detach().insertAfter('#ndpi-live-table-header .search');
        });

        historyGrid.on('loaded.rs.jquery.bootgrid', function () {
            $('#history_toolbar').detach().insertAfter('#ndpi-history-table-header .search');
        });

        const setLiveAutoRefresh = function (enabled) {
            if (liveTimer !== null) {
                clearInterval(liveTimer);
                liveTimer = null;
            }
            if (enabled) {
                liveTimer = setInterval(function () {
                    $('#ndpi-live-table').bootgrid('reload');
                    refreshStats();
                }, 5000);
            }
        };

        $('#refreshLive').on('click', function () {
            $('#ndpi-live-table').bootgrid('reload');
            refreshStats();
        });

        $('#searchHistory').on('click', function () {
            $('#ndpi-history-table').bootgrid('reload');
        });

        $('#liveAutoRefresh').on('change', function () {
            setLiveAutoRefresh($(this).is(':checked'));
        });

        $('#live_window').on('change', function () {
            $('#ndpi-live-table').bootgrid('reload');
        });

        $('#history_toolbar').on('keypress', 'input', function (event) {
            if (event.which === 13) {
                event.preventDefault();
                $('#ndpi-history-table').bootgrid('reload');
            }
        });

        $('a[href="#tab_stats"]').on('shown.bs.tab', function () {
            $('#ndpi-live-table').bootgrid('reload');
            refreshStats();
        });

        $('a[href="#tab_search"]').on('shown.bs.tab', function () {
            $('#ndpi-history-table').bootgrid('reload');
        });

        refreshStats();
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
            <div class="btn-group" id="live_toolbar">
                <select id="live_window" data-width="120px" class="selectpicker" data-title="{{ lang._('Window') }}">
                    <option value="60">60s</option>
                    <option value="120" selected="selected">120s</option>
                    <option value="300">300s</option>
                </select>
                <label class="btn btn-default" style="font-weight: normal;">
                    <input type="checkbox" id="liveAutoRefresh" checked="checked"/> {{ lang._('Auto refresh') }}
                </label>
                <button class="btn btn-default" id="refreshLive" type="button" title="{{ lang._('Refresh') }}">
                    <span class="fa fa-refresh"></span>
                </button>
            </div>
        </div>
        <div class="row">
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
                    <tbody></tbody>
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
                    <tbody></tbody>
                </table>
            </div>
        </div>
    </div>

    <div id="tab_search" class="tab-pane fade in">
        <div class="hidden">
            <div class="input-group" id="history_toolbar" style="max-width: 1120px;">
                <span class="input-group-addon">{{ lang._('IP') }}</span>
                <input type="text" id="history_ip" class="form-control" placeholder="192.168.1.10"/>
                <span class="input-group-addon">{{ lang._('Application') }}</span>
                <input type="text" id="history_app" class="form-control" placeholder="YouTube"/>
                <span class="input-group-addon">{{ lang._('Start') }}</span>
                <input type="datetime-local" id="history_start" class="form-control"/>
                <span class="input-group-addon">{{ lang._('End') }}</span>
                <input type="datetime-local" id="history_end" class="form-control"/>
                <span class="input-group-addon">{{ lang._('Limit') }}</span>
                <input type="number" id="history_limit" class="form-control" value="5000" min="200" max="10000"/>
                <span class="input-group-btn">
                    <button class="btn btn-primary" id="searchHistory" type="button">{{ lang._('Search') }}</button>
                </span>
            </div>
        </div>
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
            <tbody></tbody>
        </table>
    </div>
</div>
