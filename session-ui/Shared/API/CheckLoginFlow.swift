import Foundation

struct APICheckLoginFlowSuccessResponse: Decodable {
    let ok: Bool
    let result: String?
}

struct APICheckLoginFlowErrorResponse: Decodable {
    let ok: Bool
    let error: String
}

enum APICheckLoginFlowServerResponse {
    case success(APICheckLoginFlowSuccessResponse)
    case failure(APICheckLoginFlowErrorResponse)
}

extension APICheckLoginFlowServerResponse: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let successResponse = try? container.decode(APICheckLoginFlowSuccessResponse.self) {
            self = .success(successResponse)
        } else if let errorResponse = try? container.decode(APICheckLoginFlowErrorResponse.self) {
            self = .failure(errorResponse)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode response")
        }
    }
}

func APICheckLoginFlow(flowID: String, completion: @escaping (Result<String?, Error>) -> Void) {
  let urlString =  ApiUrl + "/api/login-flow-result/" + flowID
  guard let url = URL(string: urlString) else {
      completion(.failure(URLError(.badURL)))
      return
  }

  let task = URLSession.shared.dataTask(with: url) { data, response, error in
      if let error = error {
          completion(.failure(error))
          return
      }

      guard let data = data else {
          completion(.failure(URLError(.cannotDecodeRawData)))
          return
      }

      do {
          let decoder = JSONDecoder()
          let serverResponse = try decoder.decode(APICheckLoginFlowServerResponse.self, from: data)
          
          switch serverResponse {
          case .success(let successResponse):
            completion(.success(successResponse.result))
          case .failure(let errorResponse):
              completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: errorResponse.error])))
          }
      } catch {
          completion(.failure(error))
      }
  }

  task.resume()
}
