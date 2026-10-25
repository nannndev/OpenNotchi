import Foundation

struct NineRouterQuota: Equatable {
    var name: String
    var used: Double
    var total: Double
    var remaining: Double
    var remainingPercentage: Double
    var resetAt: Date?
    var unlimited: Bool

    var isExhausted: Bool {
        if unlimited { return false }
        if total > 0 && used >= total { return true }
        return remainingPercentage <= 0.0
    }
}

struct NineRouterConnection: Identifiable, Equatable {
    var id: String
    var provider: String
    var name: String
    var email: String?
    var priority: Int
    var isActive: Bool
    var authType: String
    var testStatus: String?
    var lastError: String?
    var errorCode: Int?
    var plan: String?
    var quotas: [NineRouterQuota] = []
    var todayTokens: Int = 0
    var todayCost: Double = 0.0
    var days: [Int] = [Int](repeating: 0, count: 7)
}
