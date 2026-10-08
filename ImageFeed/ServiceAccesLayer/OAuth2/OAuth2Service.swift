import Foundation

enum NetworkError: Error {
    case httpStatusCode(Int)
    case urlRequestError(Error)
    case urlSessionError
    case invalidRequest
    case decodingError(Error)
}

final class OAuth2Service {
    static let shared = OAuth2Service()
    
    private init() {}
    
    private let urlSession = URLSession.shared
    private var task: URLSessionTask?
    
    func fetchOAuthToken(_ code: String, completion: @escaping (Result<String, Error>) -> Void) {
        assert(Thread.isMainThread)
        
        task?.cancel()
        
        guard let request = makeOAuthTokenRequest(code: code) else {
            print("[OAuth2Service] Failed to create URLRequest")
            DispatchQueue.main.async {
                completion(.failure(NetworkError.invalidRequest))
            }
            return
        }
        
        let task = urlSession.dataTask(with: request) { [weak self] data, response, error in
            defer { self?.task = nil }
            
            if let error = error {
                print("[OAuth2Service] Network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.urlRequestError(error)))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[OAuth2Service] Invalid response type")
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.urlSessionError))
                }
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("[OAuth2Service] HTTP error status code: \(httpResponse.statusCode)")
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.httpStatusCode(httpResponse.statusCode)))
                }
                return
            }
            
            guard let data = data else {
                print("[OAuth2Service] No data received")
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.urlSessionError))
                }
                return
            }
            
            do {
                let responseBody = try JSONDecoder().decode(OAuthTokenResponseBody.self, from: data)
                let accessToken = responseBody.accessToken
                
                DispatchQueue.main.async {
                    completion(.success(accessToken))
                }
            } catch {
                print("[OAuth2Service] Decoding error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.decodingError(error)))
                }
            }
        }
        
        self.task = task
        task.resume()
    }
    
    private func makeOAuthTokenRequest(code: String) -> URLRequest? {
        guard var urlComponents = URLComponents(string: "https://unsplash.com/oauth/token") else {
            print("[OAuth2Service] Failed to create URLComponents")
            return nil
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "client_id", value: Constants.accessKey),
            URLQueryItem(name: "client_secret", value: Constants.secretKey),
            URLQueryItem(name: "redirect_uri", value: Constants.redirectURI),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "grant_type", value: "authorization_code")
        ]
        
        guard let url = urlComponents.url else {
            print("[OAuth2Service] Failed to create URL from components")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        return request
    }
}
