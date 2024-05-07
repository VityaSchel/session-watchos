class ProtoBuilder {
  private var sender: LokiProfile?
  
  init(sender: LokiProfile?) {
    self.sender = sender
  }
  
  public func visibleMessage(_ message: Message) -> SNProtoContent? {
    let proto = SNProtoContent.builder()
    
//    var attachmentIds: [String] = message.attachmentIds
    let dataMessage: SNProtoDataMessage.SNProtoDataMessageBuilder
    
    // Profile
    if let profile = sender, let profileProto: SNProtoDataMessage = profile.toProto() {
      dataMessage = profileProto.asBuilder()
    }
    else {
      dataMessage = SNProtoDataMessage.builder()
    }
    
    // Text
    if let text = message.textContent { dataMessage.setBody(text) }
    
    // Quote
//    if let quotedAttachmentId = message.quote?.attachmentId, let index = attachmentIds.firstIndex(of: quotedAttachmentId) {
//      attachmentIds.remove(at: index)
//    }
    
//    if let quote = quote, let quoteProto = quote.toProto(db) {
//      dataMessage.setQuote(quoteProto)
//    }
    
    // Link preview
//    if let linkPreviewAttachmentId = linkPreview?.attachmentId, let index = attachmentIds.firstIndex(of: linkPreviewAttachmentId) {
//      attachmentIds.remove(at: index)
//    }
    
//    if let linkPreview = linkPreview, let linkPreviewProto = linkPreview.toProto(db) {
//      dataMessage.setPreview([ linkPreviewProto ])
//    }
    
    // Attachments
//    let attachmentIdIndexes: [String: Int] = (try? InteractionAttachment
//      .filter(self.attachmentIds.contains(InteractionAttachment.Columns.attachmentId))
//      .fetchAll(db))
//      .defaulting(to: [])
//      .reduce(into: [:]) { result, next in result[next.attachmentId] = next.albumIndex }
//    let attachments: [Attachment] = (try? Attachment.fetchAll(db, ids: self.attachmentIds))
//      .defaulting(to: [])
//      .sorted { lhs, rhs in (attachmentIdIndexes[lhs.id] ?? 0) < (attachmentIdIndexes[rhs.id] ?? 0) }
    let attachmentProtos: [SNProtoAttachmentPointer] = []//attachments.compactMap { $0.buildProto() }
    dataMessage.setAttachments(attachmentProtos)
    
    // Open group invitation
//    if
//      let openGroupInvitation = openGroupInvitation,
//      let openGroupInvitationProto = openGroupInvitation.toProto()
//    {
//      dataMessage.setOpenGroupInvitation(openGroupInvitationProto)
//    }
    
    // Emoji react
//    if let reaction = reaction, let reactionProto = reaction.toProto() {
//      dataMessage.setReaction(reactionProto)
//    }
    
    // DisappearingMessagesConfiguration
//    setDisappearingMessagesConfigurationIfNeeded(on: proto)
    
    // Sync target
    if let syncTarget = message.syncTarget {
      dataMessage.setSyncTarget(syncTarget)
    }
    
    // Build
    do {
      proto.setDataMessage(try dataMessage.build())
      return try proto.build()
    } catch {
      print("Couldn't construct visible message proto from: \(self).")
      return nil
    }
  }
  
  public func syncMessage(_ message: Message, recipient: String) -> SNProtoContent? {
    let proto = SNProtoContent.builder()
    
//    var attachmentIds: [String] = message.attachmentIds
    let dataSyncMessage: SNProtoDataMessage.SNProtoDataMessageBuilder
    
    dataSyncMessage = SNProtoDataMessage.builder()
    
    // Text
    if let text = message.textContent { dataSyncMessage.setBody(text) }
    
    // Quote
//    if let quotedAttachmentId = message.quote?.attachmentId, let index = attachmentIds.firstIndex(of: quotedAttachmentId) {
//      attachmentIds.remove(at: index)
//    }
    
//    if let quote = quote, let quoteProto = quote.toProto(db) {
//      dataMessage.setQuote(quoteProto)
//    }
    
    // Link preview
//    if let linkPreviewAttachmentId = linkPreview?.attachmentId, let index = attachmentIds.firstIndex(of: linkPreviewAttachmentId) {
//      attachmentIds.remove(at: index)
//    }
    
//    if let linkPreview = linkPreview, let linkPreviewProto = linkPreview.toProto(db) {
//      dataMessage.setPreview([ linkPreviewProto ])
//    }
    
    // Attachments
//    let attachmentIdIndexes: [String: Int] = (try? InteractionAttachment
//      .filter(self.attachmentIds.contains(InteractionAttachment.Columns.attachmentId))
//      .fetchAll(db))
//      .defaulting(to: [])
//      .reduce(into: [:]) { result, next in result[next.attachmentId] = next.albumIndex }
//    let attachments: [Attachment] = (try? Attachment.fetchAll(db, ids: self.attachmentIds))
//      .defaulting(to: [])
//      .sorted { lhs, rhs in (attachmentIdIndexes[lhs.id] ?? 0) < (attachmentIdIndexes[rhs.id] ?? 0) }
    let attachmentProtos: [SNProtoAttachmentPointer] = []//attachments.compactMap { $0.buildProto() }
    dataSyncMessage.setAttachments(attachmentProtos)
    
    // Open group invitation
//    if
//      let openGroupInvitation = openGroupInvitation,
//      let openGroupInvitationProto = openGroupInvitation.toProto()
//    {
//      dataMessage.setOpenGroupInvitation(openGroupInvitationProto)
//    }
    
    // Emoji react
//    if let reaction = reaction, let reactionProto = reaction.toProto() {
//      dataMessage.setReaction(reactionProto)
//    }
    
    // DisappearingMessagesConfiguration
//    setDisappearingMessagesConfigurationIfNeeded(on: proto)
    
    dataSyncMessage.setSyncTarget(recipient)
    
    // Build
    do {
      proto.setDataMessage(try dataSyncMessage.build())
      return try proto.build()
    } catch {
      print("Couldn't construct visible sycn message proto from: \(self).")
      return nil
    }
  }
}
