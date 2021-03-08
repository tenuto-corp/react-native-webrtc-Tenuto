'use strict';
/*
* 2에서 추가로 구현한 함수들
* RTCPeerConnection.addTransceiver()
* RTCPeerConnection.getTranscievers();
* RTCRtpTrasceiver.stop()
* RTCRtpTrasceiver.direction
* RTCRtpTrasceiver.currentDirection
* RTCRtpTrasceiver.mid
* RTCRtpTrasceiver.receiver
* RTCRtpTrasceiver.sender
* RTCRtpSender.replaceTrack
* RTCRtpReceiver.track
* */
import EventTarget from 'event-target-shim';
import {NativeModules, NativeEventEmitter} from 'react-native';

import MediaStream from './MediaStream';
import MediaStreamEvent from './MediaStreamEvent';
import MediaStreamTrack from './MediaStreamTrack';
import MediaStreamTrackEvent from './MediaStreamTrackEvent';
import RTCDataChannel from './RTCDataChannel';
import RTCDataChannelEvent from './RTCDataChannelEvent';
import RTCSessionDescription from './RTCSessionDescription';
import RTCIceCandidate from './RTCIceCandidate';
import RTCIceCandidateEvent from './RTCIceCandidateEvent';
import RTCEvent from './RTCEvent';
import RTCRtpTransceiver from './RTCRtpTransceiver';
import RTCRtpSender from './RTCRtpSender';
import RtpSender from "./RTCRtpSenderTemp"; // FLAG: TODO: 이건 수정해야함. .
import * as RTCUtil from './RTCUtil';
import EventEmitter from './EventEmitter';

const {WebRTCModule} = NativeModules;

type RTCSignalingState =
    'stable' |
    'have-local-offer' |
    'have-remote-offer' |
    'have-local-pranswer' |
    'have-remote-pranswer' |
    'closed';

type RTCIceGatheringState =
    'new' |
    'gathering' |
    'complete';

type RTCPeerConnectionState =
    'new' |
    'connecting' |
    'connected' |
    'disconnected' |
    'failed' |
    'closed';

type RTCIceConnectionState =
    'new' |
    'checking' |
    'connected' |
    'completed' |
    'failed' |
    'disconnected' |
    'closed';

const PEER_CONNECTION_EVENTS = [
    'connectionstatechange',
    'icecandidate',
    'icecandidateerror',
    'iceconnectionstatechange',
    'icegatheringstatechange',
    'negotiationneeded',
    'signalingstatechange',
    // Peer-to-peer Data API:
    'datachannel',
    // old:
    'addstream',
    'removestream',
    // new:
    'track', //FLAG: 2에 있어서 조금 바꾸면서 추가함
];

let nextPeerConnectionId = 0;

export default class RTCPeerConnection extends EventTarget(PEER_CONNECTION_EVENTS) {
    localDescription: RTCSessionDescription;
    remoteDescription: RTCSessionDescription;

    signalingState: RTCSignalingState = 'stable';
    iceGatheringState: RTCIceGatheringState = 'new';
    connectionState: RTCPeerConnectionState = 'new';
    iceConnectionState: RTCIceConnectionState = 'new';

    onconnectionstatechange: ?Function;
    onicecandidate: ?Function;
    onicecandidateerror: ?Function;
    oniceconnectionstatechange: ?Function;
    onicegatheringstatechange: ?Function;
    onnegotiationneeded: ?Function;
    onsignalingstatechange: ?Function;

    ontrack: ?Function; // 이러면 그냥 되는걸까?
    onaddstream: ?Function;
    onremovestream: ?Function;

    //FLAG: 2에 있어서 조금 바꾸면서 추가함
    onaddtrack: ?Function;
    onremovetrack: ?Function;

    _peerConnectionId: number;
    _localStreams: Array<MediaStream> = [];
    _senders: Array<RtpSender> = []; //TODO: 안쓰기 때문에 deprecate해야함.
    _remoteStreams: Array<MediaStream> = [];
    _subscriptions: Array<any>;
    _transceivers: Array<RTCRtpTransceiver> = [];
    _closed:Boolean = false;
    /**
     * The RTCDataChannel.id allocator of this RTCPeerConnection.
     */
    _dataChannelIds: Set = new Set();

    constructor(configuration) {
        super();
        this._peerConnectionId = nextPeerConnectionId++;
        WebRTCModule.peerConnectionInit(configuration, this._peerConnectionId);
        this._registerEvents();
    }

    get isClosed(){
        return this._closed;
    }
    set isClosed(closed){
        this._closed = closed;
    }

    addStream(stream: MediaStream) {// FLAG: callback으로 바꿨으니 callback으로 해주긴 하는데 왜 callback일까?
        return new Promise((res, rej) => {
            const index = this._localStreams.indexOf(stream);
            if (index !== -1) {
                return;
            }
            WebRTCModule.peerConnectionAddStream(stream._reactTag, this._peerConnectionId, (successful, data) => {
                if (successful) {
                    resolve();
                } else {
                    reject(data);
                }
            });
            this._localStreams.push(stream);
        });
    }

    removeStream(stream: MediaStream) {
        const index = this._localStreams.indexOf(stream);
        if (index === -1) {
            return;
        }
        this._localStreams.splice(index, 1);
        WebRTCModule.peerConnectionRemoveStream(stream._reactTag, this._peerConnectionId);
    }

    addTransceiver(source: 'audio' | 'video' | MediaStreamTrack, init) {//TODO: FLAG: 2꺼 다시 보고 FIX하기
        return new Promise((resolve, reject) => {
            console.log('RTCPeerConnection: addTransceiver');
            let src;
            if (source === 'audio') {
                src = {type: 'audio'};
            } else if (source === 'video') {
                src = {type: 'video'};
            } else {
                src = {trackId: source.id}; //FLAG: 이부분에 오타있어서 수정함.
            }

            WebRTCModule.peerConnectionAddTransceiver(this._peerConnectionId, {
                ...src,
                init: {...init}
            }, (successful, data) => {
                if (successful) {
                    console.log('RTCPeerConnection: addTransceiver Successful');
                    this._mergeState(data.state);
                    resolve(this._transceivers.find((v) => v.id === data.id));
                } else {
                    console.log('RTCPeerConnection: addTransceiver Rejecting');
                    reject(data);
                }
            });
        });
    };

    // FLAG: 추가함.
    addTrackV1(track: MediaStreamTrack) {// Version 1
        return new Promise((resolve, reject) => {
            console.log("Add Track Called", track.kind);
            let sender = this._senders.find((sender) => (sender.track && sender.track().id === track.id));
            if (sender !== undefined) {
                return;
            }
            WebRTCModule.peerConnectionAddTrack(track.id, this._peerConnectionId, (successful, data) => {
                if (successful) {
                    const info = {
                        id: data.track.id,
                        kind: data.track.kind,
                        label: data.track.kind, //FLAG: native쪽에서 label에 대한 정보를 안넣음.(없어서일까? 그냥 빼먹은거일까?) WebRTCModule.java의 760번째 코드 참고
                        enabled: data.track.enabled,
                        readyState: data.track.readyState,
                        remote: data.track.remote,
                    };
                    //FLAG: 위에서 let으로 선언해서 그냥 overwrite
                    sender = new RtpSender(data.id, new MediaStreamTrack(info));
                    this._senders.push(sender); // FLAG: 이렇게 해도 안정적인걸까?
                    resolve(sender);
                } else {
                    reject(data);
                }
            })
        })
    }
    // return Promise<RtpSender|undefined>
    addTrack(track: MediaStreamTrack){ // Version 3
        return new Promise((resolve, reject)=>{
            // 1. pc가 close인지 확인
            if(this.isClosed){
                reject('InvalidStateError: PC is Closed');
            }

            // 2. track을 더해줄 transceiver를 찾는다.
            const transceivers = this.getTransceivers();
            const existing = transceivers.find((t) => (t.sender.track == null && t.kind === track.kind));
            if(existing){
                WebRTCModule.peerConnectionAddTrackV3(this._peerConnectionId, track.id, (successful, data)=>{
                    if(successful){
                        const trackInfo = {
                            id: data.track.id,
                            kind: data.track.kind,
                            label: data.track.kind,
                            enabled: data.track.enabled,
                            readyState: data.track.readyState,
                            remote: data.track.remote,
                        };
                        if(!data.reuse){
                            console.warn("existing이면 reuse는 반드시 True여야할텐데");
                        }
                        existing.sender.id = data.id;
                        existing.sender.track = new MediaStreamTrack(trackInfo);
                        // existing.direction = "sendrecv";
                        resolve(existing.sender);
                    }else{
                        reject(data);
                    }
                });
            }else{
                console.log("NOT EXISTING");
                reject("No Transceiver exists");
                // 다른 라이브러리에서는 자동으로 이걸 추가해주기도 하는 것 같다. 하지만 일단 TenuClient에서는 addTransceiver를 하고 나서 동작하기 때문에! 이럴 일이 없을 것..
            }
        });
    }

    //FLAG: 추가한 코드. Version2
    removeTrack(sender: RTCRtpSender) {
        return new Promise((resolve, reject) => {
            const theSender = this.getTransceivers().find(t => t.sender === sender);
            if (!theSender) {
                return;
            }
            WebRTCModule.peerConnectionRemoveTrackV2(this._peerConnectionId, theSender.sender.id(), (successful) => {
                if(successful){
                    theSender.sender.track = null;
                    theSender.stop();
                }
                resolve(successful);
            })
        })
    }

    removeTrackV1(sender: RtpSender) {
        return new Promise((resolve, reject) => {
            const index = this._senders.indexOf(sender);
            if (index === -1) {
                return;
            }
            WebRTCModule.peerConnectionRemoveTrack(sender.id(),
                this._peerConnectionId, (successful) => {
                    if (successful) {
                        this._senders.splice(index, 1);
                    }
                    resolve(successful);
                });
        });
    }

    getSenders() {
        const transceivers = this.getTransceivers();
        const senders = [];
        for (let index = 0; index < transceivers.length; index += 1) {
            if (!transceivers[index].isStopped) {
                senders.push(transceivers[index].sender);
            }
        }
        return senders;
    }


    createOffer(options) {
        return new Promise((resolve, reject) => {
            WebRTCModule.peerConnectionCreateOffer(
                this._peerConnectionId,
                RTCUtil.normalizeOfferAnswerOptions(options),
                (successful, data) => {
                    if (successful) {
                        this._mergeState(data.state);
                        resolve(new RTCSessionDescription(data.session));
                    } else {
                        reject(data); // TODO: convert to NavigatorUserMediaError
                    }
                });
        });
    }

    createAnswer(options = {}) {
        return new Promise((resolve, reject) => {
            WebRTCModule.peerConnectionCreateAnswer(
                this._peerConnectionId,
                RTCUtil.normalizeOfferAnswerOptions(options),
                (successful, data) => {
                    if (successful) {
                        this._mergeState(data.state);
                        resolve(new RTCSessionDescription(data.session));
                    } else {
                        reject(data);
                    }
                });
        });
    }

    setConfiguration(configuration) {
        WebRTCModule.peerConnectionSetConfiguration(configuration, this._peerConnectionId);
    }

    setLocalDescription(sessionDescription: RTCSessionDescription) {
        return new Promise((resolve, reject) => {
            WebRTCModule.peerConnectionSetLocalDescription(
                sessionDescription.toJSON ? sessionDescription.toJSON() : sessionDescription,
                this._peerConnectionId,
                (successful, data) => {
                    if (successful) {
                        this.localDescription = sessionDescription;
                        this._mergeState(data.state);
                        resolve();
                    } else {
                        reject(data);
                    }
                });
        });
    }

    setRemoteDescription(sessionDescription: RTCSessionDescription) {
        return new Promise((resolve, reject) => {
            WebRTCModule.peerConnectionSetRemoteDescription(
                sessionDescription.toJSON ? sessionDescription.toJSON() : sessionDescription,
                this._peerConnectionId,
                (successful, data) => {
                    if (successful) {
                        this.remoteDescription = sessionDescription;
                        this._mergeState(data.state);
                        resolve();
                    } else {
                        reject(data);
                    }
                });
        });
    }

    addIceCandidate(candidate) {
        return new Promise((resolve, reject) => {
            WebRTCModule.peerConnectionAddICECandidate(
                candidate.toJSON ? candidate.toJSON() : candidate,
                this._peerConnectionId,
                (successful) => {
                    if (successful) {
                        resolve()
                    } else {
                        // XXX: This should be OperationError
                        reject(new Error('Failed to add ICE candidate'));
                    }
                });
        });
    }

    getStats() {
        return WebRTCModule.peerConnectionGetStats(this._peerConnectionId)
            .then(data => {
                /* On both Android and iOS it is faster to construct a single
                 JSON string representing the Map of StatsReports and have it
                 pass through the React Native bridge rather than the Map of
                 StatsReports. While the implementations do try to be faster in
                 general, the stress is on being faster to pass through the React
                 Native bridge which is a bottleneck that tends to be visible in
                 the UI when there is congestion involving UI-related passing.

                 TODO Implement the logic for filtering the stats based on
                 the sender/receiver
                 */
                return new Map(JSON.parse(data));
            });
    }

    getLocalStreams() {
        return this._localStreams.slice();
    }

    getRemoteStreams() {
        return this._remoteStreams.slice();
    }

    getTransceivers() {
        return this._transceivers.slice();
    }

    close() {
        this.isClosed = true;
        WebRTCModule.peerConnectionClose(this._peerConnectionId);
    }

    _getTrack(streamReactTag, trackId): MediaStreamTrack {
        const stream
            = this._remoteStreams.find(
            stream => stream._reactTag === streamReactTag);

        return stream && stream._tracks.find(track => track.id === trackId);
    }

    _getTransceiver(state): RTCRtpTransceiver {
        const existing = this._transceivers.find((t) => t.id === state.id);
        // console.log(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>");
        // console.log(state.id);
        if (existing) {
            // console.log('EE');
            existing._updateState(state);
            return existing;
        } else {
            // console.log('NN');
            let res = new RTCRtpTransceiver(this._peerConnectionId, state, (s) => this._mergeState(s));
            this._transceivers.push(res);
            return res;
        }
    }

    _mergeState(state): void {
        if (!state) {
            return;
        }

        // Merge Transceivers states
        if (state.transceivers) {
            // Apply states
            for (let transceiver of state.transceivers) {
                this._getTransceiver(transceiver);
            }
            // Restore Order
            this._transceivers =
                this._transceivers.map((t, i) => this._transceivers.find((t2) => t2.id === state.transceivers[i].id));
        }
    }

    _unregisterEvents(): void {
        this.isClosed = true;
        this._subscriptions.forEach(e => e.remove());
        this._subscriptions = [];
    }

    _registerEvents(): void {
        this._subscriptions = [
            EventEmitter.addListener('peerConnectionOnRenegotiationNeeded', ev => {
                if (ev.id !== this._peerConnectionId) {
                    return;
                }
                this.dispatchEvent(new RTCEvent('negotiationneeded'));
            }),
            EventEmitter.addListener('peerConnectionIceConnectionChanged', ev => {
                if (ev.id !== this._peerConnectionId) {
                    return;
                }
                this.iceConnectionState = ev.iceConnectionState;
                this.dispatchEvent(new RTCEvent('iceconnectionstatechange'));
                if (ev.iceConnectionState === 'closed') {
                    // This PeerConnection is done, clean up event handlers.
                    this._unregisterEvents();

                }
            }),
            EventEmitter.addListener('peerConnectionStateChanged', ev => {
                if (ev.id !== this._peerConnectionId) {
                    return;
                }
                this.connectionState = ev.connectionState;
                this.dispatchEvent(new RTCEvent('connectionstatechange'));
                if (ev.connectionState === 'closed') {
                    // This PeerConnection is done, clean up event handlers.
                    this._unregisterEvents();
                }
            }),
            EventEmitter.addListener('peerConnectionSignalingStateChanged', ev => {
                if (ev.id !== this._peerConnectionId) {
                    return;
                }
                this.signalingState = ev.signalingState;
                this.dispatchEvent(new RTCEvent('signalingstatechange'));
            }),
            EventEmitter.addListener('peerConnectionAddedTrack', ev => {
                // console.warn('peerConnectionAddedTrack event listened');
                if (ev.id !== this._peerConnectionId) {
                    // console.warn('ev.id !== this._peerConnectionId', ev.id, this._peerConnectionId);
                    return;
                }
                ev.id = ev.track.trackId;
                delete ev.track.trackId; // 이부분 뭔가 이상쓰~
                console.log(ev.track);
                const track = new MediaStreamTrack(ev.track);
                let stream1 = ev.streams[0];
                const stream = new MediaStream(stream1);
                this.dispatchEvent(new MediaStreamTrackEvent('track', {...ev, track:track, streams: [stream]}));
            }),
            EventEmitter.addListener('peerConnectionAddedStream', ev => {
                if (ev.id !== this._peerConnectionId) {
                    return;
                }
                const stream = new MediaStream(ev);
                this._remoteStreams.push(stream);
                this.dispatchEvent(new MediaStreamEvent('addstream', {stream}));
            }),
            EventEmitter.addListener('peerConnectionRemovedStream', ev => {
                if (ev.id !== this._peerConnectionId) {
                    return;
                }
                const stream = this._remoteStreams.find(s => s._reactTag === ev.streamId);
                if (stream) {
                    const index = this._remoteStreams.indexOf(stream);
                    if (index !== -1) {
                        this._remoteStreams.splice(index, 1);
                    }
                }
                console.log('in RTCPeerConnection, removedStream: ', stream);
                this.dispatchEvent(new MediaStreamEvent('removestream', {stream}));
            }),
            EventEmitter.addListener('mediaStreamTrackMuteChanged', ev => {
                if (ev.peerConnectionId !== this._peerConnectionId) {
                    return;
               }
                const track = this._getTrack(ev.streamReactTag, ev.trackId);
                if (track) {
                    track.muted = ev.muted;
                    const eventName = ev.muted ? 'mute' : 'unmute';
                    track.dispatchEvent(new MediaStreamTrackEvent(eventName, {track}));
                }
            }),
            EventEmitter.addListener('peerConnectionGotICECandidate', ev => {
                if (ev.id !== this._peerConnectionId) {
                    return;
                }
                const candidate = new RTCIceCandidate(ev.candidate);
                const event = new RTCIceCandidateEvent('icecandidate', {candidate});
                this.dispatchEvent(event);
            }),
            EventEmitter.addListener('peerConnectionIceGatheringChanged', ev => {
                if (ev.id !== this._peerConnectionId) {
                    return;
                }
                this.iceGatheringState = ev.iceGatheringState;

                if (this.iceGatheringState === 'complete') {
                    this.dispatchEvent(new RTCIceCandidateEvent('icecandidate', null));
                }

                this.dispatchEvent(new RTCEvent('icegatheringstatechange'));
            }),
            EventEmitter.addListener('peerConnectionDidOpenDataChannel', ev => {
                if (ev.id !== this._peerConnectionId) {
                    return;
                }
                const evDataChannel = ev.dataChannel;
                const id = evDataChannel.id;
                // XXX RTP data channels are not defined by the WebRTC standard, have
                // been deprecated in Chromium, and Google have decided (in 2015) to no
                // longer support them (in the face of multiple reported issues of
                // breakages).
                if (typeof id !== 'number' || id === -1) {
                    return;
                }
                const channel
                    = new RTCDataChannel(
                    this._peerConnectionId,
                    evDataChannel.label,
                    evDataChannel);
                // XXX webrtc::PeerConnection checked that id was not in use in its own
                // SID allocator before it invoked us. Additionally, its own SID
                // allocator is the authority on ResourceInUse. Consequently, it is
                // (pretty) safe to update our RTCDataChannel.id allocator without
                // checking for ResourceInUse.
                this._dataChannelIds.add(id);
                this.dispatchEvent(new RTCDataChannelEvent('datachannel', {channel}));
            })
        ];
    }

    /**
     * Creates a new RTCDataChannel object with the given label. The
     * RTCDataChannelInit dictionary can be used to configure properties of the
     * underlying channel such as data reliability.
     *
     * @param {string} label - the value with which the label attribute of the new
     * instance is to be initialized
     * @param {RTCDataChannelInit} dataChannelDict - an optional dictionary of
     * values with which to initialize corresponding attributes of the new
     * instance such as id
     */
    createDataChannel(label: string, dataChannelDict?: ?RTCDataChannelInit) {
        let id;
        const dataChannelIds = this._dataChannelIds;
        if (dataChannelDict && 'id' in dataChannelDict) {
            id = dataChannelDict.id;
            if (typeof id !== 'number') {
                throw new TypeError('DataChannel id must be a number: ' + id);
            }
            if (dataChannelIds.has(id)) {
                throw new ResourceInUse('DataChannel id already in use: ' + id);
            }
        } else {
            // Allocate a new id.
            // TODO Remembering the last used/allocated id and then incrementing it to
            // generate the next id to use will surely be faster. However, I want to
            // reuse ids (in the future) as the RTCDataChannel.id space is limited to
            // unsigned short by the standard:
            // https://www.w3.org/TR/webrtc/#dom-datachannel-id. Additionally, 65535
            // is reserved due to SCTP INIT and INIT-ACK chunks only allowing a
            // maximum of 65535 streams to be negotiated (as defined by the WebRTC
            // Data Channel Establishment Protocol).
            for (id = 1; id < 65535 && dataChannelIds.has(id); ++id) ;
            // TODO Throw an error if no unused id is available.
            dataChannelDict = Object.assign({id}, dataChannelDict);
        }
        WebRTCModule.createDataChannel(
            this._peerConnectionId,
            label,
            dataChannelDict);
        dataChannelIds.add(id);
        return new RTCDataChannel(this._peerConnectionId, label, dataChannelDict);
    }
}
