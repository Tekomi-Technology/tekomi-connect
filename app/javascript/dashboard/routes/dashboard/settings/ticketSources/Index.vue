<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { formatTicketDate } from 'dashboard/components-next/Tickets/constants';
import TicketSourceConnectionsAPI from 'dashboard/api/ticketSourceConnections';
import { useTicketPipelinesStore } from 'dashboard/stores/ticketPipelines';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import ConnectionDialog from './ConnectionDialog.vue';

const { t } = useI18n();
const pipelinesStore = useTicketPipelinesStore();

const connections = ref([]);
const providers = ref([]);
const isFetching = ref(true);
const isSaving = ref(false);
const busyAction = ref('');
const connectionDialogRef = ref(null);
const deleteDialogRef = ref(null);
const secretDialogRef = ref(null);
const connectionToDelete = ref(null);
const createdConnection = ref(null);

const pipelineName = id => pipelinesStore.getPipeline(id)?.name || `#${id}`;
const pipelines = computed(() => pipelinesStore.records);

const fetchConnections = async () => {
  try {
    const [{ data: list }, { data: providerList }] = await Promise.all([
      TicketSourceConnectionsAPI.get(),
      TicketSourceConnectionsAPI.providers(),
    ]);
    connections.value = list.payload;
    providers.value = providerList;
  } catch (error) {
    useAlert(error.message);
  } finally {
    isFetching.value = false;
  }
};

const replaceConnection = connection => {
  const index = connections.value.findIndex(item => item.id === connection.id);
  if (index === -1) connections.value.push(connection);
  else connections.value[index] = connection;
};

const errorMessage = error =>
  error.response?.data?.error || error.response?.data?.message || error.message;

const saveConnection = async ({ id, payload }) => {
  isSaving.value = true;
  try {
    const { data } = id
      ? await TicketSourceConnectionsAPI.update(id, payload)
      : await TicketSourceConnectionsAPI.create(payload);
    replaceConnection(data);
    connectionDialogRef.value?.close();
    if (id) {
      useAlert(t('TICKET_SOURCES_SETTINGS.MESSAGES.SAVED'));
    } else {
      createdConnection.value = data;
      await pipelinesStore.fetch();
      secretDialogRef.value?.open();
    }
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    isSaving.value = false;
  }
};

const runAction = async (connection, name, message) => {
  busyAction.value = `${connection.id}:${name}`;
  try {
    const { data } = await TicketSourceConnectionsAPI.action(
      connection.id,
      name
    );
    if (data?.id) replaceConnection(data);
    useAlert(message(data));
  } catch (error) {
    useAlert(errorMessage(error));
  } finally {
    busyAction.value = '';
  }
};

const testConnection = connection =>
  runAction(connection, 'test', data =>
    t('TICKET_SOURCES_SETTINGS.MESSAGES.TEST_OK', {
      user: data.display_name,
      project: data.project,
    })
  );
const syncStatuses = connection =>
  runAction(connection, 'sync_statuses', () =>
    t('TICKET_SOURCES_SETTINGS.MESSAGES.STATUSES_SYNCED')
  );
const syncNow = connection =>
  runAction(connection, 'sync', () =>
    t('TICKET_SOURCES_SETTINGS.MESSAGES.SYNC_STARTED')
  );
const toggleWebhook = connection =>
  runAction(
    connection,
    connection.webhook_registered ? 'unregister_webhook' : 'register_webhook',
    () => t('TICKET_SOURCES_SETTINGS.MESSAGES.WEBHOOK_UPDATED')
  );

const askDelete = connection => {
  connectionToDelete.value = connection;
  deleteDialogRef.value?.open();
};

const deleteConnection = async () => {
  deleteDialogRef.value?.close();
  try {
    await TicketSourceConnectionsAPI.delete(connectionToDelete.value.id);
    connections.value = connections.value.filter(
      item => item.id !== connectionToDelete.value.id
    );
    useAlert(t('TICKET_SOURCES_SETTINGS.MESSAGES.DELETED'));
  } catch (error) {
    useAlert(errorMessage(error));
  }
};

const registerCreatedWebhook = async () => {
  await runAction(createdConnection.value, 'register_webhook', () =>
    t('TICKET_SOURCES_SETTINGS.MESSAGES.WEBHOOK_UPDATED')
  );
  secretDialogRef.value?.close();
};

onMounted(() => {
  pipelinesStore.fetch().catch(error => useAlert(error.message));
  fetchConnections();
});
</script>

<template>
  <SettingsLayout
    :is-loading="isFetching"
    :loading-message="t('TICKET_SOURCES_SETTINGS.LOADING')"
    :no-records-found="!connections.length"
    :no-records-message="t('TICKET_SOURCES_SETTINGS.EMPTY')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('TICKET_SOURCES_SETTINGS.HEADER.TITLE')"
        :description="t('TICKET_SOURCES_SETTINGS.HEADER.DESCRIPTION')"
      >
        <template #actions>
          <Button
            :label="t('TICKET_SOURCES_SETTINGS.ADD')"
            icon="i-lucide-plus"
            size="sm"
            @click="connectionDialogRef?.open()"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <div class="flex flex-col gap-4 mt-4">
        <div
          v-for="connection in connections"
          :key="connection.id"
          class="flex flex-col gap-3 p-4 border rounded-xl border-n-weak bg-n-solid-2"
        >
          <div class="flex flex-wrap items-center gap-2">
            <Icon icon="i-lucide-plug-zap" class="size-5 text-n-slate-11" />
            <span class="text-base font-medium text-n-slate-12">
              {{ connection.name }}
            </span>
            <span
              class="px-2 py-0.5 text-xs uppercase rounded-md bg-n-alpha-2 text-n-slate-11"
            >
              {{ connection.provider }}
            </span>
            <span
              class="px-2 py-0.5 text-xs rounded-md"
              :class="
                connection.webhook_registered
                  ? 'bg-n-teal-3 text-n-teal-11'
                  : 'bg-n-amber-3 text-n-amber-11'
              "
            >
              {{
                connection.webhook_registered
                  ? t('TICKET_SOURCES_SETTINGS.STATUS.WEBHOOK_ON')
                  : t('TICKET_SOURCES_SETTINGS.STATUS.WEBHOOK_OFF')
              }}
            </span>
          </div>
          <div class="flex flex-wrap gap-x-6 gap-y-1 text-sm text-n-slate-11">
            <span>
              {{ t('TICKET_SOURCES_SETTINGS.FORM.PIPELINE') }}:
              {{ pipelineName(connection.pipeline_id) }}
            </span>
            <span>
              {{
                t('TICKET_SOURCES_SETTINGS.STATUS.LINKED', {
                  count: connection.linked_tickets,
                })
              }}
            </span>
            <span>
              {{
                connection.last_synced_at
                  ? t('TICKET_SOURCES_SETTINGS.STATUS.LAST_SYNCED', {
                      time: formatTicketDate(connection.last_synced_at),
                    })
                  : t('TICKET_SOURCES_SETTINGS.STATUS.NEVER')
              }}
            </span>
          </div>
          <p v-if="connection.last_error" class="text-sm text-n-ruby-11">
            {{ connection.last_error }}
          </p>
          <div class="flex flex-wrap gap-2">
            <Button
              :label="t('TICKET_SOURCES_SETTINGS.ACTIONS.TEST')"
              icon="i-lucide-plug"
              size="sm"
              variant="faded"
              color="slate"
              :is-loading="busyAction === `${connection.id}:test`"
              @click="testConnection(connection)"
            />
            <Button
              :label="t('TICKET_SOURCES_SETTINGS.ACTIONS.SYNC_STATUSES')"
              icon="i-lucide-list-checks"
              size="sm"
              variant="faded"
              color="slate"
              :is-loading="busyAction === `${connection.id}:sync_statuses`"
              @click="syncStatuses(connection)"
            />
            <Button
              :label="t('TICKET_SOURCES_SETTINGS.ACTIONS.SYNC')"
              icon="i-lucide-refresh-cw"
              size="sm"
              variant="faded"
              color="slate"
              :is-loading="busyAction === `${connection.id}:sync`"
              @click="syncNow(connection)"
            />
            <Button
              :label="
                connection.webhook_registered
                  ? t('TICKET_SOURCES_SETTINGS.ACTIONS.UNREGISTER_WEBHOOK')
                  : t('TICKET_SOURCES_SETTINGS.ACTIONS.REGISTER_WEBHOOK')
              "
              icon="i-lucide-webhook"
              size="sm"
              variant="faded"
              color="slate"
              :is-loading="
                busyAction.startsWith(`${connection.id}:`) &&
                busyAction.endsWith('webhook')
              "
              @click="toggleWebhook(connection)"
            />
            <Button
              :label="t('TICKET_SOURCES_SETTINGS.ACTIONS.EDIT')"
              icon="i-lucide-pencil"
              size="sm"
              variant="faded"
              color="slate"
              @click="connectionDialogRef?.open(connection)"
            />
            <Button
              :label="t('TICKET_SOURCES_SETTINGS.ACTIONS.DELETE')"
              icon="i-lucide-trash"
              size="sm"
              variant="faded"
              color="ruby"
              @click="askDelete(connection)"
            />
          </div>
        </div>
      </div>
    </template>

    <ConnectionDialog
      ref="connectionDialogRef"
      :providers="providers"
      :pipelines="pipelines"
      :is-saving="isSaving"
      @submit="saveConnection"
    />
    <Dialog
      ref="deleteDialogRef"
      type="alert"
      :title="
        t('TICKET_SOURCES_SETTINGS.DELETE.TITLE', {
          name: connectionToDelete?.name,
        })
      "
      :description="t('TICKET_SOURCES_SETTINGS.DELETE.DESCRIPTION')"
      :confirm-button-label="t('TICKET_SOURCES_SETTINGS.DELETE.CONFIRM')"
      @confirm="deleteConnection"
    />
    <Dialog
      ref="secretDialogRef"
      :title="t('TICKET_SOURCES_SETTINGS.CREATED.TITLE')"
      :description="t('TICKET_SOURCES_SETTINGS.CREATED.DESCRIPTION')"
      :confirm-button-label="t('TICKET_SOURCES_SETTINGS.CREATED.REGISTER')"
      :cancel-button-label="t('TICKET_SOURCES_SETTINGS.CREATED.LATER')"
      @confirm="registerCreatedWebhook"
    >
      <p class="text-sm break-all text-n-slate-11">
        {{ createdConnection?.webhook_url }}
      </p>
    </Dialog>
  </SettingsLayout>
</template>
