import Foundation
import Media

final class MediaAudioChunkCollector:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var chunks: [MediaAudioChunk] = []

    func append(
        _ chunk: MediaAudioChunk
    ) {
        lock.lock()

        chunks.append(
            chunk
        )

        lock.unlock()
    }

    func snapshot() -> [MediaAudioChunk] {
        lock.lock()

        defer {
            lock.unlock()
        }

        return chunks
    }
}
