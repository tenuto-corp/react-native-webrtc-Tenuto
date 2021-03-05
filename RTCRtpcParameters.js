'use strict';

import {NativeModules} from 'react-native';

const {WebRTCModule} = NativeModules;

export class RTCRTPCodec {
    payloadType: number;
    name: string;
    kind: string;
    clockRate: number;
    numChannels: string;
    parameters: {};

    constructor({payloadType, name, kind, clockRate, numChannels, parameters}) {
        this.payloadType = payloadType;
        this.name = name;
        this.kind = kind;
        this.clockRate = clockRate;
        this.numChannels = numChannels;
        this.parameters = parameters;
    }

    static FromMap(info) {
        const payloadType = info.payloadType;
        const name = info.name;
        const kind = info.kind;
        const clockRate = info.clockRate;
        const numChannels = info.numChannels ? info.numChannels : 1;
        const parameters = info.parameters;
        return RTCRTPCodec({payloadType, name, kind, clockRate, numChannels, parameters})
    }

    toMap(){
        return {
            payloadType, name, kind, clockRate, numChannels, parameters
        }
    }
}

export class RTCRtpEncoding{

}