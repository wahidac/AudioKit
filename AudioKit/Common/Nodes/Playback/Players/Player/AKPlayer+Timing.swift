//
//  AKPlayer+Timing.swift
//  AudioKit
//
//  Created by Ryan Francesconi on 6/12/18.
//  Copyright © 2018 AudioKit. All rights reserved.
//

// TODO: Turning the protocol conformance extension to just normal extension, crashing for some reason due to the player object not seeing the class extension
// Something to do w/ @objc modifier, I don't see a crash when i omit @objc from AKTiming...
extension AKPlayer {
    @objc public func start(at audioTime: AVAudioTime?) {
        play(at: audioTime)
    }

    public var isStarted: Bool {
        return isPlaying
    }

    @objc public func setPosition(_ position: Double) {
        startTime = position
        if isPlaying {
            stop()
            play()
        }
    }

    @objc public func position(at audioTime: AVAudioTime?) -> Double {
        guard let playerTime = playerNode.playerTime(forNodeTime: audioTime ?? AVAudioTime.now()) else {
            return startTime
        }
        return startTime + Double(playerTime.sampleTime) / playerTime.sampleRate
    }

    @objc public func audioTime(at position: Double) -> AVAudioTime? {
        let sampleRate = playerNode.outputFormat(forBus: 0).sampleRate
        let sampleTime = (position - startTime) * sampleRate
        let playerTime = AVAudioTime(sampleTime: AVAudioFramePosition(sampleTime), atRate: sampleRate)
        return playerNode.nodeTime(forPlayerTime: playerTime)
    }

    open func prepare() {
        preroll(from: startTime, to: endTime)
    }
}
