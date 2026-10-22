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

    /// Picture of the chat's image message: meal prep boxes (drawn
    /// illustration, 600 × 733 JPEG).
    static let attachmentImage: (data: Data, width: Int, height: Int) = (
        data: Data(base64Encoded: mealPrepJPEG) ?? Data(),
        width: 600,
        height: 733
    )

    private static let mealPrepJPEG = "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kW0+rZz2LvcteqNUVGqcZLsOEXcyHyLafVs57F3uR5FtPq2c9i73LXqjVFRqnGS7DhF3Mh8i2n1bOexd7keRbT6tnPYu9y16o1RUapxkuw4RdzIfItp9WznsXe5HkW0+rZz2LvcteqNUVGqcZLsOEXcyHyLafVs57F3uR5FtPq2c9i73LXqjVFRqnGS7DhF3Mh8i2n1bOexd7keRbT6tnPYu9y16o1RUapxkuw4RdzIfItp9WznsXe5HkW0+rZz2LvcteqNUVGqcZLsOEXcyHyLafVs57F3uR5FtPq2c9i73LXqjVFRqnGS7DhF3Mh8i2n1bOexd7keRbT6tnPYu9y16o1RUapxkuw4RdzIxYlqOIaLOnM8h+RcP9l05LYe1pp35aGyUZWhMV1T6AFpOWqMtVi9ZL2RK0kV1ZxbE2YkrE/KQw6NMEUMWJvHYOb+fFdenBPy1RlquaUnJ2zpjFR5IZ6EehPy1RlqsSRnoR6E/LVGWqAZ6EehPy1RlqgGehCflqhAVvO4o87ipcTgjE4KQRedxR53FS4nBGJwQEXncUedxUuJwRicEBF53FHncVLicEYnBARedxR53FS4nBGJwQEXncUedxUuJwRicEBF53FHncVLicEYnBARedxR53FS4nBGJwQEXncUedxUuJwRicEBF53FHncVLicEYnBARedxR53FS4nBGJwQEXncUedxUuJwRicEBF53FHncVLicEYnBARedxR53FS4nBGJwQEXncUedxUuJwRicEBF53FHncVLicEYnBARedxR53FS4nBGJwQEXncUedxUuJwRicEBF53FHncVLicEYnBARedxR53FS4nBGJwQEXncUedxUuJwRicEBF53FHncVLicEYnBARedxR53FS4nBGJwQEXncUedxUuJwRicEBF53FHncVLicEYnBARedxR53FS4nBGJwQEXncUedxUuJwRicEBF53FHncVLicEYnBARedxR53FS4nBGJwQEXncUedxUuJwRicEBF53FHncVLicEYnBARedxR53FS4nBGJwQEXncUedxUuJwRicEBF53FHncVLicEYnBARedxR53FS4nBGJwQEXncUedxUuJwRicEBF53FHncVLicEYnBARedxQpcTghAJiHooxD0VLlojLRLFEWIeijEPRUuWiMtFFiiLEPRRiHoqXLRGWiWKIsQ9FGIeipctEZaJYoixD0UYh6Kly0RloliiLEPRRiHoqXLRGWiWKIsQ9FGIeipctEZaJYoixD0UYh6Kly0RloliiLEPRRiHoqXLRGWiWKIsQ9FGIeipctEZaJYoixD0UYh6Kly0RloliiLEPRRiHoqXLRGWiWKIsQ9FGIeipctEZaJYoixD0UYh6Kly0RloliiLEPRRiHoqXLRGWiWKIsQ9FGIeipctEZaJYoixD0UYh6Kly0RloliiLEPRRiHoqXLRGWiWKIsQ9FGIeipctEZaJYoixD0UYh6Kly0RloliiLEPRRiHoqXLRGWiWKIsQ9FGIeipctEZaJYoixD0UYh6Kly0RloliiLEPRRiHoqXLRGWiWKIsQ9FGIeipctEZaJYoixD0UYh6Kly0RloliiLEPRRiHoqXLRGWiWKIsQ9FGIeipctEZaJYoixD0UYh6Kly0RloliiLEPRRiHoqXLRGWiWKIsQ9FGIeipctEZaJYoixD0UYh6Kly0RloliiLEPRRiHoqXLRGWiWKIsQ9FGIeipctEZaJYoixD0UYh6Kly0RloliiLEPRRiHoqXLRGWiWKIsQ9FGIeipctEZaJYoixD0UKXLRCWKP/Z"

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
        // Longest plank, in seconds.
        for (offset, row) in [(3, 50.0), (5, 60.0)].enumerated() {
            records.append([
                "id": DemoAPI.id(.record, rows.count + offset + 1).uuidString,
                "clientId": DemoAPI.anaClientId.uuidString,
                "workoutId": DemoAPI.id(.workout, DemoAPI.WorkoutNumber.plank).uuidString,
                "workoutName": workoutName(DemoAPI.WorkoutNumber.plank),
                "trainingId": DemoAPI.id(.training, row.0).uuidString,
                "type": "LongestDuration",
                "value": row.1,
                "weight": 0,
                "reps": NSNull(),
                "achievedAt": iso(anaTrainingDate(row.0).addingTimeInterval(75 * 60))
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
            "secondaryMuscles": info.secondaryMuscles,
            // Plank sets record a duration.
            "isTimed": info.number == DemoAPI.WorkoutNumber.plank
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
                // "45 s" is a duration (plank), not repetitions.
                let duration = set.reps.hasSuffix(" s") ? Int(set.reps.dropLast(2)) : nil
                sets.append([
                    "id": DemoAPI.id(.exerciseSet, number * 10_000 + index * 100 + setIndex).uuidString,
                    "order": setIndex + 1,
                    "reps": duration == nil ? set.reps : NSNull(),
                    "weight": null(set.weight),
                    "isDropSet": set.isDropSet,
                    "durationSeconds": null(duration)
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
                    "isDropSet": set["isDropSet"] as? Bool ?? false,
                    "durationSeconds": null(set["durationSeconds"] as? NSNumber)
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
            "secondaryMuscles": input["secondaryMuscles"] as? [String] ?? [String](),
            "isTimed": input["isTimed"] as? Bool ?? false
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
            muscles: ["chest"], secondaryMuscles: ["triceps"], isTimed: false
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
