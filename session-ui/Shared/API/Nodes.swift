import Foundation
import AnyCodable

public enum NodesError: Error {
  case invalidResponse
}

class URLSessionDelegateImplementation: NSObject, URLSessionDelegate {
  func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    // Snode to snode communication uses self-signed certificates but clients can safely ignore this
    completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
  }
}

public class SeedNodes {
  private struct RequestParams: Codable {
    let fields: Fields
  }
  
  private struct Fields: Codable {
    let public_ip, storage_port, pubkey_x25519, pubkey_ed25519: Bool
  }
  
  private struct RequestBody: Codable {
    let jsonrpc: String
    let method: String
    let params: RequestParams
  }
  
  private struct Result: Codable {
    let service_node_states: [ServiceNodeState]
  }
  
  private struct ServiceNodeState: Codable {
    let public_ip: String
    let storage_port: Int
  }
  
  public static func getSnodes() async throws -> [ServiceNode] {
    let seedIp = "116.203.53.213" // => seed1.getsession.org
    let url = URL(string: "https://" + seedIp + "/json_rpc")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("WhatsApp", forHTTPHeaderField: "User-Agent") // tradition: https://github.com/oxen-io/session-desktop/blob/48a245e13c3b9f99da93fc8fe79dfd5019cd1f0a/ts/session/apis/seed_node_api/SeedNodeAPI.ts#L259
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let requestBody = RequestBody(
      jsonrpc: "2.0",
      method: "get_n_service_nodes",
      params: RequestParams(fields: Fields(
        public_ip: true,
        storage_port: true,
        pubkey_x25519: true,
        pubkey_ed25519: true))
    )
    
    let jsonData = try JSONEncoder().encode(requestBody)
    
    request.httpBody = jsonData
    
    let session = URLSession(configuration: .default, delegate: URLSessionDelegateImplementation(), delegateQueue: nil)
    let (data, _) = try await session.data(for: request)

    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw NodesError.invalidResponse
    }
    
    if let error = json["error"] {
      print(error)
      throw NodesError.invalidResponse
    }
    
    guard let result = json["result"] as? [String: Any] else {
      throw NodesError.invalidResponse
    }
    
    guard let snodes = result["service_node_states"] as? [[String: Any]] else {
      throw NodesError.invalidResponse
    }
    
    return try snodes.map { n in
      guard let ip = n["public_ip"] as? String,
            let port = n["storage_port"] as? Int else {
        throw NodesError.invalidResponse
      }
      return ServiceNode(ip: ip, port: port)
    }
  }
}


public class ServiceNode {
  public var ip: String
  public var port: Int
  
  private struct RequestParams: Codable {
    let pubkey: String
  }
  
  private struct RequestBody: Codable {
    let jsonrpc: String
    let method: String
    let params: RequestParams
  }
  
  private struct SwarmState: Codable {
    let ip: String
    let port: String
  }
  
  init(ip: String, port: Int) {
    self.ip = ip
    self.port = port
  }
  
  public func getSwarmsFor(pubkey: String) async throws -> [Swarm] {
    let url = URL(string: "https://" + self.ip + ":" + String(self.port) + "/storage_rpc/v1")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("WhatsApp", forHTTPHeaderField: "User-Agent") // tradition: https://github.com/oxen-io/session-desktop/blob/48a245e13c3b9f99da93fc8fe79dfd5019cd1f0a/ts/session/apis/seed_node_api/SeedNodeAPI.ts#L259
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let requestBody = RequestBody(
      jsonrpc: "2.0",
      method: "get_swarm",
      params: RequestParams(pubkey: pubkey)
    )
    
    let jsonData = try JSONEncoder().encode(requestBody)
    request.httpBody = jsonData
    
    let session = URLSession(configuration: .default, delegate: URLSessionDelegateImplementation(), delegateQueue: nil)
    let (data, _) = try await session.data(for: request)
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      print("Error from snode:", String(decoding: data, as: UTF8.self))
      throw NodesError.invalidResponse
    }
    
    if let error = json["error"] {
      print("Error from snode:", error)
      throw NodesError.invalidResponse
    }
    
    guard let swarms = json["snodes"] as? [[String: Any]] else {
      throw NodesError.invalidResponse
    }
    
    return try swarms.map { n in
      guard let ip = n["ip"] as? String,
            let port = n["port"] as? String,
            let portNumeric = Int(port) else {
        throw NodesError.invalidResponse
      }
      return Swarm(ip: ip, port: portNumeric)
    }
  }
}

public class Swarm {
  public var ip: String
  public var port: Int
  
  init(ip: String, port: Int) {
    self.ip = ip
    self.port = port
  }
  
  private func sendRequest(method: AnyEncodable, params: AnyEncodable) async throws -> [String: Any] {
    let url = URL(string: "https://" + self.ip + ":" + String(self.port) + "/storage_rpc/v1")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("WhatsApp", forHTTPHeaderField: "User-Agent") // tradition: https://github.com/oxen-io/session-desktop/blob/48a245e13c3b9f99da93fc8fe79dfd5019cd1f0a/ts/session/apis/seed_node_api/SeedNodeAPI.ts#L259
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let body: [String: AnyEncodable] = [
      "jsonrpc": "2.0",
      "method": method,
      "params": params
    ]
    
    let jsonData = try JSONEncoder().encode(body)
    request.httpBody = jsonData
    
    let session = URLSession(configuration: .default, delegate: URLSessionDelegateImplementation(), delegateQueue: nil)
    let (data, _) = try await session.data(for: request)
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      print("Error from swarm:", String(decoding: data, as: UTF8.self))
      throw NodesError.invalidResponse
    }
    
    if let error = json["error"] {
      print("Error from swarm:", error)
      throw NodesError.invalidResponse
    }
    
    return json
  }
  
  public func storeMessage(data: String, pubkey: String, timestamp: Int, ttl: Int) async throws -> [String: Any] {
    let response = try await sendRequest(method: "store", params: [
      "data": data,
      "pubkey": pubkey,
      "timestamp": timestamp,
      "ttl": ttl
    ])
    return response
  }
}
