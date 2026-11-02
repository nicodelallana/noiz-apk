import ActivityKit
import Foundation

/// ActivityKit attributes and dynamic content state mirroring Barik's LiveTripState.
public struct LiveTripAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var currentStop: String
        public var nextStop: String
        public var stopsRemaining: Int
        public var progress: Double // 0.0 .. 1.0
        public var arrivalTime: Date
        public var status: String // scheduled | tracking | arriving | at_stop | delayed | disrupted | ended
        public var isRealtime: Bool
        public var delaySeconds: Int
        public var instruction: String?
        public var updatedAt: Date

        public init(
            currentStop: String,
            nextStop: String,
            stopsRemaining: Int,
            progress: Double,
            arrivalTime: Date,
            status: String,
            isRealtime: Bool,
            delaySeconds: Int,
            instruction: String? = nil,
            updatedAt: Date = Date()
        ) {
            self.currentStop = currentStop
            self.nextStop = nextStop
            self.stopsRemaining = stopsRemaining
            self.progress = progress
            self.arrivalTime = arrivalTime
            self.status = status
            self.isRealtime = isRealtime
            self.delaySeconds = delaySeconds
            self.instruction = instruction
            self.updatedAt = updatedAt
        }
    }

    // Static trip metadata immutable during the activity lifecycle
    public var tripId: String
    public var operatorId: String
    public var mode: String
    public var lineId: String
    public var lineName: String
    public var lineColorHex: String
    public var origin: String
    public var destination: String

    public init(
        tripId: String,
        operatorId: String,
        mode: String,
        lineId: String,
        lineName: String,
        lineColorHex: String,
        origin: String,
        destination: String
    ) {
        self.tripId = tripId
        self.operatorId = operatorId
        self.mode = mode
        self.lineId = lineId
        self.lineName = lineName
        self.lineColorHex = lineColorHex
        self.origin = origin
        self.destination = destination
    }
}
