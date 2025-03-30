import Foundation
import FirebaseAuth

class AuthService {
    static let shared = AuthService()
    
    private init() {}
    
    // Register a new user using email and password.
    func registerUser(email: String, password: String, completion: @escaping (Result<AuthDataResult, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            if let result = authResult {
                completion(.success(result))
            }
        }
    }
    
    // Login an existing user using email and password.
    func loginUser(email: String, password: String, completion: @escaping (Result<AuthDataResult, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            if let result = authResult {
                completion(.success(result))
            }
        }
    }
    
    // Sign out the current user.
    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    // Check if a user is currently logged in.
    func isUserLoggedIn() -> Bool {
        return Auth.auth().currentUser != nil
    }
}
