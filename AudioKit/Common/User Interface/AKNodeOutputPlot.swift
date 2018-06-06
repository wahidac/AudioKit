//
//  AKNodeOutputPlot.swift
//  AudioKitUI
//
//  Created by Aurelius Prochazka, revision history on Github.
//  Copyright © 2018 AudioKit. All rights reserved.
//

extension Notification.Name {
    static let IAAConnected = Notification.Name(rawValue: "IAAConnected")
    static let IAADisconnected = Notification.Name(rawValue: "IAADisconnected")
}

/// Plot the output from any node in an signal processing graph
@IBDesignable
open class AKNodeOutputPlot: EZAudioPlot {

    public var isConnected = false

    internal func setupNode(_ input: AKNode?) {
        if !isConnected {
            // Tap = something that just reads from the source but doesnt fuck w/ it
            input?.avAudioNode.installTap(
                onBus: 0,
                bufferSize: bufferSize,
                format: nil) { [weak self] (buffer, _) in
                    // TODO: Figure out how to get the "buffer" here in one shot and store it in memory
                    // (with obvious memory limits). "buffer" is just a AVAudioPCMBuffer object. We
                    // want one AVAudioPCMBuffer object (this is an apple class)
                    
                    // TODO: input in this case by default = AudioKit.output i.e. the node we connect to the
                    // mixer -> engines output. isnt literally the engines output node but for purposes of
                    // the consumer, it is the final output node
                    guard let strongSelf = self else {
                        AKLog("Unable to create strong reference to self")
                        return
                    }
                    buffer.frameLength = strongSelf.bufferSize
                    let offset = Int(buffer.frameCapacity - buffer.frameLength)
                    if let tail = buffer.floatChannelData?[0] {
                        // TODO: we might just be ignoring one channel here.......
                        strongSelf.updateBuffer(&tail[offset], withBufferSize: strongSelf.bufferSize)
                    }
            }
        }
        isConnected = true
    }

    // Useful to reconnect after connecting to Audiobus or IAA
    @objc func reconnect() {
        node?.avAudioNode.removeTap(onBus: 0)
        setupNode(node)
    }

    @objc open func pause() {
        if isConnected {
            node?.avAudioNode.removeTap(onBus: 0)
            isConnected = false
        }
    }

    @objc open func resume() {
        setupNode(node)
    }

    func setupReconnection() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reconnect),
                                               name: .IAAConnected,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reconnect),
                                               name: .IAADisconnected,
                                               object: nil)
    }

    internal var bufferSize: UInt32 = 1_024

    /// The node whose output to graph
    @objc open var node: AKNode? {
        willSet {
            node?.avAudioNode.removeTap(onBus: 0)
        }
        didSet {
            setupNode(node)
        }
    }

    deinit {
        node?.avAudioNode.removeTap(onBus: 0)
    }

    /// Required coder-based initialization (for use with Interface Builder)
    ///
    /// - parameter coder: NSCoder
    ///
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupNode(AudioKit.output)
        setupReconnection()
    }

    /// Initialize the plot with the output from a given node and optional plot size
    ///
    /// - Parameters:
    ///   - input: AKNode from which to get the plot data
    ///   - width: Width of the view
    ///   - height: Height of the view
    ///
    @objc public init(_ input: AKNode? = AudioKit.output, frame: CGRect, bufferSize: Int = 1_024) {
        // Uses the default AudioKit.output node as its input if none is specified, we will want to
        // ultimately specift directly the node to use
        super.init(frame: frame)
        self.plotType = .buffer
        self.backgroundColor = AKColor.white
        self.shouldCenterYAxis = true
        self.bufferSize = UInt32(bufferSize)

        setupNode(input)
        self.node = input
        setupReconnection()
    }
}
