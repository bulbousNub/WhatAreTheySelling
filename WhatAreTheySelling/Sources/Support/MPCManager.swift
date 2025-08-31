import Foundation
import MultipeerConnectivity
import Combine

@MainActor
final class MPCManager: NSObject, ObservableObject {
    static let serviceType = "wats-game"
    static let shared = MPCManager()

    @Published private(set) var session: MPSession?
    @Published private(set) var isHost: Bool = false
    @Published private(set) var connectedPeers: [MCPeerID] = []

    private var peerID: MCPeerID!
    private var mcSession: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var cancellables = Set<AnyCancellable>()

    // MARK: Setup

    func configurePeer(displayName: String) {
        // Regenerate peerID if display name changes to avoid stale naming
        self.peerID = MCPeerID(displayName: displayName)
        self.mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        self.mcSession.delegate = self
    }

    // MARK: Host

    func host(code: String, me: MPPlayer) {
        isHost = true
        let info = ["code": code]
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: info, serviceType: Self.serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()

        session = MPSession(code: code, hostID: me.id, judgeID: me.id, round: 1, startedAt: Date(),
                            status: .lobby, players: [me])
    }

    // MARK: Join

    func join(code: String) {
        isHost = false
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        // We’ll filter invitations by matching discoveryInfo["code"] in foundPeer callback
        pendingJoinCode = code.uppercased()
    }

    // MARK: Lifecycle

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        advertiser = nil
        browser = nil
        mcSession.disconnect()
        connectedPeers.removeAll()
        session = nil
        isHost = false
    }

    // MARK: Events

    func send(_ event: MPEvent) {
        guard let data = try? JSONEncoder().encode(event) else { return }
        do {
            try mcSession.send(data, toPeers: mcSession.connectedPeers, with: .reliable)
        } catch {
            print("send error:", error)
        }
        // Host mirrors authoritative mutations locally
        if isHost { apply(event) }
    }

    private func apply(_ event: MPEvent) {
        guard var s = session else { return }

        switch event {
        case .join(let p):
            if !s.players.contains(where: { $0.id == p.id }) {
                s.players.append(p)
            }
        case .leave(let id):
            if let i = s.players.firstIndex(where: { $0.id == id }) {
                s.players[i].isConnected = false
            }
        case .setCategory(let id, let cat):
            if let i = s.players.firstIndex(where: { $0.id == id }) {
                s.players[i].selectedCategory = cat
            }
        case .startPicking(let round, _):
            s.round = round
            s.status = .picking
            // Clear previous picks
            for i in s.players.indices { s.players[i].selectedCategory = nil }
        case .startJudging:
            s.status = .judging
        case .awardPoints(let deltas):
            for (pid, delta) in deltas {
                if let i = s.players.firstIndex(where: { $0.id == pid }) {
                    s.players[i].sessionScore += delta
                }
            }
        case .endRound:
            s.status = .playing
        case .endGame:
            s.status = .ended
        case .syncFull(let full):
            s = full
        }
        session = s
    }

    // Host-only: push full state to new peers
    func syncFullState(to peers: [MCPeerID]) {
        guard isHost, let s = session, let data = try? JSONEncoder().encode(MPEvent.syncFull(session: s)) else { return }
        try? mcSession.send(data, toPeers: peers, with: .reliable)
    }

    // MARK: Private

    private var pendingJoinCode: String?
}

extension MPCManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            connectedPeers = mcSession.connectedPeers
            if state == .connected, isHost {
                syncFullState(to: [peerID])
            }
        }
    }
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let event = try? JSONDecoder().decode(MPEvent.self, from: data) else { return }
        Task { @MainActor in
            // Non-hosts apply remote events from host; host already applied locally on send
            if !isHost { apply(event) }
        }
    }
    // Unused channels for this MVP
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension MPCManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Accept all invitations for this MVP
        invitationHandler(true, mcSession)
    }
}

extension MPCManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        guard let want = pendingJoinCode else { return }
        let code = (info?["code"] ?? "").uppercased()
        guard code == want else { return }
        browser.invitePeer(peerID, to: mcSession, withContext: nil, timeout: 15)
    }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}