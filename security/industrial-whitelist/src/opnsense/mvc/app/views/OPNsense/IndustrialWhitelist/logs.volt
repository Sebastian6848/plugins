<script>
    $(document).ready(function () {
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

                        if (phrase.trim() !== '') {
                            params.push('searchPhrase=' + encodeURIComponent(phrase));
                        }
                        params.push('limit=' + encodeURIComponent(limit));

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

        $('#refreshIndustrialLog').on('click', function () {
            $('#industrial-log-table').bootgrid('reload');
        });
    });
</script>

<div class="content-box">
    <div class="hidden">
        <div id="iw_log_toolbar" class="btn-group">
            <select id="iw_log_limit" data-width="130px" class="selectpicker" data-title="{{ lang._('Records') }}">
                <option value="2000">2000</option>
                <option value="5000" selected="selected">5000</option>
                <option value="10000">10000</option>
            </select>
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
        <tbody></tbody>
    </table>
</div>
