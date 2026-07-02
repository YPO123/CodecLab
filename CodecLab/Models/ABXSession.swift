import Foundation

enum ABXIdentity: String, Codable {
    case original
    case encoded
}

struct ABXTrial: Codable, Identifiable, Equatable {
    let id: UUID
    let a: ABXIdentity
    let b: ABXIdentity
    let x: ABXIdentity
    var guess: ABXIdentity?

    var isCorrect: Bool {
        guess == x
    }
}

struct ABXSession: Codable, Equatable {
    let id: UUID
    let totalTrials: Int
    var trials: [ABXTrial]
    var currentIndex: Int

    var completedTrials: [ABXTrial] {
        trials.filter { $0.guess != nil }
    }

    var correctCount: Int {
        completedTrials.filter(\.isCorrect).count
    }

    var completedCount: Int {
        completedTrials.count
    }

    var isComplete: Bool {
        completedCount >= totalTrials
    }

    static func make(totalTrials: Int) -> ABXSession {
        let trials = (0..<totalTrials).map { _ in
            let originalIsA = Bool.random()
            let xIsOriginal = Bool.random()
            return ABXTrial(
                id: UUID(),
                a: originalIsA ? .original : .encoded,
                b: originalIsA ? .encoded : .original,
                x: xIsOriginal ? .original : .encoded,
                guess: nil
            )
        }
        return ABXSession(id: UUID(), totalTrials: totalTrials, trials: trials, currentIndex: 0)
    }
}

