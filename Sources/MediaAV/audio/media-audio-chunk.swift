import Foundation
import MediaCore

public struct MediaAudioChunk: Sendable {
    public let trackID: Int32
    public let buffer: MediaAudioBuffer
    public let presentationTimeSeconds: TimeInterval?
    public let durationSeconds: TimeInterval?

    public init(
        trackID: Int32,
        buffer: MediaAudioBuffer,
        presentationTimeSeconds: TimeInterval?,
        durationSeconds: TimeInterval?
    ) {
        self.trackID = trackID
        self.buffer = buffer
        self.presentationTimeSeconds = presentationTimeSeconds
        self.durationSeconds = durationSeconds
    }
}
