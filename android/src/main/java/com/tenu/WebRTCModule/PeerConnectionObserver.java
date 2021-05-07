package com.tenu.WebRTCModule;

import java.io.UnsupportedEncodingException;
import java.lang.ref.SoftReference;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import androidx.annotation.Nullable;
import android.util.Base64;
import android.util.Log;
import android.util.SparseArray;

import androidx.annotation.Nullable;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;

import org.webrtc.AudioTrack;
import org.webrtc.DataChannel;
import org.webrtc.IceCandidate;
import org.webrtc.MediaStream;
import org.webrtc.MediaStreamTrack;
import org.webrtc.PeerConnection;
import org.webrtc.RtpReceiver;
import org.webrtc.RtpSender;
import org.webrtc.RtpTransceiver;
import org.webrtc.StatsObserver;
import org.webrtc.StatsReport;
import org.webrtc.VideoTrack;

import java.io.UnsupportedEncodingException;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.UUID;

class PeerConnectionObserver implements PeerConnection.Observer {
    private final static String TAG = WebRTCModule.TAG;

    private final SparseArray<DataChannel> dataChannels
            = new SparseArray<DataChannel>();
    private final int id;
    private PeerConnection peerConnection;
    final List<MediaStream> localStreams;
    final Map<String, MediaStream> remoteStreams;
    final Map<String, MediaStreamTrack> remoteTracks;
    final boolean isUnifiedPlan;
    private final VideoTrackAdapter videoTrackAdapters; // 굳이 private일 필요있을까?
    private final WebRTCModule webRTCModule;

    /**
     * The <tt>StringBuilder</tt> cache utilized by {@link #statsToJSON} in
     * order to minimize the number of allocations of <tt>StringBuilder</tt>
     * instances and, more importantly, the allocations of its <tt>char</tt>
     * buffer in an attempt to improve performance.
     */
    private SoftReference<StringBuilder> statsToJSONStringBuilder
            = new SoftReference<>(null);

    PeerConnectionObserver(WebRTCModule webRTCModule, int id, boolean isUnifiedPlan) {
        this.webRTCModule = webRTCModule;
        this.id = id;
        this.isUnifiedPlan = isUnifiedPlan;
        this.localStreams = new ArrayList<MediaStream>();
        this.remoteStreams = new HashMap<String, MediaStream>();
        this.remoteTracks = new HashMap<String, MediaStreamTrack>();
        this.videoTrackAdapters = new VideoTrackAdapter(webRTCModule, id);
    }

    /**
     * Adds a specific local <tt>MediaStream</tt> to the associated
     * <tt>PeerConnection</tt>.
     *
     * @param localStream the local <tt>MediaStream</tt> to add to the
     *                    associated <tt>PeerConnection</tt>
     * @return <tt>true</tt> if the specified <tt>localStream</tt> was added to
     * the associated <tt>PeerConnection</tt>; otherwise, <tt>false</tt>
     */
    boolean addStream(MediaStream localStream) {
        if (peerConnection != null && peerConnection.addStream(localStream)) {
            localStreams.add(localStream);

            return true;
        }

        return false;
    }

    /**
     * Removes a specific local <tt>MediaStream</tt> from the associated
     * <tt>PeerConnection</tt>.
     *
     * @param localStream the local <tt>MediaStream</tt> from the associated
     *                    <tt>PeerConnection</tt>
     * @return <tt>true</tt> if removing the specified <tt>mediaStream</tt> from
     * this instance resulted in a modification of its internal list of local
     * <tt>MediaStream</tt>s; otherwise, <tt>false</tt>
     */
    boolean removeStream(MediaStream localStream) {
        if (peerConnection != null) {
            peerConnection.removeStream(localStream);
        }

        return localStreams.remove(localStream);
    }

    /**
     * Adds a specific local <tt>MediaStream</tt> to the associated
     * <tt>PeerConnection</tt>.
     *
     * @param localStream the local <tt>MediaStream</tt> to add to the
     *                    associated <tt>PeerConnection</tt>
     * @return <tt>true</tt> if the specified <tt>localStream</tt> was added to
     * the associated <tt>PeerConnection</tt>; otherwise, <tt>false</tt>
     */
    RtpSender addTrack(MediaStreamTrack mediaStreamTrack) {
        if (peerConnection != null) {
            RtpSender sender = peerConnection.addTrack(mediaStreamTrack);
            return sender;
        }
        return null;
    }

    /**
     * Removes a specific local <tt>RtpSender</tt> from the associated
     * <tt>PeerConnection</tt>.
     *
     * @param rtpSender the local <tt>RtpSender</tt> from the associated
     *                  <tt>PeerConnection</tt>
     * @return <tt>true</tt> if removing the specified <tt>rtpSender</tt> from
     * this instance resulted in a modification of its internal list of local
     * <tt>RtpSender</tt>s; otherwise, <tt>false</tt>
     */
    boolean removeTrack(RtpSender rtpSender) {
        if (peerConnection != null) {
            boolean result = peerConnection.removeTrack(rtpSender);
            return true;
        }
        return false;
    }

    String addTransceiver(MediaStreamTrack.MediaType mediaType, RtpTransceiver.RtpTransceiverInit init) {
        if (peerConnection == null) {
            throw new Error("Impossible");
        }
        RtpTransceiver transceiver = peerConnection.addTransceiver(mediaType, init);
        return this.resolveTransceiverId(transceiver);
    }

    String addTransceiver(MediaStreamTrack track, RtpTransceiver.RtpTransceiverInit init) {
        if (peerConnection == null) {
            throw new Error("Impossible");
        }
        RtpTransceiver transceiver = peerConnection.addTransceiver(track, init);
        return this.resolveTransceiverId(transceiver);
    }

    String resolveTransceiverId(RtpTransceiver transceiver) {
        return transceiver.getSender().id();
    }

    RtpTransceiver getTransceiver(String id) {
        for (RtpTransceiver transceiver : this.peerConnection.getTransceivers()) {
            if (transceiver.getSender().id().equals(id)) {
                return transceiver;
            }
        }
        throw new Error("Unable to find transceiver");
    }


    PeerConnection getPeerConnection() {
        return peerConnection;
    }

    void setPeerConnection(PeerConnection peerConnection) {
        this.peerConnection = peerConnection;
    }

    void close() {
        Log.d(TAG, "PeerConnection.close() for " + id);

        // Close the PeerConnection first to stop any events.
        peerConnection.close();

        // PeerConnection.dispose() calls MediaStream.dispose() on all local
        // MediaStreams added to it and the app may crash if a local MediaStream
        // is added to multiple PeerConnections. In order to reduce the risks of
        // an app crash, remove all local MediaStreams from the associated
        // PeerConnection so that it doesn't attempt to dispose of them.
        for (MediaStream localStream : new ArrayList<>(localStreams)) {
            removeStream(localStream);
        }

        // Remove video track adapters
        for (MediaStream stream : remoteStreams.values()) {
            for (VideoTrack videoTrack : stream.videoTracks) {
                videoTrackAdapters.removeAdapter(videoTrack);
            }
        }

        // At this point there should be no local MediaStreams in the associated
        // PeerConnection. Call dispose() to free all remaining resources held
        // by the PeerConnection instance (RtpReceivers, RtpSenders, etc.)
        peerConnection.dispose();

        remoteStreams.clear();
        remoteTracks.clear();

        // Unlike on iOS, we cannot unregister the DataChannel.Observer
        // instance on Android. At least do whatever else we do on iOS.
        dataChannels.clear();
    }

    void createDataChannel(String label, ReadableMap config) {
        DataChannel.Init init = new DataChannel.Init();
        if (config != null) {
            if (config.hasKey("id")) {
                init.id = config.getInt("id");
            }
            if (config.hasKey("ordered")) {
                init.ordered = config.getBoolean("ordered");
            }
            if (config.hasKey("maxRetransmitTime")) {
                init.maxRetransmitTimeMs = config.getInt("maxRetransmitTime");
            }
            if (config.hasKey("maxRetransmits")) {
                init.maxRetransmits = config.getInt("maxRetransmits");
            }
            if (config.hasKey("protocol")) {
                init.protocol = config.getString("protocol");
            }
            if (config.hasKey("negotiated")) {
                init.negotiated = config.getBoolean("negotiated");
            }
        }
        DataChannel dataChannel = peerConnection.createDataChannel(label, init);
        int dataChannelId = init.id;
        if (-1 != dataChannelId) {
            dataChannels.put(dataChannelId, dataChannel);
            registerDataChannelObserver(dataChannelId, dataChannel);
        }
    }

    void dataChannelClose(int dataChannelId) {
        DataChannel dataChannel = dataChannels.get(dataChannelId);
        if (dataChannel != null) {
            dataChannel.close();
            dataChannels.remove(dataChannelId);
        } else {
            Log.d(TAG, "dataChannelClose() dataChannel is null");
        }
    }

    void dataChannelSend(int dataChannelId, String data, String type) {
        DataChannel dataChannel = dataChannels.get(dataChannelId);
        if (dataChannel != null) {
            byte[] byteArray;
            if (type.equals("text")) {
                try {
                    byteArray = data.getBytes("UTF-8");
                } catch (UnsupportedEncodingException e) {
                    Log.d(TAG, "Could not encode text string as UTF-8.");
                    return;
                }
            } else if (type.equals("binary")) {
                byteArray = Base64.decode(data, Base64.NO_WRAP);
            } else {
                Log.e(TAG, "Unsupported data type: " + type);
                return;
            }
            ByteBuffer byteBuffer = ByteBuffer.wrap(byteArray);
            DataChannel.Buffer buffer = new DataChannel.Buffer(byteBuffer, type.equals("binary"));
            dataChannel.send(buffer);
        } else {
            Log.d(TAG, "dataChannelSend() dataChannel is null");
        }
    }

    void getStats(Promise promise) {
        peerConnection.getStats(rtcStatsReport -> {
            promise.resolve(StringUtils.statsToJSON(rtcStatsReport));
        });
    }

    @Override
    public void onIceCandidate(final IceCandidate candidate) {
        Log.d(TAG, "onIceCandidate");
        WritableMap params = Arguments.createMap();
        params.putInt("id", id);
        WritableMap candidateParams = Arguments.createMap();
        candidateParams.putInt("sdpMLineIndex", candidate.sdpMLineIndex);
        candidateParams.putString("sdpMid", candidate.sdpMid);
        candidateParams.putString("candidate", candidate.sdp);
        params.putMap("candidate", candidateParams);

        webRTCModule.sendEvent("peerConnectionGotICECandidate", params);
    }

    @Override
    public void onIceCandidatesRemoved(final IceCandidate[] candidates) {
        Log.d(TAG, "onIceCandidatesRemoved");
    }

    @Override
    public void onIceConnectionChange(PeerConnection.IceConnectionState iceConnectionState) {
        WritableMap params = Arguments.createMap();
        params.putInt("id", id);
        params.putString("iceConnectionState", iceConnectionStateString(iceConnectionState));

        webRTCModule.sendEvent("peerConnectionIceConnectionChanged", params);
    }

    @Override
    public void onConnectionChange(PeerConnection.PeerConnectionState peerConnectionState) {
        WritableMap params = Arguments.createMap();
        params.putInt("id", id);
        params.putString("connectionState", peerConnectionStateString(peerConnectionState));

        webRTCModule.sendEvent("peerConnectionStateChanged", params);
    }

    @Override
    public void onIceConnectionReceivingChange(boolean var1) {
    }

    @Override
    public void onIceGatheringChange(PeerConnection.IceGatheringState iceGatheringState) {
        Log.d(TAG, "onIceGatheringChange" + iceGatheringState.name());
        WritableMap params = Arguments.createMap();
        params.putInt("id", id);
        params.putString("iceGatheringState", iceGatheringStateString(iceGatheringState));
        webRTCModule.sendEvent("peerConnectionIceGatheringChanged", params);
    }

    private String getReactTagForStream(MediaStream mediaStream) {
        for (Iterator<Map.Entry<String, MediaStream>> i
             = remoteStreams.entrySet().iterator();
             i.hasNext(); ) {
            Map.Entry<String, MediaStream> e = i.next();
            if (e.getValue().equals(mediaStream)) {
                return e.getKey();
            }
        }
        return null;
    }

    @Override
    public void onAddStream(MediaStream mediaStream) {
        Log.d(TAG, "onAddStream Called");
        String streamReactTag = null;
        String streamId = mediaStream.getId();

        // The native WebRTC implementation has a special concept of a default
        // MediaStream instance with the label default that the implementation
        // reuses.
//        if ("default".equals(streamId)) {
        for (Map.Entry<String, MediaStream> e : remoteStreams.entrySet()) {
            if (e.getValue().equals(mediaStream)) {
                streamReactTag = e.getKey();
                break;
            }
        }
//        }


        if (streamReactTag == null) {
            streamReactTag = streamId;
//            streamReactTag = UUID.randomUUID().toString();
            remoteStreams.put(streamReactTag, mediaStream);
        }

        WritableMap params = Arguments.createMap();
        params.putInt("id", id);
        params.putString("streamId", streamId);
        params.putString("streamReactTag", streamReactTag);

        WritableArray tracks = Arguments.createArray();

        for (int i = 0; i < mediaStream.videoTracks.size(); i++) {
            VideoTrack track = mediaStream.videoTracks.get(i);
            String trackId = track.id();

            remoteTracks.put(trackId, track);

            WritableMap trackInfo = Arguments.createMap();
            trackInfo.putString("id", trackId);
            trackInfo.putString("label", "Video");
            trackInfo.putString("kind", track.kind());
            trackInfo.putBoolean("enabled", track.enabled());
            trackInfo.putString("readyState", track.state().toString());
            trackInfo.putBoolean("remote", true);
            tracks.pushMap(trackInfo);

            videoTrackAdapters.addAdapter(streamReactTag, track);
        }
        for (int i = 0; i < mediaStream.audioTracks.size(); i++) {
            AudioTrack track = mediaStream.audioTracks.get(i);
            String trackId = track.id();

            remoteTracks.put(trackId, track);

            WritableMap trackInfo = Arguments.createMap();
            trackInfo.putString("id", trackId);
            trackInfo.putString("label", "Audio");
            trackInfo.putString("kind", track.kind());
            trackInfo.putBoolean("enabled", track.enabled());
            trackInfo.putString("readyState", track.state().toString());
            trackInfo.putBoolean("remote", true);
            tracks.pushMap(trackInfo);
        }
        params.putArray("tracks", tracks);

        webRTCModule.sendEvent("peerConnectionAddedStream", params);
    }

    @Override
    public void onRemoveStream(MediaStream mediaStream) {
        String streamReactTag = getReactTagForStream(mediaStream);
        if (streamReactTag == null) {
            Log.w(TAG,
                    "onRemoveStream - no remote stream for id: "
                            + mediaStream.getId());
            return;
        }

        for (VideoTrack track : mediaStream.videoTracks) {
            this.videoTrackAdapters.removeAdapter(track);
            this.remoteTracks.remove(track.id());
        }
        for (AudioTrack track : mediaStream.audioTracks) {
            this.remoteTracks.remove(track.id());
        }

        this.remoteStreams.remove(streamReactTag);

        WritableMap params = Arguments.createMap();
        params.putInt("id", id);
        params.putString("streamReactTag", streamReactTag);
        params.putString("streamId", mediaStream.getId());
        webRTCModule.sendEvent("peerConnectionRemovedStream", params);
    }

    @Override
    public void onDataChannel(DataChannel dataChannel) {
        final int dataChannelId = dataChannel.id();
        if (-1 == dataChannelId) {
            return;
        }

        WritableMap dataChannelParams = Arguments.createMap();
        dataChannelParams.putInt("id", dataChannelId);
        dataChannelParams.putString("label", dataChannel.label());
        WritableMap params = Arguments.createMap();
        params.putInt("id", id);
        params.putMap("dataChannel", dataChannelParams);

        dataChannels.put(dataChannelId, dataChannel);
        registerDataChannelObserver(dataChannelId, dataChannel);

        webRTCModule.sendEvent("peerConnectionDidOpenDataChannel", params);
    }

    private void registerDataChannelObserver(int dcId, DataChannel dataChannel) {
        // DataChannel.registerObserver implementation does not allow to
        // unregister, so the observer is registered here and is never
        // unregistered
        dataChannel.registerObserver(
                new DataChannelObserver(webRTCModule, id, dcId, dataChannel));
    }

    @Override
    public void onRenegotiationNeeded() {
        WritableMap params = Arguments.createMap();
        params.putInt("id", id);
        webRTCModule.sendEvent("peerConnectionOnRenegotiationNeeded", params);
    }

    @Override
    public void onSignalingChange(PeerConnection.SignalingState signalingState) {
        WritableMap params = Arguments.createMap();
        params.putInt("id", id);
        params.putString("signalingState", signalingStateString(signalingState));
        webRTCModule.sendEvent("peerConnectionSignalingStateChanged", params);
    }

    @Override
    public void onAddTrack(final RtpReceiver receiver, final MediaStream[] mediaStreams) {
        Log.d(TAG, "onAddTrack");

        // for plan-b
        if (!isUnifiedPlan) {
            for (MediaStream mediaStream : mediaStreams) {
                String streamId = mediaStream.getId();
                MediaStreamTrack track = receiver.track();
                String trackId = track.id();

                WritableMap params = Arguments.createMap();
                params.putString("streamId", streamId);
                params.putInt("id", id);
                params.putString("trackId", trackId);

                WritableMap trackInfo = Arguments.createMap();
                trackInfo.putString("id", trackId);
                trackInfo.putString("label", track.kind());
                trackInfo.putString("kind", track.kind());
                trackInfo.putBoolean("enabled", track.enabled());
                trackInfo.putString("readyState", track.state().toString());
                trackInfo.putBoolean("remote", true);

                params.putMap("track", trackInfo);

                webRTCModule.sendEvent("peerConnectionOnAddedTrack", params);
            }
        } else {
            // for Unified Plan
            WritableMap params = Arguments.createMap();
            params.putInt("id", id);

            WritableArray streams = Arguments.createArray();
            for (int i = 0; i < mediaStreams.length; i++) {
                MediaStream mediaStream = mediaStreams[i];
                WritableMap stream = mediaStreamToMap(mediaStream);
                streams.pushMap(stream);
            }

            params.putArray("streams", streams);
            WritableMap trackInfo = mediaTrackToMap(receiver.track());
            params.putMap("track", trackInfo);
            params.putMap("receiver", rtpReceiverToMap(receiver));


//            MediaStreamTrack track = receiver.track();
//            if (track != null) {
//                if (track.kind().equals(MediaStreamTrack.VIDEO_TRACK_KIND)) {
//                    streamReactTag = "A";
//                    Log.d(TAG, "streamReactTag Created: " + streamReactTag);
//                    videoTrackAdapters.addAdapter(streamReactTag, (VideoTrack) track);
//                } else {
//                    Log.d(TAG, "track.kind().equals(MediaStreamTrack.VIDEO_TRACK_KIND)");
//                }
//                remoteTracks.put(track.id(), track);
//            }
//            WritableMap trackInfo = Arguments.createMap();
//            trackInfo.putString("id", track.id());
//            trackInfo.putString("label", track.kind());
//            trackInfo.putString("kind", track.kind());
//            trackInfo.putBoolean("enabled", track.enabled());
//            trackInfo.putString("readyState", track.state().toString());
//            trackInfo.putBoolean("remote", true);
//
//            params.putMap("track", trackInfo);

            webRTCModule.sendEvent("peerConnectionAddedTrack", params);
        }
    }

    @Override
    public void onTrack(RtpTransceiver transceiver) {
        /*
        if(isUnifiedPlan){
            MediaStreamTrack track = transceiver.getReceiver().track();
            if(track != null){
                WritableMap trackInfo = Arguments.createMap();
                if(track.kind().equals(MediaStreamTrack.VIDEO_TRACK_KIND)){
                    String streamReactTag = UUID.randomUUID().toString();
                    videoTrackAdapters.addAdapter(streamReactTag, (VideoTrack) track);

                    if(transceiver.getSender().track() == null){
                        MediaStreamTrack videoTrack = webRTCModule.getLocalTrackByType("video");

                        if(videoTrack != null){
                            transceiver.getSender().setTrack(videoTrack, false);
                            transceiver.setDirection(RtpTransceiver.RtpTransceiverDirection.SEND_RECV);
                            this.onRenegotiationNeeded();
                        }
                    }
                }else {
                    if(transceiver.getSender().track() == null) {
                        MediaStreamTrack audioTrack = webRTCModule.getLocalTrackByType("audio");

                        if(audioTrack != null){
                            transceiver.getSender().setTrack(audioTrack, false);
                            transceiver.setDirection(RtpTransceiver.RtpTransceiverDirection.SEND_RECV);
                        }
                    }
                }

                remoteTracks.put(track.id(), track);

                trackInfo.putInt("id", id);
                trackInfo.putString("trackId", track.id());
                trackInfo.putString("kind", track.kind());
                trackInfo.putString("label", track.id());
                trackInfo.putBoolean("remote", true);
                trackInfo.putBoolean("enabled", track.enabled());
                trackInfo.putString("readyState", track.state().toString().toLowerCase());

                webRTCModule.sendEvent("peerConnectionAddedTrack", trackInfo);
            }
        }*/
    }

    @Nullable
    private String peerConnectionStateString(PeerConnection.PeerConnectionState peerConnectionState) {
        switch (peerConnectionState) {
            case NEW:
                return "new";
            case CONNECTING:
                return "connecting";
            case CONNECTED:
                return "connected";
            case DISCONNECTED:
                return "disconnected";
            case FAILED:
                return "failed";
            case CLOSED:
                return "closed";
        }
        return null;
    }

    @Nullable
    private String iceConnectionStateString(PeerConnection.IceConnectionState iceConnectionState) {
        switch (iceConnectionState) {
            case NEW:
                return "new";
            case CHECKING:
                return "checking";
            case CONNECTED:
                return "connected";
            case COMPLETED:
                return "completed";
            case FAILED:
                return "failed";
            case DISCONNECTED:
                return "disconnected";
            case CLOSED:
                return "closed";
        }
        return null;
    }

    @Nullable
    private String iceGatheringStateString(PeerConnection.IceGatheringState iceGatheringState) {
        switch (iceGatheringState) {
            case NEW:
                return "new";
            case GATHERING:
                return "gathering";
            case COMPLETE:
                return "complete";
        }
        return null;
    }

    @Nullable
    private String signalingStateString(PeerConnection.SignalingState signalingState) {
        switch (signalingState) {
            case STABLE:
                return "stable";
            case HAVE_LOCAL_OFFER:
                return "have-local-offer";
            case HAVE_LOCAL_PRANSWER:
                return "have-local-pranswer";
            case HAVE_REMOTE_OFFER:
                return "have-remote-offer";
            case HAVE_REMOTE_PRANSWER:
                return "have-remote-pranswer";
            case CLOSED:
                return "closed";
        }
        return null;
    }

    @Nullable
    private WritableMap mediaStreamToMap(MediaStream stream) {
        WritableMap params = Arguments.createMap();
        params.putString("streamId", stream.getId());

        String streamReactTag = null;
        for (Map.Entry<String, MediaStream> e : remoteStreams.entrySet()) {
            if (e.getValue().equals(stream)) {
                streamReactTag = e.getKey();
                break;
            }
        }
        if (streamReactTag == null) {
            streamReactTag = stream.getId();
//            streamReactTag = UUID.randomUUID().toString();
            remoteStreams.put(streamReactTag, stream);
        }
        params.putString("streamReactTag", streamReactTag);

        WritableArray tracks = Arguments.createArray();

        for (int i = 0; i < stream.audioTracks.size(); i++) {
            AudioTrack track = stream.audioTracks.get(i);
            String trackId = track.id();

            WritableMap trackInfo = Arguments.createMap();
            trackInfo.putString("id", trackId);
            trackInfo.putString("label", "Audio");
            trackInfo.putString("kind", track.kind());
            trackInfo.putBoolean("enabled", track.enabled());
            trackInfo.putString("readyState", track.state().toString());
            trackInfo.putBoolean("remote", true);

            tracks.pushMap(trackInfo);
        }

        for (int i = 0; i < stream.videoTracks.size(); i++) {
            VideoTrack track = stream.videoTracks.get(i);
            String trackId = track.id();

            WritableMap trackInfo = Arguments.createMap();
            trackInfo.putString("id", trackId);
            trackInfo.putString("label", "Video");
            trackInfo.putString("kind", track.kind());
            trackInfo.putBoolean("enabled", track.enabled());
            trackInfo.putString("readyState", track.state().toString());
            trackInfo.putBoolean("remote", true);

            tracks.pushMap(trackInfo);
        }

        params.putArray("tracks", tracks);

        return params;
    }

    @Nullable
    private WritableMap mediaTrackToMap(MediaStreamTrack track) {
        WritableMap trackInfo = Arguments.createMap();
        if (track != null) {
            trackInfo.putString("id", track.id());
            trackInfo.putString("label", track.getClass() == VideoTrack.class ? "video" : "audio");
            trackInfo.putString("kind", track.kind());
            trackInfo.putBoolean("enabled", track.enabled());
            trackInfo.putString("readyState", track.state().toString());
        }
        return trackInfo;
    }

    @Nullable
    private WritableMap rtpReceiverToMap(RtpReceiver receiver) {
        // TODO:
        WritableMap info = Arguments.createMap();
        info.putString("receiverId", receiver.id());
//        info.putMap("rtpParameters", )
        info.putMap("track", mediaTrackToMap(receiver.track()));
        return info;
    }
}