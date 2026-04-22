<script>
    $(document).ready(function () {
        const renderStatusCard = function () {
            ajaxGet('/api/industrialwhitelist/logs/status', {}, function (data, status) {
                if (status !== 'success' || !data) {
                    return;
                }

                $('#iw_status_revision').text(data.revision || '-');
                $('#iw_status_time').text(data.timestamp || '-');
                $('#iw_status_ids').text(data.ids_running ? '{{ lang._("Running") }}' : '{{ lang._("Not Running") }}');
            });
        };

        const grid = $('#industrial-log-table').UIBootgrid({
            search: '/api/industrialwhitelist/logs/search',
            options: {
                selection: false,
                rowSelect: false,
                multiSelect: false,
                keepSelection: false,
                rowCount: [25, 50, 100, 200, 500],
                requestHandler: function (request) {
                    request.limit = $('#iw_log_limit').val() || '5000';
                    request.revision = $('#iw_log_revision').val() || '';
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
                        const params = [];
                        const phrase = $('#industrial-log-table-header .search-field').val() || '';
                        const limit = $('#iw_log_limit').val() || '5000';
                        const revision = $('#iw_log_revision').val() || '';

                        if (phrase.trim() !== '') {
                            params.push('searchPhrase=' + encodeURIComponent(phrase));
                        }
                        params.push('limit=' + encodeURIComponent(limit));
                        if (revision.trim() !== '') {
                            params.push('revision=' + encodeURIComponent(revision));
                        }

                        window.open('/api/industrialwhitelist/logs/export?' + params.join('&'));
                    },
                    sequence: 500
                }
            }
        });

        grid.on('loaded.rs.jquery.bootgrid', function () {
            $('#iw_log_toolbar').detach().insertAfter('#industrial-log-table-header .search');
        });

        $('#iw_log_limit').on('change', function () {
            $('#industrial-log-table').bootgrid('reload');
        });

        $('#iw_log_revision').on('change keyup', function (event) {
            if (event.type === 'change' || event.key === 'Enter') {
                $('#industrial-log-table').bootgrid('reload');
            }
        });

        $('#refreshIndustrialLog').on('click', function () {
            $('#industrial-log-table').bootgrid('reload');
            renderStatusCard();
        });

        renderStatusCard();
    });
</script>

<div class="content-box">
    <div class="alert alert-info" role="alert">
        <strong>{{ lang._('Last Apply Revision') }}:</strong> <span id="iw_status_revision">-</span>
        &nbsp;|&nbsp;
        <strong>{{ lang._('Apply Time') }}:</strong> <span id="iw_status_time">-</span>
        &nbsp;|&nbsp;
        <strong>{{ lang._('IDS Status') }}:</strong> <span id="iw_status_ids">-</span>
    </div>

    <div class="hidden">
        <div id="iw_log_toolbar" class="btn-group">
            <select id="iw_log_limit" data-width="130px" class="selectpicker" data-title="{{ lang._('Records') }}">
                <option value="2000">2000</option>
                <option value="5000" selected="selected">5000</option>
                <option value="10000">10000</option>
            </select>
            <input id="iw_log_revision" class="form-control" style="width: 220px; margin-left: 6px;" placeholder="{{ lang._('Revision filter') }}" type="text"/>
            <button class="btn btn-default" id="refreshIndustrialLog" type="button" title="{{ lang._('Refresh') }}">
                <span class="fa fa-refresh"></span>
            </button>
        </div>
    </div>

    <table id="industrial-log-table" class="table table-condensed table-hover table-striped table-responsive">
        <thead>
        <tr>
            <th data-column-id="timestamp" data-type="string">{{ lang._('Timestamp') }}</th>
            <th data-column-id="engine" data-type="string">{{ lang._('Engine') }}</th>
            <th data-column-id="source" data-type="string">{{ lang._('Source') }}</th>
            <th data-column-id="destination" data-type="string">{{ lang._('Destination') }}</th>
            <th data-column-id="protocol_port" data-type="string">{{ lang._('Protocol/Port') }}</th>
            <th data-column-id="revision" data-type="string">{{ lang._('Revision') }}</th>
            <th data-column-id="action" data-type="string">{{ lang._('Action') }}</th>
            <th data-column-id="message" data-type="string">{{ lang._('Message') }}</th>
        </tr>
        </thead>
        <tbody></tbody>
    </table>
</div>
