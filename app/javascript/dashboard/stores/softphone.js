import { markRaw } from 'vue';
import { defineStore } from 'pinia';
import JsSIP from 'jssip';

import InboxesAPI from 'dashboard/api/inboxes';

const MEDIA_CONSTRAINTS = { audio: true, video: false };

const hasTurnServer = iceServers =>
  iceServers.some(server =>
    (Array.isArray(server.urls) ? server.urls : [server.urls]).some(
      url => url?.startsWith('turn:') || url?.startsWith('turns:')
    )
  );

const isRelayCandidate = candidate =>
  candidate?.type === 'relay' || candidate?.candidate?.includes(' typ relay ');

const finishIceGatheringOnRelay = ({ candidate, ready }) => {
  if (isRelayCandidate(candidate)) ready();
};

export const useSoftphoneStore = defineStore('softphone', {
  state: () => ({
    inboxId: null,
    sipDomain: '',
    pcConfig: undefined,
    ua: null,
    session: null,
    remoteStream: null,
    registered: false,
    status: 'idle',
    direction: null,
    remoteNumber: '',
    error: '',
    muted: false,
  }),

  getters: {
    hasSession: state => Boolean(state.session),
    isIncoming: state =>
      state.direction === 'inbound' && state.status === 'ringing',
    isActive: state => state.status === 'active',
  },

  actions: {
    async initialize(inboxId) {
      if (!inboxId || this.inboxId === inboxId) return;

      this.disconnect();
      this.inboxId = inboxId;
      this.status = 'connecting';
      this.error = '';

      try {
        const { data } = await InboxesAPI.getPhoneCredentials(inboxId);
        this.sipDomain = data.sip_domain;
        const iceServers = data.ice_servers || [];
        this.pcConfig = iceServers.length
          ? {
              iceServers,
              ...(hasTurnServer(iceServers) && {
                iceTransportPolicy: 'relay',
              }),
            }
          : undefined;
        const socket = new JsSIP.WebSocketInterface(data.wss_url);
        const configuration = {
          sockets: [socket],
          uri: `sip:${data.sip_username}@${data.sip_domain}`,
          authorization_user: data.sip_username,
          password: data.sip_password,
          register: true,
          session_timers: false,
        };

        this.ua = markRaw(new JsSIP.UA(configuration));
        this.ua.on('registered', () => {
          // JsSIP replaces the plain password with the HA1 calculated for the
          // REGISTER challenge. FreeSWITCH can challenge an outbound INVITE
          // with a different realm, so retain the password to let JsSIP build
          // the matching Proxy-Authorization digest.
          this.ua.set('password', data.sip_password);
          this.registered = true;
          this.status = this.session ? this.status : 'ready';
          this.error = '';
        });
        this.ua.on('unregistered', () => {
          this.registered = false;
          if (!this.session) this.status = 'disconnected';
        });
        this.ua.on('registrationFailed', event => {
          this.registered = false;
          this.status = 'error';
          this.error = event?.cause || 'SIP registration failed';
        });
        this.ua.on('newRTCSession', ({ originator, session }) => {
          this.handleNewSession(originator, session);
        });
        this.ua.start();
      } catch (error) {
        this.status = 'error';
        this.error = error?.message || 'Unable to initialize softphone';
      }
    },

    handleNewSession(originator, session) {
      if (this.session && this.session !== session) {
        session.terminate({ status_code: 486, reason_phrase: 'Busy Here' });
        return;
      }

      this.session = markRaw(session);
      this.direction = originator === 'remote' ? 'inbound' : 'outbound';
      this.remoteNumber = session.remote_identity?.uri?.user || '';
      this.status = originator === 'remote' ? 'ringing' : 'calling';
      this.muted = false;

      session.on('peerconnection', ({ peerconnection }) => {
        peerconnection.addEventListener('track', event => {
          this.remoteStream = markRaw(
            event.streams?.[0] || new MediaStream([event.track])
          );
        });
      });

      // JsSIP otherwise waits for every configured ICE transport to finish.
      // A TURN relay is sufficient for this non-trickle SIP call, so send the
      // offer/answer as soon as the first relay candidate is available.
      if (originator === 'remote') {
        session.on('icecandidate', finishIceGatheringOnRelay);
      }

      // An outbound RTCSession can emit peerconnection before newRTCSession.
      // Recover its remote receiver only after SIP has been accepted so this
      // fallback never interferes with offer creation or inbound answer().
      const recoverAcceptedRemoteStream = () => {
        if (this.remoteStream) return;

        const remoteTracks =
          session.connection
            ?.getReceivers?.()
            .map(receiver => receiver.track)
            .filter(track => track?.kind === 'audio') || [];
        if (remoteTracks.length) {
          this.remoteStream = markRaw(new MediaStream(remoteTracks));
        }
      };
      session.on('progress', () => {
        if (this.direction === 'outbound') this.status = 'ringing';
      });
      session.on('accepted', () => {
        recoverAcceptedRemoteStream();
        this.status = 'active';
      });
      session.on('confirmed', () => {
        recoverAcceptedRemoteStream();
        this.status = 'active';
      });
      session.on('ended', () => {
        this.resetSession(this.getPostCallStatus());
      });
      session.on('failed', event => {
        this.error = event?.cause || 'Call failed';
        this.resetSession(this.getPostCallStatus(true));
      });
    },

    getPostCallStatus(failed = false) {
      if (!this.inboxId) return 'idle';
      if (this.registered) return 'ready';
      return failed ? 'error' : 'disconnected';
    },

    call(number) {
      const destination = String(number || '').trim();
      if (!destination || !this.ua || !this.registered || this.session) return;

      this.error = '';
      this.ua.call(`sip:${destination}@${this.sipDomain}`, {
        eventHandlers: {
          icecandidate: finishIceGatheringOnRelay,
        },
        mediaConstraints: MEDIA_CONSTRAINTS,
        pcConfig: this.pcConfig,
      });
    },

    answer() {
      if (!this.isIncoming) return;
      this.session.answer({
        mediaConstraints: MEDIA_CONSTRAINTS,
        pcConfig: this.pcConfig,
      });
    },

    reject() {
      if (!this.session) return;
      this.session.terminate({ status_code: 486, reason_phrase: 'Busy Here' });
    },

    hangup() {
      this.session?.terminate();
    },

    toggleMute() {
      if (!this.session || !this.isActive) return;
      if (this.muted) {
        this.session.unmute({ audio: true });
      } else {
        this.session.mute({ audio: true });
      }
      this.muted = !this.muted;
    },

    sendDTMF(tone) {
      if (this.session && this.isActive) this.session.sendDTMF(tone);
    },

    resetSession(nextStatus = 'ready') {
      this.session = null;
      this.remoteStream = null;
      this.direction = null;
      this.remoteNumber = '';
      this.muted = false;
      this.status = nextStatus;
    },

    disconnect() {
      this.session?.terminate();
      this.ua?.stop();
      this.ua = null;
      this.pcConfig = undefined;
      this.inboxId = null;
      this.registered = false;
      this.resetSession('idle');
    },
  },
});
