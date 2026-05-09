import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct PolleninformationClient<HTTPClient: PolleninformationHTTPClient>: Sendable {
    public let apiKey: String
    public let baseURL: URL
    private let httpClient: HTTPClient
    private let decoder: JSONDecoder

    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://www.polleninformation.at")!,
        httpClient: HTTPClient = URLSession.shared
    ) where HTTPClient == URLSession {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.httpClient = httpClient
        self.decoder = JSONDecoder()
    }

    public init(apiKey: String, baseURL: URL = URL(string: "https://www.polleninformation.at")!, httpClient: HTTPClient) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.httpClient = httpClient
        self.decoder = JSONDecoder()
    }

    public func forecast(_ request: ForecastRequest) async throws -> ForecastResponse {
        try await forecast(
            country: request.country,
            language: request.language,
            latitude: request.latitude,
            longitude: request.longitude
        )
    }

    public func forecast(
        country: CountryCode,
        language: LanguageCode,
        latitude: Double,
        longitude: Double
    ) async throws -> ForecastResponse {
        let request = try makeForecastURLRequest(
            country: country,
            language: language,
            latitude: latitude,
            longitude: longitude
        )
        let (data, response) = try await httpClient.data(for: request)

        if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
            throw PolleninformationError.api(message: apiError.error)
        }

        guard (200...299).contains(response.statusCode) else {
            throw PolleninformationError.httpStatus(response.statusCode)
        }

        do {
            return try decoder.decode(ForecastResponse.self, from: data)
        } catch {
            throw PolleninformationError.decoding(error)
        }
    }

    public func makeForecastURLRequest(
        country: CountryCode,
        language: LanguageCode,
        latitude: Double,
        longitude: Double
    ) throws -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent("/api/forecast/public"),
            resolvingAgainstBaseURL: false
        ) else {
            throw PolleninformationError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "country", value: country.rawValue),
            URLQueryItem(name: "lang", value: language.rawValue),
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "apikey", value: apiKey),
        ]

        guard let url = components.url else {
            throw PolleninformationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}

public protocol PolleninformationHTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension URLSession: PolleninformationHTTPClient {
    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let result: (Data, URLResponse) = try await withCheckedThrowingContinuation { continuation in
            let task = dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let data, let response else {
                    continuation.resume(throwing: PolleninformationError.invalidResponse)
                    return
                }

                continuation.resume(returning: (data, response))
            }
            task.resume()
        }

        guard let httpResponse = result.1 as? HTTPURLResponse else {
            throw PolleninformationError.invalidResponse
        }
        return (result.0, httpResponse)
    }
}

public struct ForecastRequest: Hashable, Sendable {
    public var country: CountryCode
    public var language: LanguageCode
    public var latitude: Double
    public var longitude: Double

    public init(country: CountryCode, language: LanguageCode, latitude: Double, longitude: Double) {
        self.country = country
        self.language = language
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct CountryCode: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue.uppercased()
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}

public extension CountryCode {
    static let austria: Self = "AT"
    static let switzerland: Self = "CH"
    static let germany: Self = "DE"
    static let spain: Self = "ES"
    static let france: Self = "FR"
    static let greatBritain: Self = "GB"
    static let italy: Self = "IT"
    static let latvia: Self = "LV"
    static let lithuania: Self = "LT"
    static let poland: Self = "PL"
    static let sweden: Self = "SE"
    static let turkey: Self = "TR"
    static let ukraine: Self = "UA"
}

public struct LanguageCode: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue.lowercased()
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}

public extension LanguageCode {
    static let german: Self = "de"
    static let english: Self = "en"
    static let finnish: Self = "fi"
    static let swedish: Self = "sv"
    static let french: Self = "fr"
    static let italian: Self = "it"
    static let latvian: Self = "lv"
    static let lithuanian: Self = "lt"
    static let polish: Self = "pl"
    static let portuguese: Self = "pt"
    static let russian: Self = "ru"
    static let slovak: Self = "sk"
    static let spanish: Self = "es"
    static let turkish: Self = "tr"
    static let ukrainian: Self = "uk"
    static let hungarian: Self = "hu"
}

public struct ForecastResponse: Decodable, Hashable, Sendable {
    public let contamination: [PollenContamination]
    public let allergyRisk: AllergyRisk
    public let hourlyAllergyRisk: HourlyAllergyRisk

    public init(contamination: [PollenContamination], allergyRisk: AllergyRisk, hourlyAllergyRisk: HourlyAllergyRisk) {
        self.contamination = contamination
        self.allergyRisk = allergyRisk
        self.hourlyAllergyRisk = hourlyAllergyRisk
    }

    private enum CodingKeys: String, CodingKey {
        case contamination
        case allergyRisk = "allergyrisk"
        case hourlyAllergyRisk = "allergyrisk_hourly"
    }
}

public struct PollenContamination: Decodable, Hashable, Sendable {
    public let pollID: Int
    public let pollTitle: String
    public let today: Int
    public let tomorrow: Int
    public let inTwoDays: Int
    public let inThreeDays: Int

    public var dailyValues: [Int] {
        [today, tomorrow, inTwoDays, inThreeDays]
    }

    public init(pollID: Int, pollTitle: String, today: Int, tomorrow: Int, inTwoDays: Int, inThreeDays: Int) {
        self.pollID = pollID
        self.pollTitle = pollTitle
        self.today = today
        self.tomorrow = tomorrow
        self.inTwoDays = inTwoDays
        self.inThreeDays = inThreeDays
    }

    private enum CodingKeys: String, CodingKey {
        case pollID = "poll_id"
        case pollTitle = "poll_title"
        case today = "contamination_1"
        case tomorrow = "contamination_2"
        case inTwoDays = "contamination_3"
        case inThreeDays = "contamination_4"
    }
}

public struct AllergyRisk: Decodable, Hashable, Sendable {
    public let today: Int
    public let tomorrow: Int
    public let inTwoDays: Int
    public let inThreeDays: Int

    public var dailyValues: [Int] {
        [today, tomorrow, inTwoDays, inThreeDays]
    }

    public init(today: Int, tomorrow: Int, inTwoDays: Int, inThreeDays: Int) {
        self.today = today
        self.tomorrow = tomorrow
        self.inTwoDays = inTwoDays
        self.inThreeDays = inThreeDays
    }

    private enum CodingKeys: String, CodingKey {
        case today = "allergyrisk_1"
        case tomorrow = "allergyrisk_2"
        case inTwoDays = "allergyrisk_3"
        case inThreeDays = "allergyrisk_4"
    }
}

public struct HourlyAllergyRisk: Decodable, Hashable, Sendable {
    public let today: [Int]
    public let tomorrow: [Int]
    public let inTwoDays: [Int]
    public let inThreeDays: [Int]

    public var dailyValues: [[Int]] {
        [today, tomorrow, inTwoDays, inThreeDays]
    }

    public init(today: [Int], tomorrow: [Int], inTwoDays: [Int], inThreeDays: [Int]) {
        self.today = today
        self.tomorrow = tomorrow
        self.inTwoDays = inTwoDays
        self.inThreeDays = inThreeDays
    }

    private enum CodingKeys: String, CodingKey {
        case today = "allergyrisk_hourly_1"
        case tomorrow = "allergyrisk_hourly_2"
        case inTwoDays = "allergyrisk_hourly_3"
        case inThreeDays = "allergyrisk_hourly_4"
    }
}

public enum PolleninformationError: Error, Equatable, LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case api(message: String)
    case decoding(String)

    public static func == (lhs: PolleninformationError, rhs: PolleninformationError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL), (.invalidResponse, .invalidResponse):
            return true
        case let (.httpStatus(lhsStatus), .httpStatus(rhsStatus)):
            return lhsStatus == rhsStatus
        case let (.api(lhsMessage), .api(rhsMessage)):
            return lhsMessage == rhsMessage
        case let (.decoding(lhsMessage), .decoding(rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Die URL für die Polleninformation-API konnte nicht erstellt werden."
        case .invalidResponse:
            return "Die Polleninformation-API hat keine HTTP-Antwort geliefert."
        case let .httpStatus(statusCode):
            return "Die Polleninformation-API hat HTTP-Status \(statusCode) zurückgegeben."
        case let .api(message):
            return "Die Polleninformation-API hat einen Fehler gemeldet: \(message)"
        case let .decoding(message):
            return "Die Antwort der Polleninformation-API konnte nicht gelesen werden: \(message)"
        }
    }

    fileprivate static func decoding(_ error: Error) -> Self {
        .decoding(String(describing: error))
    }
}

private struct APIErrorResponse: Decodable {
    let error: String
}
