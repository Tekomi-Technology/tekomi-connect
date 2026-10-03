import { markRaw } from 'vue';
import { defineStore } from 'pinia';
import JsSIP from 'jssip';

import InboxesAPI from 'dashboard/api/inboxes';

const MEDIA_CONSTRAINTS = { audio: true, video: false };
const REGISTER_EXPIRES_SECONDS = 120;

const microphoneFailureMessage = error => {
  switch (error?.name) {
    case 'NotAllowedError':
    case 'PermissionDeniedError':
      return 'Microphone permission was denied. Allow microphone access for this site and try again.';
    case 'NotFoundError':
    case 'DevicesNotFoundError':
      return 'No microphone was found. Connect a microphone and try again.';
    case 'NotReadableError':
    case 'TrackStartError':
      return 'The microphone is unavailable or is being used by another application.';
    case 'AbortError':
      return 'Microphone access was interrupted. Try answering the call again.';
    default:
      return 'Unable to access the microphone. Check browser microphone settings and try again.';
  }
};

const errorDetails = error => ({
  name: error?.name || 'Error',
  message: error?.message || String(error || ''),
});

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
    micPermission: 'unknown',
  }),

  getters: {
    hasSession: state => Boolean(state.session),
    isIncoming: state =>
      state.direction === 'inbound' && state.status === 'ringing',
    isActive: state => state.status === 'active',
  },

  actions: {
    // Surfacing the browser's microphone prompt before the first call avoids
    // JsSIP failing the session with "User Denied Media Access" mid-dial.
    async checkMicPermission() {
      if (!navigator.mediaDevices?.getUserMedia) {
        this.micPermission = 'unsupported';
        return;
      }
      try {
        const { state } = await navigator.permissions.query({
          name: 'microphone',
        });
        this.micPermission = state;
      } catch {
        // Permissions API unavailable for microphones: assume not granted yet.
        this.micPermission = 'prompt';
      }
    },

    async requestMicAccess() {
      try {
        const stream =
          await navigator.mediaDevices.getUserMedia(MEDIA_CONSTRAINTS);
        stream.getTracks().forEach(track => track.stop());
        this.micPermission = 'granted';
      } catch {
        // Blocked prompts never re-appear; the UI guides users to site settings.
        this.micPermission = 'denied';
      }
    },

    async logMediaFailure(error) {
      const diagnostic = {
        at: new Date().toISOString(),
        error: errorDetails(error),
        microphonePermission: this.micPermission,
        audioInputs: [],
      };

      try {
        const permission = await navigator.permissions?.query?.({
          name: 'microphone',
        });
        if (permission) {
          diagnostic.microphonePermission = permission.state;
          this.micPermission = permission.state;
        }
      } catch {
        // The Permissions API is not available in every supported browser.
      }

      try {
        const devices = await navigator.mediaDevices?.enumerateDevices?.();
        diagnostic.audioInputs = (devices || [])
          .filter(device => device.kind === 'audioinput')
          .map(device => ({
            deviceId: device.deviceId,
            label:
              device.label || '(label unavailable until permission is granted)',
          }));
      } catch (deviceError) {
        diagnostic.enumerateDevicesError = errorDetails(deviceError);
      }

      // This stays in the affected browser's console: no SIP password, call
      // audio, or server-side telemetry is exposed. It gives support the exact
      // device and WebRTC failure needed to investigate a rejected INVITE.
      // eslint-disable-next-line no-console
      console.error('[Softphone] Microphone/WebRTC diagnostic', diagnostic);
      return diagnostic;
    },

    handleMediaFailure(error) {
      if (
        error?.name === 'NotAllowedError' ||
        error?.name === 'PermissionDeniedError'
      ) {
        this.micPermission = 'denied';
      }
      this.error = microphoneFailureMessage(error);
      this.logMediaFailure(error);
    },

    handleWebRTCFailure(eventName, error) {
      const diagnostic = {
        at: new Date().toISOString(),
        event: eventName,
        error: errorDetails(error),
      };
      // eslint-disable-next-line no-console
      console.error('[Softphone] WebRTC diagnostic', diagnostic);
      this.error = `WebRTC failed during ${eventName}. See the browser console for details.`;
    },

    async initialize(inboxId) {
      if (!inboxId || this.inboxId === inboxId) return;

      this.disconnect();
      this.inboxId = inboxId;
      this.status = 'connecting';
      this.error = '';
      this.checkMicPermission();

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
        // Public WSS terminates at the PBX reverse proxy. FreeSWITCH receives
        // the proxied connection on its private WS listener, so its Sofia
        // transport must see WS in the SIP Via header to route responses on
        // the existing connection.
        socket.via_transport = 'WS';
        const configuration = {
          sockets: [socket],
          uri: `sip:${data.sip_username}@${data.sip_domain}`,
          authorization_user: data.sip_username,
          password: data.sip_password,
          register: true,
          register_expires: REGISTER_EXPIRES_SECONDS,
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
        this.error = this.error || event?.cause || 'Call failed';
        this.resetSession(this.getPostCallStatus(true));
      });
      session.on('getusermediafailed', error => {
        this.handleMediaFailure(error);
      });
      [
        'peerconnection:createofferfailed',
        'peerconnection:createanswerfailed',
        'peerconnection:setlocaldescriptionfailed',
        'peerconnection:setremotedescriptionfailed',
      ].forEach(eventName => {
        session.on(eventName, error => {
          this.handleWebRTCFailure(eventName, error);
        });
      });
    },

    getPostCallStatus(failed = false) {
      if (!this.inboxId) return 'idle';
      if (this.registered) return 'ready';
      return failed ? 'error' : 'disconnected';
    },

    call(number) {
      const destination = String(number || '').trim();
      if (
        !destination ||
        !this.ua ||
        !this.registered ||
        this.session ||
        this.status === 'calling'
      )
        return;

      this.error = '';
      // Lock immediately. newRTCSession is asynchronous, so relying only on
      // this.session allows rapid click/Enter events to originate two calls.
      this.status = 'calling';
      try {
        this.ua.call(`sip:${destination}@${this.sipDomain}`, {
          eventHandlers: {
            icecandidate: finishIceGatheringOnRelay,
          },
          mediaConstraints: MEDIA_CONSTRAINTS,
          pcConfig: this.pcConfig,
        });
      } catch (error) {
        this.error = error?.message || 'Unable to start call';
        this.status = this.registered ? 'ready' : 'error';
      }
    },

    async answer() {
      if (!this.isIncoming) return;
      const session = this.session;
      try {
        // Acquire the stream on the user gesture and pass that exact stream to
        // JsSIP. This prevents JsSIP from replying 480 after an opaque second
        // getUserMedia attempt and lets the UI report the browser's real error.
        const mediaStream =
          await navigator.mediaDevices.getUserMedia(MEDIA_CONSTRAINTS);
        if (this.session !== session || !this.isIncoming) {
          mediaStream.getTracks().forEach(track => track.stop());
          return;
        }
        this.micPermission = 'granted';
        session.answer({
          mediaConstraints: MEDIA_CONSTRAINTS,
          mediaStream,
          pcConfig: this.pcConfig,
        });
      } catch (error) {
        this.handleMediaFailure(error);
      }
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
