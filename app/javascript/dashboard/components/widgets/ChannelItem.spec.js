import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';

import ChannelItem from './ChannelItem.vue';

const ChannelSelectorStub = {
  name: 'ChannelSelector',
  props: ['disabled'],
  emits: ['click'],
  template: '<button :disabled="disabled" @click="$emit(\'click\')" />',
};

describe('ChannelItem', () => {
  it('enables the phone channel and emits its key when selected', async () => {
    const wrapper = mount(ChannelItem, {
      props: {
        channel: {
          key: 'phone',
          title: 'Phone',
          description: 'PBX softphone',
          icon: 'i-ri-phone-fill',
        },
        enabledFeatures: { channel_website: true },
      },
      global: {
        stubs: { ChannelSelector: ChannelSelectorStub },
      },
    });

    const selector = wrapper.findComponent(ChannelSelectorStub);
    expect(selector.props('disabled')).toBe(false);

    await selector.trigger('click');
    expect(wrapper.emitted('channelItemClick')).toEqual([['phone']]);
  });
});
