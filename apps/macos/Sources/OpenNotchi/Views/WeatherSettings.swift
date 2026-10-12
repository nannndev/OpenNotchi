import SwiftUI

/// Place picker for the weather badge: city search or current location.
struct WeatherSettings: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var weather: WeatherManager
    @State private var query = ""
    @State private var results: [WeatherPlace] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        Toggle("Show weather in the notch", isOn: $settings.weatherEnabled)
        if settings.weatherEnabled {
            LabeledContent("Location") {
                HStack {
                    Text(settings.weatherPlace.isEmpty ? "Not set" : settings.weatherPlace)
                        .foregroundStyle(settings.weatherPlace.isEmpty ? .secondary : .primary)
                    Button {
                        weather.useCurrentLocation()
                    } label: {
                        if weather.isLocating {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Use my location", systemImage: "location.fill")
                        }
                    }
                    .disabled(weather.isLocating)
                }
            }
            TextField("Search city", text: $query)
                .onChange(of: query) { _, value in search(value) }
            ForEach(results) { place in
                Button {
                    weather.select(place)
                    query = ""
                    results = []
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(place.name)
                        Text(place.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Picker("Units", selection: $settings.useFahrenheit) {
                Text("Celsius").tag(false)
                Text("Fahrenheit").tag(true)
            }
            .pickerStyle(.segmented)
        }
    }

    private func search(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            results = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let found = await WeatherManager.search(trimmed)
            if !Task.isCancelled { results = found }
        }
    }
}
