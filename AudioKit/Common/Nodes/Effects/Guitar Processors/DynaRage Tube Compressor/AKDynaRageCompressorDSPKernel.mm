//
//  AKDynaRageCompressorDSPKernel.mm
//  AudioKit
//
//  Created by Stéphane Peter, revision history on Githbub.
//  Copyright © 2018 AudioKit. All rights reserved.
//

#include "AKDynaRageCompressorDSPKernel.hpp"

#import "Compressor.h"
#import "RageProcessor.h"

struct AKDynaRageCompressorDSPKernel::_Internal {
    Compressor *left_compressor;
    Compressor *right_compressor;
    
    RageProcessor *left_rageprocessor;
    RageProcessor *right_rageprocessor;
    
    float ratio = 1.0;
    float threshold = 0.0;
    float attackTime = 0.1;
    float releaseTime = 0.1;
    float rage = 0.1;
    BOOL rageIsOn = true;
};

AKDynaRageCompressorDSPKernel::AKDynaRageCompressorDSPKernel() : _private(new _Internal) {}
AKDynaRageCompressorDSPKernel::~AKDynaRageCompressorDSPKernel() = default;

void AKDynaRageCompressorDSPKernel::init(int _channels, double _sampleRate) {
    AKDSPKernel::init(_channels, _sampleRate);
    _private->left_compressor = new Compressor(_private->threshold, _private->ratio,
                                               _private->attackTime, _private->releaseTime, (int)_sampleRate);
    _private->right_compressor = new Compressor(_private->threshold, _private->ratio, _private->attackTime,
                                                _private->releaseTime, (int)_sampleRate);
    
    _private->left_rageprocessor = new RageProcessor((int)_sampleRate);
    _private->right_rageprocessor = new RageProcessor((int)_sampleRate);
    
    ratioRamper.init();
    thresholdRamper.init();
    attackTimeRamper.init();
    releaseTimeRamper.init();
    rageRamper.init();
}

void AKDynaRageCompressorDSPKernel::reset() {
    resetted = true;
    ratioRamper.reset();
    thresholdRamper.reset();
    attackTimeRamper.reset();
    releaseTimeRamper.reset();
    rageRamper.reset();
}

void AKDynaRageCompressorDSPKernel::setRatio(float value) {
    _private->ratio = clamp(value, 1.0f, 20.0f);
    ratioRamper.setImmediate(_private->ratio);
}

void AKDynaRageCompressorDSPKernel::setThreshold(float value) {
    _private->threshold = clamp(value, -100.0f, 0.0f);
    thresholdRamper.setImmediate(_private->threshold);
}

void AKDynaRageCompressorDSPKernel::setAttackTime(float value) {
    _private->attackTime = clamp(value, 20.0f, 500.0f);
    attackTimeRamper.setImmediate(_private->attackTime);
}

void AKDynaRageCompressorDSPKernel::setReleaseTime(float value) {
    _private->releaseTime = clamp(value, 20.0f, 500.0f);
    releaseTimeRamper.setImmediate(_private->releaseTime);
}

void AKDynaRageCompressorDSPKernel::setRage(float value) {
    _private->rage = clamp(value, 0.1f, 20.0f);
    rageRamper.setImmediate(_private->rage);
}

void AKDynaRageCompressorDSPKernel::setRageIsOn(bool value) {
    _private->rageIsOn = value;
}

void AKDynaRageCompressorDSPKernel::setParameter(AUParameterAddress address, AUValue value) {
    switch (address) {
        case ratioAddress:
            ratioRamper.setUIValue(clamp(value, 1.0f, 20.0f));
            break;
            
        case thresholdAddress:
            thresholdRamper.setUIValue(clamp(value, -100.0f, 0.0f));
            break;
            
        case attackTimeAddress:
            attackTimeRamper.setUIValue(clamp(value, 0.1f, 500.0f));
            break;
            
        case releaseTimeAddress:
            releaseTimeRamper.setUIValue(clamp(value, 0.1f, 500.0f));
            break;
            
        case rageAddress:
            rageRamper.setUIValue(clamp(value, 0.1f, 20.0f));
            break;
            
            break;
    }
}

AUValue AKDynaRageCompressorDSPKernel::getParameter(AUParameterAddress address) {
    switch (address) {
        case ratioAddress:
            return ratioRamper.getUIValue();
            
        case thresholdAddress:
            return thresholdRamper.getUIValue();
            
        case attackTimeAddress:
            return attackTimeRamper.getUIValue();
            
        case releaseTimeAddress:
            return releaseTimeRamper.getUIValue();
            
        case rageAddress:
            return rageRamper.getUIValue();
            
        default: return 0.0f;
    }
}

void AKDynaRageCompressorDSPKernel::startRamp(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) {
    switch (address) {
        case ratioAddress:
            ratioRamper.startRamp(clamp(value, 1.0f, 20.0f), duration);
            break;
            
        case thresholdAddress:
            thresholdRamper.startRamp(clamp(value, -100.0f, 0.0f), duration);
            break;
            
        case attackTimeAddress:
            attackTimeRamper.startRamp(clamp(value, 0.1f, 500.0f), duration);
            break;
            
        case releaseTimeAddress:
            releaseTimeRamper.startRamp(clamp(value, 0.1f, 500.0f), duration);
            break;
            
        case rageAddress:
            rageRamper.startRamp(clamp(value, 0.1f, 20.0f), duration);
            break;
    }
}

void AKDynaRageCompressorDSPKernel::process(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) {
    
    for (int frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
        
        int frameOffset = int(frameIndex + bufferOffset);
        
        _private->ratio = ratioRamper.getAndStep();
        _private->threshold = thresholdRamper.getAndStep();
        _private->attackTime = attackTimeRamper.getAndStep();
        _private->releaseTime = releaseTimeRamper.getAndStep();
        _private->rage = rageRamper.getAndStep();
        
        _private->left_compressor->setParameters(_private->threshold, _private->ratio,
                                                 _private->attackTime, _private->releaseTime);
        _private->right_compressor->setParameters(_private->threshold, _private->ratio,
                                                  _private->attackTime, _private->releaseTime);
        
        for (int channel = 0; channel < channels; ++channel) {
            float *in  = (float *)inBufferListPtr->mBuffers[channel].mData  + frameOffset;
            float *out = (float *)outBufferListPtr->mBuffers[channel].mData + frameOffset;
            
            if (started) {
                if (channel == 0) {
                    
                    float rageSignal = _private->left_rageprocessor->doRage(*in, _private->rage, _private->rage);
                    float compSignal = _private->left_compressor->Process((bool)_private->rageIsOn ? rageSignal : *in, false, 1);
                    *out = compSignal;
                } else {
                    float rageSignal = _private->right_rageprocessor->doRage(*in, _private->rage, _private->rage);
                    float compSignal = _private->right_compressor->Process((bool)_private->rageIsOn ? rageSignal : *in, false, 1);
                    *out = compSignal;
                }
            } else {
                *out = *in;
            }
        }
    }
}
