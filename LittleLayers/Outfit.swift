import Foundation

struct Child: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var age: Int
    var runsCold = false

    init(id: UUID = UUID(), name: String, age: Int = 6, runsCold: Bool = false) {
        self.id = id
        self.name = name
        self.age = age
        self.runsCold = runsCold
    }

    private enum CodingKeys: String, CodingKey { case id, name, age, runsCold }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try values.decode(String.self, forKey: .name)
        age = try values.decodeIfPresent(Int.self, forKey: .age) ?? 6
        runsCold = try values.decodeIfPresent(Bool.self, forKey: .runsCold) ?? false
    }
}

struct Forecast: Decodable {
    let hourly: Hourly
    struct Hourly: Decodable {
        let time: [String]
        let apparent_temperature: [Double?]
        let precipitation_probability: [Double?]
        let snowfall: [Double?]
        let snow_depth: [Double?]
    }
    func hours(on date: Date = .now, from start: Int, through end: Int) -> [Hour] {
        let day = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let datePrefix = String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0)
        return hourly.time.indices.compactMap { i in
            guard hourly.time[i].hasPrefix(datePrefix),
                  let hour = Int(hourly.time[i].suffix(5).prefix(2)),
                  (start...end).contains(hour),
                  hourly.apparent_temperature.indices.contains(i),
                  let feels = hourly.apparent_temperature[i] else { return nil }
            return Hour(hour: hour, feels: feels,
                        rain: hourly.precipitation_probability.indices.contains(i) ? hourly.precipitation_probability[i] : nil,
                        snowfall: hourly.snowfall.indices.contains(i) ? hourly.snowfall[i] : nil,
                        snowDepth: hourly.snow_depth.indices.contains(i) ? hourly.snow_depth[i] : nil)
        }
    }
}

struct Hour {
    let hour: Int
    let feels: Double
    let rain: Double?
    let snowfall: Double?
    let snowDepth: Double?
}

struct Outfit {
    let layers: String
    let shoes: String
    let extras: String
    let reason: String

    static func recommend(hours: [Hour], age: Int, runsCold: Bool, groundSnow: Bool) -> Outfit? {
        guard let low = hours.map(\.feels).min(), let high = hours.map(\.feels).max() else { return nil }
        let youngChildAdjustment = age <= 4 ? 2.0 : 0.0
        let adjusted = low - (runsCold ? 3 : 0) - youngChildAdjustment
        let wet = hours.contains { ($0.rain ?? 0) >= 40 }
        let snow = groundSnow || hours.contains { ($0.snowfall ?? 0) > 0 || ($0.snowDepth ?? 0) >= 0.01 }
        let layers: String
        switch adjusted {
        case ..<0: layers = "Warm base layer, fleece & winter jacket"
        case ..<7: layers = "Long sleeves & thick jacket"
        case ..<13: layers = "Long sleeves & light jacket"
        case ..<19: layers = "T-shirt & hoodie"
        default: layers = "Light T-shirt & breathable clothes"
        }
        let shoes = snow ? "Waterproof insulated snow boots" : wet ? "Waterproof shoes or rain boots" : "Comfortable sneakers"
        var extras: [String] = []
        if adjusted < 7 { extras.append("Warm hat & gloves") }
        if wet { extras.append("Waterproof outer layer") }
        if high - low >= 6 { extras.append("Wear a removable layer in the morning; take it off if the afternoon warms up") }
        if high >= 24 { extras.append("Sun hat & water bottle") }
        if extras.isEmpty { extras.append("Regular socks") }
        var reason = "Uses the coldest feels-like temperature during your selected hours."
        if age <= 4 { reason += " Adds warmth for a younger child." }
        if runsCold { reason += " A warmer outfit is selected because this child runs cold." }
        if snow { reason += " Snow is forecast or reported on the ground." }
        if hours.contains(where: { $0.rain == nil || $0.snowfall == nil || $0.snowDepth == nil }) {
            reason += " Some rain or snow data is unavailable; check local ground conditions."
        }
        return Outfit(layers: layers, shoes: shoes, extras: extras.joined(separator: " · "), reason: reason)
    }
}
