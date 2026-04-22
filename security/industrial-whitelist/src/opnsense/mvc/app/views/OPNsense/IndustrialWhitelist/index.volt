<script>
    $(document).ready(function () {
        const getMap = {'frm_settings': '/api/industrialwhitelist/settings/get'};
        const l7Protocols = ['modbus_tcp', 'dnp3', 'eip', 'mqtt'];
        let applyAlertTimer = null;
        let hasPendingChanges = false;

        const setPendingChanges = function (value) {
            hasPendingChanges = value;
            if (hasPendingChanges) {
                $('#iw-pending-changes-alert').show();
            } else {
                $('#iw-pending-changes-alert').hide();
            }
        };

        const refreshPrerequisiteWarning = function () {
            ajaxGet('/api/industrialwhitelist/service/prereq_status', {}, function (data, status) {
                if (status !== 'success' || !data) {
                    $('#iw-prereq-warning').show();
                    return;
                }

                if (data.ready) {
                    $('#iw-prereq-warning').hide();
                } else {
                    $('#iw-prereq-warning').show();
                }
            });
        };

        const showApplyDangerAlert = function () {
            const alertBox = $('#iw-apply-danger-alert');
            if (!alertBox.length) {
                return;
            }

            if (applyAlertTimer !== null) {
                clearTimeout(applyAlertTimer);
                applyAlertTimer = null;
            }

            alertBox.stop(true, true).fadeIn(120);
            applyAlertTimer = setTimeout(function () {
                alertBox.fadeOut(500);
            }, 2800);
        };

        const updateFunctionCodeFieldVisibility = function () {
            const dialog = $('#{{ formGridRule["edit_dialog_id"] }}');
            if (!dialog.length) {
                return;
            }

            const protocolInput = dialog.find('[name="rule.protocol"]').first();
            const functionCodeInput = dialog.find('[name="rule.AllowedFunctionCodes[]"], [name="rule.AllowedFunctionCodes"]').first();
            if (!protocolInput.length || !functionCodeInput.length) {
                return;
            }

            const selectedProtocol = protocolInput.val();
            const functionCodeGroup = functionCodeInput.closest('.form-group');
            const hintId = 'iw-l4-only-hint';
            let hintBox = dialog.find('#' + hintId);

            if (!hintBox.length) {
                hintBox = $('<div class="alert alert-info" id="' + hintId + '" style="margin-top: 8px;"></div>');
                hintBox.text('{{ lang._("Current protocol only supports network-layer (IP/port) access control.") }}');
                functionCodeGroup.after(hintBox);
            }

            if (l7Protocols.indexOf(selectedProtocol) >= 0) {
                functionCodeInput.prop('disabled', false);
                functionCodeGroup.removeClass('text-muted');
                hintBox.hide();
            } else {
                functionCodeInput.val([]);
                functionCodeInput.prop('disabled', true);
                functionCodeGroup.addClass('text-muted');
                hintBox.show();
            }

            dialog.find('.selectpicker').selectpicker('refresh');
        };

        mapDataToFormUI(getMap).done(function () {
            $('.selectpicker').selectpicker('refresh');
            setPendingChanges(false);
            refreshPrerequisiteWarning();
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
            },
            onAction: function (data) {
                if (data && data.status === 'ok') {
                    setPendingChanges(false);
                    refreshPrerequisiteWarning();
                }
            }
        });

        $('#reconfigureAct').on('click', function () {
            showApplyDangerAlert();
        });

        $('#frm_settings').on('change input', 'input,select,textarea', function () {
            setPendingChanges(true);
        });

        $(document).ajaxSuccess(function (_event, _xhr, settings) {
            const url = settings && settings.url ? settings.url : '';
            if (/\/api\/industrialwhitelist\/rules\/(set_item|add_item|del_item|toggle_item|set_sequence)/.test(url)) {
                setPendingChanges(true);
            }
        });

        $(document).on('shown.bs.modal', '#{{ formGridRule["edit_dialog_id"] }}', function () {
            updateFunctionCodeFieldVisibility();
        });

        $(document).on('change', '#{{ formGridRule["edit_dialog_id"] }} [name="rule.protocol"]', function () {
            updateFunctionCodeFieldVisibility();
        });
    });
</script>

<ul class="nav nav-tabs" data-tabs="tabs" id="maintabs">
    <li class="active"><a data-toggle="tab" href="#tab_general">{{ lang._('General Settings') }}</a></li>
    <li><a data-toggle="tab" href="#tab_rules">{{ lang._('Rules') }}</a></li>
</ul>

<div class="tab-content content-box">
    <div id="tab_general" class="tab-pane fade in active">
        <div class="alert alert-danger" id="iw-apply-danger-alert" role="alert" style="margin-top: 10px; display: none;">
            {{ lang._('⚠️ This plugin has taken over the traffic scheduling of the industrial protocol at the underlying level. The rules of the native firewall regarding these two types of ports have been silently overwritten.') }}
        </div>
        <div class="alert alert-warning" id="iw-prereq-warning" role="alert" style="margin-top: 10px;">
            {{ lang._('Prerequisite: enable Intrusion Detection and IPS mode with monitored interfaces in Services -> Intrusion Detection -> Administration.') }}
            <a class="btn btn-default btn-xs" href="/ui/ids" style="margin-left: 8px;">
                {{ lang._('Open IDS Settings') }}
            </a>
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
            <div class="alert alert-warning" id="iw-pending-changes-alert" role="alert" style="display: none;">
                {{ lang._('There are unapplied changes. Click Apply to enforce new policy.') }}
            </div>
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
