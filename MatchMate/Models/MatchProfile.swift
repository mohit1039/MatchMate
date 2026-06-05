import Foundation

struct MatchProfile: Identifiable, Codable, Equatable {
    let id: Int
    let name: String
    let username: String
    let email: String
    let address: Address
    let phone: String
    let website: String
    let company: Company

    var initials: String {
        let parts = name.split(separator: " ")
        let firstLetters = parts.prefix(2).compactMap { $0.first }
        return String(firstLetters).uppercased()
    }

    var age: Int {
        24 + (id % 9)
    }

    var matchScore: Int {
        82 + ((id * 3) % 16)
    }

    var locationSummary: String {
        "\(address.city), \(address.zipcode)"
    }

    var profileSummary: String {
        "\(age) yrs | \(address.city)"
    }

    var professionSummary: String {
        company.name
    }
}

struct Address: Codable, Equatable {
    let street: String
    let suite: String
    let city: String
    let zipcode: String
    let geo: Geo

    var fullAddress: String {
        "\(suite), \(street), \(city)"
    }
}

struct Geo: Codable, Equatable {
    let lat: String
    let lng: String
}

struct Company: Codable, Equatable {
    let name: String
    let catchPhrase: String
    let bs: String
}

#if DEBUG
extension MatchProfile {
    static let preview = MatchProfile(
        id: 1,
        name: "Leanne Graham",
        username: "Bret",
        email: "leanne@example.com",
        address: Address(
            street: "Kulas Light",
            suite: "Apt. 556",
            city: "Gwenborough",
            zipcode: "92998-3874",
            geo: Geo(lat: "-37.3159", lng: "81.1496")
        ),
        phone: "1-770-736-8031",
        website: "hildegard.org",
        company: Company(
            name: "Romaguera-Crona",
            catchPhrase: "Multi-layered client-server neural-net",
            bs: "harness real-time e-markets"
        )
    )
}
#endif

