import { createPinia, setActivePinia } from 'pinia';
import JsSIP from 'jssip';

import InboxesAPI from 'dashboard/api/inboxes';
import { useSoftphoneStore } from '../softphone';

const uaHandlers = {};
const mockUa = {
  on: vi.fn((event, callback) => {
    uaHandlers[event] = callback;
  }),
  start: vi.fn(),
  stop: vi.fn(),
  call: vi.fn(),
};

vi.mock('dashboard/api/inboxes', () => ({
  default: {
    getPhoneCredentials: vi.fn(),
  },
}));

vi.mock('jssip', () => ({
  default: {
    WebSocketInterface: vi.fn(function WebSocketInterface(url) {
      this.url = url;
    }),
    UA: vi.fn(() => mockUa),
  },
}));

describe('softphone store', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    Object.keys(uaHandlers).forEach(key => delete uaHandlers[key]);
  });

  it('registers the current agent extension and passes ICE servers to outbound calls', async () => {
    const iceServers = [
      { urls: ['stun:stun.example.com:3478'] },
      {
        urls: ['turn:turn.example.com:3478'],
        username: '1700003600:42',
        credential: 'temporary-credential',
      },
    ];
    InboxesAPI.getPhoneCredentials.mockResolvedValue({
      data: {
        wss_url: 'wss://pbx.example.com:7443',
        sip_domain: 'pbx.example.com',
        sip_username: '1002',
        sip_password: 'sip-secret',
        ice_servers: iceServers,
      },
    });
    const store = useSoftphoneStore();

    await store.initialize(7);

    expect(JsSIP.WebSocketInterface).toHaveBeenCalledWith(
      'wss://pbx.example.com:7443'
    );
    expect(JsSIP.UA).toHaveBeenCalledWith(
      expect.objectContaining({
        uri: 'sip:1002@pbx.example.com',
        authorization_user: '1002',
        password: 'sip-secret',
      })
    );
    expect(mockUa.start).toHaveBeenCalled();

    uaHandlers.registered();
    store.call('0342387314');

    expect(mockUa.call).toHaveBeenCalledWith('sip:0342387314@pbx.example.com', {
      mediaConstraints: { audio: true, video: false },
      pcConfig: { iceServers },
    });
  });

  it('passes ICE servers when answering an inbound call', async () => {
    const iceServers = [{ urls: ['stun:stun.example.com:3478'] }];
    InboxesAPI.getPhoneCredentials.mockResolvedValue({
      data: {
        wss_url: 'wss://pbx.example.com:7443',
        sip_domain: 'pbx.example.com',
        sip_username: '1002',
        sip_password: 'sip-secret',
        ice_servers: iceServers,
      },
    });
    const store = useSoftphoneStore();
    const session = {
      on: vi.fn(),
      answer: vi.fn(),
    };

    await store.initialize(7);
    uaHandlers.newRTCSession({ originator: 'remote', session });
    store.answer();

    expect(session.answer).toHaveBeenCalledWith({
      mediaConstraints: { audio: true, video: false },
      pcConfig: { iceServers },
    });
  });
});
