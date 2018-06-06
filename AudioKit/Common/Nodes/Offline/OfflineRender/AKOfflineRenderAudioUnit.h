//
//  AKOfflineRenderAudioUnit.h
//  AudioKit
//
//  Created by David O'Neill, revision history on GitHub.
//  Copyright © 2018 AudioKit. All rights reserved.
//

#pragma once
#import "AKAudioUnit.h"

NS_DEPRECATED(10_10, 10_13, 8_0, 11_0)
@interface AKOfflineRenderAudioUnit : AKAudioUnit
@property BOOL internalRenderEnabled; // default = true;

// TODO: Can we use this? It returns exactly what we need, an AVAudioPCMBuffer. Or is there some simpler Apple API we can use
// to get an AVAudioPCMBuffer object w/ our data

-(AVAudioPCMBuffer * _Nullable)renderToBuffer:(NSTimeInterval)seconds error:(NSError *_Nullable*__null_unspecified)outError;

-(BOOL)renderToFile:(NSURL * _Nonnull)fileURL seconds:(double)seconds settings:(NSDictionary<NSString *, id> * _Nullable)settings error:(NSError * _Nullable * _Nullable)error;

@end
