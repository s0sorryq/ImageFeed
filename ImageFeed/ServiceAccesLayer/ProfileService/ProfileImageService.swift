import Foundation

struct UserResult: Decodable {
    let profileImage: ProfileImage

    private enum CodingKeys: String, CodingKey {
        case profileImage = "profile_image"
    }
}

struct ProfileImage: Decodable {
    let small: String
}

final class ProfileImageService {
    
    static let shared = ProfileImageService()
    static let didChangeNotification = Notification.Name(rawValue: "ProfileImageProviderDidChange")
    
    private init() {}
    
    private let urlSession = URLSession.shared
    private var task: URLSessionTask?
    private var lastUsername: String?
    
    private(set) var avatarURL: String?
    
    func fetchProfileImageURL(
        username: String,
        _ completion: @escaping (Result<String, Error>) -> Void
    ) {
        if task != nil, lastUsername == username {
            return
        }
        
        task?.cancel()
        lastUsername = username
        
        guard let request = makeProfileImageRequest(username: username) else {
            print("[ProfileImageService] Failed to create request")
            lastUsername = nil
            DispatchQueue.main.async {
                completion(.failure(NetworkError.invalidRequest))
            }
            return
        }
        
        let task = urlSession.objectTask(for: request) { [weak self] (result: Result<UserResult, Error>) in
            guard let self else { return }
            
            guard self.lastUsername == username else { return }
            
            self.task = nil
            self.lastUsername = nil
            
            switch result {
            case .success(let userResult):
                let profileImageURL = userResult.profileImage.small
                
                self.avatarURL = profileImageURL
                completion(.success(profileImageURL))
                
                NotificationCenter.default.post(
                    name: ProfileImageService.didChangeNotification,
                    object: self,
                    userInfo: ["URL": profileImageURL]
                )
                
            case .failure(let error):
                if (error as NSError).code == NSURLErrorCancelled {
                    return
                }
                print("[ProfileImageService] Error: \(error)")
                completion(.failure(error))
            }
        }
        
        self.task = task
        task.resume()
    }
    
    private func makeProfileImageRequest(username: String) -> URLRequest? {
        guard
            let token = OAuth2TokenStorage.shared.token,
            let url = URL(string: Constants.defaultBaseURLString + "/users/\(username)")
        else {
            print("[ProfileImageService] Failed to create URL or get token")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}
