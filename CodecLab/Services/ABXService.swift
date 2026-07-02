import Combine
import Foundation

final class ABXService: ObservableObject {
    @Published private(set) var session: ABXSession?

    func start(totalTrials: Int = 10) {
        session = ABXSession.make(totalTrials: totalTrials)
    }

    func submitGuess(_ identity: ABXIdentity) {
        guard var current = session, current.currentIndex < current.trials.count else { return }
        current.trials[current.currentIndex].guess = identity
        if current.currentIndex < current.trials.count - 1 {
            current.currentIndex += 1
        }
        session = current
    }

    func reset() {
        session = nil
    }

    static func pValue(correct: Int, total: Int) -> Double {
        guard total > 0, correct <= total else { return 1 }
        let tail = correct...total
        return tail.reduce(0.0) { sum, k in
            sum + combination(total, k) * pow(0.5, Double(total))
        }
    }

    private static func combination(_ n: Int, _ k: Int) -> Double {
        guard k >= 0, k <= n else { return 0 }
        let k = min(k, n - k)
        guard k > 0 else { return 1 }

        var result = 1.0
        for value in 1...k {
            result *= Double(n - k + value)
            result /= Double(value)
        }
        return result
    }
}

