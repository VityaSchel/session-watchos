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
  
  do { try context.save() } catch {}
}

func putMessagesMocks(into context: NSManagedObjectContext) {
  let msg1 = Message()
  msg1.textContent = "Hi!"
  msg1.isIncoming = true
  
  let msg2 = Message()
  msg2.textContent = "hey"
  msg1.isIncoming = false
  
  let msg3 = Message()
  msg3.textContent = "What's up?"
  msg1.isIncoming = true
  
  let msg4 = Message()
  msg4.textContent = "quantum electrodynamics is the relativistic quantum field theory of electrodynamics; in essence, it describes how light and matter interact and is the first theory where full agreement between quantum mechanics and special relativity is achieved"
  msg4.isIncoming = false
  
  let msg5 = Message()
  msg5.textContent = "oh, i see, you're in depression again 💀"
  msg5.isIncoming = true
  
  do { try context.save() } catch {}
}
