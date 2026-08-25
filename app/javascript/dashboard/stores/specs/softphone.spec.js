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
    vi.stubGlobal(
      'MediaStream',
      class MediaStream {
        constructor(tracks = []) {
          this.tracks = [...tracks];
        }

        addTrack(track) {
          this.tracks.push(track);
        }

        getTracks() {
          return this.tracks;
        }
      }
    );
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
      eventHandlers: {
        icecandidate: expect.any(Function),
      },
      mediaConstraints: { audio: true, video: false },
      pcConfig: { iceServers, iceTransportPolicy: 'relay' },
    });

    const { icecandidate } = mockUa.call.mock.calls[0][1].eventHandlers;
    const ready = vi.fn();
    icecandidate({
      candidate: { type: 'host', candidate: 'candidate:1 typ host' },
      ready,
    });
    expect(ready).not.toHaveBeenCalled();

    icecandidate({
      candidate: { type: 'relay', candidate: 'candidate:2 typ relay' },
      ready,
    });
    expect(ready).toHaveBeenCalledOnce();
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

  it('recovers an outbound remote track only after SIP is accepted', () => {
    const store = useSoftphoneStore();
    const remoteTrack = { kind: 'audio' };
    const sessionHandlers = {};
    const peerconnection = {
      getReceivers: vi.fn(() => [{ track: remoteTrack }]),
    };
    const session = {
      connection: peerconnection,
      remote_identity: { uri: { user: '0342387314' } },
      on: vi.fn((event, callback) => {
        sessionHandlers[event] = callback;
      }),
    };

    store.handleNewSession('local', session);

    expect(store.remoteStream).toBeNull();

    sessionHandlers.accepted();

    expect(store.remoteStream.getTracks()).toEqual([remoteTrack]);
  });

  it('finishes ICE gathering when a TURN relay candidate is available', () => {
    const store = useSoftphoneStore();
    const sessionHandlers = {};
    const session = {
      remote_identity: { uri: { user: '0342387314' } },
      on: vi.fn((event, callback) => {
        sessionHandlers[event] = callback;
      }),
    };
    const ready = vi.fn();

    store.handleNewSession('remote', session);
    sessionHandlers.icecandidate({
      candidate: { type: 'host', candidate: 'candidate:1 typ host' },
      ready,
    });
    expect(ready).not.toHaveBeenCalled();

    sessionHandlers.icecandidate({
      candidate: { type: 'relay', candidate: 'candidate:2 typ relay' },
      ready,
    });
    expect(ready).toHaveBeenCalledOnce();
  });
});
