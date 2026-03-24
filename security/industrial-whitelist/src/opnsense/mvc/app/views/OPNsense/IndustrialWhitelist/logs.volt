<script>
    $(document).ready(function () {
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

        renderIndustrialLogs();
    });
</script>

<div class="content-box">
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
            <td colspan="5">{{ lang._('Loading logs...') }}</td>
        </tr>
        </tbody>
    </table>
</div>
