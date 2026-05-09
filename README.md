# polleninformation

Ein Swift Package für die offizielle JSON-Datenschnittstelle des Österreichischen Polleninformationsdienstes.

Die API liefert Pollen-Vorhersagedaten, das Allergierisiko für heute und die kommenden drei Tage sowie die stündliche Verteilung des Allergierisikos. Für die Nutzung ist ein API-Key erforderlich. Informationen zur Schnittstelle und zur Beantragung eines Keys stehen auf der offiziellen Seite: <https://www.polleninformation.at/datenschnittstelle>.

## Installation

Füge das Package in Xcode über **File > Add Package Dependencies...** hinzu oder trage es in `Package.swift` ein:

```swift
dependencies: [
    .package(url: "https://github.com/<owner>/polleninformationen-swift.git", from: "1.0.0")
]
```

Danach das Produkt in deinem Target verwenden:

```swift
.target(
    name: "MeineApp",
    dependencies: [
        .product(name: "polleninformation", package: "polleninformationen-swift")
    ]
)
```

## Schnellstart

```swift
import polleninformation

let client = PolleninformationClient(apiKey: "DEIN_API_KEY")

let forecast = try await client.forecast(
    country: .austria,
    language: .german,
    latitude: 48.20671631686089,
    longitude: 16.350157610474536
)

for pollen in forecast.contamination {
    print(pollen.pollTitle, pollen.dailyValues)
}

print("Allergierisiko:", forecast.allergyRisk.dailyValues)
print("Stündlich heute:", forecast.hourlyAllergyRisk.today)
```

## API-Key konfigurieren

Der API-Key wird beim Erzeugen des Clients übergeben:

```swift
let client = PolleninformationClient(apiKey: apiKey)
```

Empfehlung: Speichere den API-Key nicht hart kodiert im Quellcode. Verwende zum Beispiel eine Build-Konfiguration, serverseitige Konfiguration, Keychain, sichere App-Konfiguration oder Umgebungsvariable im Backend.

Für Tests oder eigene Umgebungen kann eine alternative Basis-URL gesetzt werden:

```swift
let client = PolleninformationClient(
    apiKey: "DEIN_API_KEY",
    baseURL: URL(string: "https://www.polleninformation.at")!
)
```

## Parameter

Der Forecast-Aufruf unterstützt alle Parameter der offiziellen API:

| Swift-Parameter | API-Parameter | Beschreibung |
| --- | --- | --- |
| `country` | `country` | Zweistelliger ISO-3166-1-alpha-2-Ländercode |
| `language` | `lang` | Zweistelliger ISO-639-Sprachcode für Allergen-Titel |
| `latitude` | `latitude` | Breitengrad der gewünschten Position |
| `longitude` | `longitude` | Längengrad der gewünschten Position |
| `apiKey` | `apikey` | Persönlicher API-Key |

### Unterstützte Ländercodes

Die API-Dokumentation nennt aktuell diese Länder:

```swift
.austria        // AT
.switzerland   // CH
.germany       // DE
.spain         // ES
.france        // FR
.greatBritain  // GB
.italy         // IT
.latvia        // LV
.lithuania     // LT
.poland        // PL
.sweden        // SE
.turkey        // TR
.ukraine       // UA
```

Du kannst auch eigene oder neu hinzugekommene Codes übergeben:

```swift
let country = CountryCode(rawValue: "AT")
let sameCountry: CountryCode = "AT"
```

`CountryCode` normalisiert Werte auf Großbuchstaben.

### Unterstützte Sprachcodes

Die API-Dokumentation nennt aktuell diese Sprachen:

```swift
.german      // de
.english     // en
.finnish     // fi
.swedish     // sv
.french      // fr
.italian     // it
.latvian     // lv
.lithuanian  // lt
.polish      // pl
.portuguese  // pt
.russian     // ru
.slovak      // sk
.spanish     // es
.turkish     // tr
.ukrainian   // uk
.hungarian   // hu
```

Du kannst auch eigene oder neu hinzugekommene Codes übergeben:

```swift
let language = LanguageCode(rawValue: "de")
let sameLanguage: LanguageCode = "de"
```

`LanguageCode` normalisiert Werte auf Kleinbuchstaben.

## ForecastRequest verwenden

Wenn du Parameter als Wert weiterreichen möchtest, nutze `ForecastRequest`:

```swift
let request = ForecastRequest(
    country: .austria,
    language: .german,
    latitude: 48.20671631686089,
    longitude: 16.350157610474536
)

let forecast = try await client.forecast(request)
```

## Antwortmodell

`ForecastResponse` enthält drei Bereiche:

```swift
public struct ForecastResponse {
    public let contamination: [PollenContamination]
    public let allergyRisk: AllergyRisk
    public let hourlyAllergyRisk: HourlyAllergyRisk
}
```

### Pollenbelastung

Jeder Eintrag in `contamination` beschreibt ein Allergen:

```swift
let pollen = forecast.contamination[0]

pollen.pollID       // z. B. 23
pollen.pollTitle    // z. B. "Pilzsporen (Alternaria)"
pollen.today        // Belastung heute, 0 bis 4
pollen.tomorrow     // Belastung morgen, 0 bis 4
pollen.inTwoDays    // Belastung in zwei Tagen, 0 bis 4
pollen.inThreeDays  // Belastung in drei Tagen, 0 bis 4
pollen.dailyValues  // [today, tomorrow, inTwoDays, inThreeDays]
```

Die Werte der Pollenbelastung reichen laut API von `0` für keine Belastung bis `4` für sehr starke Belastung.

### Allergierisiko

```swift
forecast.allergyRisk.today
forecast.allergyRisk.tomorrow
forecast.allergyRisk.inTwoDays
forecast.allergyRisk.inThreeDays
forecast.allergyRisk.dailyValues
```

Die Werte des Allergierisikos reichen laut API von `0` für keine Belastung bis `10` für sehr starke Belastung.

### Stündliches Allergierisiko

```swift
forecast.hourlyAllergyRisk.today
forecast.hourlyAllergyRisk.tomorrow
forecast.hourlyAllergyRisk.inTwoDays
forecast.hourlyAllergyRisk.inThreeDays
forecast.hourlyAllergyRisk.dailyValues
```

Jedes Array enthält die stündlichen Werte eines Tages. Der erste Wert steht für 0-1 Uhr, der zweite für 1-2 Uhr usw.

## Fehlerbehandlung

Der Client wirft `PolleninformationError`:

```swift
do {
    let forecast = try await client.forecast(
        country: .austria,
        language: .german,
        latitude: 48.20671631686089,
        longitude: 16.350157610474536
    )
    print(forecast)
} catch PolleninformationError.api(let message) {
    print("API-Fehler:", message)
} catch PolleninformationError.httpStatus(let statusCode) {
    print("HTTP-Status:", statusCode)
} catch {
    print("Unerwarteter Fehler:", error)
}
```

Mögliche Fehler:

| Fehler | Bedeutung |
| --- | --- |
| `.invalidURL` | Die Request-URL konnte nicht erstellt werden |
| `.invalidResponse` | Die Antwort war keine HTTP-Antwort |
| `.httpStatus(Int)` | Die API hat einen HTTP-Status außerhalb von 200...299 geliefert |
| `.api(message: String)` | Die API hat ein Fehler-JSON wie `{ "error": "invalid api key" }` geliefert |
| `.decoding(String)` | Die JSON-Antwort konnte nicht in das Swift-Modell dekodiert werden |

## Testbarkeit

Für Unit-Tests kann ein eigener HTTP-Client injiziert werden:

```swift
struct MockHTTPClient: PolleninformationHTTPClient {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data = #"{"contamination":[],"allergyrisk":{"allergyrisk_1":0,"allergyrisk_2":0,"allergyrisk_3":0,"allergyrisk_4":0},"allergyrisk_hourly":{"allergyrisk_hourly_1":[],"allergyrisk_hourly_2":[],"allergyrisk_hourly_3":[],"allergyrisk_hourly_4":[]}}"#.data(using: .utf8)!
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (data, response)
    }
}

let client = PolleninformationClient(apiKey: "test", httpClient: MockHTTPClient())
```

## Nutzungshinweise der Datenquelle

Die offizielle API setzt einen von polleninformation.at ausgestellten API-Key voraus. Bei öffentlich verfügbaren Anwendungen ist die Datenherkunft zu nennen: Österreichischer Polleninformationsdienst, <https://www.polleninformation.at>. Die Daten dürfen laut offizieller Dokumentation nicht für kommerzielle Zwecke verwendet werden. Da sich Vorhersagedaten nicht laufend ändern, empfiehlt die Datenquelle einen Abruf höchstens alle vier Stunden.
