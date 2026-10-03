import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import phoneCallsAPI from 'dashboard/api/phoneCalls';
import messages from 'dashboard/i18n/locale/en/report.json';

import PhoneCallReports from './PhoneCallReports.vue';

vi.mock('dashboard/api/phoneCalls', () => ({
  default: {
    emotionReports: vi.fn(),
    updateEmotionReport: vi.fn(),
  },
}));

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('vue-router', async importOriginal => ({
  ...(await importOriginal()),
  useRoute: () => ({ params: { accountId: '1' } }),
}));

const report = {
  id: 9,
  phone_call_id: 17,
  conversation_id: 23,
  customer_number: '0345006396',
  direction: 'outbound',
  call_status: 'completed',
  status: 'completed',
  action_status: 'none',
  duration_seconds: 62,
  emotion: 'khó chịu',
  emotion_tag: { label: 'khó chịu', color: 'orange' },
};

const response = {
  data: {
    data: [report],
    counts: {
      total: 1,
      call_status: { completed: 1 },
      action_status: { none: 1 },
    },
    meta: { current_page: 1, total_pages: 1, total_entries: 1 },
  },
};

const mountComponent = () =>
  mount(PhoneCallReports, {
    global: {
      plugins: [
        createI18n({ legacy: false, locale: 'en', messages: { en: messages } }),
      ],
      stubs: {
        ReportHeader: { template: '<div><slot name="filters" /></div>' },
        RouterLink: { template: '<a><slot /></a>' },
      },
    },
  });

describe('PhoneCallReports', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    phoneCallsAPI.emotionReports.mockResolvedValue(response);
    phoneCallsAPI.updateEmotionReport.mockResolvedValue({
      data: { ...report, action_status: 'needs_follow_up' },
    });
  });

  it('loads calls and filters them by call status', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    expect(wrapper.text()).toContain('0345006396');
    expect(wrapper.text()).toContain('khó chịu');

    await wrapper.findAll('select')[0].setValue('rejected');
    await flushPromises();

    expect(phoneCallsAPI.emotionReports).toHaveBeenLastCalledWith(
      expect.objectContaining({ call_status: 'rejected', page: 1, limit: 50 })
    );
  });

  it('updates a call follow-up status from the report table', async () => {
    const wrapper = mountComponent();
    await flushPromises();

    await wrapper.find('tbody select').setValue('needs_follow_up');
    await flushPromises();

    expect(phoneCallsAPI.updateEmotionReport).toHaveBeenCalledWith(17, {
      action_status: 'needs_follow_up',
    });
  });
});
