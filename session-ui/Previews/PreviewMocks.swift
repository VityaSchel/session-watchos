import CoreData

func putConversationsMocks(into context: NSManagedObjectContext) {
  let convo1 = DirectMessagesConversation(context: context)
  convo1.id = UUID()
  convo1.sessionID = "057aeb66e45660c3bdfb7c62706f6440226af43ec13f3b6f899c1dd4db1b8fce5b"
  convo1.displayName = "hloth"
  convo1.lastMessage = ConversationLastMessage(isIncoming: true, textContent: "Hi hloth!")
  
  let convo2 = DirectMessagesConversation(context: context)
  convo2.id = UUID()
  convo2.sessionID = "05d871fc80ca007eed9b2f4df72853e2a2d5465a92fcb1889fb5c84aa2833b3b40"
  convo2.displayName = "Kee Jef"
  
  let convo3 = DirectMessagesConversation(context: context)
  convo3.id = UUID()
  convo3.sessionID = "05fd79b286be86eab00d0e0aa3a4853603739628ba521ce204c69a2bacd42f1f3c"
  
  let convo4 = DirectMessagesConversation(context: context)
  convo4.id = UUID()
  convo4.displayName = "05fd79b286be86eab00d0e0aa3a4853603739628ba521ce204c69a2bacd42f1f3c"
  convo4.sessionID = "👀"
  convo4.lastMessage = ConversationLastMessage(isIncoming: false, textContent: "wassup?")
  
  do { try context.save() } catch {}
}

func putMessagesMocks(into context: NSManagedObjectContext, conversationId: UUID) {
  let msg1 = Message(context: context)
  msg1.id = UUID()
  msg1.conversation = conversationId
  msg1.textContent = "Hi!"
  msg1.isIncoming = true
  msg1.status = .Sent
  msg1.timestamp = Int64(Date().timeIntervalSince1970*1000)
  
  let msg2 = Message(context: context)
  msg2.id = UUID()
  msg2.conversation = conversationId
  msg2.textContent = "hey"
  msg2.isIncoming = false
  msg2.status = .Sent
  msg2.timestamp = Int64(Date().timeIntervalSince1970*1000) + 1
  
  let msg3 = Message(context: context)
  msg3.id = UUID()
  msg3.conversation = conversationId
  msg3.textContent = "What's up?"
  msg3.isIncoming = true
  msg3.status = .Sent
  msg3.timestamp = Int64(Date().timeIntervalSince1970*1000) + 2
  
  let msg4 = Message(context: context)
  msg4.id = UUID()
  msg4.conversation = conversationId
  msg4.textContent = "quantum electrodynamics is the relativistic quantum field theory of electrodynamics; in essence, it describes how light and matter interact and is the first theory where full agreement between quantum mechanics and special relativity is achieved"
  msg4.isIncoming = false
  msg4.status = .Sent
  msg4.timestamp = Int64(Date().timeIntervalSince1970*1000) + 3
  
  let msg5 = Message(context: context)
  msg5.id = UUID()
  msg5.conversation = conversationId
  msg5.textContent = "oh, i see, you're in depression again 💀"
  msg5.isIncoming = true
  msg5.status = .Sent
  msg5.timestamp = Int64(Date().timeIntervalSince1970*1000) + 4
  
  let msg6 = Message(context: context)
  msg6.id = UUID()
  msg6.conversation = conversationId
  msg6.textContent = "wait"
  msg6.isIncoming = false
  msg6.status = .Errored
  msg6.timestamp = Int64(Date().timeIntervalSince1970*1000) + 5
  
  let msg7 = Message(context: context)
  msg7.id = UUID()
  msg7.conversation = conversationId
  msg7.textContent = "shit"
  msg7.isIncoming = false
  msg7.status = .Sending
  msg7.timestamp = Int64(Date().timeIntervalSince1970*1000) + 6
  
  do { try context.save() } catch {}
}
