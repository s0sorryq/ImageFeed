import Foundation

struct Profile {
    let username: String
    let name: String
    let loginName: String
    let bio: String?
}

struct ProfileResult: Decodable {
    let username: String
    let firstName: String?
    let lastName: String?
    let bio: String?

    private enum CodingKeys: String, CodingKey {
        case username
        case firstName = "first_name"
        case lastName = "last_name"
        case bio
    }
}

final class ProfileService {
    static let shared = ProfileService()
    
    private init() {}
    
    private var task: URLSessionTask?
    private let urlSession = URLSession.shared
    
    private(set) var profile: Profile?
    
    func fetchProfile(_ token: String, completion: @escaping (Result<Profile, Error>) -> Void) {
        task?.cancel()
        
        guard let request = makeProfileRequest(token: token) else {
            print("[ProfileService] Failed to create profile request")
            DispatchQueue.main.async {
                completion(.failure(NetworkError.invalidRequest))
            }
            return
        }
        
        let task = urlSession.objectTask(for: request) { [weak self] (result: Result<ProfileResult, Error>) in
            guard let self else { return }
            
            self.task = nil
            
            switch result {
            case .success(let profileResult):
                let fullName = [profileResult.firstName, profileResult.lastName]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                
                let profile = Profile(
                    username: profileResult.username,
                    name: fullName,
                    loginName: "@\(profileResult.username)",
                    bio: profileResult.bio
                )
                
                self.profile = profile
                completion(.success(profile))
                
            case .failure(let error):
                if (error as NSError).code == NSURLErrorCancelled {
                    return
                }
                print("[ProfileService] Error: \(error)")
                completion(.failure(error))
            }
        }
        
        self.task = task
        task.resume()
    }
    
    private func makeProfileRequest(token: String) -> URLRequest? {
        guard let url = URL(string: Constants.defaultBaseURLString + "/me") else {
            print("[ProfileService] Failed to create URL")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}
