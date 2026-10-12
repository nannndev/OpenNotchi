import Combine
import CoreLocation
import Foundation

struct WeatherSnapshot: Equatable {
    let temperature: Double
    let high: Double
    let low: Double
    let code: Int
    let isDay: Bool

    /// SF Symbol for a WMO weather code.
    var symbol: String {
        switch code {
        case 0: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...57: return "cloud.drizzle.fill"
        case 65, 82: return "cloud.heavyrain.fill"
        case 61...67, 80...82: return "cloud.rain.fill"
        case 71...77, 85, 86: return "cloud.snow.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}

struct WeatherPlace: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String?
    let admin1: String?

    var subtitle: String { [admin1, country].compactMap { $0 }.joined(separator: ", ") }
}

/// Current weather from Open-Meteo (free, no API key) for a place chosen in Settings.
final class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var snapshot: WeatherSnapshot?
    @Published private(set) var isLocating = false

    private let settings: AppSettings
    private let locationManager = CLLocationManager()
    private var timer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    init(settings: AppSettings) {
        self.settings = settings
        super.init()
        locationManager.delegate = self

        // Refetch when the place, units or the feature toggle change.
        Publishers.CombineLatest3(settings.$weatherPlace, settings.$useFahrenheit, settings.$weatherEnabled)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        timer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in self?.refresh() }
    }

    var hasPlace: Bool { !settings.weatherPlace.isEmpty }

    func refresh() {
        guard settings.weatherEnabled, hasPlace else {
            snapshot = nil
            return
        }
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(settings.weatherLatitude)),
            URLQueryItem(name: "longitude", value: String(settings.weatherLongitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "forecast_days", value: "1"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "temperature_unit", value: settings.useFahrenheit ? "fahrenheit" : "celsius"),
        ]
        guard let url = components.url else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let response = try? JSONDecoder().decode(ForecastResponse.self, from: data) else { return }
            let snapshot = WeatherSnapshot(
                temperature: response.current.temperature_2m,
                high: response.daily.temperature_2m_max.first ?? response.current.temperature_2m,
                low: response.daily.temperature_2m_min.first ?? response.current.temperature_2m,
                code: response.current.weather_code,
                isDay: response.current.is_day == 1
            )
            DispatchQueue.main.async { self?.snapshot = snapshot }
        }.resume()
    }

    func select(_ place: WeatherPlace) {
        settings.setWeatherPlace(name: place.name, latitude: place.latitude, longitude: place.longitude)
    }

    static func search(_ query: String) async -> [WeatherPlace] {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "6"),
            URLQueryItem(name: "language", value: Locale.current.language.languageCode?.identifier ?? "en"),
        ]
        guard let url = components.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let result = try? JSONDecoder().decode(SearchResponse.self, from: data) else { return [] }
        return result.results ?? []
    }

    // MARK: - Current location

    func useCurrentLocation() {
        isLocating = true
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            isLocating = false
        default:
            locationManager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isLocating else { return }
        switch manager.authorizationStatus {
        case .authorized, .authorizedAlways: manager.requestLocation()
        case .denied, .restricted: isLocating = false
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            let name = placemarks?.first?.locality ?? placemarks?.first?.name ?? "Current location"
            DispatchQueue.main.async {
                self?.isLocating = false
                self?.settings.setWeatherPlace(name: name, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLocating = false
    }

    // MARK: - API models

    private struct ForecastResponse: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let weather_code: Int
            let is_day: Int
        }
        struct Daily: Decodable {
            let temperature_2m_max: [Double]
            let temperature_2m_min: [Double]
        }
        let current: Current
        let daily: Daily
    }

    private struct SearchResponse: Decodable {
        let results: [WeatherPlace]?
    }
}

