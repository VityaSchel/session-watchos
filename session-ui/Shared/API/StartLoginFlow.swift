//
//  start-login-flow.swift
//  session-ui
//
//  Created by Виктор Щелочков on 16.03.2024.
//

import Foundation

struct APIStartLoginFlowSuccessResponse: Decodable {
    let ok: Bool
    let flowID: String
}

struct APIStartLoginFlowErrorResponse: Decodable {
    let ok: Bool
    let error: String
}

enum APIStartLoginFlowServerResponse {
    case success(APIStartLoginFlowSuccessResponse)
    case failure(APIStartLoginFlowErrorResponse)
}

extension APIStartLoginFlowServerResponse: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let successResponse = try? container.decode(APIStartLoginFlowSuccessResponse.self) {
            self = .success(successResponse)
        } else if let errorResponse = try? container.decode(APIStartLoginFlowErrorResponse.self) {
            self = .failure(errorResponse)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode response")
        }
    }
}

func APIStartLoginFlow(completion: @escaping (Result<String, Error>) -> Void) {
  let urlString =  ApiUrl + "/api/start-login-flow"
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
          let serverResponse = try decoder.decode(APIStartLoginFlowServerResponse.self, from: data)
          
          switch serverResponse {
          case .success(let successResponse):
              completion(.success(successResponse.flowID))
          case .failure(let errorResponse):
              completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: errorResponse.error])))
          }
      } catch {
          completion(.failure(error))
      }
  }

  task.resume()
}
