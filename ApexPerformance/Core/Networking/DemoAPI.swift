//
//  DemoAPI.swift
//  ApexPerformance
//

#if DEBUG
import Foundation
import UIKit

/// App Store screenshots without real people's data. Launched with
/// -demoData (Debug builds only), every request to the API host is
/// answered on the device with invented data: coach Luka Marić and his
/// clients, Ana Kovač being the demo client. A username with "coach"
/// in it logs in as the coach, any other as Ana.
enum DemoAPI {
    typealias JSON = [String: Any]

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-demoData")
    }

    /// Answers requests to the API host from now on (URLSession.shared).
    static func start() {
        URLProtocol.registerClass(DemoURLProtocol.self)
    }

    enum Role {
        case coach, client
    }

    struct Reply {
        var status = 200
        var contentType = "application/json"
        var data = Data()

        static let notFound = Reply(status: 404)

        static func json(_ object: Any) -> Reply {
            guard JSONSerialization.isValidJSONObject(object),
                  let data = try? JSONSerialization.data(withJSONObject: object) else {
                print("⚠️ DemoAPI: fixture is not valid JSON")
                return Reply(status: 500)
            }
            return Reply(data: data)
        }
    }

    // MARK: - Ids

    /// What an id belongs to, so everything keeps its id in all answers.
    enum Kind: Int {
        case user = 1, coach, client, workout, workoutType, training, exercise, exerciseSet,
             measurement, appointment, timeSlot, status, request, conversation, message,
             attachment, notification, record, review, fms, template, catalog
    }

    static func id(_ kind: Kind, _ number: Int = 0) -> UUID {
        func hex(_ value: Int, _ width: Int) -> String {
            let digits = String(value, radix: 16, uppercase: true)
            return String(repeating: "0", count: max(0, width - digits.count)) + digits
        }
        return UUID(uuidString: "DE300000-\(hex(kind.rawValue, 4))-4000-8000-\(hex(number, 12))")!
    }

    static func clientId(_ index: Int) -> UUID { id(.client, index + 1) }
    static func userId(ofClient index: Int) -> UUID { id(.user, 100 + index) }
    static func conversationId(_ index: Int) -> UUID { id(.conversation, index + 1) }

    // The tokens' "sub": the chat tells own messages by it.
    static let coachUserId = id(.user, 1)
    static let coachId = id(.coach, 1)
    static let anaUserId = userId(ofClient: ClientIndex.ana)
    static let anaClientId = clientId(ClientIndex.ana)
    static let anaConversationId = conversationId(ClientIndex.ana)

    // MARK: - People

    struct Person {
        let firstName: String
        let lastName: String
        let phone: String
        let plan: String
        let credits: Int

        var fullName: String { "\(firstName) \(lastName)" }

        // firstname.lastname@example.com without diacritics.
        var email: String {
            "\(firstName).\(lastName)@example.com"
                .folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US"))
                .lowercased()
        }
    }

    enum ClientIndex {
        static let ana = 0, marko = 1, ivana = 2, petra = 3, tomislav = 4, lucija = 5, filip = 6, maja = 7
    }

    static let coach = Person(firstName: "Luka", lastName: "Marić", phone: "+385 91 555 0100", plan: "", credits: 0)

    // Ana first: the screenshots open the first client of the list.
    static let clients: [Person] = [
        Person(firstName: "Ana", lastName: "Kovač", phone: "+385 91 555 0123", plan: "PrivateCoaching", credits: 5),
        Person(firstName: "Marko", lastName: "Horvat", phone: "+385 98 555 0147", plan: "PrivateCoaching", credits: 8),
        Person(firstName: "Ivana", lastName: "Babić", phone: "+385 95 555 0162", plan: "OnlineCoaching", credits: 4),
        Person(firstName: "Petra", lastName: "Novak", phone: "+385 91 555 0178", plan: "PrivateCoaching", credits: 10),
        Person(firstName: "Tomislav", lastName: "Jurić", phone: "+385 92 555 0185", plan: "Membership", credits: 2),
        Person(firstName: "Lucija", lastName: "Perić", phone: "+385 99 555 0191", plan: "OnlineCoaching", credits: 6),
        Person(firstName: "Filip", lastName: "Knežević", phone: "+385 97 555 0134", plan: "PrivateCoaching", credits: 0),
        Person(firstName: "Maja", lastName: "Šimić", phone: "+385 91 555 0156", plan: "Membership", credits: 3)
    ]

    static let coachPermissions = [
        Permissions.canGetClients,
        Permissions.canGetAppointments,
        Permissions.canCreateAppointment,
        Permissions.canGetAppointmentRequests
    ]

    static let clientPermissions = [
        Permissions.canGetAppointments,
        Permissions.canCreateAppointment
    ]

    // MARK: - Workouts

    struct WorkoutInfo {
        let number: Int
        let name: (en: String, hr: String)
        let description: (en: String, hr: String)
        let types: [Int]
        let muscles: [String]
        let secondaryMuscles: [String]
    }

    enum WorkoutNumber {
        static let bench = 1, inclinePress = 2, squat = 3, romanianDeadlift = 4, deadlift = 5,
                   pullUp = 6, row = 7, overheadPress = 8, lateralRaise = 9, hipThrust = 10,
                   lunge = 11, curl = 12, pushdown = 13, plank = 14, hipFlexorStretch = 15,
                   thoracicRotation = 16
    }

    // Strength, upper body, lower body, core, mobility (the plan's library).
    static let workoutTypes: [(number: Int, en: String, hr: String)] = [
        (1, "Strength", "Snaga"),
        (2, "Upper body", "Gornji dio tijela"),
        (3, "Lower body", "Donji dio tijela"),
        (4, "Core", "Trup"),
        (5, "Mobility & stretching", "Mobilnost i istezanje")
    ]

    // Muscle codes as in BodyMapPaths.
    static let workouts: [WorkoutInfo] = [
        WorkoutInfo(
            number: WorkoutNumber.bench,
            name: ("Bench Press", "Potisak s ravne klupe"),
            description: ("Lie on a flat bench with your feet planted. Lower the bar to mid-chest under control and press it back up, keeping your shoulder blades pulled together.",
                          "Lezi na ravnu klupu, stopala čvrsto na podu. Kontrolirano spusti šipku do sredine prsa i potisni je natrag, lopatice drži skupljene."),
            types: [1, 2], muscles: ["chest", "triceps"], secondaryMuscles: ["shoulders"]),
        WorkoutInfo(
            number: WorkoutNumber.inclinePress,
            name: ("Incline Dumbbell Press", "Kosi potisak bučicama"),
            description: ("On a bench set to about 30°, press the dumbbells up over your upper chest and lower them slowly to chest level.",
                          "Na klupi nagnutoj oko 30° potisni bučice iznad gornjeg dijela prsa i polako ih spusti do razine prsa."),
            types: [1, 2], muscles: ["chest", "shoulders"], secondaryMuscles: ["triceps"]),
        WorkoutInfo(
            number: WorkoutNumber.squat,
            name: ("Barbell Back Squat", "Čučanj sa šipkom na leđima"),
            description: ("With the bar on your upper back, brace your core and sit down between your hips until your thighs are at least parallel, then drive back up.",
                          "Sa šipkom na gornjem dijelu leđa zategni trup i spusti se između kukova barem do paralele, zatim se snažno podigni."),
            types: [1, 3], muscles: ["quads", "glutes"], secondaryMuscles: ["adductors", "hamstrings", "lower_back"]),
        WorkoutInfo(
            number: WorkoutNumber.romanianDeadlift,
            name: ("Romanian Deadlift", "Rumunjsko mrtvo dizanje"),
            description: ("Hold the bar at hip height, push your hips back with soft knees and lower the bar along your legs until you feel a stretch in the hamstrings.",
                          "Drži šipku u visini kukova, gurni kukove unatrag s blago savijenim koljenima i spuštaj šipku uz noge dok ne osjetiš istezanje stražnje lože."),
            types: [1, 3], muscles: ["hamstrings", "glutes"], secondaryMuscles: ["lower_back", "forearms"]),
        WorkoutInfo(
            number: WorkoutNumber.deadlift,
            name: ("Deadlift", "Mrtvo dizanje"),
            description: ("Start with the bar over mid-foot, grip it just outside your legs, brace and stand up by pushing the floor away. Keep your back neutral throughout.",
                          "Šipka je iznad sredine stopala, uhvati je odmah izvan nogu, zategni trup i ustani odgurujući pod. Leđa su cijelo vrijeme neutralna."),
            types: [1, 3], muscles: ["glutes", "hamstrings", "lower_back"], secondaryMuscles: ["quads", "traps", "forearms"]),
        WorkoutInfo(
            number: WorkoutNumber.pullUp,
            name: ("Pull-Up", "Zgib"),
            description: ("Hang from the bar with straight arms and pull your chest towards it by driving your elbows down. Lower yourself all the way under control.",
                          "Visi na šipki ispruženih ruku i povuci prsa prema njoj vodeći laktove prema dolje. Kontrolirano se spusti do kraja."),
            types: [1, 2], muscles: ["lats"], secondaryMuscles: ["biceps", "upper_back", "forearms"]),
        WorkoutInfo(
            number: WorkoutNumber.row,
            name: ("Barbell Row", "Veslanje šipkom"),
            description: ("Hinge forward with a flat back and row the bar to your lower ribs, squeezing your shoulder blades together at the top.",
                          "Nagni se naprijed ravnih leđa i povuci šipku prema donjim rebrima, na vrhu stisni lopatice."),
            types: [1, 2], muscles: ["lats", "upper_back"], secondaryMuscles: ["biceps", "lower_back"]),
        WorkoutInfo(
            number: WorkoutNumber.overheadPress,
            name: ("Overhead Press", "Potisak iznad glave"),
            description: ("Stand tall with your glutes and core tight and press the bar from your shoulders to straight arms overhead.",
                          "Stojeći uspravno sa zategnutim trupom i stražnjicom potisni šipku s ramena iznad glave do ispruženih ruku."),
            types: [1, 2], muscles: ["shoulders"], secondaryMuscles: ["triceps", "traps"]),
        WorkoutInfo(
            number: WorkoutNumber.lateralRaise,
            name: ("Lateral Raise", "Odručenje bučicama"),
            description: ("With a slight bend in the elbows, raise the dumbbells out to the sides up to shoulder height and lower them slowly.",
                          "Blago savijenih laktova podigni bučice u stranu do visine ramena i polako ih spusti."),
            types: [2], muscles: ["shoulders"], secondaryMuscles: ["traps"]),
        WorkoutInfo(
            number: WorkoutNumber.hipThrust,
            name: ("Hip Thrust", "Potisak kukovima"),
            description: ("With your upper back on a bench and the bar over your hips, drive through your heels until your body is in a straight line. Pause and squeeze your glutes.",
                          "Gornjim dijelom leđa osloni se na klupu, šipka je na kukovima. Odgurni se petama do ravne linije tijela, zadrži i stisni gluteuse."),
            types: [1, 3], muscles: ["glutes"], secondaryMuscles: ["hamstrings"]),
        WorkoutInfo(
            number: WorkoutNumber.lunge,
            name: ("Walking Lunge", "Hodajući iskorak"),
            description: ("Step forward into a long lunge until the back knee nearly touches the floor, then step through into the next one. Keep your torso upright.",
                          "Iskorači naprijed dok stražnje koljeno gotovo ne dotakne pod, zatim nastavi u sljedeći iskorak. Trup drži uspravno."),
            types: [3], muscles: ["quads", "glutes"], secondaryMuscles: ["hamstrings", "adductors", "calves"]),
        WorkoutInfo(
            number: WorkoutNumber.curl,
            name: ("Biceps Curl", "Pregib za biceps"),
            description: ("With your elbows by your sides, curl the dumbbells up without swinging and lower them slowly.",
                          "Laktovi uz tijelo, savij bučice prema ramenima bez njihanja i polako ih spusti."),
            types: [2], muscles: ["biceps"], secondaryMuscles: ["forearms"]),
        WorkoutInfo(
            number: WorkoutNumber.pushdown,
            name: ("Triceps Pushdown", "Potisak na sajli za triceps"),
            description: ("Keep your elbows pinned to your sides and push the cable attachment down until your arms are straight.",
                          "Laktove drži uz tijelo i potiskuj ručku sajle prema dolje do potpuno ispruženih ruku."),
            types: [2], muscles: ["triceps"], secondaryMuscles: []),
        WorkoutInfo(
            number: WorkoutNumber.plank,
            name: ("Plank", "Plank"),
            description: ("Support yourself on your forearms and toes with your body in a straight line. Brace your core and breathe steadily.",
                          "Osloni se na podlaktice i prste, tijelo je u ravnoj liniji. Zategni trup i diši ravnomjerno."),
            types: [4], muscles: ["abs"], secondaryMuscles: ["obliques", "shoulders"]),
        WorkoutInfo(
            number: WorkoutNumber.hipFlexorStretch,
            name: ("Hip Flexor Stretch", "Istezanje pregibača kuka"),
            description: ("From a half-kneeling position, tuck your pelvis and shift forward until you feel a stretch at the front of the back hip. Hold 30–45 s per side.",
                          "Iz polukleka podvuci zdjelicu i pomakni se naprijed dok ne osjetiš istezanje s prednje strane stražnjeg kuka. Zadrži 30–45 s po strani."),
            types: [5], muscles: ["quads"], secondaryMuscles: ["abs"]),
        WorkoutInfo(
            number: WorkoutNumber.thoracicRotation,
            name: ("Thoracic Rotation", "Rotacija prsne kralježnice"),
            description: ("Lying on your side with your knees bent, open your top arm and chest towards the floor behind you and return slowly. 8–10 reps per side.",
                          "Ležeći na boku savijenih koljena otvori gornju ruku i prsa prema podu iza sebe pa se polako vrati. 8–10 ponavljanja po strani."),
            types: [5], muscles: ["upper_back"], secondaryMuscles: ["chest", "obliques"])
    ]

    // MARK: - Body

    // Ana, oldest first: (days ago, weight, shoulders, chest, upper arm, waist, thigh, calves, glutes).
    // Only whole and half numbers, which JSON keeps exact.
    static let anaMeasurements: [(Int, Double, Double, Double, Double, Double, Double, Double, Double)] = [
        (154, 84.0, 108.0, 102.0, 32.0, 92.0, 62.0, 39.0, 108.0),
        (124, 83.0, 107.5, 101.0, 31.5, 91.0, 61.5, 39.0, 107.0),
        (94, 82.0, 107.5, 100.5, 31.5, 89.5, 61.0, 38.5, 106.0),
        (63, 81.0, 107.0, 99.5, 31.0, 88.0, 60.0, 38.5, 105.0),
        (33, 80.5, 106.5, 99.0, 31.0, 87.0, 59.5, 38.0, 104.5),
        (3, 79.5, 106.5, 98.5, 30.5, 86.0, 59.0, 38.0, 104.0)
    ]

    // Other clients: height and weights, oldest first, a month apart.
    static let otherBodies: [Int: (height: Double, weights: [Double])] = [
        ClientIndex.marko: (182, [92.0, 90.5, 89.0]),
        ClientIndex.ivana: (165, [68.0, 67.0]),
        ClientIndex.petra: (170, [63.5, 63.0, 62.5]),
        ClientIndex.tomislav: (178, [85.0]),
        ClientIndex.lucija: (160, [58.0, 57.5]),
        ClientIndex.filip: (185, [78.0, 79.0, 80.5])
    ]

    // MARK: - Appointments

    // Other clients' sessions: (number, day offset, hour, minute, client).
    static let otherSessions: [(number: Int, day: Int, hour: Int, minute: Int, client: Int)] = [
        (10, -3, 7, 30, ClientIndex.lucija),
        (11, -2, 8, 0, ClientIndex.petra),
        (12, -2, 18, 0, ClientIndex.filip),
        (13, -1, 7, 0, ClientIndex.marko),
        (14, -1, 17, 0, ClientIndex.ivana),
        (15, 0, 7, 30, ClientIndex.marko),
        (16, 0, 9, 0, ClientIndex.petra),
        (17, 0, 17, 0, ClientIndex.ivana),
        (18, 0, 18, 30, ClientIndex.filip),
        (19, 1, 18, 0, ClientIndex.marko),
        // Lucija asks to cancel this one.
        (20, 1, 10, 0, ClientIndex.lucija),
        // Maja asks to join this one.
        (21, 2, 8, 0, ClientIndex.petra),
        (22, 2, 18, 30, ClientIndex.ivana),
        (23, 3, 7, 30, ClientIndex.marko),
        (24, 4, 9, 0, ClientIndex.petra),
        (25, 4, 17, 30, ClientIndex.lucija),
        (26, 5, 10, 0, ClientIndex.filip),
        (27, 5, 17, 0, ClientIndex.tomislav)
    ]

    // MARK: - Pictures and dates

    /// Picture of the chat's image message.
    static let attachmentImage: (data: Data, width: Int, height: Int) = {
        if let image = UIImage(named: "login-background"), let data = image.jpegData(compressionQuality: 0.8) {
            return (data: data, width: Int(image.size.width * image.scale), height: Int(image.size.height * image.scale))
        }
        let size = CGSize(width: 800, height: 1000)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(red: 0.13, green: 0.15, blue: 0.19, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.86, green: 0.66, blue: 0.22, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 150, y: 250, width: 500, height: 500))
        }
        return (data: image.jpegData(compressionQuality: 0.8) ?? Data(), width: 800, height: 1000)
    }()

    // With the time zone, e.g. 2026-10-21T07:30:00+02:00.
    static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .current
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // Dates the app sends, e.g. 2026-10-21T05:30:00Z.
    static let isoParser = ISO8601DateFormatter()

    // MARK: - Tokens

    /// Unsigned JWT; the app only reads the payload.
    static func token(for role: Role) -> String {
        let now = Int(Date().timeIntervalSince1970)
        let isCoach = role == .coach
        let payload: JSON = [
            "name": isCoach ? "luka.maric" : "ana.kovac",
            "sub": (isCoach ? coachUserId : anaUserId).uuidString,
            "permissions": isCoach ? coachPermissions : clientPermissions,
            "role": isCoach ? "Coach" : "Client",
            "exp": now + 10 * 365 * 24 * 3600,
            "iat": now,
            "nbf": now
        ]
        func base64URL(_ object: JSON) -> String {
            let data = (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
            return data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        return "\(base64URL(["alg": "none", "typ": "JWT"])).\(base64URL(payload)).demo"
    }

    /// The coach when the request carries the coach's token, otherwise Ana.
    static func role(of request: URLRequest) -> Role {
        guard let header = request.value(forHTTPHeaderField: "Authorization"),
              header.hasPrefix("Bearer ") else { return .client }
        let token = String(header.dropFirst("Bearer ".count))
        return JWTDecoder.getUserId(token: token) == coachUserId ? .coach : .client
    }

    // MARK: - Answers

    static func reply(to request: URLRequest) -> Reply {
        guard let url = request.url else { return .notFound }

        // Path relative to the API, e.g. "chat/conversations".
        let slash = CharacterSet(charactersIn: "/")
        let basePath = AppEnvironment.apiURL.path.trimmingCharacters(in: slash)
        var path = url.path.trimmingCharacters(in: slash)
        if !basePath.isEmpty, path.hasPrefix(basePath) {
            path = String(path.dropFirst(basePath.count)).trimmingCharacters(in: slash)
        }

        var query: [String: String] = [:]
        for item in URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [] {
            query[item.name] = item.value
        }

        return Fixtures(role: role(of: request))
            .reply(method: request.httpMethod ?? "GET", path: path, query: query, body: body(of: request))
    }

    /// Answer as the coach or the client, e.g. "monthly-reviews?clientId=...".
    static func fixture(_ method: String, _ path: String, role: Role, body: Data? = nil) -> Reply {
        let parts = path.split(separator: "?", maxSplits: 1).map(String.init)
        var components = URLComponents(
            url: AppEnvironment.apiURL.appendingPathComponent(parts.first ?? ""),
            resolvingAgainstBaseURL: false
        )
        if parts.count > 1 {
            components?.query = parts[1]
        }
        var request = URLRequest(url: components?.url ?? AppEnvironment.apiURL)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("Bearer \(token(for: role))", forHTTPHeaderField: "Authorization")
        return reply(to: request)
    }

    // Inside a URLProtocol the body usually comes as a stream.
    private static func body(of request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }

        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

// MARK: - URL protocol

/// Answers every request to the API host with demo data.
final class DemoURLProtocol: URLProtocol {

    override class func canInit(with request: URLRequest) -> Bool {
        guard let host = request.url?.host else { return false }
        return host == AppEnvironment.apiURL.host
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let reply = DemoAPI.reply(to: request)
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: reply.status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": reply.contentType]
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Fixtures

/// Demo data as the API returns it, with dates around now.
fileprivate struct Fixtures {
    typealias JSON = DemoAPI.JSON
    typealias Reply = DemoAPI.Reply
    typealias SetSpec = (reps: String, weight: Double?, isDropSet: Bool)

    struct ExerciseSpec {
        let workout: Int
        let sets: [SetSpec]
        let note: String?
        let isSuperset: Bool
    }

    struct Measurement {
        let number: Int
        let daysAgo: Int
        let height, weight, shoulders, chest, upperArm, waist, thigh, calves, glutes: Double
    }

    struct MessageSpec {
        let number: Int
        let fromCoach: Bool
        let date: Date
        // Minutes until the other side read it, nil while unread.
        let readAfter: Int?
        let content: String
        var type = "text"
        var workout: Int? = nil
        var hasAttachment = false
    }

    private typealias W = DemoAPI.WorkoutNumber
    private typealias C = DemoAPI.ClientIndex

    let now: Date
    let role: DemoAPI.Role
    private let calendar = Calendar.current

    init(now: Date = Date(), role: DemoAPI.Role) {
        self.now = now
        self.role = role
    }

    private var isCoach: Bool { role == .coach }

    // MARK: Helpers

    /// Day relative to today at a time, e.g. day(1, 7, 30) is tomorrow 07:30.
    func day(_ offset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let start = calendar.startOfDay(for: now)
        let day = calendar.date(byAdding: .day, value: offset, to: start) ?? start
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    func minutesAgo(_ minutes: Int) -> Date {
        now.addingTimeInterval(TimeInterval(-minutes * 60))
    }

    func iso(_ date: Date) -> String {
        DemoAPI.isoFormatter.string(from: date)
    }

    func null(_ value: Any?) -> Any {
        value ?? NSNull()
    }

    func text(_ en: String, _ hr: String) -> JSON {
        ["translations": ["EN": en, "HR": hr]]
    }

    private func pad(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    // For example "07:30".
    func timeText(_ date: Date) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return "\(pad(parts.hour ?? 0)):\(pad(parts.minute ?? 0))"
    }

    func clientIndex(_ idText: String?) -> Int? {
        guard let idText, let id = UUID(uuidString: idText) else { return nil }
        return DemoAPI.clients.indices.first { DemoAPI.clientId($0) == id }
    }

    func conversationIndex(_ idText: String?) -> Int? {
        guard let idText, let id = UUID(uuidString: idText) else { return nil }
        return DemoAPI.clients.indices.first { DemoAPI.conversationId($0) == id }
    }

    func workoutNumber(_ idText: String?) -> Int? {
        guard let idText, let id = UUID(uuidString: idText) else { return nil }
        return DemoAPI.workouts.first { DemoAPI.id(.workout, $0.number) == id }?.number
    }

    // MARK: People

    var profile: JSON {
        let person = isCoach ? DemoAPI.coach : DemoAPI.clients[C.ana]
        return [
            "userId": (isCoach ? DemoAPI.coachUserId : DemoAPI.anaUserId).uuidString,
            "username": isCoach ? "luka.maric" : "ana.kovac",
            "email": person.email,
            "roles": [isCoach ? "Coach" : "Client"],
            "profileType": isCoach ? "Coach" : "Client",
            "firstName": person.firstName,
            "lastName": person.lastName,
            "phone": person.phone,
            // The app shows initials, no picture to load.
            "hasProfilePicture": false,
            "profilePictureUpdatedAt": NSNull()
        ]
    }

    var coach: JSON {
        let coach = DemoAPI.coach
        return [
            "id": DemoAPI.coachId.uuidString,
            "firstName": coach.firstName,
            "lastName": coach.lastName,
            "email": coach.email,
            "phone": coach.phone
        ]
    }

    /// Client as in lists and clients/current-client (also read as UserProfile).
    func client(_ index: Int, withMeasurements: Bool = false) -> JSON {
        let person = DemoAPI.clients[index]
        var json: JSON = [
            "id": DemoAPI.clientId(index).uuidString,
            "firstName": person.firstName,
            "lastName": person.lastName,
            "email": person.email,
            "phone": person.phone,
            "credits": person.credits,
            "plan": person.plan,
            "lastCreditsIncrease": iso(day(-12 - index * 4, 10))
        ]
        if withMeasurements {
            json["bodyMeasurements"] = measurements(of: index).map { measurementJSON($0, dateKey: "measuredAt") }
        }
        return json
    }

    // Short form in trainings and FMS.
    func person(_ index: Int) -> JSON {
        let person = DemoAPI.clients[index]
        return [
            "id": DemoAPI.clientId(index).uuidString,
            "firstName": person.firstName,
            "lastName": person.lastName
        ]
    }

    // MARK: Body measurements

    func measurements(of index: Int) -> [Measurement] {
        var result: [Measurement] = []
        if index == C.ana {
            for (number, row) in DemoAPI.anaMeasurements.enumerated() {
                result.append(Measurement(
                    number: number, daysAgo: row.0, height: 172, weight: row.1, shoulders: row.2,
                    chest: row.3, upperArm: row.4, waist: row.5, thigh: row.6, calves: row.7, glutes: row.8
                ))
            }
            return result
        }

        guard let body = DemoAPI.otherBodies[index] else { return [] }
        // Circumferences that go with the weight, to the half centimetre.
        func half(_ value: Double) -> Double { (value * 2).rounded() / 2 }
        for (number, weight) in body.weights.enumerated() {
            result.append(Measurement(
                number: index * 10 + number,
                daysAgo: (body.weights.count - 1 - number) * 30 + 6,
                height: body.height, weight: weight,
                shoulders: half(70 + weight * 0.45), chest: half(60 + weight * 0.45),
                upperArm: half(14 + weight * 0.22), waist: half(30 + weight * 0.62),
                thigh: half(25 + weight * 0.38), calves: half(22 + weight * 0.18),
                glutes: half(55 + weight * 0.55)
            ))
        }
        return result
    }

    /// dateKey is measuredAt in client lists, createdAt in GET body-measurements.
    func measurementJSON(_ measurement: Measurement, dateKey: String) -> JSON {
        [
            "id": DemoAPI.id(.measurement, measurement.number).uuidString,
            "height": measurement.height,
            "weight": measurement.weight,
            "shoulders": measurement.shoulders,
            "chest": measurement.chest,
            "upperArm": measurement.upperArm,
            "waist": measurement.waist,
            "thigh": measurement.thigh,
            "calves": measurement.calves,
            "glutes": measurement.glutes,
            dateKey: iso(day(-measurement.daysAgo, 8))
        ]
    }

    // MARK: Goal, reviews and records

    var anaGoal: JSON {
        [
            "goal": "Lose 5 kg of body fat and bench press 80 kg",
            "currentBlock": "Strength block — 4 trainings per week",
            "focus": "Progressive overload and a calorie deficit",
            "nextAssessment": "Body measurements and FMS re-test",
            "nextAssessmentDate": iso(day(21, 9)),
            // No date, so the "goal and plan updated" sheet isn't shown over home.
            "updatedAt": NSNull()
        ]
    }

    /// Last month's review and the one before, newest first.
    var anaReviews: [JSON] {
        let contents = [
            "Great month, Ana! You trained consistently, set a new bench press record of 70 kg and lost another kilo while getting stronger. Keep the protein high and aim for seven hours of sleep — next month we go after 75 kg on the bench.",
            "A solid start to the strength block. Your squat depth and bracing improved a lot and the scale is moving in the right direction. Next step: keep the weekends on plan so the progress stays steady."
        ]
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        var reviews: [JSON] = []
        for (index, content) in contents.enumerated() {
            let month = calendar.date(byAdding: .month, value: -(index + 1), to: monthStart) ?? monthStart
            let parts = calendar.dateComponents([.year, .month], from: month)
            // Written on the 1st of the next month.
            let written = calendar.date(byAdding: .month, value: 1, to: month) ?? month
            reviews.append([
                "id": DemoAPI.id(.review, index + 1).uuidString,
                "clientId": DemoAPI.anaClientId.uuidString,
                "year": parts.year ?? 2026,
                "month": parts.month ?? 1,
                "content": content,
                "updatedAt": iso(written.addingTimeInterval(10 * 3600))
            ])
        }
        return reviews
    }

    /// Records from Ana's trainings, Epley for the estimated 1RM.
    var anaRecords: [JSON] {
        // (workout, training, type, value, weight, reps)
        let rows: [(Int, Int, String, Double, Double, Double)] = [
            (W.bench, 2, "MaxWeight", 62.5, 62.5, 6), (W.bench, 2, "EstimatedOneRepMax", 75, 62.5, 6),
            (W.bench, 4, "MaxWeight", 67.5, 67.5, 6), (W.bench, 4, "EstimatedOneRepMax", 81, 67.5, 6),
            (W.bench, 6, "MaxWeight", 70, 70, 6), (W.bench, 6, "EstimatedOneRepMax", 84, 70, 6),
            (W.squat, 1, "MaxWeight", 90, 90, 3), (W.squat, 1, "EstimatedOneRepMax", 99, 90, 3),
            (W.squat, 3, "MaxWeight", 95, 95, 3), (W.squat, 3, "EstimatedOneRepMax", 104.5, 95, 3),
            (W.squat, 5, "MaxWeight", 100, 100, 3), (W.squat, 5, "EstimatedOneRepMax", 110, 100, 3),
            (W.deadlift, 1, "MaxWeight", 110, 110, 3), (W.deadlift, 1, "EstimatedOneRepMax", 121, 110, 3),
            (W.deadlift, 3, "MaxWeight", 115, 115, 3), (W.deadlift, 3, "EstimatedOneRepMax", 126.5, 115, 3),
            (W.deadlift, 5, "MaxWeight", 120, 120, 3), (W.deadlift, 5, "EstimatedOneRepMax", 132, 120, 3)
        ]
        var records: [JSON] = []
        for (index, row) in rows.enumerated() {
            records.append([
                "id": DemoAPI.id(.record, index + 1).uuidString,
                "clientId": DemoAPI.anaClientId.uuidString,
                "workoutId": DemoAPI.id(.workout, row.0).uuidString,
                "workoutName": workoutName(row.0),
                "trainingId": DemoAPI.id(.training, row.1).uuidString,
                "type": row.2,
                "value": row.3,
                "weight": row.4,
                "reps": row.5,
                "achievedAt": iso(anaTrainingDate(row.1).addingTimeInterval(75 * 60))
            ])
        }
        return records
    }

    // MARK: Workouts

    func workoutType(_ number: Int) -> JSON {
        let type = DemoAPI.workoutTypes.first { $0.number == number } ?? DemoAPI.workoutTypes[0]
        return [
            "id": DemoAPI.id(.workoutType, type.number).uuidString,
            "name": text(type.en, type.hr)
        ]
    }

    func workoutName(_ number: Int) -> JSON {
        guard let info = DemoAPI.workouts.first(where: { $0.number == number }) else { return text("", "") }
        return text(info.name.en, info.name.hr)
    }

    func workout(_ number: Int) -> JSON? {
        guard let info = DemoAPI.workouts.first(where: { $0.number == number }) else { return nil }
        return [
            "id": DemoAPI.id(.workout, info.number).uuidString,
            "name": text(info.name.en, info.name.hr),
            "description": text(info.description.en, info.description.hr),
            // Empty, the app shows its placeholder.
            "thumbnailUrl": "",
            "videoUrl": "",
            "workoutTypes": info.types.map { workoutType($0) },
            "muscles": info.muscles,
            "secondaryMuscles": info.secondaryMuscles
        ]
    }

    var allWorkouts: [JSON] {
        DemoAPI.workouts.compactMap { workout($0.number) }
    }

    // MARK: Trainings

    func s(_ reps: String, _ weight: Double?) -> SetSpec {
        (reps: reps, weight: weight, isDropSet: false)
    }

    // Drop set: right after the previous set with less weight.
    func drop(_ reps: String, _ weight: Double) -> SetSpec {
        (reps: reps, weight: weight, isDropSet: true)
    }

    func sets(_ count: Int, _ reps: String, _ weight: Double?) -> [SetSpec] {
        [SetSpec](repeating: (reps: reps, weight: weight, isDropSet: false), count: count)
    }

    func ex(_ workout: Int, _ sets: [SetSpec], note: String? = nil, superset: Bool = false) -> ExerciseSpec {
        ExerciseSpec(workout: workout, sets: sets, note: note, isSuperset: superset)
    }

    /// Exercises of training (or template) number, orders from 1.
    func exercisesJSON(_ number: Int, _ exercises: [ExerciseSpec]) -> [JSON] {
        var result: [JSON] = []
        for (index, exercise) in exercises.enumerated() {
            var sets: [JSON] = []
            for (setIndex, set) in exercise.sets.enumerated() {
                sets.append([
                    "id": DemoAPI.id(.exerciseSet, number * 10_000 + index * 100 + setIndex).uuidString,
                    "order": setIndex + 1,
                    "reps": set.reps,
                    "weight": null(set.weight),
                    "isDropSet": set.isDropSet
                ])
            }
            result.append([
                "id": DemoAPI.id(.exercise, number * 100 + index).uuidString,
                "workoutId": DemoAPI.id(.workout, exercise.workout).uuidString,
                "workoutName": workoutName(exercise.workout),
                "order": index + 1,
                "note": null(exercise.note),
                "sets": sets,
                "isSupersetWithPrevious": exercise.isSuperset
            ])
        }
        return result
    }

    func training(_ number: Int, _ name: String, client: Int, date: Date, completed: Bool,
                  note: String? = nil, _ exercises: [ExerciseSpec]) -> JSON {
        [
            "id": DemoAPI.id(.training, number).uuidString,
            "name": name,
            "date": iso(date),
            "note": null(note),
            "isCompleted": completed,
            "completedAt": null(completed ? iso(date.addingTimeInterval(75 * 60)) : nil),
            "client": person(client),
            "exercises": exercisesJSON(number, exercises)
        ]
    }

    /// Ana's completed trainings 1...6, about a week apart, 18:00.
    func anaTrainingDate(_ number: Int) -> Date {
        let daysAgo = [36, 29, 22, 15, 8, 1]
        return day(-daysAgo[max(0, min(number - 1, daysAgo.count - 1))], 18)
    }

    /// Six completed trainings with growing weights and the next planned one.
    var anaTrainings: [JSON] {
        let ana = C.ana
        return [
            training(1, "Lower Body Strength", client: ana, date: anaTrainingDate(1), completed: true, [
                ex(W.squat, [s("8", 70), s("5", 80), s("3", 90), s("3", 90)]),
                ex(W.deadlift, [s("5", 90), s("3", 100), s("3", 110)]),
                ex(W.hipThrust, sets(3, "10", 80)),
                ex(W.lunge, sets(3, "12", 10)),
                ex(W.plank, sets(3, "45 s", nil))
            ]),
            training(2, "Upper Body Strength", client: ana, date: anaTrainingDate(2), completed: true, [
                ex(W.bench, [s("10", 55), s("8", 60), s("6", 62.5), s("6", 62.5)]),
                ex(W.row, sets(4, "8", 40)),
                ex(W.overheadPress, sets(3, "10", 25)),
                ex(W.lateralRaise, sets(3, "15", 6))
            ]),
            training(3, "Lower Body Strength", client: ana, date: anaTrainingDate(3), completed: true, [
                ex(W.squat, [s("8", 75), s("5", 85), s("3", 95), s("3", 95)]),
                ex(W.deadlift, [s("5", 95), s("3", 105), s("3", 115)]),
                ex(W.hipThrust, sets(3, "10", 90)),
                ex(W.lunge, sets(3, "12", 10)),
                ex(W.plank, sets(3, "50 s", nil))
            ]),
            training(4, "Upper Body Strength", client: ana, date: anaTrainingDate(4), completed: true, [
                ex(W.bench, [s("10", 57.5), s("8", 62.5), s("6", 67.5), s("6", 67.5)]),
                ex(W.row, sets(4, "8", 42.5)),
                ex(W.overheadPress, sets(3, "10", 27.5)),
                ex(W.lateralRaise, sets(3, "15", 7))
            ]),
            training(5, "Lower Body Strength", client: ana, date: anaTrainingDate(5), completed: true,
                     note: "Squat 100 kg for 3 — great depth and bracing.", [
                ex(W.squat, [s("8", 80), s("5", 90), s("3", 100), s("3", 100)]),
                ex(W.deadlift, [s("5", 100), s("3", 110), s("3", 120)]),
                ex(W.hipThrust, sets(3, "10", 100)),
                ex(W.lunge, sets(3, "12", 12.5)),
                ex(W.plank, sets(3, "60 s", nil))
            ]),
            training(6, "Upper Body Strength", client: ana, date: anaTrainingDate(6), completed: true,
                     note: "Strong session — new bench press record: 70 kg for 6 reps!", [
                ex(W.bench, [s("10", 60), s("8", 65), s("6", 70), s("6", 70), drop("8", 55), drop("10", 45)],
                   note: "Pause on the chest on every rep. Two drop sets after the last set."),
                ex(W.row, sets(4, "8", 45)),
                ex(W.overheadPress, sets(3, "10", 30)),
                ex(W.curl, sets(3, "12", 10)),
                ex(W.pushdown, [s("12", 25), s("12", 25), s("12", 25), drop("12", 17.5)],
                   note: "Elbows pinned to your sides, full lockout.", superset: true)
            ]),
            // Planned with tomorrow's appointment; only the coach sees it.
            training(7, "Lower Body Strength", client: ana, date: day(1, 7, 30), completed: false,
                     note: "Aim for 102.5 kg on the top squat sets.", [
                ex(W.squat, [s("8", 80), s("5", 90), s("3", 102.5), s("3", 102.5)]),
                ex(W.romanianDeadlift, sets(3, "10", 70)),
                ex(W.hipThrust, sets(3, "10", 105)),
                ex(W.lunge, sets(3, "12", 12.5)),
                ex(W.plank, sets(3, "60 s", nil))
            ])
        ]
    }

    var otherTrainings: [JSON] {
        [
            training(20, "Full Body Conditioning", client: C.marko, date: day(-2, 7, 30), completed: true, [
                ex(W.squat, sets(4, "8", 100)),
                ex(W.pullUp, sets(4, "8", nil)),
                ex(W.overheadPress, sets(3, "10", 45)),
                ex(W.plank, sets(3, "60 s", nil))
            ]),
            training(21, "Upper Body Hypertrophy", client: C.petra, date: day(-3, 9), completed: true, [
                ex(W.inclinePress, sets(4, "10", 16), note: "16 kg dumbbells."),
                ex(W.row, sets(3, "12", 35)),
                ex(W.lateralRaise, sets(3, "15", 5)),
                ex(W.curl, sets(3, "12", 8)),
                ex(W.pushdown, sets(3, "12", 20), superset: true)
            ]),
            training(22, "Glutes & Hamstrings", client: C.ivana, date: day(2, 18, 30), completed: false, [
                ex(W.hipThrust, sets(4, "10", 70)),
                ex(W.romanianDeadlift, sets(3, "10", 50)),
                ex(W.lunge, sets(3, "12", 8))
            ])
        ]
    }

    var templates: [JSON] {
        let specs: [(Int, String, String?, [ExerciseSpec])] = [
            (90, "Upper Body Strength", "Main lift first, finish with the arm superset.", [
                ex(W.bench, sets(4, "6–8", nil)),
                ex(W.row, sets(4, "8", nil)),
                ex(W.overheadPress, sets(3, "10", nil)),
                ex(W.curl, sets(3, "12", nil)),
                ex(W.pushdown, sets(3, "12", nil), superset: true)
            ]),
            (91, "Lower Body Strength", nil, [
                ex(W.squat, sets(4, "5", nil)),
                ex(W.deadlift, sets(3, "3", nil)),
                ex(W.hipThrust, sets(3, "10", nil)),
                ex(W.lunge, sets(3, "12", nil)),
                ex(W.plank, sets(3, "45 s", nil))
            ]),
            (92, "Full Body Conditioning", "Short rests, keep the heart rate up.", [
                ex(W.squat, sets(3, "10", nil)),
                ex(W.pullUp, sets(3, "8", nil)),
                ex(W.overheadPress, sets(3, "10", nil)),
                ex(W.romanianDeadlift, sets(3, "10", nil)),
                ex(W.plank, sets(3, "60 s", nil))
            ])
        ]
        var result: [JSON] = []
        for (index, spec) in specs.enumerated() {
            result.append([
                "id": DemoAPI.id(.template, spec.0).uuidString,
                "name": spec.1,
                "note": null(spec.2),
                "exercises": exercisesJSON(spec.0, spec.3),
                "authorName": DemoAPI.coach.fullName,
                "canEdit": true,
                "createdAt": iso(day(-90 + index * 10, 12)),
                "updatedAt": iso(day(-30 + index * 5, 12))
            ])
        }
        return result
    }

    // MARK: FMS

    /// scores: deep squat, hurdle step, in-line lunge, active straight leg raise,
    /// trunk stability push-up, rotary stability, shoulder mobility.
    func screen(_ number: Int, client: Int, date: Date, _ scores: [String], description: String) -> JSON {
        [
            "id": DemoAPI.id(.fms, number).uuidString,
            "deepSquat": scores[0],
            "hurdleStep": scores[1],
            "inLineLunge": scores[2],
            "activeStraightLegRaise": scores[3],
            "trunkStabilityPushUp": scores[4],
            "rotaryStability": scores[5],
            "shoulderMobility": scores[6],
            "xTest": "Negative",
            "description": description,
            "createdAt": iso(date),
            "client": person(client)
        ]
    }

    var anaScreens: [JSON] {
        [
            screen(2, client: C.ana, date: day(-7, 10), ["2", "2", "2", "3", "2", "2", "3"],
                   description: "Clear progress: the deep squat now reaches parallel with the heels down and the push-up stays solid. Total score 16 (+4)."),
            screen(1, client: C.ana, date: day(-70, 10), ["1", "2", "2", "2", "1", "2", "2"],
                   description: "Deep squat limited by ankle mobility, lower back sags in the push-up. Focus: ankle mobility and core bracing. Total score 12.")
        ]
    }

    var allScreens: [JSON] {
        anaScreens + [
            screen(3, client: C.marko, date: day(-40, 9), ["2", "2", "3", "2", "3", "2", "1"],
                   description: "Shoulder mobility is the limiting factor. Thoracic and shoulder mobility work before every upper body session.")
        ]
    }

    // MARK: Appointments

    func status(_ name: String) -> JSON {
        let number = ["Approved": 1, "Pending": 2, "Cancelled": 3][name] ?? 1
        return ["id": DemoAPI.id(.status, number).uuidString, "name": name, "description": name]
    }

    func appointment(_ number: Int, _ start: Date, clients: [Int], status name: String = "Approved") -> JSON {
        let end = start.addingTimeInterval(3600)
        let parts = calendar.dateComponents([.hour, .minute], from: start)
        let times = "\(timeText(start)) - \(timeText(end))"
        let slot: JSON = [
            "id": DemoAPI.id(.timeSlot, (parts.hour ?? 0) * 100 + (parts.minute ?? 0)).uuidString,
            "name": times,
            "description": times,
            "startTime": "\(timeText(start)):00",
            "endTime": "\(timeText(end)):00"
        ]
        return [
            "id": DemoAPI.id(.appointment, number).uuidString,
            "startTime": iso(start),
            "endTime": iso(end),
            "timeSlot": slot,
            "status": status(name),
            "clients": clients.map { client($0) }
        ]
    }

    /// Ana's sessions this month that are over. With two booked and five
    /// credits left the package adds up to 12 (fewer early in the month).
    var anaDoneDates: [Date] {
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let candidates = [(1, 18, 0), (4, 7, 30), (8, 18, 0), (11, 7, 30), (15, 18, 0),
                          (18, 7, 30), (22, 18, 0), (25, 7, 30), (29, 18, 0)]
        var dates = candidates.map { day(-$0.0, $0.1, $0.2) }.filter { $0 >= monthStart }
        // Early in the month: sessions earlier today.
        var hour = calendar.component(.hour, from: now) - 2
        while dates.count < 5, hour >= 6 {
            dates.append(day(0, hour))
            hour -= 2
        }
        return Array(dates.prefix(5))
    }

    var anaDone: [JSON] {
        anaDoneDates.enumerated().map { appointment(50 + $0.offset, $0.element, clients: [C.ana]) }
    }

    // Booked: tomorrow 07:30 (the next appointment on home) and in three days.
    var anaBooked: [JSON] {
        [
            appointment(1, day(1, 7, 30), clients: [C.ana]),
            appointment(2, day(3, 18), clients: [C.ana])
        ]
    }

    // Requested by Ana, waiting for the coach.
    var anaPending: [JSON] {
        [appointment(3, day(6, 18), clients: [C.ana], status: "Pending")]
    }

    func otherAppointment(_ number: Int) -> JSON {
        guard let session = DemoAPI.otherSessions.first(where: { $0.number == number }) else { return [:] }
        return appointment(session.number, day(session.day, session.hour, session.minute), clients: [session.client])
    }

    var appointmentsStatus: JSON {
        var approved = anaDone + anaBooked
        if isCoach {
            approved += DemoAPI.otherSessions.map { otherAppointment($0.number) }
        }
        return [
            "approvedAppointments": approved,
            "pendingAppointments": anaPending,
            "inProgressAppointments": [JSON]()
        ]
    }

    func requestType(_ name: String) -> JSON {
        let isCancelation = name == "CancelationRequest"
        return [
            "id": DemoAPI.id(.catalog, isCancelation ? 1 : 2).uuidString,
            "name": name,
            // Localization keys, the app lowercases them.
            "description": isCancelation ? "cancelation-request" : "join-request"
        ]
    }

    /// Requests Ana sent (GET appointment-requests).
    var anaSentRequests: [JSON] {
        [
            [
                "id": DemoAPI.id(.request, 1).uuidString,
                "comment": "I'm on a business trip that week, sorry. I'll make it up next week!",
                "type": requestType("CancelationRequest"),
                "status": ["name": "Approved"],
                "appointment": appointment(4, day(-6, 18), clients: [C.ana], status: "Cancelled"),
                "createdAt": iso(day(-9, 12, 10)),
                "updatedAt": iso(day(-9, 14, 30))
            ],
            [
                "id": DemoAPI.id(.request, 2).uuidString,
                "comment": "Could I join Petra's morning session?",
                "type": requestType("JoinRequest"),
                "status": ["name": "Declined"],
                "appointment": otherAppointment(21),
                "createdAt": iso(day(-2, 20, 15)),
                "updatedAt": iso(day(-1, 8, 5))
            ]
        ]
    }

    /// Appointments Ana requested herself (GET appointments/my-requests).
    var anaMyRequests: [JSON] {
        [
            [
                "appointment": anaBooked[0],
                "createdAt": iso(day(-4, 19)),
                "updatedAt": iso(day(-4, 20, 30))
            ],
            [
                "appointment": anaPending[0],
                "createdAt": iso(minutesAgo(180)),
                "updatedAt": iso(minutesAgo(180))
            ]
        ]
    }

    /// Requests waiting for the coach (GET appointment-requests/pending).
    var pendingRequests: [JSON] {
        [
            [
                "id": DemoAPI.id(.request, 10).uuidString,
                "comment": "I have a doctor's appointment tomorrow morning. Sorry for the short notice!",
                "sender": client(C.lucija),
                "type": requestType("CancelationRequest"),
                "appointment": otherAppointment(20),
                "createdAt": iso(minutesAgo(120))
            ],
            [
                "id": DemoAPI.id(.request, 11).uuidString,
                "comment": "Petra told me about your morning sessions. Could I join this one?",
                "sender": client(C.maja),
                "type": requestType("JoinRequest"),
                "appointment": otherAppointment(21),
                "createdAt": iso(minutesAgo(300))
            ]
        ]
    }

    var appointmentTypes: [JSON] {
        [
            ["id": DemoAPI.id(.catalog, 10).uuidString, "name": "PersonalTraining", "description": "Personal training"],
            ["id": DemoAPI.id(.catalog, 11).uuidString, "name": "Consultation", "description": "Consultation"],
            ["id": DemoAPI.id(.catalog, 12).uuidString, "name": "GroupTraining", "description": "Small group training"]
        ]
    }

    /// Free slots of a day, one taken by Petra that can be joined.
    func timeSlots(dayText: String?) -> [JSON] {
        let times = [(7, 30), (9, 0), (10, 30), (16, 0), (17, 30), (19, 0)]
        var slots: [JSON] = []
        for (hour, minute) in times {
            let start = day(1, hour, minute)
            let end = start.addingTimeInterval(3600)
            let isTaken = hour == 17
            var name = "\(timeText(start)) - \(timeText(end))"
            if isTaken {
                name += " (\(DemoAPI.clients[C.petra].fullName))"
            }
            var slot: JSON = [
                "id": DemoAPI.id(.timeSlot, 10_000 + hour * 100 + minute).uuidString,
                "name": name,
                "startTime": "\(timeText(start)):00",
                "endTime": "\(timeText(end)):00",
                "isTaken": isTaken
            ]
            if let dayText {
                slot["day"] = dayText
            }
            if isTaken {
                slot["appointmentId"] = DemoAPI.id(.appointment, 90).uuidString
            }
            slots.append(slot)
        }
        return slots
    }

    // MARK: Notifications

    func notification(_ number: Int, _ type: String, _ title: String, _ body: String, _ date: Date,
                      read: Bool, data: [String: String] = [:]) -> JSON {
        [
            "id": DemoAPI.id(.notification, number).uuidString,
            "type": type,
            "title": title,
            "body": body,
            "data": data,
            "createdAt": iso(date),
            "readAt": null(read ? iso(date.addingTimeInterval(1800)) : nil)
        ]
    }

    var lastMonthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "LLLL"
        return formatter.string(from: calendar.date(byAdding: .month, value: -1, to: now) ?? now)
    }

    /// Newest first, two unread.
    var notifications: [JSON] {
        if isCoach {
            return [
                notification(10, "appointment_request", "Cancelation request",
                             "Lucija Perić asked to cancel tomorrow's session at 10:00.", minutesAgo(118), read: false),
                notification(11, "appointment_request", "New appointment request",
                             "Ana Kovač asked for an appointment next week.", minutesAgo(178), read: false),
                notification(12, "monthly_review_reminder", "Time for monthly reviews",
                             "Write last month's reviews for your clients.", day(-2, 9), read: true)
            ]
        }
        return [
            notification(1, "training", "New training planned",
                         "Luka planned your next training: Lower Body Strength.", minutesAgo(130), read: false,
                         data: ["trainingId": DemoAPI.id(.training, 7).uuidString]),
            notification(2, "appointment_updated", "Appointment approved",
                         "Your appointment tomorrow at 07:30 is confirmed. See you there!", minutesAgo(310), read: false),
            notification(3, "monthly_review", "Your monthly review is ready",
                         "Luka wrote your review for \(lastMonthName). Great progress!", day(-2, 9, 15), read: true),
            notification(4, "client_goal", "Goal and plan updated",
                         "Your coach updated your goal and plan for the new strength block.", day(-3, 10, 20), read: true),
            notification(5, "body_measurement", "New body measurement",
                         "Weight 79.5 kg, waist 86 cm. That's 4.5 kg down since you started!", day(-3, 8, 40), read: true)
        ]
    }

    var unreadNotificationCount: Int {
        notifications.filter { $0["readAt"] is NSNull }.count
    }

    // MARK: Chat

    func participant(client index: Int?) -> JSON {
        guard let index else {
            return [
                "id": DemoAPI.coachId.uuidString,
                "userId": DemoAPI.coachUserId.uuidString,
                "fullName": DemoAPI.coach.fullName
            ]
        }
        return [
            "id": DemoAPI.clientId(index).uuidString,
            "userId": DemoAPI.userId(ofClient: index).uuidString,
            "fullName": DemoAPI.clients[index].fullName
        ]
    }

    func attachmentJSON(_ id: UUID) -> JSON {
        [
            "id": id.uuidString,
            "contentType": "image/jpeg",
            "width": DemoAPI.attachmentImage.width,
            "height": DemoAPI.attachmentImage.height
        ]
    }

    /// Yesterday's training talk and this morning's messages, oldest first.
    var anaMessages: [MessageSpec] {
        [
            MessageSpec(number: 1, fromCoach: true, date: day(-1, 19, 40), readAfter: 6,
                        content: "Great work tonight, Ana! 70 kg for 6 on the bench is a new personal record 🎉"),
            MessageSpec(number: 2, fromCoach: false, date: day(-1, 19, 52), readAfter: 3,
                        content: "Thank you! The last set was heavy, but the bar was still moving well."),
            MessageSpec(number: 3, fromCoach: true, date: day(-1, 19, 58), readAfter: 4,
                        content: "It looked solid. Keep your shoulder blades pinned and drive your feet into the floor — that's where the next 5 kg will come from."),
            MessageSpec(number: 4, fromCoach: false, date: day(-1, 20, 5), readAfter: 5,
                        content: "Got it! My lower back felt a bit tight after the rows, though."),
            MessageSpec(number: 5, fromCoach: true, date: day(-1, 20, 12), readAfter: 8,
                        content: "That usually means the hips aren't hinging enough. Add this to your warm-up before the next lower body session:"),
            MessageSpec(number: 6, fromCoach: true, date: day(-1, 20, 13), readAfter: 7,
                        content: "2 × 10 with an empty bar, slow on the way down.",
                        type: "workout", workout: DemoAPI.WorkoutNumber.romanianDeadlift),
            MessageSpec(number: 7, fromCoach: false, date: minutesAgo(95), readAfter: 13,
                        content: "Meal prep for the week 💪", type: "image", hasAttachment: true),
            MessageSpec(number: 8, fromCoach: true, date: minutesAgo(80), readAfter: 20,
                        content: "Looks great — plenty of protein and veggies. Exactly what we need for the deficit."),
            MessageSpec(number: 9, fromCoach: false, date: minutesAgo(40), readAfter: 10,
                        content: "Thanks! See you tomorrow at 7:30?"),
            MessageSpec(number: 10, fromCoach: true, date: minutesAgo(25), readAfter: 5,
                        content: "Yes, see you then. We start with squats 💪")
        ]
    }

    /// Messages of a conversation; the coach's other chats have one each.
    func messageSpecs(of index: Int) -> [MessageSpec] {
        switch index {
        case C.ana:
            return anaMessages
        case C.marko:
            return [MessageSpec(number: 101, fromCoach: false, date: minutesAgo(185), readAfter: nil,
                                content: "Thanks, 18:00 tomorrow works for me 👍")]
        case C.petra:
            return [MessageSpec(number: 102, fromCoach: false, date: day(-1, 21, 10), readAfter: 12,
                                content: "My shoulders feel much better since the new warm-up. Thank you!")]
        case C.ivana:
            return [MessageSpec(number: 103, fromCoach: true, date: day(-3, 12), readAfter: 45,
                                content: "Send me a video of your hip thrusts when you get a chance.")]
        default:
            return []
        }
    }

    func message(_ spec: MessageSpec, client index: Int) -> JSON {
        let sender = spec.fromCoach ? DemoAPI.coachUserId : DemoAPI.userId(ofClient: index)
        var json: JSON = [
            "id": DemoAPI.id(.message, spec.number).uuidString,
            "conversationId": DemoAPI.conversationId(index).uuidString,
            "senderUserId": sender.uuidString,
            "content": spec.content,
            "createdAt": iso(spec.date),
            "readAt": null(spec.readAfter.map { iso(spec.date.addingTimeInterval(TimeInterval($0 * 60))) }),
            "type": spec.type
        ]
        if let number = spec.workout, let shared = workout(number) {
            json["workout"] = shared
        }
        if spec.hasAttachment {
            json["attachment"] = attachmentJSON(DemoAPI.id(.attachment, spec.number))
        }
        return json
    }

    func messages(of index: Int) -> [JSON] {
        messageSpecs(of: index).map { message($0, client: index) }
    }

    func conversation(_ index: Int) -> JSON {
        let specs = messageSpecs(of: index)
        // Unread: the other side's messages the logged user hasn't read.
        let unread = specs.filter { $0.fromCoach != isCoach && $0.readAfter == nil }.count
        var json: JSON = [
            "id": DemoAPI.conversationId(index).uuidString,
            "coach": participant(client: nil),
            "client": participant(client: index),
            "isEnabled": true,
            "isBlockedByClient": false,
            "unreadCount": unread
        ]
        if let last = specs.last {
            json["lastMessageAt"] = iso(last.date)
            json["lastMessage"] = message(last, client: index)
        }
        return json
    }

    // Clients the coach chats with; Ana's conversation is the newest.
    var chatClients: [Int] {
        guard isCoach else { return [C.ana] }
        return [C.ana, C.marko, C.petra, C.ivana].sorted {
            (messageSpecs(of: $0).last?.date ?? .distantPast) > (messageSpecs(of: $1).last?.date ?? .distantPast)
        }
    }

    var conversations: [JSON] {
        chatClients.map { conversation($0) }
    }

    var chatUnreadCount: Int {
        chatClients.reduce(0) { total, index in
            total + messageSpecs(of: index).filter { $0.fromCoach != isCoach && $0.readAfter == nil }.count
        }
    }

    var contacts: [JSON] {
        guard isCoach else {
            return [[
                "id": DemoAPI.coachId.uuidString,
                "userId": DemoAPI.coachUserId.uuidString,
                "fullName": DemoAPI.coach.fullName,
                "conversationId": DemoAPI.anaConversationId.uuidString,
                "isEnabled": true
            ]]
        }
        let chats = chatClients
        return DemoAPI.clients.indices.map { index in
            [
                "id": DemoAPI.clientId(index).uuidString,
                "userId": DemoAPI.userId(ofClient: index).uuidString,
                "fullName": DemoAPI.clients[index].fullName,
                "conversationId": null(chats.contains(index) ? DemoAPI.conversationId(index).uuidString : nil),
                "isEnabled": true
            ] as JSON
        }
    }

    /// Message the logged user just sent: text, a shared workout or a picture.
    func sentMessage(conversation idText: String, content: String, workoutId: String? = nil,
                     isImage: Bool = false) -> JSON {
        let sharedWorkout = workoutNumber(workoutId)
        var json: JSON = [
            "id": UUID().uuidString,
            "conversationId": idText,
            "senderUserId": (isCoach ? DemoAPI.coachUserId : DemoAPI.anaUserId).uuidString,
            "content": content,
            "createdAt": iso(now),
            "readAt": NSNull(),
            "type": isImage ? "image" : (sharedWorkout == nil ? "text" : "workout")
        ]
        if let sharedWorkout, let shared = workout(sharedWorkout) {
            json["workout"] = shared
        }
        if isImage {
            json["attachment"] = attachmentJSON(UUID())
        }
        return json
    }

    // MARK: Saved changes

    /// Training (or the exercises of a template) from a POST or PUT body.
    func savedExercises(_ value: Any?) -> [JSON] {
        var exercises: [JSON] = []
        for (index, exercise) in ((value as? [JSON]) ?? []).enumerated() {
            let workoutId = exercise["workout"] as? String ?? UUID().uuidString
            var sets: [JSON] = []
            for (setIndex, set) in ((exercise["sets"] as? [JSON]) ?? []).enumerated() {
                sets.append([
                    "id": UUID().uuidString,
                    "order": setIndex + 1,
                    "reps": null(set["reps"] as? String),
                    "weight": null(set["weight"] as? NSNumber),
                    "isDropSet": set["isDropSet"] as? Bool ?? false
                ])
            }
            exercises.append([
                "id": UUID().uuidString,
                "workoutId": workoutId,
                "workoutName": workoutNumber(workoutId).map { workoutName($0) } ?? text("", ""),
                "order": index + 1,
                "note": null(exercise["note"] as? String),
                "sets": sets,
                "isSupersetWithPrevious": exercise["isSupersetWithPrevious"] as? Bool ?? false
            ])
        }
        return exercises
    }

    func savedTraining(id: UUID, _ input: JSON) -> JSON {
        let index = clientIndex(input["client"] as? String) ?? C.ana
        let isCompleted = input["isCompleted"] as? Bool ?? false
        let date = (input["date"] as? String).flatMap { DemoAPI.isoParser.date(from: $0) } ?? now
        return [
            "id": id.uuidString,
            "name": input["name"] as? String ?? "",
            "date": iso(date),
            "note": null(input["note"] as? String),
            "isCompleted": isCompleted,
            "completedAt": null(isCompleted ? iso(now) : nil),
            "client": person(index),
            "exercises": savedExercises(input["exercises"])
        ]
    }

    func savedTemplate(id: UUID, _ input: JSON) -> JSON {
        [
            "id": id.uuidString,
            "name": input["name"] as? String ?? "",
            "note": null(input["note"] as? String),
            "exercises": savedExercises(input["exercises"]),
            "authorName": DemoAPI.coach.fullName,
            "canEdit": true,
            "createdAt": iso(now),
            "updatedAt": iso(now)
        ]
    }

    func savedWorkout(id: UUID, _ input: JSON) -> JSON {
        let typeIds = (input["workoutTypes"] as? [String] ?? []).compactMap { UUID(uuidString: $0) }
        let types = DemoAPI.workoutTypes.filter { typeIds.contains(DemoAPI.id(.workoutType, $0.number)) }
        return [
            "id": id.uuidString,
            "name": input["name"] ?? text("", ""),
            "description": input["description"] ?? text("", ""),
            "thumbnailUrl": input["thumbnailUrl"] as? String ?? "",
            "videoUrl": input["videoUrl"] as? String ?? "",
            "workoutTypes": types.map { workoutType($0.number) },
            "muscles": input["muscles"] as? [String] ?? [String](),
            "secondaryMuscles": input["secondaryMuscles"] as? [String] ?? [String]()
        ]
    }

    // MARK: Routes

    func reply(method: String, path: String, query: [String: String], body: Data?) -> Reply {
        let segments = path.split(separator: "/").map(String.init)
        let input = (body.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? JSON) ?? [:]

        // Captured "*" segments when the request matches, e.g. "workouts/*".
        func route(_ expectedMethod: String, _ pattern: String) -> [String]? {
            guard method == expectedMethod else { return nil }
            let parts = pattern.split(separator: "/").map(String.init)
            guard parts.count == segments.count else { return nil }
            var captured: [String] = []
            for (part, segment) in zip(parts, segments) {
                if part == "*" {
                    captured.append(segment)
                } else if part != segment {
                    return nil
                }
            }
            return captured
        }

        // Staff ask for one client; only Ana has reviews and records.
        let asksForAna = query["clientId"].map { UUID(uuidString: $0) == DemoAPI.anaClientId } ?? true
        let statusReply = Reply.json(["id": UUID().uuidString])

        // The chat hub (SignalR) isn't faked, it fails quietly and retries.
        if segments.first == "hubs" {
            return .notFound
        }

        // Login: a username with "coach" in it is the coach, any other Ana.
        if route("POST", "authentication/login") != nil {
            let username = (input["username"] as? String ?? "").lowercased()
            return .json(["token": DemoAPI.token(for: username.contains("coach") ? .coach : .client)])
        }

        // People
        if route("GET", "profile") != nil {
            return .json(profile)
        }
        if route("GET", "profile/picture") != nil {
            return .notFound
        }
        if route("GET", "clients/current-client") != nil {
            return .json(client(C.ana))
        }
        if route("GET", "coaches/current-coach") != nil {
            return .json(coach)
        }
        if route("GET", "coaches/all") != nil || route("GET", "coaches/client") != nil {
            return .json([coach])
        }
        if route("GET", "clients") != nil {
            return .json(DemoAPI.clients.indices.map { client($0, withMeasurements: true) })
        }

        // Body, goal, reviews and records
        if route("GET", "body-measurements") != nil {
            return .json(measurements(of: C.ana).reversed().map { measurementJSON($0, dateKey: "createdAt") })
        }
        if route("GET", "client-goals/my") != nil {
            return .json(anaGoal)
        }
        if let ids = route("GET", "client-goals/*") {
            return .json(UUID(uuidString: ids[0]) == DemoAPI.anaClientId ? anaGoal : JSON())
        }
        if route("GET", "monthly-reviews") != nil {
            return .json(asksForAna ? anaReviews : [JSON]())
        }
        if route("GET", "personal-records") != nil {
            return .json(asksForAna ? anaRecords : [JSON]())
        }
        if route("GET", "functional-movement-screens") != nil {
            return .json(isCoach ? allScreens : anaScreens)
        }

        // Trainings and workouts
        if route("GET", "trainings") != nil {
            // Clients only get completed trainings.
            return .json(isCoach ? anaTrainings + otherTrainings : anaTrainings.filter { $0["isCompleted"] as? Bool == true })
        }
        if route("GET", "training-templates") != nil {
            return .json(templates)
        }
        if route("GET", "workouts") != nil {
            return .json(allWorkouts)
        }
        if let ids = route("GET", "workouts/*") {
            guard let number = workoutNumber(ids[0]), let json = workout(number) else { return .notFound }
            return .json(json)
        }
        if route("GET", "workout-types") != nil {
            return .json(DemoAPI.workoutTypes.map { workoutType($0.number) })
        }

        // Appointments
        if route("GET", "appointments") != nil {
            return .json(appointmentsStatus)
        }
        if route("GET", "appointments/my-requests") != nil {
            return .json(isCoach ? [JSON]() : anaMyRequests)
        }
        if route("GET", "appointment-requests") != nil {
            return .json(isCoach ? [JSON]() : anaSentRequests)
        }
        if route("GET", "appointment-requests/pending") != nil {
            return .json(isCoach ? pendingRequests : [JSON]())
        }
        if route("GET", "appointment-types") != nil {
            return .json(appointmentTypes)
        }
        if route("GET", "recurring-appointments/generate-next-week") != nil {
            // Number of appointments created.
            return Reply(data: Data("3".utf8))
        }
        // Approving, declining, canceling and joining are GET requests.
        if route("GET", "appointments/*/*") != nil || route("GET", "appointment-requests/*/*") != nil {
            return statusReply
        }
        if route("POST", "time-slots/available") != nil {
            return .json(timeSlots(dayText: input["day"] as? String))
        }

        // Notifications
        if route("GET", "notifications") != nil {
            return .json(notifications)
        }
        if route("GET", "notifications/unread-count") != nil {
            return .json(["count": unreadNotificationCount])
        }

        // Chat
        if route("GET", "chat/conversations") != nil {
            return .json(conversations)
        }
        if route("GET", "chat/contacts") != nil {
            return .json(contacts)
        }
        if route("GET", "chat/unread-count") != nil {
            return .json(["count": chatUnreadCount])
        }
        if let ids = route("GET", "chat/conversations/*/messages") {
            // One page holds the whole conversation, there are no older messages.
            guard query["before"] == nil, let index = conversationIndex(ids[0]) else { return .json([JSON]()) }
            return .json(messages(of: index))
        }
        if route("GET", "chat/conversations/*/attachments/*") != nil {
            return Reply(contentType: "image/jpeg", data: DemoAPI.attachmentImage.data)
        }
        if let ids = route("POST", "chat/conversations/*/messages") {
            return .json(sentMessage(conversation: ids[0], content: input["content"] as? String ?? "",
                                     workoutId: input["workoutId"] as? String))
        }
        if let ids = route("POST", "chat/conversations/*/images") {
            return .json(sentMessage(conversation: ids[0], content: "", isImage: true))
        }
        if route("POST", "chat/conversations/start") != nil {
            return .json(conversation(C.ana))
        }
        if route("POST", "chat/conversations") != nil {
            var json = conversation(clientIndex(input["clientId"] as? String) ?? C.ana)
            json["isEnabled"] = input["isEnabled"] as? Bool ?? true
            return .json(json)
        }
        if let ids = route("POST", "chat/conversations/*/block") {
            let isBlocked = input["isBlocked"] as? Bool ?? false
            var json = conversation(conversationIndex(ids[0]) ?? C.ana)
            json["isBlockedByClient"] = isBlocked
            json["isEnabled"] = !isBlocked
            return .json(json)
        }

        // Changes answered with what the app decodes.
        if route("PUT", "trainings/*/completion") != nil {
            let isCompleted = input["isCompleted"] as? Bool ?? true
            return .json(["isCompleted": isCompleted, "completedAt": null(isCompleted ? iso(now) : nil)] as JSON)
        }
        if route("POST", "trainings") != nil {
            return .json(savedTraining(id: UUID(), input))
        }
        if let ids = route("PUT", "trainings/*") {
            return .json(savedTraining(id: UUID(uuidString: ids[0]) ?? UUID(), input))
        }
        if route("POST", "training-templates") != nil {
            return .json(savedTemplate(id: UUID(), input))
        }
        if let ids = route("PUT", "training-templates/*") {
            return .json(savedTemplate(id: UUID(uuidString: ids[0]) ?? UUID(), input))
        }
        if route("POST", "training-templates/*/assign") != nil {
            let clients = input["clients"] as? [String] ?? []
            return .json(["trainingIds": clients.map { _ in UUID().uuidString }])
        }
        if route("PUT", "client-goals/*") != nil {
            var goal: JSON = ["updatedAt": iso(now)]
            for key in ["goal", "currentBlock", "focus", "nextAssessment", "nextAssessmentDate"] {
                goal[key] = input[key] ?? NSNull()
            }
            return .json(goal)
        }
        if route("PUT", "monthly-reviews") != nil {
            return .json([
                "id": UUID().uuidString,
                "clientId": input["client"] as? String ?? DemoAPI.anaClientId.uuidString,
                "year": input["year"] as? Int ?? calendar.component(.year, from: now),
                "month": input["month"] as? Int ?? calendar.component(.month, from: now),
                "content": input["content"] as? String ?? "",
                "updatedAt": iso(now)
            ] as JSON)
        }
        if route("POST", "workouts/import") != nil {
            return .json(["id": UUID().uuidString, "status": true, "queuedWorkoutsCount": 0] as JSON)
        }
        if route("POST", "workouts") != nil {
            return .json(savedWorkout(id: UUID(), input))
        }
        if let ids = route("PUT", "workouts/*") {
            return .json(savedWorkout(id: UUID(uuidString: ids[0]) ?? UUID(), input))
        }
        if route("PUT", "profile") != nil {
            var updated = profile
            for key in ["email", "firstName", "lastName", "phone"] {
                if let value = input[key] as? String { updated[key] = value }
            }
            return .json(updated)
        }
        if let ids = route("PUT", "clients/*") {
            var updated = client(clientIndex(ids[0]) ?? C.ana, withMeasurements: true)
            for key in ["firstName", "lastName", "email", "phone", "plan"] {
                if let value = input[key] as? String { updated[key] = value }
            }
            if let credits = input["credits"] as? Int {
                updated["credits"] = credits
            }
            return .json(updated)
        }

        if method == "GET" {
            print("⚠️ DemoAPI: no demo data for GET \(path)")
            return .notFound
        }
        // Other changes succeed without changing the demo data.
        return statusReply
    }
}

// MARK: - Checks for tests

extension DemoAPI {
    /// A demo answer and the decoding the app does with it.
    struct DecodingCheck {
        let method: String
        let path: String
        let role: Role
        let body: Data?
        let decode: @MainActor (Data) throws -> Void
    }

    // Answers the app decodes with types declared inside its functions.
    private struct CountResponse: Decodable { let count: Int }
    private struct CompletionResponse: Decodable {
        let isCompleted: Bool
        let completedAt: Date?
    }
    private struct AssignResponse: Decodable { let trainingIds: [UUID] }
    // BodyMeasurement.loadMine()
    private struct MeasurementResponse: Decodable {
        let id: UUID
        let height, weight, shoulders, chest, upperArm, waist, thigh, calves, glutes: Decimal
        let createdAt: Date
    }

    private static func check<T: Decodable>(_ type: T.Type, _ path: String, method: String = "GET",
                                            as role: Role, body: Data? = nil) -> DecodingCheck {
        DecodingCheck(method: method, path: path, role: role, body: body) { data in
            _ = try APIClient.decoder.decode(T.self, from: data)
        }
    }

    private static func jsonBody(_ object: JSON) -> Data? {
        try? JSONSerialization.data(withJSONObject: object)
    }

    /// Every GET the screens make and the changes whose answers are decoded,
    /// with the exact types the app decodes them into.
    static let decodingChecks: [DecodingCheck] = {
        let ana = anaClientId.uuidString
        let marko = clientId(ClientIndex.marko).uuidString
        let conversation = anaConversationId.uuidString
        let bench = id(.workout, WorkoutNumber.bench)
        let training = id(.training, 7).uuidString

        let trainingBody = try? JSONEncoder().encode(SaveTrainingRequest(
            client: anaClientId,
            name: "Upper Body Strength",
            date: ISO8601DateFormatter().string(from: Date()),
            note: nil,
            isCompleted: false,
            exercises: [
                SaveTrainingRequest.Exercise(
                    workout: bench, note: "Pause on the chest.",
                    sets: [SaveTrainingRequest.ExerciseSet(reps: "8", weight: 65),
                           SaveTrainingRequest.ExerciseSet(reps: "10", weight: 50, isDropSet: true)],
                    isSupersetWithPrevious: false
                )
            ]
        ))
        let templateBody = try? JSONEncoder().encode(SaveTrainingTemplateRequest(
            name: "Upper Body Strength", note: nil,
            exercises: [SaveTrainingRequest.Exercise(workout: bench, note: nil,
                                                     sets: [SaveTrainingRequest.ExerciseSet(reps: "8", weight: nil)],
                                                     isSupersetWithPrevious: false)]
        ))
        let workoutBody = try? JSONEncoder().encode(UpdateWorkoutRequest(
            name: LocalizedText(translations: ["EN": "Bench Press", "HR": "Potisak s ravne klupe"]),
            description: LocalizedText(translations: ["EN": "Press.", "HR": "Potisak."]),
            thumbnailUrl: "", videoUrl: "",
            workoutTypes: [id(.workoutType, 1)],
            muscles: ["chest"], secondaryMuscles: ["triceps"]
        ))
        let goalBody = try? JSONEncoder().encode(ClientGoal(goal: "Bench press 80 kg", nextAssessmentDate: Date()))
        let profileBody = try? JSONEncoder().encode(UpdateProfileRequest(
            email: "ana.kovac@example.com", firstName: "Ana", lastName: "Kovač", phone: "+385 91 555 0123"
        ))
        let clientBody = try? JSONEncoder().encode(Client(
            id: clientId(ClientIndex.marko), firstName: "Marko", lastName: "Horvat", credits: 12,
            lastCreditsIncrease: Date(), plan: "OnlineCoaching"
        ))

        return [
            // Client
            check(Profile.self, "profile", as: .client),
            check(UserProfile.self, "clients/current-client", as: .client),
            check(Client.self, "clients/current-client", as: .client),
            check(AppointmentsStatus.self, "appointments", as: .client),
            check(ClientGoal.self, "client-goals/my", as: .client),
            check([MonthlyReview].self, "monthly-reviews", as: .client),
            check([PersonalRecord].self, "personal-records", as: .client),
            check([MeasurementResponse].self, "body-measurements", as: .client),
            check([Training].self, "trainings", as: .client),
            check([Workout].self, "workouts", as: .client),
            check(Workout.self, "workouts/\(bench.uuidString)", as: .client),
            check([FunctionalMovementScreen].self, "functional-movement-screens", as: .client),
            check([AppNotification].self, "notifications", as: .client),
            check(CountResponse.self, "notifications/unread-count", as: .client),
            check([SentAppointmentRequest].self, "appointment-requests", as: .client),
            check([MyAppointmentRequest].self, "appointments/my-requests", as: .client),
            check([Coach].self, "coaches/client", as: .client),
            check([CatalogData].self, "appointment-types", as: .client),
            check([TimeSlot].self, "time-slots/available", method: "POST", as: .client,
                  body: jsonBody(["coaches": [coachId.uuidString], "day": "2026-10-21"])),
            check(StatusResponse.self, "appointments", method: "POST", as: .client, body: jsonBody([:])),
            check(StatusResponse.self, "appointment-requests/join/\(id(.appointment, 21).uuidString)", as: .client),
            check([ChatConversation].self, "chat/conversations", as: .client),
            check([ChatMessage].self, "chat/conversations/\(conversation)/messages?take=50", as: .client),
            check([ChatContact].self, "chat/contacts", as: .client),
            check(CountResponse.self, "chat/unread-count", as: .client),
            check(ChatConversation.self, "chat/conversations/start", method: "POST", as: .client,
                  body: jsonBody(["coachId": coachId.uuidString])),
            check(ChatConversation.self, "chat/conversations/\(conversation)/block", method: "POST", as: .client,
                  body: jsonBody(["isBlocked": false])),
            check(ChatMessage.self, "chat/conversations/\(conversation)/messages", method: "POST", as: .client,
                  body: jsonBody(["content": "See you tomorrow!"])),
            check(ChatMessage.self, "chat/conversations/\(conversation)/images", method: "POST", as: .client),
            check(Profile.self, "profile", method: "PUT", as: .client, body: profileBody),

            // Coach
            check(Profile.self, "profile", as: .coach),
            check(Coach.self, "coaches/current-coach", as: .coach),
            check([Coach].self, "coaches/all", as: .coach),
            check([Client].self, "clients", as: .coach),
            check(Client.self, "clients/\(marko)", method: "PUT", as: .coach, body: clientBody),
            check(AppointmentsStatus.self, "appointments", as: .coach),
            check([AppointmentRequest].self, "appointment-requests/pending", as: .coach),
            check(StatusResponse.self, "appointments/approve/\(id(.appointment, 3).uuidString)", as: .coach),
            check(StatusResponse.self, "appointment-requests/approve/\(id(.request, 10).uuidString)", as: .coach),
            check(Int.self, "recurring-appointments/generate-next-week", as: .coach),
            check([Training].self, "trainings", as: .coach),
            check(Training.self, "trainings", method: "POST", as: .coach, body: trainingBody),
            check(Training.self, "trainings/\(training)", method: "PUT", as: .coach, body: trainingBody),
            check(CompletionResponse.self, "trainings/\(training)/completion", method: "PUT", as: .coach,
                  body: jsonBody(["isCompleted": true])),
            check([TrainingTemplate].self, "training-templates", as: .coach),
            check(TrainingTemplate.self, "training-templates", method: "POST", as: .coach, body: templateBody),
            check(AssignResponse.self, "training-templates/\(id(.template, 90).uuidString)/assign", method: "POST",
                  as: .coach, body: jsonBody(["clients": [ana, marko], "date": "2026-10-21T16:00:00Z", "notifyClient": true])),
            check([WorkoutType].self, "workout-types", as: .coach),
            check([Workout].self, "workouts", as: .coach),
            check(Workout.self, "workouts/\(bench.uuidString)", method: "PUT", as: .coach, body: workoutBody),
            check(ImportWorkoutsResponse.self, "workouts/import", method: "POST", as: .coach),
            check(ClientGoal.self, "client-goals/\(ana)", as: .coach),
            check(ClientGoal.self, "client-goals/\(marko)", as: .coach),
            check(ClientGoal.self, "client-goals/\(ana)", method: "PUT", as: .coach, body: goalBody),
            check([MonthlyReview].self, "monthly-reviews?clientId=\(ana)", as: .coach),
            check([MonthlyReview].self, "monthly-reviews?clientId=\(marko)", as: .coach),
            check(MonthlyReview.self, "monthly-reviews", method: "PUT", as: .coach,
                  body: jsonBody(["client": ana, "year": 2026, "month": 9, "content": "Great month!", "notifyClient": true])),
            check([PersonalRecord].self, "personal-records?clientId=\(ana)", as: .coach),
            check([FunctionalMovementScreen].self, "functional-movement-screens", as: .coach),
            check(StatusResponse.self, "body-measurements", method: "POST", as: .coach, body: jsonBody(["client": ana])),
            check([ChatConversation].self, "chat/conversations", as: .coach),
            check([ChatMessage].self, "chat/conversations/\(conversation)/messages?take=50", as: .coach),
            check([ChatContact].self, "chat/contacts", as: .coach),
            check(ChatConversation.self, "chat/conversations", method: "POST", as: .coach,
                  body: jsonBody(["clientId": clientId(ClientIndex.tomislav).uuidString, "isEnabled": true])),
            check(ChatMessage.self, "chat/conversations/\(conversation)/messages", method: "POST", as: .coach,
                  body: jsonBody(["content": "", "workoutId": id(.workout, WorkoutNumber.romanianDeadlift).uuidString])),
            check([AppNotification].self, "notifications", as: .coach),
            check(CountResponse.self, "notifications/unread-count", as: .coach)
        ]
    }()
}
#endif
