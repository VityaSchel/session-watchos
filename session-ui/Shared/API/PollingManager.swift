import Foundation
import Combine
import CoreData

class PollingManager: ObservableObject {
  var accountContext: AccountContext
  var messagesReceiver: MessagesReceiver
  private var cancellables: Set<AnyCancellable> = []
  private var pollCancellable: AnyCancellable?
  
  init(accountContext: AccountContext, context: NSManagedObjectContext) async throws {
    self.accountContext = accountContext
    guard let seedData = KeychainHelper.load(key: "mnemonic") else {
      throw MessagesReceiverError.noMnemonic
    }
    self.messagesReceiver = try await MessagesReceiver(seed: seedData, context: context)
    setupSubscribers()
  }
  
  private func setupSubscribers() {
    accountContext.$authorized
      .receive(on: RunLoop.main)
      .sink { [weak self] authorized in
        if authorized {
          print("User is authorized, start polling")
          self?.startPolling()
        } else {
          print("User is not authorized, pause polling")
          self?.stopPolling()
        }
      }
      .store(in: &cancellables)
  }
  
  public func startPolling() {
    pollOnceAndScheduleNext()
  }
  
  public func stopPolling() {
    print("Stopping polling")
    pollCancellable?.cancel()
  }
  
  private func pollOnceAndScheduleNext() {
    Task {
      let startTime = Date()
      
      let _ = try await self.messagesReceiver.poll()
      
      let executionTime = Date().timeIntervalSince(startTime)
      let delay = max(0, 5 - executionTime)
      
      pollCancellable = Just(())
        .delay(for: .seconds(delay), scheduler: RunLoop.main)
        .sink { [weak self] in
          self?.pollOnceAndScheduleNext()
        }
    }
  }
}
