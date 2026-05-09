import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import polleninformation

@Test func forecastRequestContainsAllAPIParameters() throws {
    let client = PolleninformationClient(apiKey: "secret")

    let request = try client.makeForecastURLRequest(
        country: .austria,
        language: .german,
        latitude: 48.20671631686089,
        longitude: 16.350157610474536
    )

    let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
    let queryItems = Dictionary(uniqueKeysWithValues: components.queryItems!.map { ($0.name, $0.value) })

    #expect(components.scheme == "https")
    #expect(components.host == "www.polleninformation.at")
    #expect(components.path == "/api/forecast/public")
    #expect(queryItems["country"] == "AT")
    #expect(queryItems["lang"] == "de")
    #expect(queryItems["latitude"] == "48.20671631686089")
    #expect(queryItems["longitude"] == "16.350157610474536")
    #expect(queryItems["apikey"] == "secret")
    #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
}

@Test func forecastDecodesSuccessfulResponse() async throws {
    let httpClient = MockHTTPClient(
        data: """
        {
            "contamination": [
                {
                    "poll_id": 23,
                    "poll_title": "Pilzsporen (Alternaria)",
                    "contamination_1": 3,
                    "contamination_2": 2,
                    "contamination_3": 1,
                    "contamination_4": 0
                }
            ],
            "allergyrisk": {
                "allergyrisk_1": 8,
                "allergyrisk_2": 7,
                "allergyrisk_3": 6,
                "allergyrisk_4": 5
            },
            "allergyrisk_hourly": {
                "allergyrisk_hourly_1": [1, 2, 3],
                "allergyrisk_hourly_2": [4, 5, 6],
                "allergyrisk_hourly_3": [7, 8, 9],
                "allergyrisk_hourly_4": [0, 1, 2]
            }
        }
        """.data(using: .utf8)!,
        statusCode: 200
    )
    let client = PolleninformationClient(apiKey: "secret", httpClient: httpClient)

    let forecast = try await client.forecast(country: .austria, language: .german, latitude: 48.2, longitude: 16.3)

    #expect(forecast.contamination.first?.pollID == 23)
    #expect(forecast.contamination.first?.pollTitle == "Pilzsporen (Alternaria)")
    #expect(forecast.contamination.first?.dailyValues == [3, 2, 1, 0])
    #expect(forecast.allergyRisk.dailyValues == [8, 7, 6, 5])
    #expect(forecast.hourlyAllergyRisk.dailyValues == [[1, 2, 3], [4, 5, 6], [7, 8, 9], [0, 1, 2]])
}

@Test func forecastThrowsAPIErrorResponse() async throws {
    let httpClient = MockHTTPClient(
        data: #"{"error": "invalid api key"}"#.data(using: .utf8)!,
        statusCode: 200
    )
    let client = PolleninformationClient(apiKey: "wrong", httpClient: httpClient)

    await #expect(throws: PolleninformationError.api(message: "invalid api key")) {
        try await client.forecast(country: .austria, language: .german, latitude: 48.2, longitude: 16.3)
    }
}

@Test func customCountryAndLanguageCodesAreNormalized() {
    #expect(CountryCode(rawValue: "at").rawValue == "AT")
    #expect(LanguageCode(rawValue: "DE").rawValue == "de")
}

private struct MockHTTPClient: PolleninformationHTTPClient {
    let data: Data
    let statusCode: Int

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }
}
