//
//  WebRTCModule+RTCPeerConnection.m
//
//  Created by one on 2015/9/24.
//  Copyright © 2015 One. All rights reserved.
//

#import <objc/runtime.h>

#import <React/RCTBridge.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTLog.h>
#import <React/RCTUtils.h>

#import <WebRTC/WebRTC.h>

#import "WebRTCModule.h"
#import "WebRTCModule+RTCDataChannel.h"
#import "WebRTCModule+RTCPeerConnection.h"
#import "WebRTCModule+VideoTrackAdapter.h"

@implementation RTCPeerConnection (React)

- (NSMutableDictionary<NSNumber *, RTCDataChannel *> *)dataChannels
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setDataChannels:(NSMutableDictionary<NSNumber *, RTCDataChannel *> *)dataChannels
{
    objc_setAssociatedObject(self, @selector(dataChannels), dataChannels, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSNumber *)reactTag
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setReactTag:(NSNumber *)reactTag
{
    objc_setAssociatedObject(self, @selector(reactTag), reactTag, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary<NSString *, RTCMediaStream *> *)remoteStreams
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setRemoteStreams:(NSMutableDictionary<NSString *,RTCMediaStream *> *)remoteStreams
{
    objc_setAssociatedObject(self, @selector(remoteStreams), remoteStreams, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary<NSString *, RTCMediaStreamTrack *> *)remoteTracks
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setRemoteTracks:(NSMutableDictionary<NSString *,RTCMediaStreamTrack *> *)remoteTracks
{
    objc_setAssociatedObject(self, @selector(remoteTracks), remoteTracks, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)webRTCModule
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setWebRTCModule:(id)webRTCModule
{
    objc_setAssociatedObject(self, @selector(webRTCModule), webRTCModule, OBJC_ASSOCIATION_ASSIGN);
}

@end

@implementation WebRTCModule (RTCPeerConnection)

RCT_EXPORT_METHOD(peerConnectionInit:(RTCConfiguration*)configuration
        objectID:(nonnull NSNumber *)objectID)
{
    NSDictionary *optionalConstraints = @{ @"DtlsSrtpKeyAgreement" : @"true" };
    RTCMediaConstraints* constraints =
            [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil
                                                  optionalConstraints:optionalConstraints];
    RTCPeerConnection *peerConnection
            = [self.peerConnectionFactory
                    peerConnectionWithConfiguration:configuration
                                        constraints:constraints
                                           delegate:self];
    
    peerConnection.dataChannels = [NSMutableDictionary new];
    peerConnection.reactTag = objectID;
    peerConnection.remoteStreams = [NSMutableDictionary new];
    peerConnection.remoteTracks = [NSMutableDictionary new];
    peerConnection.videoTrackAdapters = [NSMutableDictionary new];
    peerConnection.webRTCModule = self;
    self.peerConnections[objectID] = peerConnection;
}

RCT_EXPORT_METHOD(peerConnectionSetConfiguration:(RTCConfiguration*)configuration objectID:(nonnull NSNumber *)objectID)
{
    RTCPeerConnection *peerConnection = self.peerConnections[objectID];
    if (!peerConnection) {
        return;
    }
    [peerConnection setConfiguration:configuration];
}

RCT_EXPORT_METHOD(peerConnectionAddStream:(nonnull NSString *)streamID objectID:(nonnull NSNumber *)objectID)
{
    RTCPeerConnection *peerConnection = self.peerConnections[objectID];
    if (!peerConnection) {
        return;
    }
    RTCMediaStream *stream = self.localStreams[streamID];
    if (!stream) {
        return;
    }

    [peerConnection addStream:stream];
}

RCT_EXPORT_METHOD(peerConnectionRemoveStream:(nonnull NSString *)streamID objectID:(nonnull NSNumber *)objectID)
{
    RTCPeerConnection *peerConnection = self.peerConnections[objectID];
    if (!peerConnection) {
        return;
    }
    RTCMediaStream *stream = self.localStreams[streamID];
    if (!stream) {
        return;
    }

    [peerConnection removeStream:stream];
}

RCT_EXPORT_METHOD(peerConnectionAddTransceiver:(nonnull NSNumber *)objectID
        options:(NSDictionary *)options
        callback:(RCTResponseSenderBlock)callback)
{
    RTCPeerConnection *peerConnection = self.peerConnections[objectID];
    if (!peerConnection) {
        return;
    }
    NSString* trackId = [options objectForKey:@"trackId"];
    NSString* mediaType = [options objectForKey:@"type"];
    NSDictionary* initOpt = [options objectForKey:@"init"];
    RTCRtpTransceiver *transceiver = nil;

    if(trackId != nil){
        RTCMediaStreamTrack* track = [self trackForId:trackId];
        if(initOpt != nil){
            RTCRtpTransceiverInit *init = [self mapToTransceiverInit:initOpt];
            transceiver = [peerConnection addTransceiverWithTrack:track init:init];
        }else{
            transceiver = [peerConnection addTransceiverWithTrack:track];
        }
    }else if(mediaType != nil){
        RTCRtpTransceiverInit *init = [self mapToTransceiverInit:initOpt];
        if([mediaType isEqualToString:@"audio"]){
            transceiver = [peerConnection addTransceiverOfType: RTCRtpMediaTypeAudio init: init];
        }else if ([mediaType isEqualToString:@"video"]) {
            transceiver = [peerConnection addTransceiverOfType: RTCRtpMediaTypeVideo init: init];
        } else {
            // error 로그
                id errorResponse = @{
                        @"name": @"AddTransceiver",
                        @"message": @"Error: Invalid MediaType"
                };
                callback(@[@(NO), errorResponse]);
        }
    }else{
        // error 로그
                id errorResponse = @{
                        @"name": @"AddTransceiver",
                        @"message":  @"Error: Incomplete Parameters"
                };
                callback(@[@(NO), errorResponse]);
    }

    if(transceiver == nil){
        // error 로그
                id errorResponse = @{
                        @"name": @"AddTransceiver",
                        @"message": @"Error: can't addTransceiver!"
                };
                callback(@[@(NO), errorResponse]);
    } else{
        // 정상
        id response = @{
                @"id": transceiver.sender.senderId,
                @"state": [self extractPeerConnectionState: peerConnection]
        };
        callback(@[@(YES), response]);
    }
}

RCT_EXPORT_METHOD(peerConnectionAddTrack:(nonnull NSNumber *)objectID
        trackId:(NSString *)trackId
        callback:(RCTResponseSenderBlock)callback)
{
    //TODO: Implement 되어야함.
    /*
    //0. 해당하는 peerConnection 찾기
    RTCPeerConnection *peerConnection = self.peerConnections[objectID];
    if (!peerConnection) {
        //1. peerConnection 에러 반환.
        //callback.invoke(false, "pco == null || pco.getPeerConnection() == null");
        return;
    }
    //0. 해당하는 track 찾기
    RTCMediaStreamTrack *track = [self trackForId:trackId];
    if(track == nil){
        RCTLogTrace(@"peerConnectionAddTrack() is nil");
    }
    RTCRtpSender *sender = [peerConnection addTrack:track streamIds:<#(nonnull NSArray<NSString *> *)#>]
    
    // 2. isUnifiedPlan인지
    if(peerConnection.configuration.sdpSemantics == RTCSdpSemanticsUnifiedPlan){
        // 3. 이미 전송하고 있는 track인지 확인
        RTCRtpSender *sender = nil;
        for (RTCRtpSender *rtpSender in peerConnection.senders) {
            if(rtpSender.track != nil){
                if([rtpSender.track.trackId isEqualToString:track.trackId]){
                    sender = rtpSender;
                    RCTLogTrace(@"이미 전송중인 Track 입니다.");
                    break;
                }
            }
        }
        Boolean reuse = false;
        if(sender == nil){
            // 4. transceiver 찾기 -> kind 같고 & sender.track 이 null이고
            for (RTCRtpTransceiver *transceiver in peerConnection.transceivers) {
                if(transceiver.receiver.track != nil){
                    if(transceiver.sender.track == nil && [transceiver.receiver.track.kind isEqualToString:track.kind]){
                        transceiver.sender.s
                    }
                }
            }
            
        }
    }
    */
}

RCT_EXPORT_METHOD(peerConnectionTransceiverSetDirection:(nonnull NSNumber *)objectID
        transceiverId:(NSString *)transceiverId
        direction: (NSString* )direction
        callback:(RCTResponseSenderBlock)callback) {
    RTCPeerConnection *peerConnection = self.peerConnections[objectID];
    if (!peerConnection) {
        return;
    }
    for (RTCRtpTransceiver *transceiver in peerConnection.transceivers) {
        if ([transceiver.sender.senderId isEqualToString:transceiverId]) {
            NSError* error = nil;
            [transceiver setDirection:[self parseDirection:direction] error:&error];
            if(error){
                id errorResponse = @{
                        @"name": @"TransceiverSetDirection",
                        @"message": error.localizedDescription ?: [NSNull null]
                };
                callback(@[@(NO), errorResponse]);
            }
        }
    }
    id response = @{
            @"id": transceiverId,
            @"state": [self extractPeerConnectionState: peerConnection]
    };
    callback(@[@(YES), response]);
}

RCT_EXPORT_METHOD(peerConnectionTransceiverReplaceTrack:(nonnull NSNumber *)objectID
        transceiverId:(NSString *)transceiverId
        trackId: (NSString* )trackId
        callback:(RCTResponseSenderBlock)callback) {
    RTCPeerConnection *peerConnection = self.peerConnections[objectID];
    if (!peerConnection) {
        return;
    }
    for (RTCRtpTransceiver *transceiver in peerConnection.transceivers) {
        if ([transceiver.sender.senderId isEqualToString:transceiverId]) {
            if (trackId == nil) {
                [transceiver.sender setTrack:nil];
            } else {
                [transceiver.sender setTrack:[self trackForId:trackId]];
            }
        }
    }
    id response = @{
            @"id": transceiverId,
            @"state": [self extractPeerConnectionState: peerConnection]
    };
    callback(@[@(YES), response]);
}

RCT_EXPORT_METHOD(peerConnectionTransceiverStop:(nonnull NSNumber *)objectID
        transceiverId:(NSString *)transceiverId
        callback:(RCTResponseSenderBlock)callback) {
    RTCPeerConnection *peerConnection = self.peerConnections[objectID];
    if (!peerConnection) {
        return;
    }
    for (RTCRtpTransceiver *transceiver in peerConnection.transceivers) {
        if ([transceiver.sender.senderId isEqualToString:transceiverId]) {
            [transceiver stopInternal];
        }
    }
    id response = @{
            @"id": transceiverId,
            @"state": [self extractPeerConnectionState: peerConnection]
    };
    callback(@[@(YES), response]);
}

RCT_EXPORT_METHOD(peerConnectionCreateOffer:(nonnull NSNumber *)objectID
        options:(NSDictionary *)options
        callback:(RCTResponseSenderBlock)callback)
{
    RTCPeerConnection *peerConnection = self.peerConnections[objectID];
    if (!peerConnection) {
        return;
    }

    RTCMediaConstraints *constraints =
            [[RTCMediaConstraints alloc] initWithMandatoryConstraints:options
                                                  optionalConstraints:nil];

    [peerConnection
            offerForConstraints:constraints
              completionHandler:^(RTCSessionDescription *sdp, NSError *error) {
                  if (error) {
                      callback(@[
                              @(NO),
                              @{
                                      @"type": @"CreateOfferFailed",
                                      @"message": error.localizedDescription ?: [NSNull null]
                              }
                      ]);
                  } else {
                      [self applyTransceivers: peerConnection];
                      NSString *type = [RTCSessionDescription stringForType:sdp.type];
                      id response = @{
                              @"state": [self extractPeerConnectionState: peerConnection],
                              @"session":  @{@"sdp": sdp.sdp, @"type": type}
                      };
                      callback(@[@(YES), response]);
                  }
              }];
}

RCT_EXPORT_METHOD(peerConnectionCreateAnswer:(nonnull NSNumber *)objectID
        options:(NSDictionary *)options
        callback:(RCTResponseSenderBlock)callback)
{
    RTCPeerConnection *peerConnection = self.peerConnections[objectID];
    if (!peerConnection) {
        return;
    }

    RTCMediaConstraints *constraints =
            [[RTCMediaConstraints alloc] initWithMandatoryConstraints:options
                                                  optionalConstraints:nil];

    [peerConnection
            answerForConstraints:constraints
               completionHandler:^(RTCSessionDescription *sdp, NSError *error) {
                   if (error) {
                       callback(@[
                               @(NO),
                               @{
                                       @"type": @"CreateAnswerFailed",
                                       @"message": error.localizedDescription ?: [NSNull null]
                               }
                       ]);
                   } else {
                       [self applyTransceivers: peerConnection];
                       NSString *type = [RTCSessionDescription stringForType:sdp.type];
                       id response = @{
                               @"state": [self extractPeerConnectionState: peerConnection],
                               @"session":  @{@"sdp": sdp.sdp, @"type": type}
                       };
                       callback(@[@(YES), response]);
                   }
               }];
}

RCT_EXPORT_METHOD(peerConnectionSetLocalDescription:(RTCSessionDescription *)sdp objectID:(nonnull NSNumber *)objectID callback:(RCTResponseSenderBlock)callback)
{
    RTCPeerConnection *peerConnection = self.peerConnections[objectID];
    if (!peerConnection) {
        return;
    }

    [peerConnection setLocalDescription:sdp completionHandler: ^(NSError *error) {
        if (error) {
            id errorResponse = @{
                    @"name": @"SetLocalDescriptionFailed",
                    @"message": error.localizedDescription ?: [NSNull null]
            };
            callback(@[@(NO), errorResponse]);
        } else {
            [self applyTransceivers: peerConnection];
            id response = @{
                    @"state": [self extractPeerConnectionState: peerConnection]
            };
            callback(@[@(YES), response]);
        }
    }];
}

RCT_EXPORT_METHOD(peerConnectionSetRemoteDescription:(RTCSessionDescription *)sdp objectID:(nonnull NSNumber *)objectID callback:(RCTResponseSenderBlock)callback)
{
    RTCPeerConnection *peerConnection = self.peerConnections[objectID];
    if (!peerConnection) {
        return;
    }

    [peerConnection setRemoteDescription: sdp completionHandler: ^(NSError *error) {
        if (error) {
            id errorResponse = @{
                    @"name": @"SetRemoteDescriptionFailed",
                    @"message": error.localizedDescription ?: [NSNull null]
            };
            callback(@[@(NO), errorResponse]);
        } else {
            [self applyTransceivers: peerConnection];
            id response = @{
                    @"state": [self extractPeerConnectionState: peerConnection]
            };
            callback(@[@(YES), response]);
        }
    }];
}

RCT_EXPORT_METHOD(peerConnectionAddICECandidate:(RTCIceCandidate*)candidate objectID:(nonnull NSNumber *)objectID callback:(RCTResponseSenderBlock)callback)
{
    RTCPeerConnection *peerConnection = self.peerConnections[objectID];
    if (!peerConnection) {
        return;
    }

    [peerConnection addIceCandidate:candidate];
    RCTLogTrace(@"addICECandidateresult: %@", candidate);
    callback(@[@true]);
}

RCT_EXPORT_METHOD(peerConnectionClose:(nonnull NSNumber *)objectID)
{
    RTCPeerConnection *peerConnection = self.peerConnections[objectID];
    if (!peerConnection) {
        return;
    }

    // Remove video track adapters
    for(RTCMediaStream *stream in [peerConnection.remoteStreams allValues]) {
        for (RTCVideoTrack *track in stream.videoTracks) {
            [peerConnection removeVideoTrackAdapter:track];
        }
    }

    [peerConnection close];
    [self.peerConnections removeObjectForKey:objectID];

    // Clean up peerConnection's streams and tracks
    [peerConnection.remoteStreams removeAllObjects];
    [peerConnection.remoteTracks removeAllObjects];

    // Clean up peerConnection's dataChannels.
    NSMutableDictionary<NSNumber *, RTCDataChannel *> *dataChannels
            = peerConnection.dataChannels;
    for (NSNumber *dataChannelId in dataChannels) {
        dataChannels[dataChannelId].delegate = nil;
        // There is no need to close the RTCDataChannel because it is owned by the
        // RTCPeerConnection and the latter will close the former.
    }
    [dataChannels removeAllObjects];
}

RCT_EXPORT_METHOD(peerConnectionGetStats:(nonnull NSString *)trackID
        objectID:(nonnull NSNumber *)objectID
        callback:(RCTResponseSenderBlock)callback)
{
    RTCPeerConnection *peerConnection = self.peerConnections[objectID];
    if (!peerConnection) {
        callback(@[@(NO), @"PeerConnection ID not found"]);
        return;
    }

    RTCMediaStreamTrack *track = nil;
    if (!trackID
            || !trackID.length
            || (track = self.localTracks[trackID])
            || (track = peerConnection.remoteTracks[trackID])) {
        [peerConnection statsForTrack:track
                     statsOutputLevel:RTCStatsOutputLevelStandard
                    completionHandler:^(NSArray<RTCLegacyStatsReport *> *stats) {
                        callback(@[@(YES), [self statsToJSON:stats]]);
                    }];
    } else {
        callback(@[@(NO), @"Track not found"]);
    }
}

RCT_EXPORT_METHOD(getTrackVolumes:(RCTResponseSenderBlock)callback)
{
    RTCMediaStreamTrack *track = nil;
    __block int statsRemaining = self.peerConnections.count;
    __block NSMutableArray *statsAll = [NSMutableArray new];

    for(id key in self.peerConnections) {
        RTCPeerConnection *peerConnection = self.peerConnections[key];

        [peerConnection statsForTrack:track statsOutputLevel:RTCStatsOutputLevelStandard completionHandler:^(NSArray<RTCLegacyStatsReport *> *stats) {
            for (RTCLegacyStatsReport *report in stats) {
                if ([report.type isEqualToString:@"ssrc"]) {
                    NSString *googTrackId = report.values[@"googTrackId"];
                    NSString *audioOutputLevel = report.values[@"audioOutputLevel"];
                    NSString *audioInputLevel = report.values[@"audioInputLevel"];

                    if (googTrackId != Nil && (audioOutputLevel != Nil || audioInputLevel != Nil)) {
                        [statsAll addObject:@[googTrackId, audioOutputLevel != Nil ? audioOutputLevel : audioInputLevel]];
                    }
                }
            }

            statsRemaining--;

            if (statsRemaining <= 0) {
                callback(@[statsAll]);
            }
        }];
    }
}

/**
 * Constructs a JSON <tt>NSString</tt> representation of a specific array of
 * <tt>RTCLegacyStatsReport</tt>s.
 * <p>
 * On iOS it is faster to (1) construct a single JSON <tt>NSString</tt>
 * representation of an array of <tt>RTCLegacyStatsReport</tt>s and (2) have it
 * pass through the React Native bridge rather than the array of
 * <tt>RTCLegacyStatsReport</tt>s.
 *
 * @param reports the array of <tt>RTCLegacyStatsReport</tt>s to represent in
 * JSON format
 * @return an <tt>NSString</tt> which represents the specified <tt>stats</tt> in
 * JSON format
 */
- (NSString *)statsToJSON:(RTCStatisticsReport *)report
{
  /* 
  The initial capacity matters, of course, because it determines how many
  times the NSMutableString will have grow. But walking through the reports
  to compute an initial capacity which exactly matches the requirements of
  the reports is too much work without real-world bang here. An improvement
  should be caching the required capacity from the previous invocation of the 
  method and using it as the initial capacity in the next invocation. 
  As I didn't want to go even through that,choosing just about any initial 
  capacity is OK because NSMutableCopy doesn't have too bad a strategy of growing.
  */
  NSMutableString *s = [NSMutableString stringWithCapacity:16 * 1024];

  [s appendString:@"["];
  BOOL firstReport = YES;
  for (NSString *key in report.statistics.allKeys) {
    if (firstReport) {
      firstReport = NO;
    } else {
      [s appendString:@","];
    }
  
    [s appendString:@"[\""];
    [s appendString: key];
    [s appendString:@"\",{"];

    RTCStatistics *statistics = report.statistics[key];
    [s appendString:@"\"timestamp\":"];
    [s appendFormat:@"%f", statistics.timestamp_us / 1000.0];
    [s appendString:@",\"type\":\""]; 
    [s appendString:statistics.type];
    [s appendString:@"\",\"id\":\""];
    [s appendString:statistics.id];
    [s appendString:@"\""];

    for (id key in statistics.values) {
        [s appendString:@","];
        [s appendString:@"\""];
        [s appendString:key];
        [s appendString:@"\":"];
        NSObject *statisticsValue = [statistics.values objectForKey:key];
        if ([statisticsValue isKindOfClass:[NSArray class]]) {
            [s appendString:@"["];
            BOOL firstValue = YES;
            for (NSObject *value in statisticsValue) {
              if(firstValue) {
                firstValue = NO;
              } else {
                [s appendString:@","];
              }

              [s appendString:@"\""];
              [s appendString:[NSString stringWithFormat:@"%@", value]];
              [s appendString:@"\""];
            }
            [s appendString:@"]"];
        } else {
            [s appendString:@"\""];
            [s appendString:[NSString stringWithFormat:@"%@", statisticsValue]];
            [s appendString:@"\""];
        }
    }
    
    [s appendString:@"}]"];
  } 

  [s appendString:@"]"];

  return s;
}

- (NSString *)stringForICEConnectionState:(RTCIceConnectionState)state {
    switch (state) {
        case RTCIceConnectionStateNew: return @"new";
        case RTCIceConnectionStateChecking: return @"checking";
        case RTCIceConnectionStateConnected: return @"connected";
        case RTCIceConnectionStateCompleted: return @"completed";
        case RTCIceConnectionStateFailed: return @"failed";
        case RTCIceConnectionStateDisconnected: return @"disconnected";
        case RTCIceConnectionStateClosed: return @"closed";
        case RTCIceConnectionStateCount: return @"count";
    }
    return nil;
}

- (NSString *)stringForICEGatheringState:(RTCIceGatheringState)state {
    switch (state) {
        case RTCIceGatheringStateNew: return @"new";
        case RTCIceGatheringStateGathering: return @"gathering";
        case RTCIceGatheringStateComplete: return @"complete";
    }
    return nil;
}

- (NSString *)stringForSignalingState:(RTCSignalingState)state {
    switch (state) {
        case RTCSignalingStateStable: return @"stable";
        case RTCSignalingStateHaveLocalOffer: return @"have-local-offer";
        case RTCSignalingStateHaveLocalPrAnswer: return @"have-local-pranswer";
        case RTCSignalingStateHaveRemoteOffer: return @"have-remote-offer";
        case RTCSignalingStateHaveRemotePrAnswer: return @"have-remote-pranswer";
        case RTCSignalingStateClosed: return @"closed";
    }
    return nil;
}

- (NSString *)stringForTransceiverDirection:(RTCRtpTransceiverDirection)direction {
    switch(direction) {
        case RTCRtpTransceiverDirectionSendRecv: return @"sendrecv";
        case RTCRtpTransceiverDirectionSendOnly: return @"sendonly";
        case RTCRtpTransceiverDirectionRecvOnly: return @"recvonly";
        case RTCRtpTransceiverDirectionInactive: return @"inactive";
    }
    return nil;
}

- (RTCRtpTransceiverDirection) parseDirection: (NSString*)direction {
    if ([direction isEqualToString:@"sendrecv"]) {
        return RTCRtpTransceiverDirectionSendRecv;
    } else if ([direction isEqualToString:@"sendonly"]) {
        return RTCRtpTransceiverDirectionSendOnly;
    } else if ([direction isEqualToString:@"recvonly"]) {
        return RTCRtpTransceiverDirectionRecvOnly;
    } else if ([direction isEqualToString:@"inactive"]) {
        return RTCRtpTransceiverDirectionInactive;
    }

    return RTCRtpTransceiverDirectionSendRecv;
}

- (NSDictionary *)extractTransceiver:(RTCRtpTransceiver *)transceiver {
    NSMutableDictionary *res = [NSMutableDictionary dictionary];
    [res setValue: transceiver.sender.senderId forKey:@"id"];
    if (transceiver.mid != nil) {
        [res setValue: transceiver.mid forKey:@"mid"];
    }
    [res setValue:[self stringForTransceiverDirection: transceiver.direction] forKey:@"direction"];
    [res setValue: (transceiver.isStopped ? @YES : @NO) forKey:@"isStopped"];
    [res setValue:@{
            @"id": transceiver.receiver.receiverId,
            @"track": @{
                    @"id": transceiver.receiver.track.trackId,
                    @"kind": transceiver.receiver.track.kind,
                    @"label": transceiver.receiver.track.trackId,
                    @"enabled": @(transceiver.receiver.track.isEnabled),
                    @"remote": @(YES),
                    @"readyState": @"live"
            }
    } forKey: @"receiver"];
    return res;
}

- (NSDictionary *)extractPeerConnectionState:(RTCPeerConnection *)peerConnection {
    NSMutableDictionary *res = [NSMutableDictionary dictionary];
    NSMutableArray *transceivers = [NSMutableArray array];
    if (peerConnection.configuration.sdpSemantics == RTCSdpSemanticsUnifiedPlan) {
        for (RTCRtpTransceiver *transceiver in peerConnection.transceivers) {
            [transceivers addObject: [self extractTransceiver: transceiver]];
        }
    }
    [res setValue:transceivers forKey:@"transceivers"];
    return res;
}

#pragma mark - RTCPeerConnectionDelegate methods

- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeSignalingState:(RTCSignalingState)newState {
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"peerConnectionSignalingStateChanged" body:
            @{@"id": peerConnection.reactTag, @"signalingState": [self stringForSignalingState:newState]}];
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didAddStream:(RTCMediaStream *)stream {
    RCTLogTrace(@"didAddStream =============================== triggerred");
    // 괜히 streamReactTag를 만들어서 번거롭게 이런 절차가 필요함.
    
    // step1) 해당 stream이 이미 존재하는지 확인하는 부분. 
    // - didAddTrack 이벤트가 didAddStream보다 먼저 일어날지도 몰라서 이곳에서 처리.
    NSString *streamReactTag = nil;
    for (NSString *aReactTag in peerConnection.remoteStreams) {
        RTCMediaStream *aStream = peerConnection.remoteStreams[aReactTag];
        if ([aStream.streamId isEqualToString:stream.streamId]) {
            streamReactTag = aReactTag;
            break;
        }
    }
    
    // step2) 해당 stream이 이미 존재할 경우
    if(streamReactTag){
        NSMutableArray *tracks = [NSMutableArray array];
        for (RTCVideoTrack *track in stream.videoTracks) {
            if(!peerConnection.remoteTracks[track.trackId]){
                peerConnection.remoteTracks[track.trackId] = track;
                [peerConnection addVideoTrackAdapter:streamReactTag track:track];
            }
            [tracks addObject:@{@"id": track.trackId, @"kind": track.kind, @"label": track.trackId, @"enabled": @(track.isEnabled), @"remote": @(YES), @"readyState": @"live"}];
        }
        for (RTCAudioTrack *track in stream.audioTracks) {
            if(!peerConnection.remoteTracks[track.trackId]){
                peerConnection.remoteTracks[track.trackId] = track;
            }
            [tracks addObject:@{@"id": track.trackId, @"kind": track.kind, @"label": track.trackId, @"enabled": @(track.isEnabled), @"remote": @(YES), @"readyState": @"live"}];
        }
        peerConnection.remoteStreams[streamReactTag] = stream; // 중복 저장이지만 뭐 어때. 같은 객체라서 저장하는건데... 혹시 몰라서 overwrite하는 것. 근데 이러면 쓸데없는 자원 소모가 있는지 걱정임.
        /* Event Dispatch */
        [self.bridge.eventDispatcher sendDeviceEventWithName:@"peerConnectionAddedStream"
                                        body:@{@"id":peerConnection.reactTag, 
                                                @"streamId": stream.streamId,
                                                @"streamReactTag": streamReactTag,
                                                @"tracks": tracks
                                    }]; // 나는 unifiedplan기반으로 peerConnectionAddedStream 을 쓰기로 결정해서 이 event를 dispatch함.
    }else{
        // step3) 해당 stream이 존재하지 않을 경우(아마 plan-b를 쓰면 유용할 듯)
        streamReactTag = [[NSUUID UUID] UUIDString];
        NSMutableArray *tracks = [NSMutableArray array];
        for (RTCVideoTrack *track in stream.videoTracks) {
            if(!peerConnection.remoteTracks[track.trackId]){
                peerConnection.remoteTracks[track.trackId] = track;
                [peerConnection addVideoTrackAdapter:streamReactTag track:track];
            }
            [tracks addObject:@{@"id": track.trackId, @"kind": track.kind, @"label": track.trackId, @"enabled": @(track.isEnabled), @"remote": @(YES), @"readyState": @"live"}];
        }
        for (RTCAudioTrack *track in stream.audioTracks) {
            if(!peerConnection.remoteTracks[track.trackId]){
                peerConnection.remoteTracks[track.trackId] = track;
            }
            [tracks addObject:@{@"id": track.trackId, @"kind": track.kind, @"label": track.trackId, @"enabled": @(track.isEnabled), @"remote": @(YES), @"readyState": @"live"}];
        }

        peerConnection.remoteStreams[streamReactTag] = stream;

        [self.bridge.eventDispatcher sendDeviceEventWithName:@"peerConnectionAddedStream"
                                        body:@{@"id":peerConnection.reactTag, 
                                                @"streamId": stream.streamId,
                                                @"streamReactTag": streamReactTag,
                                                @"tracks": tracks
                                    }];
    }
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didRemoveStream:(RTCMediaStream *)stream {
    // XXX Find the stream by comparing the 'streamId' values. It turns out that WebRTC (as of M69) creates new wrapper
    // instance for the native media stream before invoking the 'didRemoveStream' callback. This means it's a different
    // RTCMediaStream instance passed to 'didAddStream' and 'didRemoveStream'.
    NSString *streamReactTag = nil;
    for (NSString *aReactTag in peerConnection.remoteStreams) {
        RTCMediaStream *aStream = peerConnection.remoteStreams[aReactTag];
        if ([aStream.streamId isEqualToString:stream.streamId]) {
            streamReactTag = aReactTag;
            break;
        }
    }
    if (!streamReactTag) {
        RCTLogWarn(@"didRemoveStream - stream not found, id: %@", stream.streamId);
        return;
    }
    for (RTCVideoTrack *track in stream.videoTracks) {
        [peerConnection removeVideoTrackAdapter:track];
        [peerConnection.remoteTracks removeObjectForKey:track.trackId];
    }
    for (RTCAudioTrack *track in stream.audioTracks) {
        [peerConnection.remoteTracks removeObjectForKey:track.trackId];
    }
    [peerConnection.remoteStreams removeObjectForKey:streamReactTag];
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"peerConnectionRemovedStream" 
                                body:@{@"id": peerConnection.reactTag, @"streamId": stream.streamId}];
}


- (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)peerConnection {
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"peerConnectionOnRenegotiationNeeded" body:
            @{@"id": peerConnection.reactTag}];
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeIceConnectionState:(RTCIceConnectionState)newState {
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"peerConnectionIceConnectionChanged" body:
            @{@"id": peerConnection.reactTag, @"iceConnectionState": [self stringForICEConnectionState:newState]}];
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeIceGatheringState:(RTCIceGatheringState)newState {
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"peerConnectionIceGatheringChanged" body:
            @{@"id": peerConnection.reactTag, @"iceGatheringState": [self stringForICEGatheringState:newState]}];
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didGenerateIceCandidate:(RTCIceCandidate *)candidate {
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"peerConnectionGotICECandidate" body:
            @{@"id": peerConnection.reactTag, @"candidate": @{@"candidate": candidate.sdp, @"sdpMLineIndex": @(candidate.sdpMLineIndex), @"sdpMid": candidate.sdpMid}}];
}

- (void)peerConnection:(RTCPeerConnection*)peerConnection didOpenDataChannel:(RTCDataChannel*)dataChannel {
    // XXX RTP data channels are not defined by the WebRTC standard, have been
    // deprecated in Chromium, and Google have decided (in 2015) to no longer
    // support them (in the face of multiple reported issues of breakages).
    if (-1 == dataChannel.channelId) {
        return;
    }

    NSNumber *dataChannelId = [NSNumber numberWithInteger:dataChannel.channelId];
    dataChannel.peerConnectionId = peerConnection.reactTag;
    peerConnection.dataChannels[dataChannelId] = dataChannel;
    // WebRTCModule implements the category RTCDataChannel i.e. the protocol
    // RTCDataChannelDelegate.
    dataChannel.delegate = self;

    NSDictionary *body = @{@"id": peerConnection.reactTag,
            @"dataChannel": @{@"id": dataChannelId,
                    @"label": dataChannel.label}};
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"peerConnectionDidOpenDataChannel"
                                                    body:body];
}

- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didRemoveIceCandidates:(nonnull NSArray<RTCIceCandidate *> *)candidates {
    // TODO
}

/** Called when signaling indicates a transceiver will be receiving media from
 *  the remote endpoint.
 *  This is only called with RTCSdpSemanticsUnifiedPlan specified.
 */
/** Called when a receiver and its track are created. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
        didAddReceiver:(RTCRtpReceiver *)rtpReceiver
               streams:(NSArray<RTCMediaStream *> *)mediaStreams{
    RCTLogTrace(@"didAddReceiver ============================ triggerred");
    // For UnifiedPlan
    NSMutableArray* streams = [NSMutableArray array];
    for(RTCMediaStream *stream in mediaStreams){
        //1. 이미 존재하는지 확인하기
        NSString *streamReactTag = nil;
        for (NSString *aReactTag in peerConnection.remoteStreams) {
          RTCMediaStream *aStream = peerConnection.remoteStreams[aReactTag];
          if ([aStream.streamId isEqualToString:stream.streamId]) {
            streamReactTag = aReactTag;
            break;
          }
        }
        if (!streamReactTag) {
            //1.2 그렇지않으면 streamId로 streamReactTag만들기 (근데 어차피 streamId랑 같게할거면 이게 필요한가)
            // - 내부적으로(native단에서) streamId를 백퍼센트 확실하게 UUID로 만드는지 검증할 필요가 있겠네.
            RCTLogTrace(@"didAddTrack, no streamReactTag");
            streamReactTag = stream.streamId;
//             streamReactTag = [[NSUUID UUID] UUIDString];
            peerConnection.remoteStreams[streamReactTag] = stream;
        }else{ //1.1 존재하면 streamReactTag 가져오기
            RCTLogTrace(@"didAddTrack, yes streamReactTag");
        }
        //2. 만들어진 stream(stream property+streamReactTag)를 map해서 반환에 알맞은 형태로 만들고, streams 배열에 넣는다.
        NSDictionary* mappedStream = [self mediaStreamToMap:stream streamReactTag:streamReactTag];
        
        [streams addObject:mappedStream];
    }
    
    //3. receiver로부터 track을 만든다
    RTCMediaStreamTrack * track = rtpReceiver.track;
    //4. 반환쓰~
    
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"peerConnectionAddedTrack"
                                body:@{
                         @"id": peerConnection.reactTag,
                         @"streams": streams,
                         @"track": @{
                                 @"id": track.trackId,
                                 @"kind":track.kind,
                                 @"label": track.kind,
                                 @"enabled": @(track.isEnabled),
                                 @"remote":@(YES),
                                 @"readyState":@"live"
                         } // receiver는 반환 안함. 왜냐면 JS단에서 안쓰니까...ㅎㅎ.
                       }];
}

/** Called any time the PeerConnectionState changes. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeConnectionState:(RTCPeerConnectionState)newState {
    RCTLogTrace(@"didChangeConnectionState ============================ triggerred");
    
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"peerConnectionStateChanged"
                                body:@{
                         @"id": peerConnection.reactTag,
                         @"connectionState": [self peerConnectionStateToString:newState]
                       }];
}


- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeStandardizedIceConnectionState:(RTCIceConnectionState)newState{
    
    RCTLogTrace(@"didChangeStandardizedIceConnectionState ============================ triggerred");
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didStartReceivingOnTransceiver:(RTCRtpTransceiver *)transceiver{
    RCTLogTrace(@"didStartReceivingOnTransceiver ============================ triggerred");
    
}


/** 언젠가는 이 메서드가 구현되기를... 아직은 didAddReceiver라는 메서드로 우회구현 */
-(void)peerConnection:(RTCPeerConnection *)peerConnection
          mediaStream:(RTCMediaStream *)stream didAddTrack:(RTCVideoTrack*)track{

    //=== Stream 관련 ===//
    RCTLogTrace(@"didAddTrack =============================== triggerred"); // didAddReceiver로 우회
    // streamId로 streamReactTag를 찾는 부분. 왜 streamReactTag를 따로 만들어서 이렇게 귀찮게 하는걸까,,,
    NSString *streamReactTag = nil;
    for (NSString *aReactTag in peerConnection.remoteStreams) {
      RTCMediaStream *aStream = peerConnection.remoteStreams[aReactTag];
      if ([aStream.streamId isEqualToString:stream.streamId]) {
        streamReactTag = aReactTag;
        break;
      }
    }
    if (!streamReactTag) {// 없으면 새로 만들고
        RCTLogTrace(@"didAddTrack, no streamReactTag");
        streamReactTag = [[NSUUID UUID] UUIDString];
        peerConnection.remoteStreams[streamReactTag] = stream;
    }else{ // 있으면 재활용하고
        RCTLogTrace(@"didAddTrack, yes streamReactTag");
    }


    //=== Track 관련 ===//
    peerConnection.remoteTracks[track.trackId] = track;


    // 이벤트 전송.
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"peerConnectionAddedTrack"
                                body:@{
                         @"id": peerConnection.reactTag,
                         @"streamId": streamReactTag,
                         @"trackId": track.trackId,
                         @"track": @{
                                 @"id": track.trackId,
                                 @"kind":track.kind,
                                 @"label": track.kind,
                                 @"enabled": @(track.isEnabled),
                                 @"remote":@(YES),
                                 @"readyState":@"live"
                         }
                       }];
}

- (void)applyTransceivers: (nonnull RTCPeerConnection *)peerConnection {
    if (peerConnection.configuration.sdpSemantics == RTCSdpSemanticsUnifiedPlan) {
        for (RTCRtpTransceiver *transceiver in peerConnection.transceivers) {
            RTCMediaStreamTrack* track = transceiver.receiver.track;
            if (track != nil) {
                if (transceiver.mediaType == RTCRtpMediaTypeAudio) {
                    if ([peerConnection.remoteTracks objectForKey:track.trackId] == nil) {
                        peerConnection.remoteTracks[track.trackId] = track;
                    }
                } else if (transceiver.mediaType == RTCRtpMediaTypeVideo) {
                    if ([peerConnection.remoteTracks objectForKey:track.trackId] == nil) {
                        peerConnection.remoteTracks[track.trackId] = track;
                        NSString *streamReactTag = [[NSUUID UUID] UUIDString];
                        [peerConnection addVideoTrackAdapter:streamReactTag track: track];
                    }
                }
            }
        }
    }
}

- (RTCRtpTransceiverInit*)mapToTransceiverInit:(NSDictionary*)map {
    NSArray<NSString*>* streamIds = map[@"streamIds"];
    NSArray<NSDictionary*>* encodingsParams = map[@"sendEncodings"];
    NSString* direction = map[@"direction"];
    
    RTCRtpTransceiverInit* init = [RTCRtpTransceiverInit alloc];

    if(direction != nil) {
        init.direction = [self parseDirection:direction];
    }

    if(streamIds != nil) {
        init.streamIds = streamIds;
    }

    if(encodingsParams != nil) {
        NSMutableArray<RTCRtpEncodingParameters *> *sendEncodings = [[NSMutableArray alloc] init];
        for (NSDictionary* map in encodingsParams){
            [sendEncodings insertObject:[self mapToEncoding:map] atIndex:0];
        }
        [init setSendEncodings:sendEncodings];
    }
    return  init;
}

// 종우가 넣음. from Flutter SDK 참고
- (NSDictionary*)mediaStreamToMap:(RTCMediaStream *)stream streamReactTag:(NSString*)streamReactTag {
    
    // 굳이 AudioTracks와 videoTrack를 나눌 필요가 있는감.
    //    NSMutableArray* audioTracks = [NSMutableArray array];
    //    NSMutableArray* videoTracks = [NSMutableArray array];
        NSMutableArray* tracks = [NSMutableArray array];
    
    for (RTCMediaStreamTrack* track in stream.audioTracks) {
        //        [audioTracks addObject:[self mediaTrackToMap:track]];
        [tracks addObject:[self mediaTrackToMap:track]];
    }

    for (RTCMediaStreamTrack* track in stream.videoTracks) {
        //        [videoTracks addObject:[self mediaTrackToMap:track]];
        [tracks addObject:[self mediaTrackToMap:track]];
    }

    return @{
        @"streamReactTag": streamReactTag,
        @"streamId": stream.streamId,
        @"tracks": tracks,
    };
}


- (NSDictionary*)mediaTrackToMap:(RTCMediaStreamTrack*)track {
    if(track == nil)
        return @{};
    NSDictionary *params = @{
        @"enabled": @(track.isEnabled),
        @"id": track.trackId,
        @"kind": track.kind,
        @"label": track.trackId,
        @"readyState": [self streamTrackStateToString:track.readyState],
        @"remote": @(YES)
        };
    return params;
}

-(NSString*)streamTrackStateToString:(RTCMediaStreamTrackState)state {
    switch (state) {
        case RTCMediaStreamTrackStateLive:
            return @"live";
        case RTCMediaStreamTrackStateEnded:
            return @"ended";
        default:
            break;
    }
    return @"";
}
-(NSString *)peerConnectionStateToString:(RTCPeerConnectionState)state{
    switch (state) {
        case RTCPeerConnectionStateNew: return @"new";
        case RTCPeerConnectionStateConnecting: return @"connecting";
        case RTCPeerConnectionStateConnected: return @"connected";
        case RTCPeerConnectionStateDisconnected: return @"disconnected";
        case RTCPeerConnectionStateFailed: return @"failed";
        case RTCPeerConnectionStateClosed: return @"closed";
    }
    return nil;
}

-(RTCRtpEncodingParameters*)mapToEncoding:(NSDictionary*)map {
    RTCRtpEncodingParameters *encoding = [[RTCRtpEncodingParameters alloc] init];
    encoding.isActive = YES;
    encoding.scaleResolutionDownBy = [NSNumber numberWithDouble:1.0];
    encoding.numTemporalLayers = [NSNumber numberWithInt:1];
#if TARGET_OS_IPHONE
    encoding.networkPriority = RTCPriorityLow;
    encoding.bitratePriority = 1.0;
#endif
    [encoding setRid:map[@"rid"]];
    
    if(map[@"active"] != nil) {
        [encoding setIsActive:((NSNumber*)map[@"active"]).boolValue];
    }
    
    if(map[@"minBitrate"] != nil) {
        [encoding setMinBitrateBps:(NSNumber*)map[@"minBitrate"]];
    }
    
    if(map[@"maxBitrate"] != nil) {
        [encoding setMaxBitrateBps:(NSNumber*)map[@"maxBitrate"]];
    }
    
    if(map[@"maxFramerate"] != nil) {
        [encoding setMaxFramerate:(NSNumber*)map[@"maxFramerate"]];
    }
    
    if(map[@"numTemporalLayers"] != nil) {
        [encoding setNumTemporalLayers:(NSNumber*)map[@"numTemporalLayers"]];
    }
    
    if(map[@"scaleResolutionDownBy"] != nil) {
        [encoding setScaleResolutionDownBy:(NSNumber*)map[@"scaleResolutionDownBy"]];
    }
    return  encoding;
}

@end
