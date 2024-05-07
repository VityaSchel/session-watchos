import Foundation
import Combine
import CoreData

class PollingManager: ObservableObject {
  var accountContext: AccountContext
  var context: NSManagedObjectContext
  var messagesReceiver: MessagesReceiver?
  private var cancellables: Set<AnyCancellable> = []
  private var pollCancellable: AnyCancellable?
  
  init(accountContext: AccountContext, context: NSManagedObjectContext) async throws {
    self.accountContext = accountContext
    self.context = context
    setupSubscribers()
  }
  
  private func setupSubscribers() {
    accountContext.$authorized
      .receive(on: RunLoop.main)
      .sink { [weak self] authorized in
        if authorized {
          self?.startPolling()
        } else {
          self?.stopPolling()
        }
      }
      .store(in: &cancellables)
  }
  
  public func startPolling() {
    print("Start polling")
    pollOnceAndScheduleNext()
  }
  
  public func stopPolling() {
    print("Stopping polling")
    pollCancellable?.cancel()
  }
  
  private func pollOnceAndScheduleNext() {
    Task {
      let startTime = Date()
      
      if self.messagesReceiver != nil {} else {
        guard let seedData = KeychainHelper.load(key: "mnemonic") else {
          throw MessagesReceiverError.noMnemonic
        }
        self.messagesReceiver = try await MessagesReceiver(seed: seedData, context: self.context)
      }
      
      do {
        let _ = try await self.messagesReceiver!.poll()
      } catch let error {
        print("Error while polling", error)
      }
      
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
