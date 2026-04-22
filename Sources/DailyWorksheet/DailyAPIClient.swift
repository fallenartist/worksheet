import Foundation

enum DailyAPIError: Error, LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case serverStatus(Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add your Daily API key in Settings first."
        case .invalidURL:
            return "The Daily API URL could not be built."
        case .invalidResponse:
            return "Daily returned an unexpected response."
        case .serverStatus(let status):
            return "Daily returned HTTP \(status)."
        }
    }
}

final class DailyAPIClient {
    private let baseURL = URL(string: "https://api.dailytimetracking.com")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchUser(apiKey: String, completion: @escaping (Result<DailyUserResponse, Error>) -> Void) {
        request(path: "/user", apiKey: apiKey, queryItems: [], completion: completion)
    }

    func fetchTimesheet(start: Date, end: Date, apiKey: String, completion: @escaping (Result<[DailyTimesheetDay], Error>) -> Void) {
        request(
            path: "/timesheet",
            apiKey: apiKey,
            queryItems: [
                URLQueryItem(name: "start", value: Formatters.apiDay.string(from: start)),
                URLQueryItem(name: "end", value: Formatters.apiDay.string(from: end)),
                URLQueryItem(name: "includeArchivedActivities", value: "true")
            ],
            completion: completion
        )
    }

    private func request<T: Decodable>(
        path: String,
        apiKey: String,
        queryItems: [URLQueryItem],
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        guard apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            completion(.failure(DailyAPIError.missingAPIKey))
            return
        }

        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            completion(.failure(DailyAPIError.invalidURL))
            return
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            completion(.failure(DailyAPIError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "API-Key")

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(.failure(DailyAPIError.invalidResponse)) }
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                DispatchQueue.main.async { completion(.failure(DailyAPIError.serverStatus(httpResponse.statusCode))) }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(DailyAPIError.invalidResponse)) }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                DispatchQueue.main.async { completion(.success(decoded)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }
}
