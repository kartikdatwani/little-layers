import SwiftUI

@main
struct LittleLayersApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}

struct ContentView: View {
    @StateObject private var weather = WeatherModel()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("children") private var childrenData = Data()
    @AppStorage("fahrenheit") private var fahrenheit = true
    @State private var children: [Child] = []
    @State private var start = 8
    @State private var end = 16
    @State private var groundSnow = false
    @State private var newName = ""
    private let ink = Color.black
    private let cream = Color(red: 0.975, green: 0.965, blue: 0.935)
    private var notificationScheduleToken: String {
        let childData = (try? JSONEncoder().encode(children).base64EncodedString()) ?? ""
        return "\(childData)-\(start)-\(end)-\(groundSnow)-\(notificationHour)-\(notificationMinute)-\(notificationsEnabled)-\(weather.updated?.timeIntervalSince1970 ?? 0)"
    }
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("notificationHour") private var notificationHour = 6
    @AppStorage("notificationMinute") private var notificationMinute = 0
    @State private var showingSettings = false
    @State private var notificationMessage: String?
    @State private var showSnowConfetti = false
    private var hours: [Hour] { weather.forecast?.hours(from: start, through: end) ?? [] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("TODAY’S CONDITIONS", systemImage: "cloud.sun.fill").font(.caption.bold())
                        Toggle("Snow already on the ground", isOn: $groundSnow)
                            .font(.subheadline)
                    }.card()

                    if weather.loading {
                        HStack { ProgressView(); Text("Checking your local forecast…") }.card()
                    } else if let message = weather.message {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(message)
                            Button("Try again") { weather.refresh() }.buttonStyle(.borderedProminent)
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                Link("Open Settings", destination: url)
                            }
                        }.card()
                    } else if let low = hours.map(\.feels).min(), let high = hours.map(\.feels).max() {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("YOUR LOCAL FORECAST", systemImage: "cloud.sun.fill").font(.caption.bold())
                            Text("\(temperature(low)) → \(temperature(high))").font(.system(size: 36, weight: .semibold, design: .rounded))
                            Text("Feels-like range · \(hourLabel(start))–\(hourLabel(end))")
                                .font(.subheadline)
                            if let probability = hours.compactMap(\.rain).max() {
                                Text("\(Int(probability))% peak precipitation chance").font(.subheadline)
                            }
                            if hours.count < end - start + 1 {
                                Text("Some selected hours are unavailable. Advice uses available hours only.").font(.caption)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20).background(cream, in: RoundedRectangle(cornerRadius: 24))
                        ForEach(children) { child in
                            if let outfit = Outfit.recommend(hours: hours, age: child.age, runsCold: child.runsCold, groundSnow: groundSnow) {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(child.name).font(.title2.bold())
                                            Text("Age \(child.age)").font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if child.runsCold { Text("Runs cold").font(.caption).foregroundStyle(.secondary) }
                                    }
                                    outfitRow("Layers", outfit.layers, "tshirt.fill")
                                    outfitRow("Shoes", outfit.shoes, "shoeprints.fill")
                                    outfitRow("Bring along", outfit.extras, "backpack.fill")
                                    Text(outfit.reason).font(.caption).foregroundStyle(.secondary)
                                }.card()
                            }
                        }
                    } else if weather.forecast != nil {
                        Text("No forecast data is available for these hours. Try another time window or refresh.").card()
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Check the local forecast for today’s outfits.")
                            Text("Your approximate location is sent to Open-Meteo to get the forecast. Children’s names stay on this device.").font(.caption).foregroundStyle(.secondary)
                            Button("Get today’s outfit") { weather.refresh() }.buttonStyle(.borderedProminent)
                        }.card()
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("A starting point for everyday outdoor clothing. Adjust for activity, comfort, and local conditions.")
                        if let updated = weather.updated { Text("Updated \(updated.formatted(date: .omitted, time: .shortened))") }
                        Link("Weather data by Open-Meteo", destination: URL(string: "https://open-meteo.com/")!)
                    }.font(.caption).foregroundStyle(.secondary)
                }.padding(20)
            }
            .background(cream)
            .navigationTitle("Little Layers")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(fahrenheit ? "°F" : "°C") { fahrenheit.toggle() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Refresh", systemImage: "arrow.clockwise") { weather.refresh() }.disabled(weather.loading)
                    Button("Settings", systemImage: "gearshape") { showingSettings = true }
                }
            }
            .sheet(isPresented: $showingSettings) { notificationSettings }
            .alert("Notifications", isPresented: Binding(get: { notificationMessage != nil }, set: { if !$0 { notificationMessage = nil } })) {
                Button("OK", role: .cancel) { notificationMessage = nil }
            } message: { Text(notificationMessage ?? "") }
            .onAppear {
                children = (try? JSONDecoder().decode([Child].self, from: childrenData)) ?? [Child(name: "My child")]
            }
            .onChange(of: children) { _, value in childrenData = (try? JSONEncoder().encode(value)) ?? Data() }
            .onChange(of: start) { _, value in if end <= value { end = value + 1 } }
            .onChange(of: notificationScheduleToken) { _, _ in scheduleOutfitNotifications() }
            .onChange(of: groundSnow) { _, enabled in
                guard enabled else { return }
                showSnowConfetti = true
                Task {
                    try? await Task.sleep(for: .seconds(2.8))
                    showSnowConfetti = false
                }
            }
            .onChange(of: notificationsEnabled) { _, enabled in
                Task {
                    if enabled {
                        let granted = await OutfitNotifications.requestPermission()
                        if granted { scheduleOutfitNotifications() }
                        else {
                            notificationsEnabled = false
                            notificationMessage = "Allow notifications for Little Layers in Settings to receive outfit reminders."
                        }
                    } else { OutfitNotifications.cancelScheduled() }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active, let updated = weather.updated, Date().timeIntervalSince(updated) > 900 {
                    weather.refresh()
                }
            }
        }
        .overlay {
            if showSnowConfetti {
                SnowConfetti().allowsHitTesting(false).transition(.opacity)
            }
        }
        .tint(ink).preferredColorScheme(.light)
    }

    private var notificationSettings: some View {
        NavigationStack {
            Form {
                Section("Time outside") {
                    Picker("From", selection: $start) {
                        ForEach(0..<23, id: \.self) { Text(hourLabel($0)).tag($0) }
                    }
                    Picker("Until", selection: $end) {
                        ForEach((start + 1)...23, id: \.self) { Text(hourLabel($0)).tag($0) }
                    }
                }
                Section {
                    Toggle("Daily outfit reminder", isOn: $notificationsEnabled)
                    DatePicker("Notification time", selection: notificationTimeBinding, displayedComponents: .hourAndMinute)
                        .disabled(!notificationsEnabled)
                } footer: {
                    Text("Default time is 6:00 AM. Reminders use the latest forecast loaded in the app and your selected outdoor hours. Open the app to refresh upcoming forecasts.")
                }
                Section("Your children") {
                    ForEach($children) { $child in
                        VStack(alignment: .leading) {
                            TextField("Name", text: $child.name)
                            Picker("Age", selection: $child.age) {
                                ForEach(1...18, id: \.self) { age in Text("\(age) years").tag(age) }
                            }
                            Toggle("Usually runs cold", isOn: $child.runsCold)
                        }
                    }.onDelete { offsets in children.remove(atOffsets: offsets) }
                }
                Section("Add a child") {
                    TextField("Child’s name", text: $newName)
                    Picker("Age", selection: $newAge) {
                        ForEach(1...18, id: \.self) { age in Text("\(age) years").tag(age) }
                    }
                    Button("Add child") {
                        children.append(Child(name: newName.trimmingCharacters(in: .whitespacesAndNewlines), age: newAge))
                        newName = ""
                    }.disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Section { Text("Names, ages, and comfort preferences are saved only on this device.") }
            }.navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingSettings = false } } }
        }
    }

    @State private var newAge = 6

    private var notificationTimeBinding: Binding<Date> {
        Binding(get: {
            Calendar.current.date(from: DateComponents(hour: notificationHour, minute: notificationMinute)) ?? .now
        }, set: { value in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: value)
            notificationHour = parts.hour ?? 6
            notificationMinute = parts.minute ?? 0
        })
    }

    private func scheduleOutfitNotifications() {
        guard notificationsEnabled, let forecast = weather.forecast, !children.isEmpty else { return }
        OutfitNotifications.schedule(forecast: forecast, children: children, start: start, end: end,
                                     hour: notificationHour, minute: notificationMinute, groundSnow: groundSnow)
    }

    private func outfitRow(_ title: String, _ text: String, _ icon: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title3).frame(width: 28).foregroundStyle(ink)
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased()).font(.caption2.bold()).foregroundStyle(.secondary)
                Text(text).font(.body.weight(.medium))
            }
        }
    }
    private func temperature(_ celsius: Double) -> String { "\(Int((fahrenheit ? celsius * 9 / 5 + 32 : celsius).rounded()))°\(fahrenheit ? "F" : "C")" }
    private func hourLabel(_ hour: Int) -> String { "\(hour % 12 == 0 ? 12 : hour % 12) \(hour < 12 ? "am" : "pm")" }
}

private extension View {
    func card() -> some View {
        self.frame(maxWidth: .infinity, alignment: .leading).padding(18)
            .background(.white, in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct SnowConfetti: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<76 {
                    let seed = Double(index) * 1.618
                    let progress = (time * 0.42 + seed / 76).truncatingRemainder(dividingBy: 1)
                    let drift = sin(time * 1.2 + seed) * 24
                    let x = (seed * 83 + drift).truncatingRemainder(dividingBy: max(size.width, 1))
                    let y = progress * size.height
                    let diameter = 3 + (Double(index % 4) * 1.4)
                    let flake = Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter))
                    context.fill(flake, with: .color(.white.opacity(0.92)))
                    context.stroke(flake, with: .color(.black.opacity(0.14)), lineWidth: 0.6)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
