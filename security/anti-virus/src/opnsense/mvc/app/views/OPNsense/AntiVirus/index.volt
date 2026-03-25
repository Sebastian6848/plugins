<script>
    $(document).ready(function () {
        mapDataToFormUI({
            'frm_basic': '/api/antivirus/general/get',
            'frm_tuning': '/api/antivirus/general/get'
        }).done(function () {
            $('.selectpicker').selectpicker('refresh');
        });

        $('#{{ formGridHash["table_id"] }}').UIBootgrid({
            search: '/api/antivirus/hashes/search_item/',
            get: '/api/antivirus/hashes/get_item/',
            set: '/api/antivirus/hashes/set_item/',
            add: '/api/antivirus/hashes/add_item/',
            del: '/api/antivirus/hashes/del_item/',
            toggle: '/api/antivirus/hashes/toggle_item/'
        });

        $('#reconfigureAct').SimpleActionButton({
            onPreAction: function () {
                const deferred = new $.Deferred();

                saveFormToEndpoint('/api/antivirus/general/set', 'frm_basic', function () {
                    saveFormToEndpoint('/api/antivirus/general/set', 'frm_tuning', function () {
                        deferred.resolve();
                    });
                });

                return deferred;
            }
        });

        const loadStats = function () {
            ajaxGet('/api/antivirus/logs/stats', {}, function (data) {
                const stats = (data && data.stats) ? data.stats : {};
                $('#av-stats').text(JSON.stringify(stats, null, 2));
            });
        };

        loadStats();
        setInterval(loadStats, 10000);
    });
</script>

<ul class="nav nav-tabs" data-tabs="tabs" id="maintabs">
    <li class="active"><a data-toggle="tab" href="#tab_general">{{ lang._('General Settings') }}</a></li>
    <li><a data-toggle="tab" href="#tab_hashes">{{ lang._('SHA256 Whitelist') }}</a></li>
    <li><a data-toggle="tab" href="#tab_stats">{{ lang._('Runtime Stats') }}</a></li>
</ul>

<div class="tab-content content-box">
    <div id="tab_general" class="tab-pane fade in active">
        <div class="alert alert-info" style="margin-top: 10px;">
            {{ lang._('Fail-open sidecar mode: forwarding path is never blocked. Only plaintext extraction traffic (HTTP/FTP/SMB) is scanned.') }}
        </div>
        <h3>{{ lang._('Basic Policy') }}</h3>
        {{ partial('layout_partials/base_form', ['fields': formBasic, 'id': 'frm_basic']) }}

        <h3>{{ lang._('Engine Tuning') }}</h3>
        {{ partial('layout_partials/base_form', ['fields': formTuning, 'id': 'frm_tuning']) }}
    </div>
    <div id="tab_hashes" class="tab-pane fade in">
        {{ partial('layout_partials/base_bootgrid_table', formGridHash) }}
    </div>
    <div id="tab_stats" class="tab-pane fade in">
        <pre id="av-stats" style="min-height: 200px; margin-top: 10px;"></pre>
    </div>
</div>

{{ partial('layout_partials/base_apply_button', {'data_endpoint': '/api/antivirus/service/reconfigure'}) }}
{{ partial('layout_partials/base_dialog', ['fields': formDialogHash, 'id': formGridHash['edit_dialog_id'], 'label': lang._('Edit Whitelist Entry')]) }}