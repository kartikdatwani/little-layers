import Foundation
import CoreLocation
import Combine

@MainActor
final class WeatherModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var forecast: Forecast?
    @Published var loading = false
    @Published var message: String?
    @Published var updated: Date?
    private let manager = CLLocationManager()
    private var task: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func refresh() {
        task?.cancel()
        forecast = nil
        updated = nil
        message = nil
        loading = true
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        default: fail("Location is disabled. Enable location for Little Layers in Settings, then try again.")
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard loading else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted: fail("Enable location for Little Layers in Settings to get your local forecast.")
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        fail("Couldn’t find your location. Please try again.")
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { fail("Location unavailable. Try again."); return }
        task?.cancel()
        task = Task {
            do {
                var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
                components.queryItems = [
                    URLQueryItem(name: "latitude", value: String(location.coordinate.latitude)),
                    URLQueryItem(name: "longitude", value: String(location.coordinate.longitude)),
                    URLQueryItem(name: "hourly", value: "apparent_temperature,precipitation_probability,snowfall,snow_depth"),
                    URLQueryItem(name: "timezone", value: "auto"),
                    URLQueryItem(name: "forecast_days", value: "7")
                ]
                let (data, response) = try await URLSession.shared.data(from: components.url!)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                let result = try JSONDecoder().decode(Forecast.self, from: data)
                guard !Task.isCancelled else { return }
                forecast = result
                updated = Date()
                loading = false
            } catch {
                guard !Task.isCancelled else { return }
                fail("Couldn’t load today’s forecast. Check your connection and try again.")
            }
        }
    }

    private func fail(_ text: String) {
        forecast = nil
        message = text
        loading = false
    }
}
