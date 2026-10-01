import { ref } from 'vue';
import { flushPromises, shallowMount } from '@vue/test-utils';
import CrmInfoPanel from '../CrmInfoPanel.vue';

const testState = vi.hoisted(() => ({
  dispatch: vi.fn(),
  unmapCrm: vi.fn(),
  alert: vi.fn(),
  requestedGetters: [],
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: testState.alert,
}));

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: testState.dispatch }),
  useMapGetter: key => {
    testState.requestedGetters.push(key);
    if (key === 'contacts/getContact') {
      return ref(() => ({
        additional_attributes: {
          external: { perfex_contact_id: '42' },
          crm: { name: 'CRM customer' },
        },
      }));
    }
    return ref(undefined);
  },
}));

vi.mock('dashboard/api/contacts', () => ({
  default: {
    unmapCrm: testState.unmapCrm,
    search: vi.fn(),
  },
}));

vi.mock('dashboard/components-next/button/Button.vue', () => ({
  default: { template: '<button />' },
}));

vi.mock('dashboard/components-next/button/ConfirmButton.vue', () => ({
  default: { template: '<button />' },
}));

vi.mock('dashboard/components-next/input/Input.vue', () => ({
  default: { template: '<input />' },
}));

const mountComponent = () =>
  shallowMount(CrmInfoPanel, {
    props: { contactId: 10, conversationId: 321 },
    global: {
      mocks: { $t: key => key },
    },
  });

describe('CrmInfoPanel', () => {
  beforeEach(() => {
    testState.dispatch.mockReset().mockResolvedValue(undefined);
    testState.unmapCrm.mockReset().mockResolvedValue({});
    testState.alert.mockReset();
    testState.requestedGetters.length = 0;
  });

  it('unmaps using the conversation id supplied by the conversation screen', async () => {
    const wrapper = mountComponent();

    await wrapper.vm.unmapCrm();
    await flushPromises();

    expect(testState.unmapCrm).toHaveBeenCalledWith(10, 321);
    expect(testState.dispatch).toHaveBeenCalledWith('getConversation', 321);
    expect(testState.alert).toHaveBeenCalledWith(
      'CONVERSATION_SIDEBAR.CRM_INFO.CHANNEL_UNMAPPED'
    );
    expect(testState.requestedGetters).not.toContain('getCurrentChat');
  });
});
