//
//  ZiggyParkVoice.swift
//  Ziggy
//
//  Talking while you walk.
//
//  The voices go straight from one phone to the other over WebRTC; Firestore
//  only introduces them. Each phone that joins writes a small document,
//  `relationships/{code}/games/ziggyPark/voice/{deviceID}`, saying it is
//  here and naming this visit with a fresh session ID. When both are there,
//  the phone with the smaller device ID writes an offer addressed to the
//  other's session, and the other writes back an answer. Every candidate
//  route is gathered before either is sent, so that one exchange is the
//  whole conversation; after it, nothing more goes through Firestore except
//  a heartbeat every few seconds and whether you are muted.
//
//  If either of you leaves and comes back, the new session ID tells the other
//  phone to start again from the top. If the connection drops, the offering
//  phone sends a new offer.
//
//  How loudly each of you is speaking is read from the connection a few
//  times a second, for the rings that light up on screen. Your partner's
//  voice is a little softer when they are far off along the path and full
//  when they are at your side.
//

import AVFoundation
import FirebaseFirestore
import Foundation
import Observation
import WebRTC

@available(iOS 18.0, *)
@Observable
final class ZiggyParkVoice {

    enum State: Equatable {
        /// Not in voice chat.
        case off
        /// In, and waiting for your partner to join too.
        case waiting
        /// Both in, the phones finding each other.
        case connecting
        /// Talking.
        case live
        /// The microphone is not allowed.
        case noMic
    }

    private(set) var state: State = .off
    private(set) var muted = false
    private(set) var speaker = true
    /// How loudly each of you is talking right now, 0...1.
    private(set) var myLevel: Float = 0
    private(set) var partnerLevel: Float = 0
    private(set) var partnerMuted = false
    /// Your partner's name, once they have joined.
    private(set) var partnerName = ""

    var isOn: Bool { state != .off && state != .noMic }

    @ObservationIgnored private let myID = FirestoreManager.shared.currentDeviceID
    @ObservationIgnored private var session = UUID().uuidString
    @ObservationIgnored private var voice: CollectionReference?
    @ObservationIgnored private var listener: ListenerRegistration?
    @ObservationIgnored private var heartbeat: Timer?
    @ObservationIgnored private var meter: Timer?

    @ObservationIgnored private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        return RTCPeerConnectionFactory(encoderFactory: RTCDefaultVideoEncoderFactory(), decoderFactory: RTCDefaultVideoDecoderFactory())
    }()
    @ObservationIgnored private var peer: RTCPeerConnection?
    @ObservationIgnored private var peerDelegate: PeerDelegate?
    @ObservationIgnored private var localTrack: RTCAudioTrack?
    /// Your partner's session this connection is for.
    @ObservationIgnored private var peerSession: String?
    @ObservationIgnored private var partnerID: String?
    /// The offer this connection was made from, so each is answered once.
    @ObservationIgnored private var offerID: String?
    @ObservationIgnored private var answered = false
    @ObservationIgnored private var partnerVolume: Double = 1
    @ObservationIgnored private var lastHeard: [String: Double] = [:]
    @ObservationIgnored private var routeWatch: NSObjectProtocol?
    /// How much your partner's voice is turned up: the call would otherwise
    /// be at phone-call loudness, too quiet over the speaker outdoors.
    private static let boost: Double = 3

    private static var clock: Double { Date().timeIntervalSince1970 }

    // MARK: Joining and leaving

    func join() {
        guard state == .off || state == .noMic else { return }
        let code = RelationshipManager.shared.relationshipCode
        guard !code.isEmpty else { return }

        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                guard granted else { self.state = .noMic; return }
                self.start(code: code)
            }
        }
    }

    private func start(code: String) {
        configureAudio(on: true)
        session = UUID().uuidString
        muted = false
        state = .waiting
        voice = Firestore.firestore()
            .collection("relationships").document(code)
            .collection("games").document("ziggyPark")
            .collection("voice")
        writeMine(["here": true, "session": session, "muted": false, "at": Self.clock, "name": UserManager.shared.username,
                   "offer": FieldValue.delete(), "answer": FieldValue.delete()])

        listener = voice?.addSnapshotListener { [weak self] snapshot, error in
            guard error == nil, let snapshot else { return }
            self?.receive(snapshot.documents.map { ($0.documentID, $0.data()) })
        }
        // A heartbeat, so a phone that vanished without saying goodbye is
        // noticed, and the meters for the rings.
        heartbeat = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.writeMine(["at": Self.clock])
                self.checkPartnerStillThere()
            }
        }
        meter = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.readLevels() }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func leave() {
        guard isOn else { if state == .noMic { state = .off }; return }
        writeMine(["here": false, "offer": FieldValue.delete(), "answer": FieldValue.delete()])
        listener?.remove()
        listener = nil
        heartbeat?.invalidate()
        meter?.invalidate()
        heartbeat = nil
        meter = nil
        closePeer()
        configureAudio(on: false)
        state = .off
        myLevel = 0
        partnerLevel = 0
        partnerMuted = false
    }

    func toggleMute() {
        muted.toggle()
        localTrack?.isEnabled = !muted
        writeMine(["muted": muted])
        if muted { myLevel = 0 }
    }

    func toggleSpeaker() {
        speaker.toggle()
        let audio = RTCAudioSession.sharedInstance()
        audio.lockForConfiguration()
        try? audio.overrideOutputAudioPort(speaker ? .speaker : .none)
        audio.unlockForConfiguration()
    }

    /// Softer when your partner is far away along the path, full beside you.
    func setPartnerDistance(_ distance: Float?) {
        let wanted: Double = distance.map { Double(min(1, max(0.4, 1.25 - $0 / 24))) } ?? 1
        guard abs(wanted - partnerVolume) > 0.03 else { return }
        partnerVolume = wanted
        remoteTrack?.source.volume = wanted * Self.boost
    }

    private var remoteTrack: RTCAudioTrack? {
        peer?.transceivers.lazy.compactMap { $0.receiver.track as? RTCAudioTrack }.first
    }

    /// Out loud through the speaker, like a video call, not quietly at
    /// your ear like a phone call: you are walking along, not holding the
    /// phone to your head.
    ///
    /// WebRTC sets the audio session up again itself whenever it starts its
    /// audio, from its own default — which is a phone call on the earpiece —
    /// so that default is changed too, not just the session as it is now.
    /// "Video chat" keeps the echo cancelling of a call but plays from the
    /// loudspeaker.
    private func configureAudio(on: Bool) {
        var options: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetoothA2DP]
        if #available(iOS 26.0, *) { options.insert(.allowBluetoothHFP) }
        let defaults = RTCAudioSessionConfiguration.webRTC()
        defaults.category = AVAudioSession.Category.playAndRecord.rawValue
        defaults.mode = AVAudioSession.Mode.videoChat.rawValue
        defaults.categoryOptions = options
        RTCAudioSessionConfiguration.setWebRTC(defaults)

        let audio = RTCAudioSession.sharedInstance()
        audio.lockForConfiguration()
        defer { audio.unlockForConfiguration() }
        if on {
            try? audio.setCategory(.playAndRecord, mode: .videoChat, options: options)
            try? audio.setActive(true)
            if speaker { try? audio.overrideOutputAudioPort(.speaker) }
            routeWatch = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.keepOnSpeaker() }
            }
        } else {
            if let routeWatch { NotificationCenter.default.removeObserver(routeWatch) }
            routeWatch = nil
            try? audio.setActive(false)
        }
    }

    /// If the sound has slipped back to the earpiece (WebRTC starting up,
    /// headphones coming out), puts it back on the speaker.
    private func keepOnSpeaker() {
        guard isOn, speaker else { return }
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs.map(\.portType)
        guard outputs.contains(.builtInReceiver) else { return }
        let audio = RTCAudioSession.sharedInstance()
        audio.lockForConfiguration()
        try? audio.overrideOutputAudioPort(.speaker)
        audio.unlockForConfiguration()
    }

    private func writeMine(_ fields: [String: Any]) {
        voice?.document(myID).setData(fields, merge: true)
    }

    // MARK: Signalling

    private func receive(_ documents: [(id: String, data: [String: Any])]) {
        guard isOn else { return }
        let now = Self.clock
        let partner = documents.first { id, data in
            id != myID && data["here"] as? Bool == true && now - Self.double(data["at"]) < 40
        }
        guard let (id, data) = partner, let theirSession = data["session"] as? String else {
            partnerLeft()
            return
        }
        lastHeard[id] = now
        partnerID = id
        partnerMuted = data["muted"] as? Bool ?? false
        partnerName = data["name"] as? String ?? ""

        // Someone new, or the same person back again: start over.
        if theirSession != peerSession {
            closePeer()
            peerSession = theirSession
            state = .connecting
            if myID < id { makeOffer() }
        }

        if myID < id {
            // Offering: take their answer to the current offer.
            if !answered, let answer = data["answer"] as? [String: Any],
               answer["to"] as? String == session, answer["for"] as? String == offerID,
               let sdp = answer["sdp"] as? String {
                answered = true
                peer?.setRemoteDescription(RTCSessionDescription(type: .answer, sdp: sdp)) { _ in }
            }
        } else {
            // Answering: take each new offer addressed to this visit.
            if let offer = data["offer"] as? [String: Any],
               offer["to"] as? String == session, offer["from"] as? String == theirSession,
               let id = offer["id"] as? String, id != offerID,
               let sdp = offer["sdp"] as? String {
                closePeer(keepingSession: true)
                offerID = id
                answer(sdp, offerID: id)
            }
        }
    }

    private func checkPartnerStillThere() {
        guard let partnerID, let heard = lastHeard[partnerID] else { return }
        // The listener stays quiet while nothing changes; the heartbeat
        // keeps it talking. Forty seconds without a word and they have gone.
        if Self.clock - heard > 40 { partnerLeft() }
    }

    private func partnerLeft() {
        guard peerSession != nil || state == .connecting || state == .live else { return }
        closePeer()
        peerSession = nil
        partnerLevel = 0
        if isOn { state = .waiting }
    }

    private func makePeer() -> RTCPeerConnection? {
        let config = RTCConfiguration()
        config.iceServers = [RTCIceServer(urlStrings: [
            "stun:stun.l.google.com:19302",
            "stun:stun1.l.google.com:19302",
            "stun:stun2.l.google.com:19302",
        ])]
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherOnce
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: ["DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue])

        let delegate = PeerDelegate()
        delegate.onState = { [weak self] state in
            DispatchQueue.main.async { self?.connectionChanged(state) }
        }
        guard let peer = Self.factory.peerConnection(with: config, constraints: constraints, delegate: delegate) else { return nil }

        let source = Self.factory.audioSource(with: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil))
        let track = Self.factory.audioTrack(with: source, trackId: "ziggy-voice")
        track.isEnabled = !muted
        peer.add(track, streamIds: ["ziggy"])
        localTrack = track
        peerDelegate = delegate
        self.peer = peer
        return peer
    }

    private func makeOffer() {
        guard let peer = makePeer() else { return }
        let id = UUID().uuidString
        offerID = id
        answered = false
        let constraints = RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveAudio": kRTCMediaConstraintsValueTrue], optionalConstraints: nil)
        peer.offer(for: constraints) { [weak self] sdp, _ in
            guard let sdp else { return }
            peer.setLocalDescription(sdp) { _ in
                self?.whenGathered(peer) { full in
                    guard let self, self.peer === peer, let to = self.peerSession else { return }
                    self.writeMine(["offer": ["sdp": full, "id": id, "from": self.session, "to": to], "answer": FieldValue.delete()])
                }
            }
        }
    }

    private func answer(_ offer: String, offerID id: String) {
        guard let peer = makePeer() else { return }
        state = .connecting
        peer.setRemoteDescription(RTCSessionDescription(type: .offer, sdp: offer)) { [weak self] error in
            guard error == nil else { return }
            let constraints = RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveAudio": kRTCMediaConstraintsValueTrue], optionalConstraints: nil)
            peer.answer(for: constraints) { sdp, _ in
                guard let sdp else { return }
                peer.setLocalDescription(sdp) { _ in
                    self?.whenGathered(peer) { full in
                        guard let self, self.peer === peer, let to = self.peerSession else { return }
                        self.writeMine(["answer": ["sdp": full, "for": id, "from": self.session, "to": to]])
                    }
                }
            }
        }
    }

    /// Waits until every route has been found (or a couple of seconds, which
    /// is plenty), then hands back the description with all of them in.
    private func whenGathered(_ peer: RTCPeerConnection, then send: @escaping (String) -> Void) {
        let started = Date()
        func check() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let done = peer.iceGatheringState == .complete || Date().timeIntervalSince(started) > 2.5
                if done, let sdp = peer.localDescription?.sdp { send(sdp) } else { check() }
            }
        }
        check()
    }

    private func connectionChanged(_ connection: RTCIceConnectionState) {
        guard isOn, peerSession != nil else { return }
        switch connection {
        case .connected, .completed:
            if state != .live { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            state = .live
            remoteTrack?.source.volume = partnerVolume * Self.boost
            keepOnSpeaker()
        case .failed:
            // Try again from a fresh offer; the answering phone follows.
            state = .connecting
            if let partnerID, myID < partnerID {
                closePeer(keepingSession: true)
                makeOffer()
            }
        case .disconnected:
            state = .connecting
        default:
            break
        }
    }

    private func closePeer(keepingSession: Bool = false) {
        peer?.close()
        peer = nil
        peerDelegate = nil
        localTrack = nil
        if !keepingSession {
            offerID = nil
            answered = false
        }
    }

    // MARK: Who is talking

    private func readLevels() {
        guard let peer, state == .live else {
            myLevel *= 0.6
            partnerLevel *= 0.6
            return
        }
        peer.statistics { [weak self] report in
            var mine: Float = 0, theirs: Float = 0
            for stat in report.statistics.values {
                guard stat.values["kind"] as? String == "audio" else { continue }
                let level = (stat.values["audioLevel"] as? NSNumber)?.floatValue ?? 0
                if stat.type == "media-source" { mine = level }
                if stat.type == "inbound-rtp" { theirs = level }
            }
            DispatchQueue.main.async {
                guard let self else { return }
                // Quick to light, slow to fade, like a voice rather than a flicker.
                let me = self.muted ? 0 : min(1, mine * 3)
                let them = min(1, theirs * 3)
                self.myLevel = me > self.myLevel ? me : self.myLevel * 0.7 + me * 0.3
                self.partnerLevel = them > self.partnerLevel ? them : self.partnerLevel * 0.7 + them * 0.3
            }
        }
    }

    private static func double(_ value: Any?) -> Double {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        return 0
    }
}

/// Hears from the connection on WebRTC's own thread and passes on the one
/// thing the voice chat needs.
nonisolated private final class PeerDelegate: NSObject, RTCPeerConnectionDelegate {

    var onState: ((RTCIceConnectionState) -> Void)?

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        onState?(newState)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}
