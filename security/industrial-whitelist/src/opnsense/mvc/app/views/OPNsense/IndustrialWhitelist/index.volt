<script>
    $(document).ready(function () {
        const getMap = {'frm_settings': '/api/industrialwhitelist/settings/get'};

        mapDataToFormUI(getMap).done(function () {
            $('.selectpicker').selectpicker('refresh');
        });

        $('#{{ formGridRule["table_id"] }}').UIBootgrid({
            search: '/api/industrialwhitelist/rules/search_item/',
            get: '/api/industrialwhitelist/rules/get_item/',
            set: '/api/industrialwhitelist/rules/set_item/',
            add: '/api/industrialwhitelist/rules/add_item/',
            del: '/api/industrialwhitelist/rules/del_item/',
            toggle: '/api/industrialwhitelist/rules/toggle_item/',
            options: {
                sorting: false,
                rowCount: [-1, 10, 25, 50]
            }
        }).on('loaded.rs.jquery.bootgrid', function () {
            const table = $('#{{ formGridRule["table_id"] }}').closest('.tabulator').find('.tabulator-table');
            if (!table.length || table.data('iw-sortable')) {
                return;
            }

            table.data('iw-sortable', true);
            table.sortable({
                items: '.tabulator-row',
                update: function () {
                    const uuids = [];
                    table.find('.tabulator-row').each(function () {
                        const rowId = $(this).find('.command-edit').first().data('row-id');
                        if (rowId) {
                            uuids.push(rowId);
                        }
                    });

                    if (uuids.length > 0) {
                        ajaxCall('/api/industrialwhitelist/rules/set_sequence', {uuids: uuids}, function () {
                            $('#{{ formGridRule["table_id"] }}').bootgrid('reload');
                        });
                    }
                }
            });
        });

        $('#reconfigureAct').SimpleActionButton({
            onPreAction: function () {
                const deferred = new $.Deferred();
                saveFormToEndpoint('/api/industrialwhitelist/settings/set', 'frm_settings', function () {
                    deferred.resolve();
                });
                return deferred;
            }
        });
    });
</script>

<ul class="nav nav-tabs" data-tabs="tabs" id="maintabs">
    <li class="active"><a data-toggle="tab" href="#tab_general">{{ lang._('General Settings') }}</a></li>
    <li><a data-toggle="tab" href="#tab_rules">{{ lang._('Rules') }}</a></li>
</ul>

<div class="tab-content content-box">
    <div id="tab_general" class="tab-pane fade in active">
        <div class="alert alert-danger" role="alert" style="margin-top: 10px;">
            {{ lang._('⚠️ 本插件已在底层接管 Modbus(502) 及 S7Comm(102) 的流量调度，原生防火墙关于此两类端口的规则已被静默覆盖。') }}
        </div>
        {{ partial('layout_partials/base_form', ['fields': formSettings, 'id': 'frm_settings']) }}
    </div>
    <div id="tab_rules" class="tab-pane fade in">
        {{ partial('layout_partials/base_bootgrid_table', formGridRule) }}
    </div>
</div>

<section class="page-content-main">
    <div class="content-box">
        <div class="col-md-12">
            <hr/>
            <div class="alert alert-info" role="alert">
                {{ lang._('Tip: drag rows in the Rules tab to change matching priority, then click Apply.') }}
            </div>
            <button class="btn btn-primary" id="reconfigureAct"
                    data-endpoint="/api/industrialwhitelist/service/reconfigure"
                    data-label="{{ lang._('Apply') }}"
                    data-error-title="{{ lang._('Error applying industrial whitelist') }}"
                    type="button"></button>
            <br/><br/>
        </div>
    </div>
</section>

{{ partial('layout_partials/base_dialog', ['fields': formDialogRule, 'id': formGridRule['edit_dialog_id'], 'label': lang._('Edit Rule')]) }}
