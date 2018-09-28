//
//  ADSREnvelope.hpp
//  AudioKit Core
//
//  Created by Shane Dunne, revision history on Github.
//  Copyright © 2018 AudioKit. All rights reserved.
//

#include "ADSREnvelope.hpp"
#include <stdio.h>

namespace AudioKitCore
{

    ADSREnvelopeParameters::ADSREnvelopeParameters()
    : sampleRateHz(44100.0f) // a guess, will be overridden later by a call to init(,,,,)
    {
        init(0.0f, 0.0f, 1.0f, 0.0f);
    }
    
    void ADSREnvelopeParameters::init(float attackSeconds, float decaySeconds, float susFraction, float releaseSeconds)
    {
        attackSamples = attackSeconds * sampleRateHz;
        decaySamples = decaySeconds * sampleRateHz;
        sustainFraction = susFraction;
        releaseSamples = releaseSeconds * sampleRateHz;
    }
    
    void ADSREnvelopeParameters::init(float newSampleRateHz, float attackSeconds, float decaySeconds, float susFraction, float releaseSeconds)
    {
        sampleRateHz = newSampleRateHz;
        init(attackSeconds, decaySeconds, susFraction, releaseSeconds);
    }
    
    void ADSREnvelopeParameters::updateSampleRate(float newSampleRateHz)
    {
        float scaleFactor = newSampleRateHz / sampleRateHz;
        sampleRateHz = newSampleRateHz;
        attackSamples *= scaleFactor;
        decaySamples *= scaleFactor;
        releaseSamples *= scaleFactor;
    }
    
    
    void ADSREnvelope::init()
    {
        segment = kIdle;
        ramper.init(0.0f);
    }
    
    void ADSREnvelope::start()
    {
        // have to make attack go above 1.0, or decay won't work if sustain is 1.0
        ramper.init(0.0f, 1.01f, pParameters->attackSamples);
        segment = kAttack;
    }
    
    void ADSREnvelope::release()
    {
        if (ramper.value == 0.0f) init();
        else
        {
            segment = kRelease;
            ramper.reinit(0.0f, pParameters->releaseSamples);
        }
    }

    void ADSREnvelope::restart()
    {
        if (ramper.value == 0.0f) init();
        else
        {
            segment = kSilence;
            ramper.reinit(0.0f, 0.01f * pParameters->sampleRateHz); // always silence in 10 ms
        }
    }

    void ADSREnvelope::reset()
    {
        init();
    }

}
