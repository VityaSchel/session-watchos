// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import UIKit
import AVKit
import AVFoundation
import Combine
import CoreServices
import Photos
import PhotosUI
import Sodium
import GRDB
import SessionUIKit
import SessionMessagingKit
import SessionUtilitiesKit
import SignalUtilitiesKit
import SessionSnodeKit

extension ConversationVC:
    InputViewDelegate,
    MessageCellDelegate,
    ContextMenuActionDelegate,
    SendMediaNavDelegate,
    UIDocumentPickerDelegate,
    AttachmentApprovalViewControllerDelegate,
    GifPickerViewControllerDelegate
{
    // MARK: - Open Settings
    
    @objc func handleTitleViewTapped() {
        // Don't take the user to settings for unapproved threads
        guard viewModel.threadData.threadRequiresApproval == false else { return }

        openSettingsFromTitleView()
    }
    
    @objc func  openSettingsFromTitleView() {
        switch self.titleView.currentLabelType {
            case .userCount:
                if self.viewModel.threadData.threadVariant == .group || self.viewModel.threadData.threadVariant == .legacyGroup {
                    let viewController = EditClosedGroupVC(
                        threadId: self.viewModel.threadData.threadId,
                        threadVariant: self.viewModel.threadData.threadVariant
                    )
                    navigationController?.pushViewController(viewController, animated: true)
                } else {
                    openSettings()
                }
                break
            case .none, .notificationSettings:
                openSettings()
                break
            
            case .disappearingMessageSetting:
                let viewController = SessionTableViewController(
                    viewModel: ThreadDisappearingMessagesSettingsViewModel(
                        threadId: self.viewModel.threadData.threadId,
                        threadVariant: self.viewModel.threadData.threadVariant,
                        currentUserIsClosedGroupMember: self.viewModel.threadData.currentUserIsClosedGroupMember,
                        currentUserIsClosedGroupAdmin: self.viewModel.threadData.currentUserIsClosedGroupAdmin,
                        config: self.viewModel.threadData.disappearingMessagesConfiguration!
                    )
                )
                navigationController?.pushViewController(viewController, animated: true)
                break
        }
    }

    @objc func openSettings() {
        let viewController = SessionTableViewController(viewModel: ThreadSettingsViewModel(
                threadId: self.viewModel.threadData.threadId,
                threadVariant: self.viewModel.threadData.threadVariant,
                didTriggerSearch: { [weak self] in
                    DispatchQueue.main.async {
                        self?.showSearchUI()
                        self?.popAllConversationSettingsViews {
                            // Note: Without this delay the search bar doesn't show
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self?.searchController.uiSearchController.searchBar.becomeFirstResponder()
                            }
                        }
                    }
                }
            )
        )
        navigationController?.pushViewController(viewController, animated: true)
    }
    
    // MARK: - Call
    
    @objc func startCall(_ sender: Any?) {
        guard SessionCall.isEnabled else { return }
        guard viewModel.threadData.threadIsBlocked == false else { return }
        guard Storage.shared[.areCallsEnabled] else {
            let confirmationModal: ConfirmationModal = ConfirmationModal(
                info: ConfirmationModal.Info(
                    title: "modal_call_permission_request_title".localized(),
                    body: .text("modal_call_permission_request_explanation".localized()),
                    confirmTitle: "vc_settings_title".localized(),
                    confirmAccessibility: Accessibility(identifier: "Settings"),
                    dismissOnConfirm: false // Custom dismissal logic
                ) { [weak self] _ in
                    self?.dismiss(animated: true) {
                        let navController: UINavigationController = StyledNavigationController(
                            rootViewController: SessionTableViewController(
                                viewModel: PrivacySettingsViewModel(
                                    shouldShowCloseButton: true
                                )
                            )
                        )
                        navController.modalPresentationStyle = .fullScreen
                        self?.present(navController, animated: true, completion: nil)
                    }
                }
            )
            
            self.navigationController?.present(confirmationModal, animated: true, completion: nil)
            return
        }
        
        Permissions.requestMicrophonePermissionIfNeeded()
        
        let threadId: String = self.viewModel.threadData.threadId
        
        guard AVAudioSession.sharedInstance().recordPermission == .granted else { return }
        guard self.viewModel.threadData.threadVariant == .contact else { return }
        guard AppEnvironment.shared.callManager.currentCall == nil else { return }
        guard let call: SessionCall = Storage.shared.read({ db in SessionCall(db, for: threadId, uuid: UUID().uuidString.lowercased(), mode: .offer, outgoing: true) }) else {
            return
        }
        
        let callVC = CallVC(for: call)
        callVC.conversationVC = self
        hideInputAccessoryView()
        
        present(callVC, animated: true, completion: nil)
    }

    // MARK: - Blocking
    
    @objc func unblock() {
        self.showBlockedModalIfNeeded()
    }

    @discardableResult func showBlockedModalIfNeeded() -> Bool {
        guard
            self.viewModel.threadData.threadVariant == .contact &&
            self.viewModel.threadData.threadIsBlocked == true
        else { return false }
        
        let message = String(
            format: "modal_blocked_explanation".localized(),
            self.viewModel.threadData.displayName
        )
        let confirmationModal: ConfirmationModal = ConfirmationModal(
            info: ConfirmationModal.Info(
                title: String(
                    format: "modal_blocked_title".localized(),
                    self.viewModel.threadData.displayName
                ),
                body: .attributedText(
                    NSAttributedString(string: message)
                        .adding(
                            attributes: [ .font: UIFont.boldSystemFont(ofSize: Values.smallFontSize) ],
                            range: (message as NSString).range(of: self.viewModel.threadData.displayName)
                        )
                ),
                confirmTitle: "modal_blocked_button_title".localized(),
                confirmAccessibility: Accessibility(identifier: "Confirm block"),
                cancelAccessibility: Accessibility(identifier: "Cancel block"),
                dismissOnConfirm: false // Custom dismissal logic
            ) { [weak self] _ in
                self?.viewModel.unblockContact()
                self?.dismiss(animated: true, completion: nil)
            }
        )
        present(confirmationModal, animated: true, completion: nil)
        
        return true
    }

    // MARK: - SendMediaNavDelegate

    func sendMediaNavDidCancel(_ sendMediaNavigationController: SendMediaNavigationController?) {
        dismiss(animated: true, completion: nil)
    }

    func sendMediaNav(
        _ sendMediaNavigationController: SendMediaNavigationController,
        didApproveAttachments attachments: [SignalAttachment],
        forThreadId threadId: String,
        threadVariant: SessionThread.Variant,
        messageText: String?,
        using dependencies: Dependencies
    ) {
        sendMessage(text: (messageText ?? ""), attachments: attachments, using: dependencies)
        resetMentions()
        
        dismiss(animated: true) { [weak self] in
            if self?.isFirstResponder == false {
                self?.becomeFirstResponder()
            }
            else {
                self?.reloadInputViews()
            }
        }
    }

    func sendMediaNavInitialMessageText(_ sendMediaNavigationController: SendMediaNavigationController) -> String? {
        return snInputView.text
    }

    func sendMediaNav(_ sendMediaNavigationController: SendMediaNavigationController, didChangeMessageText newMessageText: String?) {
        snInputView.text = (newMessageText ?? "")
    }

    // MARK: - AttachmentApprovalViewControllerDelegate
    
    func attachmentApproval(
        _ attachmentApproval: AttachmentApprovalViewController,
        didApproveAttachments attachments: [SignalAttachment],
        forThreadId threadId: String,
        threadVariant: SessionThread.Variant,
        messageText: String?,
        using dependencies: Dependencies
    ) {
        sendMessage(text: (messageText ?? ""), attachments: attachments, using: dependencies)
        resetMentions()
        
        dismiss(animated: true) { [weak self] in
            if self?.isFirstResponder == false {
                self?.becomeFirstResponder()
            }
            else {
                self?.reloadInputViews()
            }
        }
    }

    func attachmentApprovalDidCancel(_ attachmentApproval: AttachmentApprovalViewController) {
        dismiss(animated: true, completion: nil)
    }

    func attachmentApproval(_ attachmentApproval: AttachmentApprovalViewController, didChangeMessageText newMessageText: String?) {
        snInputView.text = (newMessageText ?? "")
    }
    
    func attachmentApproval(_ attachmentApproval: AttachmentApprovalViewController, didRemoveAttachment attachment: SignalAttachment) {
    }

    func attachmentApprovalDidTapAddMore(_ attachmentApproval: AttachmentApprovalViewController) {
    }

    // MARK: - ExpandingAttachmentsButtonDelegate

    func handleGIFButtonTapped() {
        guard Storage.shared[.isGiphyEnabled] else {
            let modal: ConfirmationModal = ConfirmationModal(
                info: ConfirmationModal.Info(
                    title: "GIPHY_PERMISSION_TITLE".localized(),
                    body: .text("GIPHY_PERMISSION_MESSAGE".localized()),
                    confirmTitle: "continue_2".localized()
                ) { [weak self] _ in
                    Storage.shared.writeAsync(
                        updates: { db in
                            db[.isGiphyEnabled] = true
                        },
                        completion: { _, _ in
                            DispatchQueue.main.async {
                                self?.handleGIFButtonTapped()
                            }
                        }
                    )
                }
            )
            
            present(modal, animated: true, completion: nil)
            return
        }
        
        let gifVC = GifPickerViewController()
        gifVC.delegate = self
        
        let navController = StyledNavigationController(rootViewController: gifVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true) { }
    }

    func handleDocumentButtonTapped() {
        // UIDocumentPickerModeImport copies to a temp file within our container.
        // It uses more memory than "open" but lets us avoid working with security scoped URLs.
        let documentPickerVC = UIDocumentPickerViewController(documentTypes: [ kUTTypeItem as String ], in: UIDocumentPickerMode.import)
        documentPickerVC.delegate = self
        documentPickerVC.modalPresentationStyle = .fullScreen
        
        present(documentPickerVC, animated: true, completion: nil)
    }
    
    func handleLibraryButtonTapped() {
        let threadId: String = self.viewModel.threadData.threadId
        let threadVariant: SessionThread.Variant = self.viewModel.threadData.threadVariant
        
        Permissions.requestLibraryPermissionIfNeeded { [weak self] in
            DispatchQueue.main.async {
                let sendMediaNavController = SendMediaNavigationController.showingMediaLibraryFirst(
                    threadId: threadId,
                    threadVariant: threadVariant
                )
                sendMediaNavController.sendMediaNavDelegate = self
                sendMediaNavController.modalPresentationStyle = .fullScreen
                self?.present(sendMediaNavController, animated: true, completion: nil)
            }
        }
    }
    
    func handleCameraButtonTapped() {
        guard Permissions.requestCameraPermissionIfNeeded(presentingViewController: self) else { return }
        
        Permissions.requestMicrophonePermissionIfNeeded()
        
        if AVAudioSession.sharedInstance().recordPermission != .granted {
            SNLog("Proceeding without microphone access. Any recorded video will be silent.")
        }
        
        let sendMediaNavController = SendMediaNavigationController.showingCameraFirst(
            threadId: self.viewModel.threadData.threadId,
            threadVariant: self.viewModel.threadData.threadVariant
        )
        sendMediaNavController.sendMediaNavDelegate = self
        sendMediaNavController.modalPresentationStyle = .fullScreen
        
        present(sendMediaNavController, animated: true, completion: nil)
    }
    
    // MARK: - GifPickerViewControllerDelegate
    
    func gifPickerDidSelect(attachment: SignalAttachment) {
        showAttachmentApprovalDialog(for: [ attachment ])
    }
    
    // MARK: - UIDocumentPickerDelegate
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return } // TODO: Handle multiple?
        
        let urlResourceValues: URLResourceValues
        do {
            urlResourceValues = try url.resourceValues(forKeys: [ .typeIdentifierKey, .isDirectoryKey, .nameKey ])
        }
        catch {
            DispatchQueue.main.async { [weak self] in
                let modal: ConfirmationModal = ConfirmationModal(
                    targetView: self?.view,
                    info: ConfirmationModal.Info(
                        title: "Session",
                        body: .text("An error occurred."),
                        cancelTitle: "BUTTON_OK".localized(),
                        cancelStyle: .alert_text
                    )
                )
                self?.present(modal, animated: true)
            }
            return
        }
        
        let type = urlResourceValues.typeIdentifier ?? (kUTTypeData as String)
        guard urlResourceValues.isDirectory != true else {
            DispatchQueue.main.async { [weak self] in
                let modal: ConfirmationModal = ConfirmationModal(
                    targetView: self?.view,
                    info: ConfirmationModal.Info(
                        title: "ATTACHMENT_PICKER_DOCUMENTS_PICKED_DIRECTORY_FAILED_ALERT_TITLE".localized(),
                        body: .text("ATTACHMENT_PICKER_DOCUMENTS_PICKED_DIRECTORY_FAILED_ALERT_BODY".localized()),
                        cancelTitle: "BUTTON_OK".localized(),
                        cancelStyle: .alert_text
                    )
                )
                self?.present(modal, animated: true)
            }
            return
        }
        
        let fileName = urlResourceValues.name ?? NSLocalizedString("ATTACHMENT_DEFAULT_FILENAME", comment: "")
        guard let dataSource = DataSourcePath.dataSource(with: url, shouldDeleteOnDeallocation: false) else {
            DispatchQueue.main.async { [weak self] in
                let modal: ConfirmationModal = ConfirmationModal(
                    targetView: self?.view,
                    info: ConfirmationModal.Info(
                        title: "ATTACHMENT_PICKER_DOCUMENTS_FAILED_ALERT_TITLE".localized(),
                        cancelTitle: "BUTTON_OK".localized(),
                        cancelStyle: .alert_text
                    )
                )
                self?.present(modal, animated: true)
            }
            return
        }
        dataSource.sourceFilename = fileName
        
        // Although we want to be able to send higher quality attachments through the document picker
        // it's more imporant that we ensure the sent format is one all clients can accept (e.g. *not* quicktime .mov)
        guard !SignalAttachment.isInvalidVideo(dataSource: dataSource, dataUTI: type) else {
            return showAttachmentApprovalDialogAfterProcessingVideo(at: url, with: fileName)
        }
        
        // "Document picker" attachments _SHOULD NOT_ be resized
        let attachment = SignalAttachment.attachment(dataSource: dataSource, dataUTI: type, imageQuality: .original)
        showAttachmentApprovalDialog(for: [ attachment ])
    }

    func showAttachmentApprovalDialog(for attachments: [SignalAttachment]) {
        let navController = AttachmentApprovalViewController.wrappedInNavController(
            threadId: self.viewModel.threadData.threadId,
            threadVariant: self.viewModel.threadData.threadVariant,
            attachments: attachments,
            approvalDelegate: self
        )
        navController.modalPresentationStyle = .fullScreen
        
        present(navController, animated: true, completion: nil)
    }

    func showAttachmentApprovalDialogAfterProcessingVideo(at url: URL, with fileName: String) {
        ModalActivityIndicatorViewController.present(fromViewController: self, canCancel: true, message: nil) { [weak self] modalActivityIndicator in
            let dataSource = DataSourcePath.dataSource(with: url, shouldDeleteOnDeallocation: false)!
            dataSource.sourceFilename = fileName
            
            SignalAttachment
                .compressVideoAsMp4(
                    dataSource: dataSource,
                    dataUTI: kUTTypeMPEG4 as String
                )
                .attachmentPublisher
                .sinkUntilComplete(
                    receiveValue: { [weak self] attachment in
                        guard !modalActivityIndicator.wasCancelled else { return }
                        
                        modalActivityIndicator.dismiss {
                            guard !attachment.hasError else {
                                self?.showErrorAlert(for: attachment)
                                return
                            }
                            
                            self?.showAttachmentApprovalDialog(for: [ attachment ])
                        }
                    }
                )
        }
    }
    
    // MARK: - InputViewDelegate

    // MARK: --Message Sending
    
    func handleSendButtonTapped() {
        sendMessage(
            text: snInputView.text.trimmingCharacters(in: .whitespacesAndNewlines),
            linkPreviewDraft: snInputView.linkPreviewInfo?.draft,
            quoteModel: snInputView.quoteDraftInfo?.model
        )
    }

    func sendMessage(
        text: String,
        attachments: [SignalAttachment] = [],
        linkPreviewDraft: LinkPreviewDraft? = nil,
        quoteModel: QuotedReplyModel? = nil,
        hasPermissionToSendSeed: Bool = false,
        using dependencies: Dependencies = Dependencies()
    ) {
        guard !showBlockedModalIfNeeded() else { return }
        
        // Handle attachment errors if applicable
        if let failedAttachment: SignalAttachment = attachments.first(where: { $0.hasError }) {
            return showErrorAlert(for: failedAttachment)
        }
        
        let processedText: String = replaceMentions(in: text.trimmingCharacters(in: .whitespacesAndNewlines))
        
        // If we have no content then do nothing
        guard !processedText.isEmpty || !attachments.isEmpty else { return }

        if processedText.contains(mnemonic) && !viewModel.threadData.threadIsNoteToSelf && !hasPermissionToSendSeed {
            // Warn the user if they're about to send their seed to someone
            let modal: ConfirmationModal = ConfirmationModal(
                info: ConfirmationModal.Info(
                    title: "modal_send_seed_title".localized(),
                    body: .text("modal_send_seed_explanation".localized()),
                    confirmTitle: "modal_send_seed_send_button_title".localized(),
                    confirmStyle: .danger,
                    cancelStyle: .alert_text,
                    onConfirm: { [weak self] _ in
                        self?.sendMessage(
                            text: text,
                            attachments: attachments,
                            linkPreviewDraft: linkPreviewDraft,
                            quoteModel: quoteModel,
                            hasPermissionToSendSeed: true
                        )
                    }
                )
            )
            
            return present(modal, animated: true, completion: nil)
        }
        
        // Clearing this out immediately to make this appear more snappy
        DispatchQueue.main.async { [weak self] in
            self?.snInputView.text = ""
            self?.snInputView.quoteDraftInfo = nil

            self?.resetMentions()
            self?.scrollToBottom(isAnimated: false)
        }

        // Note: 'shouldBeVisible' is set to true the first time a thread is saved so we can
        // use it to determine if the user is creating a new thread and update the 'isApproved'
        // flags appropriately
        let oldThreadShouldBeVisible: Bool = (self.viewModel.threadData.threadShouldBeVisible == true)
        let sentTimestampMs: Int64 = SnodeAPI.currentOffsetTimestampMs()

        // If this was a message request then approve it
        approveMessageRequestIfNeeded(
            for: self.viewModel.threadData.threadId,
            threadVariant: self.viewModel.threadData.threadVariant,
            isNewThread: !oldThreadShouldBeVisible,
            timestampMs: (sentTimestampMs - 1)  // Set 1ms earlier as this is used for sorting
        )
        
        // Optimistically insert the outgoing message (this will trigger a UI update)
        self.viewModel.sentMessageBeforeUpdate = true
        let optimisticData: ConversationViewModel.OptimisticMessageData = self.viewModel.optimisticallyAppendOutgoingMessage(
            text: processedText,
            sentTimestampMs: sentTimestampMs,
            attachments: attachments,
            linkPreviewDraft: linkPreviewDraft,
            quoteModel: quoteModel
        )
        
        sendMessage(optimisticData: optimisticData, using: dependencies)
    }
    
    private func sendMessage(
        optimisticData: ConversationViewModel.OptimisticMessageData,
        using dependencies: Dependencies
    ) {
        let threadId: String = self.viewModel.threadData.threadId
        let threadVariant: SessionThread.Variant = self.viewModel.threadData.threadVariant
        
        DispatchQueue.global(qos:.userInitiated).async(using: dependencies) {
            // Generate the quote thumbnail if needed (want this to happen outside of the DBWrite thread as
            // this can take up to 0.5s
            let quoteThumbnailAttachment: Attachment? = optimisticData.quoteModel?.attachment?.cloneAsQuoteThumbnail()
            
            // Actually send the message
            dependencies.storage
                .writePublisher { [weak self] db in
                    // Update the thread to be visible (if it isn't already)
                    if self?.viewModel.threadData.threadShouldBeVisible == false {
                        _ = try SessionThread
                            .filter(id: threadId)
                            .updateAllAndConfig(db, SessionThread.Columns.shouldBeVisible.set(to: true))
                    }
                    
                    // Insert the interaction and associated it with the optimistically inserted message so
                    // we can remove it once the database triggers a UI update
                    let insertedInteraction: Interaction = try optimisticData.interaction.inserted(db)
                    self?.viewModel.associate(optimisticMessageId: optimisticData.id, to: insertedInteraction.id)
                    
                    // If there is a LinkPreview draft then check the state of any existing link previews and
                    // insert a new one if needed
                    if let linkPreviewDraft: LinkPreviewDraft = optimisticData.linkPreviewDraft {
                        let invalidLinkPreviewAttachmentStates: [Attachment.State] = [
                            .failedDownload, .pendingDownload, .downloading, .failedUpload, .invalid
                        ]
                        let linkPreviewAttachmentId: String? = try? insertedInteraction.linkPreview
                            .select(.attachmentId)
                            .asRequest(of: String.self)
                            .fetchOne(db)
                        let linkPreviewAttachmentState: Attachment.State = linkPreviewAttachmentId
                            .map {
                                try? Attachment
                                    .filter(id: $0)
                                    .select(.state)
                                    .asRequest(of: Attachment.State.self)
                                    .fetchOne(db)
                            }
                            .defaulting(to: .invalid)
                        
                        // If we don't have a "valid" existing link preview then upsert a new one
                        if invalidLinkPreviewAttachmentStates.contains(linkPreviewAttachmentState) {
                            try LinkPreview(
                                url: linkPreviewDraft.urlString,
                                title: linkPreviewDraft.title,
                                attachmentId: try optimisticData.linkPreviewAttachment?.inserted(db).id
                            ).save(db)
                        }
                    }
                    
                    // If there is a Quote the insert it now
                    if let interactionId: Int64 = insertedInteraction.id, let quoteModel: QuotedReplyModel = optimisticData.quoteModel {
                        try Quote(
                            interactionId: interactionId,
                            authorId: quoteModel.authorId,
                            timestampMs: quoteModel.timestampMs,
                            body: quoteModel.body,
                            attachmentId: try quoteThumbnailAttachment?.inserted(db).id
                        ).insert(db)
                    }
                    
                    // Process any attachments
                    try Attachment.process(
                        db,
                        data: optimisticData.attachmentData,
                        for: insertedInteraction.id
                    )
                    
                    try MessageSender.send(
                        db,
                        interaction: insertedInteraction,
                        threadId: threadId,
                        threadVariant: threadVariant,
                        using: dependencies
                    )
                }
                .subscribe(on: DispatchQueue.global(qos: .userInitiated))
                .sinkUntilComplete(
                    receiveCompletion: { [weak self] result in
                        switch result {
                            case .finished: break
                            case .failure(let error):
                                self?.viewModel.failedToStoreOptimisticOutgoingMessage(id: optimisticData.id, error: error)
                        }
                        
                        self?.handleMessageSent()
                    }
                )
        }
    }

    func handleMessageSent() {
        if Storage.shared[.playNotificationSoundInForeground] {
            let soundID = Preferences.Sound.systemSoundId(for: .messageSent, quiet: true)
            AudioServicesPlaySystemSound(soundID)
        }
        
        let threadId: String = self.viewModel.threadData.threadId
        
        Storage.shared.writeAsync { db in
            TypingIndicators.didStopTyping(db, threadId: threadId, direction: .outgoing)
            
            _ = try SessionThread
                .filter(id: threadId)
                .updateAll(db, SessionThread.Columns.messageDraft.set(to: ""))
        }
    }

    func showLinkPreviewSuggestionModal() {
        let linkPreviewModal: ConfirmationModal = ConfirmationModal(
            info: ConfirmationModal.Info(
                title: "modal_link_previews_title".localized(),
                body: .text("modal_link_previews_explanation".localized()),
                confirmTitle: "modal_link_previews_button_title".localized()
            ) { [weak self] _ in
                Storage.shared.writeAsync { db in
                    db[.areLinkPreviewsEnabled] = true
                }
                
                self?.snInputView.autoGenerateLinkPreview()
            }
        )
        
        present(linkPreviewModal, animated: true, completion: nil)
    }
    
    func inputTextViewDidChangeContent(_ inputTextView: InputTextView) {
        // Note: If there is a 'draft' message then we don't want it to trigger the typing indicator to
        // appear (as that is not expected/correct behaviour)
        guard !viewIsAppearing else { return }
        
        let newText: String = (inputTextView.text ?? "")
        
        if !newText.isEmpty {
            let threadId: String = self.viewModel.threadData.threadId
            let threadVariant: SessionThread.Variant = self.viewModel.threadData.threadVariant
            let threadIsMessageRequest: Bool = (self.viewModel.threadData.threadIsMessageRequest == true)
            let threadIsBlocked: Bool = (self.viewModel.threadData.threadIsBlocked == true)
            let needsToStartTypingIndicator: Bool = TypingIndicators.didStartTypingNeedsToStart(
                threadId: threadId,
                threadVariant: threadVariant,
                threadIsBlocked: threadIsBlocked,
                threadIsMessageRequest: threadIsMessageRequest,
                direction: .outgoing,
                timestampMs: SnodeAPI.currentOffsetTimestampMs()
            )
            
            if needsToStartTypingIndicator {
                Storage.shared.writeAsync { db in
                    TypingIndicators.start(db, threadId: threadId, direction: .outgoing)
                }
            }
        }
        
        updateMentions(for: newText)
    }
    
    // MARK: --Attachments
    
    func didPasteImageFromPasteboard(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 1.0) else { return }
        
        let dataSource = DataSourceValue.dataSource(with: imageData, utiType: kUTTypeJPEG as String)
        let attachment = SignalAttachment.attachment(dataSource: dataSource, dataUTI: kUTTypeJPEG as String, imageQuality: .medium)

        let approvalVC = AttachmentApprovalViewController.wrappedInNavController(
            threadId: self.viewModel.threadData.threadId,
            threadVariant: self.viewModel.threadData.threadVariant,
            attachments: [ attachment ],
            approvalDelegate: self
        )
        approvalVC.modalPresentationStyle = .fullScreen
        
        self.present(approvalVC, animated: true, completion: nil)
    }

    // MARK: --Mentions
    
    func handleMentionSelected(_ mentionInfo: MentionInfo, from view: MentionSelectionView) {
        guard let currentMentionStartIndex = currentMentionStartIndex else { return }
        
        mentions.append(mentionInfo)
        
        let newText: String = snInputView.text.replacingCharacters(
            in: currentMentionStartIndex...,
            with: "@\(mentionInfo.profile.displayName(for: self.viewModel.threadData.threadVariant)) "
        )
        
        snInputView.text = newText
        self.currentMentionStartIndex = nil
        snInputView.hideMentionsUI()
        
        mentions = mentions.filter { mentionInfo -> Bool in
            newText.contains(mentionInfo.profile.displayName(for: self.viewModel.threadData.threadVariant))
        }
    }
    
    func updateMentions(for newText: String) {
        guard !newText.isEmpty else {
            if currentMentionStartIndex != nil {
                snInputView.hideMentionsUI()
            }
            
            resetMentions()
            return
        }
        
        let lastCharacterIndex = newText.index(before: newText.endIndex)
        let lastCharacter = newText[lastCharacterIndex]
        
        // Check if there is whitespace before the '@' or the '@' is the first character
        let isCharacterBeforeLastWhiteSpaceOrStartOfLine: Bool
        if newText.count == 1 {
            isCharacterBeforeLastWhiteSpaceOrStartOfLine = true // Start of line
        }
        else {
            let characterBeforeLast = newText[newText.index(before: lastCharacterIndex)]
            isCharacterBeforeLastWhiteSpaceOrStartOfLine = characterBeforeLast.isWhitespace
        }
        
        if lastCharacter == "@" && isCharacterBeforeLastWhiteSpaceOrStartOfLine {
            currentMentionStartIndex = lastCharacterIndex
            snInputView.showMentionsUI(for: self.viewModel.mentions())
        }
        else if lastCharacter.isWhitespace || lastCharacter == "@" { // the lastCharacter == "@" is to check for @@
            currentMentionStartIndex = nil
            snInputView.hideMentionsUI()
        }
        else {
            if let currentMentionStartIndex = currentMentionStartIndex {
                let query = String(newText[newText.index(after: currentMentionStartIndex)...]) // + 1 to get rid of the @
                snInputView.showMentionsUI(for: self.viewModel.mentions(for: query))
            }
        }
    }

    func resetMentions() {
        currentMentionStartIndex = nil
        mentions = []
    }

    func replaceMentions(in text: String) -> String {
        var result = text
        for mention in mentions {
            guard let range = result.range(of: "@\(mention.profile.displayName(for: mention.threadVariant))") else { continue }
            result = result.replacingCharacters(in: range, with: "@\(mention.profile.id)")
        }
        
        return result
    }
    
    func hideInputAccessoryView() {
        self.inputAccessoryView?.isHidden = true
        self.inputAccessoryView?.alpha = 0
    }
    
    func showInputAccessoryView() {
        UIView.animate(withDuration: 0.25, animations: {
            self.inputAccessoryView?.isHidden = false
            self.inputAccessoryView?.alpha = 1
        })
    }

    // MARK: MessageCellDelegate

    func handleItemLongPressed(_ cellViewModel: MessageViewModel) {
        // Show the context menu if applicable
        guard
            // FIXME: Need to update this when an appropriate replacement is added (see https://teng.pub/technical/2021/11/9/uiapplication-key-window-replacement)
            let keyWindow: UIWindow = UIApplication.shared.keyWindow,
            let sectionIndex: Int = self.viewModel.interactionData
                .firstIndex(where: { $0.model == .messages }),
            let index = self.viewModel.interactionData[sectionIndex]
                .elements
                .firstIndex(of: cellViewModel),
            let cell = tableView.cellForRow(at: IndexPath(row: index, section: sectionIndex)) as? MessageCell,
            let contextSnapshotView: UIView = cell.contextSnapshotView,
            let snapshot = contextSnapshotView.snapshotView(afterScreenUpdates: false),
            contextMenuWindow == nil,
            let actions: [ContextMenuVC.Action] = ContextMenuVC.actions(
                for: cellViewModel,
                recentEmojis: (self.viewModel.threadData.recentReactionEmoji ?? []).compactMap { EmojiWithSkinTones(rawValue: $0) },
                currentUserPublicKey: self.viewModel.threadData.currentUserPublicKey,
                currentUserBlinded15PublicKey: self.viewModel.threadData.currentUserBlinded15PublicKey,
                currentUserBlinded25PublicKey: self.viewModel.threadData.currentUserBlinded25PublicKey,
                currentUserIsOpenGroupModerator: OpenGroupManager.isUserModeratorOrAdmin(
                    self.viewModel.threadData.currentUserPublicKey,
                    for: self.viewModel.threadData.openGroupRoomToken,
                    on: self.viewModel.threadData.openGroupServer
                ),
                currentThreadIsMessageRequest: (self.viewModel.threadData.threadIsMessageRequest == true),
                delegate: self
            )
        else { return }
        
        /// Lock the contentOffset of the tableView so the transition doesn't look buggy
        self.tableView.lockContentOffset = true
        
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        self.contextMenuWindow = ContextMenuWindow()
        self.contextMenuVC = ContextMenuVC(
            snapshot: snapshot,
            frame: contextSnapshotView.convert(contextSnapshotView.bounds, to: keyWindow),
            cellViewModel: cellViewModel,
            actions: actions
        ) { [weak self] in
            self?.contextMenuWindow?.isHidden = true
            self?.contextMenuVC = nil
            self?.contextMenuWindow = nil
            self?.scrollButton.alpha = 0
            
            UIView.animate(
                withDuration: 0.25,
                animations: { self?.updateScrollToBottom() },
                completion: { _ in
                    guard let contentOffset: CGPoint = self?.tableView.contentOffset else { return }
                    
                    // Unlock the contentOffset so everything will be in the right
                    // place when we return
                    self?.tableView.lockContentOffset = false
                    self?.tableView.setContentOffset(contentOffset, animated: false)
                }
            )
        }
        
        self.contextMenuWindow?.themeBackgroundColor = .clear
        self.contextMenuWindow?.rootViewController = self.contextMenuVC
        self.contextMenuWindow?.overrideUserInterfaceStyle = ThemeManager.currentTheme.interfaceStyle
        self.contextMenuWindow?.makeKeyAndVisible()
    }

    func handleItemTapped(
        _ cellViewModel: MessageViewModel,
        cell: UITableViewCell,
        cellLocation: CGPoint,
        using dependencies: Dependencies = Dependencies()
    ) {
        guard cellViewModel.variant != .standardOutgoing || (cellViewModel.state != .failed && cellViewModel.state != .failedToSync) else {
            // Show the failed message sheet
            showFailedMessageSheet(for: cellViewModel, using: dependencies)
            return
        }
        
        // For call info messages show the "call missed" modal
        guard cellViewModel.variant != .infoCall else {
            let callMissedTipsModal: CallMissedTipsModal = CallMissedTipsModal(caller: cellViewModel.authorName)
            present(callMissedTipsModal, animated: true, completion: nil)
            return
        }
        
        // For disappearing messages config update, show the following settings modal
        guard cellViewModel.variant != .infoDisappearingMessagesUpdate else {
            let messageDisappearingConfig = cellViewModel.messageDisappearingConfiguration()
            let expirationTimerString: String = floor(messageDisappearingConfig.durationSeconds).formatted(format: .long)
            let expirationTypeString: String = (messageDisappearingConfig.type == .disappearAfterRead ? "DISAPPEARING_MESSAGE_STATE_READ".localized() : "DISAPPEARING_MESSAGE_STATE_SENT".localized())
            let modalBodyString: String = (
                messageDisappearingConfig.isEnabled ?
                String(
                    format: "FOLLOW_SETTING_EXPLAINATION_TURNING_ON".localized(),
                    expirationTimerString,
                    expirationTypeString
                ) :
                "FOLLOW_SETTING_EXPLAINATION_TURNING_OFF".localized()
            )
            let modalConfirmTitle: String = messageDisappearingConfig.isEnabled ? "DISAPPERING_MESSAGES_SAVE_TITLE".localized() : "CONFIRM_BUTTON_TITLE".localized()
            let confirmationModal: ConfirmationModal = ConfirmationModal(
                info: ConfirmationModal.Info(
                    title: "FOLLOW_SETTING_TITLE".localized(),
                    body: .attributedText(
                        NSAttributedString(string: modalBodyString)
                            .adding(
                                attributes: [ .font: UIFont.boldSystemFont(ofSize: Values.smallFontSize) ],
                                range: (modalBodyString as NSString).range(of: expirationTypeString)
                            )
                            .adding(
                                attributes: [ .font: UIFont.boldSystemFont(ofSize: Values.smallFontSize) ],
                                range: (modalBodyString as NSString).range(of: expirationTimerString)
                            )
                            .adding(
                                attributes: [ .font: UIFont.boldSystemFont(ofSize: Values.smallFontSize) ],
                                range: (modalBodyString as NSString).range(of: "DISAPPEARING_MESSAGES_OFF".localized().lowercased())
                            )
                    ),
                    accessibility: Accessibility(identifier: "Follow setting dialog"),
                    confirmTitle: modalConfirmTitle,
                    confirmAccessibility: Accessibility(identifier: "Set button"),
                    confirmStyle: .danger,
                    cancelStyle: .textPrimary,
                    dismissOnConfirm: false // Custom dismissal logic
                ) { [weak self] _ in
                    dependencies.storage.writeAsync { db in
                        try messageDisappearingConfig.save(db)
                        try SessionUtil
                            .update(
                                db,
                                sessionId: cellViewModel.threadId,
                                disappearingMessagesConfig: messageDisappearingConfig
                            )
                    }
                    self?.dismiss(animated: true, completion: nil)
                }
            )
            
            present(confirmationModal, animated: true, completion: nil)
            return
        }
        
        // If it's an incoming media message and the thread isn't trusted then show the placeholder view
        if cellViewModel.cellType != .textOnlyMessage && cellViewModel.variant == .standardIncoming && !cellViewModel.threadIsTrusted {
            let message: String = String(
                format: "modal_download_attachment_explanation".localized(),
                cellViewModel.authorName
            )
            let confirmationModal: ConfirmationModal = ConfirmationModal(
                info: ConfirmationModal.Info(
                    title: String(
                        format: "modal_download_attachment_title".localized(),
                        cellViewModel.authorName
                    ),
                    body: .attributedText(
                        NSAttributedString(string: message)
                            .adding(
                                attributes: [ .font: UIFont.boldSystemFont(ofSize: Values.smallFontSize) ],
                                range: (message as NSString).range(of: cellViewModel.authorName)
                            )
                    ),
                    confirmTitle: "modal_download_button_title".localized(),
                    confirmAccessibility: Accessibility(identifier: "Download media"),
                    cancelAccessibility: Accessibility(identifier: "Don't download media"),
                    dismissOnConfirm: false // Custom dismissal logic
                ) { [weak self] _ in
                    self?.viewModel.trustContact()
                    self?.dismiss(animated: true, completion: nil)
                }
            )
            
            present(confirmationModal, animated: true, completion: nil)
            return
        }
        
        /// Takes the `cell` and a `targetView` and returns `true` if the user tapped a link in the cell body text instead
        /// of the `targetView`
        func handleLinkTapIfNeeded(cell: UITableViewCell, targetView: UIView?) -> Bool {
            let locationInTargetView: CGPoint = cell.convert(cellLocation, to: targetView)
            
            guard
                let visibleCell: VisibleMessageCell = cell as? VisibleMessageCell,
                targetView?.bounds.contains(locationInTargetView) != true,
                visibleCell.bodyTappableLabel?.containsLinks == true
            else { return false }
            
            let tappableLabelPoint: CGPoint = cell.convert(cellLocation, to: visibleCell.bodyTappableLabel)
            visibleCell.bodyTappableLabel?.handleTouch(at: tappableLabelPoint)
            return true
        }
        
        switch cellViewModel.cellType {
            case .voiceMessage: viewModel.playOrPauseAudio(for: cellViewModel)
            
            case .mediaMessage:
                guard
                    let albumView: MediaAlbumView = (cell as? VisibleMessageCell)?.albumView,
                    !handleLinkTapIfNeeded(cell: cell, targetView: albumView)
                else { return }
                
                // Figure out which of the media views was tapped
                let locationInAlbumView: CGPoint = cell.convert(cellLocation, to: albumView)
                guard let mediaView = albumView.mediaView(forLocation: locationInAlbumView) else { return }
                
                switch mediaView.attachment.state {
                    case .pendingDownload, .downloading, .uploading, .invalid: break
                    
                    // Failed uploads should be handled via the "resend" process instead
                    case .failedUpload: break
                        
                    case .failedDownload:
                        let threadId: String = self.viewModel.threadData.threadId
                        
                        // Retry downloading the failed attachment
                        dependencies.storage.writeAsync { db in
                            dependencies.jobRunner.add(
                                db,
                                job: Job(
                                    variant: .attachmentDownload,
                                    threadId: threadId,
                                    interactionId: cellViewModel.id,
                                    details: AttachmentDownloadJob.Details(
                                        attachmentId: mediaView.attachment.id
                                    )
                                ),
                                canStartJob: true,
                                using: dependencies
                            )
                        }
                        break
                        
                    default:
                        // Ignore invalid media
                        guard mediaView.attachment.isValid else { return }
                        
                        guard albumView.numItems > 1 || !mediaView.attachment.isVideo else {
                            guard
                                let originalFilePath: String = mediaView.attachment.originalFilePath,
                                FileManager.default.fileExists(atPath: originalFilePath)
                            else { return SNLog("Missing video file") }
                            
                            let viewController: AVPlayerViewController = AVPlayerViewController()
                            viewController.player = AVPlayer(url: URL(fileURLWithPath: originalFilePath))
                            self.navigationController?.present(viewController, animated: true)
                            return
                        }
                        
                        let viewController: UIViewController? = MediaGalleryViewModel.createDetailViewController(
                            for: self.viewModel.threadData.threadId,
                            threadVariant: self.viewModel.threadData.threadVariant,
                            interactionId: cellViewModel.id,
                            selectedAttachmentId: mediaView.attachment.id,
                            options: [ .sliderEnabled, .showAllMediaButton ]
                        )
                        
                        if let viewController: UIViewController = viewController {
                            /// Delay becoming the first responder to make the return transition a little nicer (allows
                            /// for the footer on the detail view to slide out rather than instantly vanish)
                            self.delayFirstResponder = true
                            
                            /// Dismiss the input before starting the presentation to make everything look smoother
                            self.resignFirstResponder()
                            
                            /// Delay the actual presentation to give the 'resignFirstResponder' call the chance to complete
                            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250)) { [weak self] in
                                /// Lock the contentOffset of the tableView so the transition doesn't look buggy
                                self?.tableView.lockContentOffset = true
                                
                                self?.present(viewController, animated: true) { [weak self] in
                                    // Unlock the contentOffset so everything will be in the right
                                    // place when we return
                                    self?.tableView.lockContentOffset = false
                                }
                            }
                        }
                }
                
            case .audio:
                guard
                    !handleLinkTapIfNeeded(cell: cell, targetView: (cell as? VisibleMessageCell)?.documentView),
                    let attachment: Attachment = cellViewModel.attachments?.first,
                    let originalFilePath: String = attachment.originalFilePath
                else { return }
                
                // Use the native player to play audio files
                let viewController: AVPlayerViewController = AVPlayerViewController()
                viewController.player = AVPlayer(url: URL(fileURLWithPath: originalFilePath))
                self.navigationController?.present(viewController, animated: true)
                
            case .genericAttachment:
                guard
                    !handleLinkTapIfNeeded(cell: cell, targetView: (cell as? VisibleMessageCell)?.documentView),
                    let attachment: Attachment = cellViewModel.attachments?.first,
                    let originalFilePath: String = attachment.originalFilePath
                else { return }
                
                let fileUrl: URL = URL(fileURLWithPath: originalFilePath)
                
                // Open a preview of the document for text, pdf or microsoft files
                if
                    attachment.isText ||
                    attachment.isMicrosoftDoc ||
                    attachment.contentType == OWSMimeTypeApplicationPdf
                {
                    
                    let interactionController: UIDocumentInteractionController = UIDocumentInteractionController(url: fileUrl)
                    interactionController.delegate = self
                    interactionController.presentPreview(animated: true)
                    return
                }
                
                // Otherwise share the file
                let shareVC = UIActivityViewController(activityItems: [ fileUrl ], applicationActivities: nil)
                
                if UIDevice.current.isIPad {
                    shareVC.excludedActivityTypes = []
                    shareVC.popoverPresentationController?.permittedArrowDirections = []
                    shareVC.popoverPresentationController?.sourceView = self.view
                    shareVC.popoverPresentationController?.sourceRect = self.view.bounds
                }
                
                navigationController?.present(shareVC, animated: true, completion: nil)
                
            case .textOnlyMessage:
                guard let visibleCell: VisibleMessageCell = cell as? VisibleMessageCell else { return }
                
                let quotePoint: CGPoint = visibleCell.convert(cellLocation, to: visibleCell.quoteView)
                let linkPreviewPoint: CGPoint = visibleCell.convert(cellLocation, to: visibleCell.linkPreviewView?.previewView)
                let tappableLabelPoint: CGPoint = visibleCell.convert(cellLocation, to: visibleCell.bodyTappableLabel)
                let containsLinks: Bool = (
                    // If there is only a single link and it matches the LinkPreview then consider this _just_ a
                    // LinkPreview
                    visibleCell.bodyTappableLabel?.containsLinks == true && (
                        (visibleCell.bodyTappableLabel?.links.count ?? 0) > 1 ||
                        visibleCell.bodyTappableLabel?.links[cellViewModel.linkPreview?.url ?? ""] == nil
                    )
                )
                let quoteViewContainsTouch: Bool = (visibleCell.quoteView?.bounds.contains(quotePoint) == true)
                let linkPreviewViewContainsTouch: Bool = (visibleCell.linkPreviewView?.previewView.bounds.contains(linkPreviewPoint) == true)
                
                switch (containsLinks, quoteViewContainsTouch, linkPreviewViewContainsTouch, cellViewModel.quote, cellViewModel.linkPreview) {
                    // If the message contains both links and a quote, and the user tapped on the quote; OR the
                    // message only contained a quote, then scroll to the quote
                    case (true, true, _, .some(let quote), _), (false, _, _, .some(let quote), _):
                        let maybeOriginalInteractionInfo: Interaction.TimestampInfo? = Storage.shared.read { db in
                            try quote.originalInteraction
                                .select(.id, .timestampMs)
                                .asRequest(of: Interaction.TimestampInfo.self)
                                .fetchOne(db)
                        }
                        
                        guard let interactionInfo: Interaction.TimestampInfo = maybeOriginalInteractionInfo else {
                            return
                        }
                        
                        self.scrollToInteractionIfNeeded(
                            with: interactionInfo,
                            focusBehaviour: .highlight,
                            originalIndexPath: self.tableView.indexPath(for: cell)
                        )
                    
                    // If the message contains both links and a LinkPreview, and the user tapped on
                    // the LinkPreview; OR the message only contained a LinkPreview, then open the link
                    case (true, _, true, _, .some(let linkPreview)), (false, _, _, _, .some(let linkPreview)):
                        switch linkPreview.variant {
                            case .standard: openUrl(linkPreview.url)
                            case .openGroupInvitation: joinOpenGroup(name: linkPreview.title, url: linkPreview.url)
                        }
                    
                    // If the message contained links then interact with them directly
                    case (true, _, _, _, _): visibleCell.bodyTappableLabel?.handleTouch(at: tappableLabelPoint)
                        
                    default: break
                }
                
            default: break
        }
    }
    
    func handleItemDoubleTapped(_ cellViewModel: MessageViewModel) {
        switch cellViewModel.cellType {
            // The user can double tap a voice message when it's playing to speed it up
            case .voiceMessage: self.viewModel.speedUpAudio(for: cellViewModel)
            default: break
        }
    }

    func handleItemSwiped(_ cellViewModel: MessageViewModel, state: SwipeState) {
        switch state {
            case .began: tableView.isScrollEnabled = false
            case .ended, .cancelled: tableView.isScrollEnabled = true
        }
    }
    
    func openUrl(_ urlString: String) {
        guard let url: URL = URL(string: urlString) else { return }
        
        // URLs can be unsafe, so always ask the user whether they want to open one
        let actionSheet: UIAlertController = UIAlertController(
            title: "modal_open_url_title".localized(),
            message: String(format: "modal_open_url_explanation".localized(), url.absoluteString),
            preferredStyle: .actionSheet
        )
        actionSheet.addAction(UIAlertAction(title: "modal_open_url_button_title".localized(), style: .default) { [weak self] _ in
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            self?.showInputAccessoryView()
        })
        actionSheet.addAction(UIAlertAction(title: "modal_copy_url_button_title".localized(), style: .default) { [weak self] _ in
            UIPasteboard.general.string = url.absoluteString
            self?.showInputAccessoryView()
        })
        actionSheet.addAction(UIAlertAction(title: "cancel".localized(), style: .cancel) { [weak self] _ in
            self?.showInputAccessoryView()
        })
        
        Modal.setupForIPadIfNeeded(actionSheet, targetView: self.view)
        self.present(actionSheet, animated: true)
    }
    
    func handleReplyButtonTapped(for cellViewModel: MessageViewModel, using dependencies: Dependencies) {
        reply(cellViewModel, using: dependencies)
    }
    
    func startThread(with sessionId: String, openGroupServer: String?, openGroupPublicKey: String?) {
        guard viewModel.threadData.canWrite else { return }
        // FIXME: Add in support for starting a thread with a 'blinded25' id
        guard SessionId.Prefix(from: sessionId) != .blinded25 else { return }
        guard SessionId.Prefix(from: sessionId) == .blinded15 else {
            Storage.shared.write { db in
                try SessionThread
                    .fetchOrCreate(db, id: sessionId, variant: .contact, shouldBeVisible: nil)
            }
            
            let conversationVC: ConversationVC = ConversationVC(threadId: sessionId, threadVariant: .contact)
                
            self.navigationController?.pushViewController(conversationVC, animated: true)
            return
        }
        
        // If the sessionId is blinded then check if there is an existing un-blinded thread with the contact
        // and use that, otherwise just use the blinded id
        guard let openGroupServer: String = openGroupServer, let openGroupPublicKey: String = openGroupPublicKey else {
            return
        }
        
        let targetThreadId: String? = Storage.shared.write { db in
            let lookup: BlindedIdLookup = try BlindedIdLookup
                .fetchOrCreate(
                    db,
                    blindedId: sessionId,
                    openGroupServer: openGroupServer,
                    openGroupPublicKey: openGroupPublicKey,
                    isCheckingForOutbox: false
                )
            
            return try SessionThread
                .fetchOrCreate(
                    db,
                    id: (lookup.sessionId ?? lookup.blindedId),
                    variant: .contact,
                    shouldBeVisible: nil
                )
                .id
        }
        
        guard let threadId: String = targetThreadId else { return }
        
        let conversationVC: ConversationVC = ConversationVC(threadId: threadId, threadVariant: .contact)
        self.navigationController?.pushViewController(conversationVC, animated: true)
    }
    
    func showReactionList(_ cellViewModel: MessageViewModel, selectedReaction: EmojiWithSkinTones?) {
        guard
            cellViewModel.reactionInfo?.isEmpty == false &&
            (
                self.viewModel.threadData.threadVariant == .legacyGroup ||
                self.viewModel.threadData.threadVariant == .group ||
                self.viewModel.threadData.threadVariant == .community
            ),
            let allMessages: [MessageViewModel] = self.viewModel.interactionData
                .first(where: { $0.model == .messages })?
                .elements
        else { return }
        
        let reactionListSheet: ReactionListSheet = ReactionListSheet(for: cellViewModel.id) { [weak self] in
            self?.currentReactionListSheet = nil
        }
        reactionListSheet.delegate = self
        reactionListSheet.handleInteractionUpdates(
            allMessages,
            selectedReaction: selectedReaction,
            initialLoad: true,
            shouldShowClearAllButton: OpenGroupManager.isUserModeratorOrAdmin(
                self.viewModel.threadData.currentUserPublicKey,
                for: self.viewModel.threadData.openGroupRoomToken,
                on: self.viewModel.threadData.openGroupServer
            )
        )
        reactionListSheet.modalPresentationStyle = .overFullScreen
        present(reactionListSheet, animated: true, completion: nil)
        
        // Store so we can updated the content based on the current VC
        self.currentReactionListSheet = reactionListSheet
    }
    
    func needsLayout(for cellViewModel: MessageViewModel, expandingReactions: Bool) {
        guard
            let messageSectionIndex: Int = self.viewModel.interactionData
                .firstIndex(where: { $0.model == .messages }),
            let targetMessageIndex = self.viewModel.interactionData[messageSectionIndex]
                .elements
                .firstIndex(where: { $0.id == cellViewModel.id })
        else { return }
        
        if expandingReactions {
            self.viewModel.expandReactions(for: cellViewModel.id)
        }
        else {
            self.viewModel.collapseReactions(for: cellViewModel.id)
        }
        
        UIView.setAnimationsEnabled(false)
        tableView.reloadRows(
            at: [IndexPath(row: targetMessageIndex, section: messageSectionIndex)],
            with: .none
        )
        UIView.setAnimationsEnabled(true)
    }
    
    func react(_ cellViewModel: MessageViewModel, with emoji: EmojiWithSkinTones, using dependencies: Dependencies) {
        react(cellViewModel, with: emoji.rawValue, remove: false, using: dependencies)
    }
    
    func removeReact(_ cellViewModel: MessageViewModel, for emoji: EmojiWithSkinTones, using dependencies: Dependencies) {
        react(cellViewModel, with: emoji.rawValue, remove: true, using: dependencies)
    }
    
    func removeAllReactions(_ cellViewModel: MessageViewModel, for emoji: String, using dependencies: Dependencies) {
        guard cellViewModel.threadVariant == .community else { return }
        
        Storage.shared
            .readPublisher { db -> (OpenGroupAPI.PreparedSendData<OpenGroupAPI.ReactionRemoveAllResponse>, OpenGroupAPI.PendingChange) in
                guard
                    let openGroup: OpenGroup = try? OpenGroup
                        .fetchOne(db, id: cellViewModel.threadId),
                    let openGroupServerMessageId: Int64 = try? Interaction
                        .select(.openGroupServerMessageId)
                        .filter(id: cellViewModel.id)
                        .asRequest(of: Int64.self)
                        .fetchOne(db)
                else { throw StorageError.objectNotFound }
                
                let sendData: OpenGroupAPI.PreparedSendData<OpenGroupAPI.ReactionRemoveAllResponse> = try OpenGroupAPI
                    .preparedReactionDeleteAll(
                        db,
                        emoji: emoji,
                        id: openGroupServerMessageId,
                        in: openGroup.roomToken,
                        on: openGroup.server
                    )
                let pendingChange: OpenGroupAPI.PendingChange = OpenGroupManager
                    .addPendingReaction(
                        emoji: emoji,
                        id: openGroupServerMessageId,
                        in: openGroup.roomToken,
                        on: openGroup.server,
                        type: .removeAll
                    )
                
                return (sendData, pendingChange)
            }
            .subscribe(on: DispatchQueue.global(qos: .userInitiated))
            .flatMap { sendData, pendingChange in
                OpenGroupAPI.send(data: sendData)
                    .handleEvents(
                        receiveOutput: { _, response in
                            OpenGroupManager
                                .updatePendingChange(
                                    pendingChange,
                                    seqNo: response.seqNo
                                )
                        }
                    )
                    .eraseToAnyPublisher()
            }
            .sinkUntilComplete(
                receiveCompletion: { _ in
                    Storage.shared.writeAsync { db in
                        _ = try Reaction
                            .filter(Reaction.Columns.interactionId == cellViewModel.id)
                            .filter(Reaction.Columns.emoji == emoji)
                            .deleteAll(db)
                    }
                }
            )
    }
    
    func react(
        _ cellViewModel: MessageViewModel,
        with emoji: String,
        remove: Bool,
        using dependencies: Dependencies = Dependencies()
    ) {
        guard
            self.viewModel.threadData.threadIsMessageRequest != true && (
                cellViewModel.variant == .standardIncoming ||
                cellViewModel.variant == .standardOutgoing
            )
        else { return }
        
        // Perform local rate limiting (don't allow more than 20 reactions within 60 seconds)
        let threadVariant: SessionThread.Variant = self.viewModel.threadData.threadVariant
        let openGroupRoom: String? = self.viewModel.threadData.openGroupRoomToken
        let sentTimestamp: Int64 = SnodeAPI.currentOffsetTimestampMs()
        let recentReactionTimestamps: [Int64] = dependencies.caches[.general].recentReactionTimestamps
        
        guard
            recentReactionTimestamps.count < 20 ||
            (sentTimestamp - (recentReactionTimestamps.first ?? sentTimestamp)) > (60 * 1000)
        else {
            let toastController: ToastController = ToastController(
                text: "EMOJI_REACTS_RATE_LIMIT_TOAST".localized(),
                background: .backgroundSecondary
            )
            toastController.presentToastView(
                fromBottomOfView: self.view,
                inset: (snInputView.bounds.height + Values.largeSpacing),
                duration: .milliseconds(2500)
            )
            return
        }
        
        dependencies.caches.mutate(cache: .general) {
            $0.recentReactionTimestamps = Array($0.recentReactionTimestamps
                .suffix(19))
                .appending(sentTimestamp)
        }
        
        typealias OpenGroupInfo = (
            pendingReaction: Reaction?,
            pendingChange: OpenGroupAPI.PendingChange,
            sendData: OpenGroupAPI.PreparedSendData<Int64?>
        )
        
        /// Perform the sending logic, we generate the pending reaction first in a deferred future closure to prevent the OpenGroup
        /// cache from blocking either the main thread or the database write thread
        Deferred {
            Future<OpenGroupAPI.PendingChange?, Error> { resolver in
                guard
                    threadVariant == .community,
                    let serverMessageId: Int64 = cellViewModel.openGroupServerMessageId,
                    let openGroupServer: String = cellViewModel.threadOpenGroupServer,
                    let openGroupPublicKey: String = cellViewModel.threadOpenGroupPublicKey
                else { return resolver(Result.success(nil)) }
                  
                // Create the pending change if we have open group info
                return resolver(Result.success(
                    OpenGroupManager.addPendingReaction(
                        emoji: emoji,
                        id: serverMessageId,
                        in: openGroupServer,
                        on: openGroupPublicKey,
                        type: (remove ? .remove : .add)
                    )
                ))
            }
        }
        .subscribe(on: DispatchQueue.global(qos: .userInitiated), using: dependencies)
        .flatMap { pendingChange -> AnyPublisher<(MessageSender.PreparedSendData?, OpenGroupInfo?), Error> in
            dependencies.storage.writePublisher { [weak self] db -> (MessageSender.PreparedSendData?, OpenGroupInfo?) in
                // Update the thread to be visible (if it isn't already)
                if self?.viewModel.threadData.threadShouldBeVisible == false {
                    _ = try SessionThread
                        .filter(id: cellViewModel.threadId)
                        .updateAllAndConfig(db, SessionThread.Columns.shouldBeVisible.set(to: true))
                }
                
                let pendingReaction: Reaction? = {
                    guard !remove else {
                        return try? Reaction
                            .filter(Reaction.Columns.interactionId == cellViewModel.id)
                            .filter(Reaction.Columns.authorId == cellViewModel.currentUserPublicKey)
                            .filter(Reaction.Columns.emoji == emoji)
                            .fetchOne(db)
                    }
                    
                    let sortId: Int64 = Reaction.getSortId(
                        db,
                        interactionId: cellViewModel.id,
                        emoji: emoji
                    )
                    
                    return Reaction(
                        interactionId: cellViewModel.id,
                        serverHash: nil,
                        timestampMs: sentTimestamp,
                        authorId: cellViewModel.currentUserPublicKey,
                        emoji: emoji,
                        count: 1,
                        sortId: sortId
                    )
                }()
                
                // Update the database
                if remove {
                    try Reaction
                        .filter(Reaction.Columns.interactionId == cellViewModel.id)
                        .filter(Reaction.Columns.authorId == cellViewModel.currentUserPublicKey)
                        .filter(Reaction.Columns.emoji == emoji)
                        .deleteAll(db)
                }
                else {
                    try pendingReaction?.insert(db)
                    
                    // Add it to the recent list
                    Emoji.addRecent(db, emoji: emoji)
                }
                
                switch threadVariant {
                    case .community:
                        guard
                            let serverMessageId: Int64 = cellViewModel.openGroupServerMessageId,
                            let openGroupServer: String = cellViewModel.threadOpenGroupServer,
                            let openGroupRoom: String = openGroupRoom,
                            let pendingChange: OpenGroupAPI.PendingChange = pendingChange,
                            OpenGroupManager.doesOpenGroupSupport(db, capability: .reactions, on: openGroupServer)
                        else { throw MessageSenderError.invalidMessage }
                        
                        let sendData: OpenGroupAPI.PreparedSendData<Int64?> = try {
                            guard !remove else {
                                return try OpenGroupAPI
                                    .preparedReactionDelete(
                                        db,
                                        emoji: emoji,
                                        id: serverMessageId,
                                        in: openGroupRoom,
                                        on: openGroupServer
                                    )
                                    .map { _, response in response.seqNo }
                            }
                            
                            return try OpenGroupAPI
                                .preparedReactionAdd(
                                    db,
                                    emoji: emoji,
                                    id: serverMessageId,
                                    in: openGroupRoom,
                                    on: openGroupServer
                                )
                                .map { _, response in response.seqNo }
                        }()
                        
                        return (nil, (pendingReaction, pendingChange, sendData))
                        
                    default:
                        let sendData: MessageSender.PreparedSendData = try MessageSender.preparedSendData(
                            db,
                            message: VisibleMessage(
                                sentTimestamp: UInt64(sentTimestamp),
                                text: nil,
                                reaction: VisibleMessage.VMReaction(
                                    timestamp: UInt64(cellViewModel.timestampMs),
                                    publicKey: {
                                        guard cellViewModel.variant == .standardIncoming else {
                                            return cellViewModel.currentUserPublicKey
                                        }
                                        
                                        return cellViewModel.authorId
                                    }(),
                                    emoji: emoji,
                                    kind: (remove ? .remove : .react)
                                )
                            ),
                            to: try Message.Destination
                                .from(db, threadId: cellViewModel.threadId, threadVariant: cellViewModel.threadVariant),
                            namespace: try Message.Destination
                                .from(db, threadId: cellViewModel.threadId, threadVariant: cellViewModel.threadVariant)
                                .defaultNamespace,
                            interactionId: cellViewModel.id,
                            using: dependencies
                        )
                        
                        return (sendData, nil)
                }
            }
        }
        .tryFlatMap { messageSendData, openGroupInfo -> AnyPublisher<Void, Error> in
            switch (messageSendData, openGroupInfo) {
                case (.some(let sendData), _):
                    return MessageSender.sendImmediate(data: sendData, using: dependencies)
                    
                case (_, .some(let info)):
                    return OpenGroupAPI.send(data: info.sendData)
                        .handleEvents(
                            receiveOutput: { _, seqNo in
                                OpenGroupManager
                                    .updatePendingChange(
                                        info.pendingChange,
                                        seqNo: seqNo
                                    )
                            },
                            receiveCompletion: { [weak self] result in
                                switch result {
                                    case .finished: break
                                    case .failure:
                                        OpenGroupManager.removePendingChange(info.pendingChange)

                                        self?.handleReactionSentFailure(
                                            info.pendingReaction,
                                            remove: remove
                                        )
                                }
                            }
                        )
                        .map { _ in () }
                        .eraseToAnyPublisher()
                    
                default: throw MessageSenderError.invalidMessage
            }
        }
        .sinkUntilComplete()
    }
    
    func handleReactionSentFailure(_ pendingReaction: Reaction?, remove: Bool) {
        guard let pendingReaction = pendingReaction else { return }
        Storage.shared.writeAsync { db in
            // Reverse the database
            if remove {
                try pendingReaction.insert(db)
            }
            else {
                try Reaction
                    .filter(Reaction.Columns.interactionId == pendingReaction.interactionId)
                    .filter(Reaction.Columns.authorId == pendingReaction.authorId)
                    .filter(Reaction.Columns.emoji == pendingReaction.emoji)
                    .deleteAll(db)
            }
        }
    }
    
    func showFullEmojiKeyboard(_ cellViewModel: MessageViewModel, using dependencies: Dependencies) {
        hideInputAccessoryView()
        
        let emojiPicker = EmojiPickerSheet(
            completionHandler: { [weak self] emoji in
                guard let emoji: EmojiWithSkinTones = emoji else { return }
                
                self?.react(cellViewModel, with: emoji, using: dependencies)
            },
            dismissHandler: { [weak self] in
                self?.showInputAccessoryView()
            }
        )
        
        present(emojiPicker, animated: true, completion: nil)
    }
    
    func contextMenuDismissed() {
        recoverInputView()
    }
    
    // MARK: --action handling
    
    private func showFailedMessageSheet(for cellViewModel: MessageViewModel, using dependencies: Dependencies) {
        let sheet = UIAlertController(
            title: (cellViewModel.state == .failedToSync ?
                "MESSAGE_DELIVERY_FAILED_SYNC_TITLE".localized() :
                "MESSAGE_DELIVERY_FAILED_TITLE".localized()
            ),
            message: cellViewModel.mostRecentFailureText,
            preferredStyle: .actionSheet
        )
        sheet.addAction(UIAlertAction(title: "TXT_CANCEL_TITLE".localized(), style: .cancel, handler: nil))
        
        if cellViewModel.state != .failedToSync {
            sheet.addAction(UIAlertAction(title: "TXT_DELETE_TITLE".localized(), style: .destructive, handler: { _ in
                Storage.shared.writeAsync { db in
                    try Interaction
                        .filter(id: cellViewModel.id)
                        .deleteAll(db)
                }
            }))
        }
        
        sheet.addAction(UIAlertAction(
            title: (cellViewModel.state == .failedToSync ?
                "context_menu_resync".localized() :
                "context_menu_resend".localized()
            ),
            style: .default,
            handler: { [weak self] _ in self?.retry(cellViewModel, using: dependencies) }
        ))
        
        // HACK: Extracting this info from the error string is pretty dodgy
        let prefix: String = "HTTP request failed at destination (Service node "
        if let mostRecentFailureText: String = cellViewModel.mostRecentFailureText, mostRecentFailureText.hasPrefix(prefix) {
            let rest = mostRecentFailureText.substring(from: prefix.count)
            
            if let index = rest.firstIndex(of: ")") {
                let snodeAddress = String(rest[rest.startIndex..<index])
                
                sheet.addAction(UIAlertAction(title: "Copy Service Node Info", style: .default) { _ in
                    UIPasteboard.general.string = snodeAddress
                })
            }
        }
        
        Modal.setupForIPadIfNeeded(sheet, targetView: self.view)
        present(sheet, animated: true, completion: nil)
    }
    
    func joinOpenGroup(name: String?, url: String) {
        // Open groups can be unsafe, so always ask the user whether they want to join one
        let finalName: String = (name ?? "Open Group")
        let message: String = "Are you sure you want to join the \(finalName) open group?";
        let modal: ConfirmationModal = ConfirmationModal(
            info: ConfirmationModal.Info(
                title: "Join \(finalName)?",
                body: .attributedText(
                    NSMutableAttributedString(string: message)
                        .adding(
                            attributes: [ .font: UIFont.boldSystemFont(ofSize: Values.smallFontSize) ],
                            range: (message as NSString).range(of: finalName)
                        )
                ),
                confirmTitle: "JOIN_COMMUNITY_BUTTON_TITLE".localized(),
                onConfirm: { modal in
                    guard let presentingViewController: UIViewController = modal.presentingViewController else {
                        return
                    }
                    
                    guard let (room, server, publicKey) = SessionUtil.parseCommunity(url: url) else {
                        let errorModal: ConfirmationModal = ConfirmationModal(
                            info: ConfirmationModal.Info(
                                title: "COMMUNITY_ERROR_GENERIC".localized(),
                                cancelTitle: "BUTTON_OK".localized(),
                                cancelStyle: .alert_text
                            )
                        )
                        
                        return presentingViewController.present(errorModal, animated: true, completion: nil)
                    }
                    
                    Storage.shared
                        .writePublisher { db in
                            OpenGroupManager.shared.add(
                                db,
                                roomToken: room,
                                server: server,
                                publicKey: publicKey,
                                calledFromConfigHandling: false
                            )
                        }
                        .flatMap { successfullyAddedGroup in
                            OpenGroupManager.shared.performInitialRequestsAfterAdd(
                                successfullyAddedGroup: successfullyAddedGroup,
                                roomToken: room,
                                server: server,
                                publicKey: publicKey,
                                calledFromConfigHandling: false
                            )
                        }
                        .subscribe(on: DispatchQueue.global(qos: .userInitiated))
                        .receive(on: DispatchQueue.main)
                        .sinkUntilComplete(
                            receiveCompletion: { result in
                                switch result {
                                    case .finished: break
                                    case .failure(let error):
                                        // If there was a failure then the group will be in invalid state until
                                        // the next launch so remove it (the user will be left on the previous
                                        // screen so can re-trigger the join)
                                        Storage.shared.writeAsync { db in
                                            OpenGroupManager.shared.delete(
                                                db,
                                                openGroupId: OpenGroup.idFor(roomToken: room, server: server),
                                                calledFromConfigHandling: false
                                            )
                                        }
                                        
                                        // Show the user an error indicating they failed to properly join the group
                                        let errorModal: ConfirmationModal = ConfirmationModal(
                                            info: ConfirmationModal.Info(
                                                title: "COMMUNITY_ERROR_GENERIC".localized(),
                                                body: .text(error.localizedDescription),
                                                cancelTitle: "BUTTON_OK".localized(),
                                                cancelStyle: .alert_text
                                            )
                                        )
                                        
                                        presentingViewController.present(errorModal, animated: true, completion: nil)
                                }
                            }
                        )
                }
            )
        )
        
        present(modal, animated: true, completion: nil)
    }
    
    // MARK: - ContextMenuActionDelegate
    
    func info(_ cellViewModel: MessageViewModel, using dependencies: Dependencies) {
        let mediaInfoVC = MediaInfoVC(
            attachments: (cellViewModel.attachments ?? []),
            isOutgoing: (cellViewModel.variant == .standardOutgoing),
            threadId: self.viewModel.threadData.threadId,
            threadVariant: self.viewModel.threadData.threadVariant,
            interactionId: cellViewModel.id
        )
        navigationController?.pushViewController(mediaInfoVC, animated: true)
    }

    func retry(_ cellViewModel: MessageViewModel, using dependencies: Dependencies) {
        guard cellViewModel.id != MessageViewModel.optimisticUpdateId else {
            guard
                let optimisticMessageId: UUID = cellViewModel.optimisticMessageId,
                let optimisticMessageData: ConversationViewModel.OptimisticMessageData = self.viewModel.optimisticMessageData(for: optimisticMessageId)
            else {
                // Show an error for the retry
                let modal: ConfirmationModal = ConfirmationModal(
                    info: ConfirmationModal.Info(
                        title: "ALERT_ERROR_TITLE".localized(),
                        body: .text("FAILED_TO_STORE_OUTGOING_MESSAGE".localized()),
                        cancelTitle: "BUTTON_OK".localized(),
                        cancelStyle: .alert_text
                    )
                )
                
                self.present(modal, animated: true, completion: nil)
                return
            }
            
            // Try to send the optimistic message again
            sendMessage(optimisticData: optimisticMessageData, using: dependencies)
            return
        }
        
        dependencies.storage.writeAsync { [weak self] db in
            guard
                let threadId: String = self?.viewModel.threadData.threadId,
                let threadVariant: SessionThread.Variant = self?.viewModel.threadData.threadVariant,
                let interaction: Interaction = try? Interaction.fetchOne(db, id: cellViewModel.id)
            else { return }
            
            if
                let quote = try? interaction.quote.fetchOne(db),
                let quotedAttachment = try? quote.attachment.fetchOne(db),
                quotedAttachment.isVisualMedia,
                quotedAttachment.downloadUrl == Attachment.nonMediaQuoteFileId,
                let quotedInteraction = try? quote.originalInteraction.fetchOne(db)
            {
                let attachment: Attachment? = {
                    if let attachment = try? quotedInteraction.attachments.fetchOne(db) {
                        return attachment
                    }
                    if
                        let linkPreview = try? quotedInteraction.linkPreview.fetchOne(db),
                        let linkPreviewAttachment = try? linkPreview.attachment.fetchOne(db)
                    {
                        return linkPreviewAttachment
                    }
                       
                    return nil
                }()
                try quote.with(
                    attachmentId: attachment?.cloneAsQuoteThumbnail()?.inserted(db).id
                ).update(db)
            }
            
            // Remove message sending jobs for the same interaction in database
            // Prevent the same message being sent twice
            try Job.filter(Job.Columns.interactionId == interaction.id).deleteAll(db)
            
            try MessageSender.send(
                db,
                interaction: interaction,
                threadId: threadId,
                threadVariant: threadVariant,
                isSyncMessage: (cellViewModel.state == .failedToSync),
                using: dependencies
            )
        }
    }

    func reply(_ cellViewModel: MessageViewModel, using dependencies: Dependencies) {
        let maybeQuoteDraft: QuotedReplyModel? = QuotedReplyModel.quotedReplyForSending(
            threadId: self.viewModel.threadData.threadId,
            authorId: cellViewModel.authorId,
            variant: cellViewModel.variant,
            body: cellViewModel.body,
            timestampMs: cellViewModel.timestampMs,
            attachments: cellViewModel.attachments,
            linkPreviewAttachment: cellViewModel.linkPreviewAttachment,
            currentUserPublicKey: cellViewModel.currentUserPublicKey,
            currentUserBlinded15PublicKey: cellViewModel.currentUserBlinded15PublicKey,
            currentUserBlinded25PublicKey: cellViewModel.currentUserBlinded25PublicKey
        )
        
        guard let quoteDraft: QuotedReplyModel = maybeQuoteDraft else { return }
        
        snInputView.quoteDraftInfo = (
            model: quoteDraft,
            isOutgoing: (cellViewModel.variant == .standardOutgoing)
        )
        snInputView.becomeFirstResponder()
    }

    func copy(_ cellViewModel: MessageViewModel, using dependencies: Dependencies) {
        switch cellViewModel.cellType {
            case .typingIndicator, .dateHeader, .unreadMarker: break
            
            case .textOnlyMessage:
                if cellViewModel.body == nil, let linkPreview: LinkPreview = cellViewModel.linkPreview {
                    UIPasteboard.general.string = linkPreview.url
                    return
                }
                
                UIPasteboard.general.string = cellViewModel.body
            
            case .audio, .voiceMessage, .genericAttachment, .mediaMessage:
                guard
                    cellViewModel.attachments?.count == 1,
                    let attachment: Attachment = cellViewModel.attachments?.first,
                    attachment.isValid,
                    (
                        attachment.state == .downloaded ||
                        attachment.state == .uploaded
                    ),
                    let utiType: String = MIMETypeUtil.utiType(forMIMEType: attachment.contentType),
                    let originalFilePath: String = attachment.originalFilePath,
                    let data: Data = try? Data(contentsOf: URL(fileURLWithPath: originalFilePath))
                else { return }
            
                UIPasteboard.general.setData(data, forPasteboardType: utiType)
        }
    }

    func copySessionID(_ cellViewModel: MessageViewModel) {
        guard cellViewModel.variant == .standardIncoming || cellViewModel.variant == .standardIncomingDeleted else {
            return
        }
        
        UIPasteboard.general.string = cellViewModel.authorId
    }

    func delete(_ cellViewModel: MessageViewModel, using dependencies: Dependencies) {
        switch cellViewModel.variant {
            case .standardIncomingDeleted, .infoCall,
                .infoScreenshotNotification, .infoMediaSavedNotification,
                .infoClosedGroupCreated, .infoClosedGroupUpdated,
                .infoClosedGroupCurrentUserLeft, .infoClosedGroupCurrentUserLeaving, .infoClosedGroupCurrentUserErrorLeaving,
                .infoMessageRequestAccepted, .infoDisappearingMessagesUpdate:
                // Info messages and unsent messages should just trigger a local
                // deletion (they are created as side effects so we wouldn't be
                // able to delete them for all participants anyway)
                Storage.shared.writeAsync { db in
                    _ = try Interaction
                        .filter(id: cellViewModel.id)
                        .deleteAll(db)
                }
                return
                
            case .standardOutgoing, .standardIncoming: break
        }
        
        let threadName: String = self.viewModel.threadData.displayName
        let userPublicKey: String = getUserHexEncodedPublicKey()
        
        // Remote deletion logic
        func deleteRemotely(from viewController: UIViewController?, request: AnyPublisher<Void, Error>, onComplete: (() -> ())?) {
            // Show a loading indicator
            Deferred {
                Future<Void, Error> { resolver in
                    DispatchQueue.main.async {
                        ModalActivityIndicatorViewController.present(fromViewController: viewController, canCancel: false) { _ in
                            resolver(Result.success(()))
                        }
                    }
                }
            }
            .flatMap { _ in request }
            .subscribe(on: DispatchQueue.global(qos: .userInitiated))
            .receive(on: DispatchQueue.main)
            .sinkUntilComplete(
                receiveCompletion: { [weak self] result in
                    switch result {
                        case .failure: break
                        case .finished:
                            // Delete the interaction (and associated data) from the database
                            Storage.shared.writeAsync { db in
                                _ = try Interaction
                                    .filter(id: cellViewModel.id)
                                    .deleteAll(db)
                            }
                    }
                    
                    // Regardless of success we should dismiss and callback
                    if self?.presentedViewController is ModalActivityIndicatorViewController {
                        self?.dismiss(animated: true, completion: nil) // Dismiss the loader
                    }
                    
                    onComplete?()
                }
            )
        }
        
        // How we delete the message differs depending on the type of thread
        switch cellViewModel.threadVariant {
            // Handle open group messages the old way
            case .community:
                // If it's an incoming message the user must have moderator status
                let result: (openGroupServerMessageId: Int64?, openGroup: OpenGroup?)? = Storage.shared.read { db -> (Int64?, OpenGroup?) in
                    (
                        try Interaction
                            .select(.openGroupServerMessageId)
                            .filter(id: cellViewModel.id)
                            .asRequest(of: Int64.self)
                            .fetchOne(db),
                        try OpenGroup.fetchOne(db, id: cellViewModel.threadId)
                    )
                }
                
                guard
                    let openGroup: OpenGroup = result?.openGroup,
                    let openGroupServerMessageId: Int64 = result?.openGroupServerMessageId, (
                        cellViewModel.variant != .standardIncoming ||
                        OpenGroupManager.isUserModeratorOrAdmin(
                            userPublicKey,
                            for: openGroup.roomToken,
                            on: openGroup.server
                        )
                    )
                else {
                    // If the message hasn't been sent yet then just delete locally
                    guard cellViewModel.state == .sending || cellViewModel.state == .failed else { return }
                    
                    // Retrieve any message send jobs for this interaction
                    let jobs: [Job] = Storage.shared
                        .read { db in
                            try? Job
                                .filter(Job.Columns.variant == Job.Variant.messageSend)
                                .filter(Job.Columns.interactionId == cellViewModel.id)
                                .fetchAll(db)
                        }
                        .defaulting(to: [])
                    
                    // If the job is currently running then wait until it's done before triggering
                    // the deletion
                    let targetJob: Job? = jobs.first(where: { JobRunner.isCurrentlyRunning($0) })
                    
                    guard targetJob == nil else {
                        JobRunner.afterCurrentlyRunningJob(targetJob) { [weak self] result in
                            switch result {
                                // If it succeeded then we'll need to delete from the server so re-run
                                // this function (if we still don't have the server id for some reason
                                // then this would result in a local-only deletion which should be fine
                                case .succeeded: self?.delete(cellViewModel)
                                    
                                // Otherwise we just need to cancel the pending job (in case it retries)
                                // and delete the interaction
                                default:
                                    JobRunner.removePendingJob(targetJob)
                                    
                                    Storage.shared.writeAsync { db in
                                        _ = try Interaction
                                            .filter(id: cellViewModel.id)
                                            .deleteAll(db)
                                    }
                            }
                        }
                        return
                    }
                    
                    // If it's not currently running then remove any pending jobs (just to be safe) and
                    // delete the interaction locally
                    jobs.forEach { JobRunner.removePendingJob($0) }
                    
                    Storage.shared.writeAsync { db in
                        _ = try Interaction
                            .filter(id: cellViewModel.id)
                            .deleteAll(db)
                    }
                    return
                }
                
                // Delete the message from the open group
                deleteRemotely(
                    from: self,
                    request: Storage.shared
                        .readPublisher { db in
                            try OpenGroupAPI.preparedMessageDelete(
                                db,
                                id: openGroupServerMessageId,
                                in: openGroup.roomToken,
                                on: openGroup.server
                            )
                        }
                        .flatMap { OpenGroupAPI.send(data: $0) }
                        .map { _ in () }
                        .eraseToAnyPublisher()
                ) { [weak self] in
                    self?.showInputAccessoryView()
                }
                
            case .contact, .legacyGroup, .group:
                let targetPublicKey: String = (cellViewModel.threadVariant == .contact ?
                    userPublicKey :
                    cellViewModel.threadId
                )
                let serverHash: String? = Storage.shared.read { db -> String? in
                    try Interaction
                        .select(.serverHash)
                        .filter(id: cellViewModel.id)
                        .asRequest(of: String.self)
                        .fetchOne(db)
                }
                let unsendRequest: UnsendRequest = UnsendRequest(
                    timestamp: UInt64(cellViewModel.timestampMs),
                    author: (cellViewModel.variant == .standardOutgoing ?
                        userPublicKey :
                        cellViewModel.authorId
                    )
                )
                .with(
                    expiresInSeconds: cellViewModel.expiresInSeconds,
                    expiresStartedAtMs: cellViewModel.expiresStartedAtMs
                )
                
                // For incoming interactions or interactions with no serverHash just delete them locally
                guard cellViewModel.variant == .standardOutgoing, let serverHash: String = serverHash else {
                    Storage.shared.writeAsync { db in
                        _ = try Interaction
                            .filter(id: cellViewModel.id)
                            .deleteAll(db)
                        
                        // No need to send the unsendRequest if there is no serverHash (ie. the message
                        // was outgoing but never got to the server)
                        guard serverHash != nil else { return }
                        
                        MessageSender
                            .send(
                                db,
                                message: unsendRequest,
                                threadId: cellViewModel.threadId,
                                interactionId: nil,
                                to: .contact(publicKey: userPublicKey),
                                using: dependencies
                            )
                    }
                    return
                }
                
                let actionSheet: UIAlertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
                actionSheet.addAction(UIAlertAction(
                    title: "delete_message_for_me".localized(),
                    accessibilityIdentifier: "Delete for me",
                    style: .destructive
                ) { [weak self] _ in
                    Storage.shared.writeAsync { db in
                        _ = try Interaction
                            .filter(id: cellViewModel.id)
                            .deleteAll(db)
                        
                        MessageSender
                            .send(
                                db,
                                message: unsendRequest,
                                threadId: cellViewModel.threadId,
                                interactionId: nil,
                                to: .contact(publicKey: userPublicKey),
                                using: dependencies
                            )
                    }
                    self?.showInputAccessoryView()
                })
                
                actionSheet.addAction(UIAlertAction(
                    title: {
                        switch cellViewModel.threadVariant {
                            case .legacyGroup, .group: return "delete_message_for_everyone".localized()
                            default:
                                return (cellViewModel.threadId == userPublicKey ?
                                    "delete_message_for_me_and_my_devices".localized() :
                                    String(format: "delete_message_for_me_and_recipient".localized(), threadName)
                                )
                        }
                    }(),
                    accessibilityIdentifier: "Delete for everyone",
                    style: .destructive
                ) { [weak self] _ in
                    let completeServerDeletion = { [weak self] in
                        Storage.shared.writeAsync { db in
                            try MessageSender
                                .send(
                                    db,
                                    message: unsendRequest,
                                    interactionId: nil,
                                    threadId: cellViewModel.threadId,
                                    threadVariant: cellViewModel.threadVariant,
                                    using: dependencies
                                )
                        }
                        
                        self?.showInputAccessoryView()
                    }
                    
                    // We can only delete messages on the server for `contact` and `group` conversations
                    guard cellViewModel.threadVariant == .contact || cellViewModel.threadVariant == .group else {
                        return completeServerDeletion()
                    }
                    
                    deleteRemotely(
                        from: self,
                        request: SnodeAPI
                            .deleteMessages(
                                publicKey: targetPublicKey,
                                serverHashes: [serverHash]
                            )
                            .map { _ in () }
                            .eraseToAnyPublisher()
                    ) { completeServerDeletion() }
                })

                actionSheet.addAction(UIAlertAction.init(title: "TXT_CANCEL_TITLE".localized(), style: .cancel) { [weak self] _ in
                    self?.showInputAccessoryView()
                })

                self.hideInputAccessoryView()
                Modal.setupForIPadIfNeeded(actionSheet, targetView: self.view)
                self.present(actionSheet, animated: true)
        }
    }

    func save(_ cellViewModel: MessageViewModel, using dependencies: Dependencies) {
        guard cellViewModel.cellType == .mediaMessage else { return }
        
        let mediaAttachments: [(Attachment, String)] = (cellViewModel.attachments ?? [])
            .filter { attachment in
                attachment.isValid &&
                attachment.isVisualMedia && (
                    attachment.state == .downloaded ||
                    attachment.state == .uploaded
                )
            }
            .compactMap { attachment in
                guard let originalFilePath: String = attachment.originalFilePath else { return nil }
                
                return (attachment, originalFilePath)
            }
        
        guard !mediaAttachments.isEmpty else { return }
    
        mediaAttachments.forEach { attachment, originalFilePath in
            PHPhotoLibrary.shared().performChanges(
                {
                    if attachment.isImage || attachment.isAnimated {
                        PHAssetChangeRequest.creationRequestForAssetFromImage(
                            atFileURL: URL(fileURLWithPath: originalFilePath)
                        )
                    }
                    else if attachment.isVideo {
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(
                            atFileURL: URL(fileURLWithPath: originalFilePath)
                        )
                    }
                },
                completionHandler: { _, _ in }
            )
        }
        
        // Send a 'media saved' notification if needed
        guard self.viewModel.threadData.threadVariant == .contact, cellViewModel.variant == .standardIncoming else {
            return
        }
        
        sendDataExtraction(kind: .mediaSaved(timestamp: UInt64(cellViewModel.timestampMs)))
    }

    func ban(_ cellViewModel: MessageViewModel, using dependencies: Dependencies) {
        guard cellViewModel.threadVariant == .community else { return }
        
        let threadId: String = self.viewModel.threadData.threadId
        let modal: ConfirmationModal = ConfirmationModal(
            targetView: self.view,
            info: ConfirmationModal.Info(
                title: "Session",
                body: .text("This will ban the selected user from this room. It won't ban them from other rooms."),
                confirmTitle: "BUTTON_OK".localized(),
                cancelStyle: .alert_text,
                onConfirm: { [weak self] _ in
                    Storage.shared
                        .readPublisher { db -> OpenGroupAPI.PreparedSendData<NoResponse> in
                            guard let openGroup: OpenGroup = try OpenGroup.fetchOne(db, id: threadId) else {
                                throw StorageError.objectNotFound
                            }
                            
                            return try OpenGroupAPI
                                .preparedUserBan(
                                    db,
                                    sessionId: cellViewModel.authorId,
                                    from: [openGroup.roomToken],
                                    on: openGroup.server
                                )
                        }
                        .flatMap { OpenGroupAPI.send(data: $0) }
                        .subscribe(on: DispatchQueue.global(qos: .userInitiated))
                        .receive(on: DispatchQueue.main)
                        .sinkUntilComplete(
                            receiveCompletion: { result in
                                switch result {
                                    case .finished: break
                                    case .failure:
                                        let modal: ConfirmationModal = ConfirmationModal(
                                            targetView: self?.view,
                                            info: ConfirmationModal.Info(
                                                title: CommonStrings.errorAlertTitle,
                                                body: .text("context_menu_ban_user_error_alert_message".localized()),
                                                cancelTitle: "BUTTON_OK".localized(),
                                                cancelStyle: .alert_text
                                            )
                                        )
                                        self?.present(modal, animated: true)
                                }
                            }
                        )
                    
                    self?.becomeFirstResponder()
                },
                afterClosed: { [weak self] in self?.becomeFirstResponder() }
            )
        )
        self.present(modal, animated: true)
    }

    func banAndDeleteAllMessages(_ cellViewModel: MessageViewModel, using dependencies: Dependencies) {
        guard cellViewModel.threadVariant == .community else { return }
        
        let threadId: String = self.viewModel.threadData.threadId
        let modal: ConfirmationModal = ConfirmationModal(
            targetView: self.view,
            info: ConfirmationModal.Info(
                title: "Session",
                body: .text("This will ban the selected user from this room and delete all messages sent by them. It won't ban them from other rooms or delete the messages they sent there."),
                confirmTitle: "BUTTON_OK".localized(),
                cancelStyle: .alert_text,
                onConfirm: { [weak self] _ in
                    Storage.shared
                        .readPublisher { db in
                            guard let openGroup: OpenGroup = try OpenGroup.fetchOne(db, id: threadId) else {
                                throw StorageError.objectNotFound
                            }
                        
                            return try OpenGroupAPI
                                .preparedUserBanAndDeleteAllMessages(
                                    db,
                                    sessionId: cellViewModel.authorId,
                                    in: openGroup.roomToken,
                                    on: openGroup.server
                                )
                        }
                        .flatMap { OpenGroupAPI.send(data: $0) }
                        .subscribe(on: DispatchQueue.global(qos: .userInitiated))
                        .receive(on: DispatchQueue.main)
                        .sinkUntilComplete(
                            receiveCompletion: { result in
                                switch result {
                                    case .finished: break
                                    case .failure:
                                        let modal: ConfirmationModal = ConfirmationModal(
                                            targetView: self?.view,
                                            info: ConfirmationModal.Info(
                                                title: CommonStrings.errorAlertTitle,
                                                body: .text("context_menu_ban_user_error_alert_message".localized()),
                                                cancelTitle: "BUTTON_OK".localized(),
                                                cancelStyle: .alert_text
                                            )
                                        )
                                        self?.present(modal, animated: true)
                                }
                            }
                        )
                    
                    self?.becomeFirstResponder()
                },
                afterClosed: { [weak self] in self?.becomeFirstResponder() }
            )
        )
        self.present(modal, animated: true)
    }

    // MARK: - VoiceMessageRecordingViewDelegate

    func startVoiceMessageRecording(using dependencies: Dependencies) {
        // Request permission if needed
        Permissions.requestMicrophonePermissionIfNeeded() { [weak self] in
            DispatchQueue.main.async {
                self?.cancelVoiceMessageRecording()
            }
        }
        
        // Keep screen on
        UIApplication.shared.isIdleTimerDisabled = false
        guard AVAudioSession.sharedInstance().recordPermission == .granted else { return }
        
        // Cancel any current audio playback
        self.viewModel.stopAudio()
        
        // Create URL
        let directory: String = Singleton.appContext.temporaryDirectory
        let fileName: String = "\(SnodeAPI.currentOffsetTimestampMs()).m4a"
        let url: URL = URL(fileURLWithPath: directory).appendingPathComponent(fileName)
        
        // Set up audio session
        guard Environment.shared?.audioSession.startAudioActivity(recordVoiceMessageActivity) == true else {
            return cancelVoiceMessageRecording()
        }
        
        // Set up audio recorder
        let audioRecorder: AVAudioRecorder
        do {
            audioRecorder = try AVAudioRecorder(
                url: url,
                settings: [
                    AVFormatIDKey: NSNumber(value: kAudioFormatMPEG4AAC),
                    AVSampleRateKey: NSNumber(value: 44100),
                    AVNumberOfChannelsKey: NSNumber(value: 2),
                    AVEncoderBitRateKey: NSNumber(value: 128 * 1024)
                ]
            )
            audioRecorder.isMeteringEnabled = true
            self.audioRecorder = audioRecorder
        }
        catch {
            SNLog("Couldn't start audio recording due to error: \(error).")
            return cancelVoiceMessageRecording()
        }
        
        // Limit voice messages to a minute
        audioTimer = Timer.scheduledTimer(withTimeInterval: 180, repeats: false, block: { [weak self] _ in
            self?.snInputView.hideVoiceMessageUI()
            self?.endVoiceMessageRecording(using: dependencies)
        })
        
        // Prepare audio recorder and start recording
        let successfullyPrepared: Bool = audioRecorder.prepareToRecord()
        let startedRecording: Bool = (successfullyPrepared && audioRecorder.record())
        
        
        guard successfullyPrepared && startedRecording else {
            SNLog(successfullyPrepared ? "Couldn't record audio." : "Couldn't prepare audio recorder.")
            
            // Dispatch to the next run loop to avoid
            DispatchQueue.main.async {
                let modal: ConfirmationModal = ConfirmationModal(
                    targetView: self.view,
                    info: ConfirmationModal.Info(
                        title: "ALERT_ERROR_TITLE".localized(),
                        body: .text("VOICE_MESSAGE_FAILED_TO_START_MESSAGE".localized()),
                        cancelTitle: "BUTTON_OK".localized(),
                        cancelStyle: .alert_text
                    )
                )
                self.present(modal, animated: true)
            }
            
            return cancelVoiceMessageRecording()
        }
    }

    func endVoiceMessageRecording(using dependencies: Dependencies) {
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Hide the UI
        snInputView.hideVoiceMessageUI()
        
        // Cancel the timer
        audioTimer?.invalidate()
        
        // Check preconditions
        guard let audioRecorder = audioRecorder else { return }
        
        // Get duration
        let duration = audioRecorder.currentTime
        
        // Stop the recording
        stopVoiceMessageRecording()
        
        // Check for user misunderstanding
        guard duration > 1 else {
            self.audioRecorder = nil
            
            let modal: ConfirmationModal = ConfirmationModal(
                targetView: self.view,
                info: ConfirmationModal.Info(
                    title: "VOICE_MESSAGE_TOO_SHORT_ALERT_TITLE".localized(),
                    body: .text("VOICE_MESSAGE_TOO_SHORT_ALERT_MESSAGE".localized()),
                    cancelTitle: "BUTTON_OK".localized(),
                    cancelStyle: .alert_text
                )
            )
            self.present(modal, animated: true)
            return
        }
        
        // Get data
        let dataSourceOrNil = DataSourcePath.dataSource(with: audioRecorder.url, shouldDeleteOnDeallocation: true)
        self.audioRecorder = nil
        
        guard let dataSource = dataSourceOrNil else { return SNLog("Couldn't load recorded data.") }
        
        // Create attachment
        let fileName = ("VOICE_MESSAGE_FILE_NAME".localized() as NSString).appendingPathExtension("m4a")
        dataSource.sourceFilename = fileName
        
        let attachment = SignalAttachment.voiceMessageAttachment(dataSource: dataSource, dataUTI: kUTTypeMPEG4Audio as String)
        
        guard !attachment.hasError else {
            return showErrorAlert(for: attachment)
        }
        
        // Send attachment
        sendMessage(text: "", attachments: [attachment], using: dependencies)
    }

    func cancelVoiceMessageRecording() {
        snInputView.hideVoiceMessageUI()
        audioTimer?.invalidate()
        stopVoiceMessageRecording()
        audioRecorder = nil
    }

    func stopVoiceMessageRecording() {
        audioRecorder?.stop()
        Environment.shared?.audioSession.endAudioActivity(recordVoiceMessageActivity)
    }
    
    // MARK: - Data Extraction Notifications
    
    @objc func sendScreenshotNotification() { sendDataExtraction(kind: .screenshot) }
    
    func sendDataExtraction(
        kind: DataExtractionNotification.Kind,
        using dependencies: Dependencies = Dependencies()
    ) {
        // Only send screenshot notifications to one-to-one conversations
        guard self.viewModel.threadData.threadVariant == .contact else { return }
        
        let threadId: String = self.viewModel.threadData.threadId
        let threadVariant: SessionThread.Variant = self.viewModel.threadData.threadVariant
        
        dependencies.storage.writeAsync { db in
            try MessageSender.send(
                db,
                message: DataExtractionNotification(
                    kind: kind,
                    sentTimestamp: UInt64(SnodeAPI.currentOffsetTimestampMs())
                )
                .with(DisappearingMessagesConfiguration
                    .fetchOne(db, id: threadId)?
                    .forcedWithDisappearAfterReadIfNeeded()
                ),
                interactionId: nil,
                threadId: threadId,
                threadVariant: threadVariant,
                using: dependencies
            )
        }
    }

    // MARK: - Convenience
    
    func showErrorAlert(for attachment: SignalAttachment) {
        let modal: ConfirmationModal = ConfirmationModal(
            targetView: self.view,
            info: ConfirmationModal.Info(
                title: "ATTACHMENT_ERROR_ALERT_TITLE".localized(),
                body: .text(attachment.localizedErrorDescription ?? SignalAttachment.missingDataErrorMessage),
                cancelTitle: "BUTTON_OK".localized(),
                cancelStyle: .alert_text
            )
        )
        self.present(modal, animated: true)
    }
}

// MARK: - UIDocumentInteractionControllerDelegate

extension ConversationVC: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
}

// MARK: - Message Request Actions

extension ConversationVC {
    fileprivate func approveMessageRequestIfNeeded(
        for threadId: String,
        threadVariant: SessionThread.Variant,
        isNewThread: Bool,
        timestampMs: Int64,
        using dependencies: Dependencies = Dependencies()
    ) {
        guard threadVariant == .contact else { return }
        
        let updateNavigationBackStack: () -> Void = {
            // Remove the 'SessionTableViewController<MessageRequestsViewModel>' from the nav hierarchy if present
            DispatchQueue.main.async { [weak self] in
                if
                    let viewControllers: [UIViewController] = self?.navigationController?.viewControllers,
                    let messageRequestsIndex = viewControllers
                        .firstIndex(where: { viewCon -> Bool in
                            (viewCon as? SessionViewModelAccessible)?.viewModelType == MessageRequestsViewModel.self
                        }),
                    messageRequestsIndex > 0
                {
                    var newViewControllers = viewControllers
                    newViewControllers.remove(at: messageRequestsIndex)
                    self?.navigationController?.viewControllers = newViewControllers
                }
            }
        }

        // If the contact doesn't exist then we should create it so we can store the 'isApproved' state
        // (it'll be updated with correct profile info if they accept the message request so this
        // shouldn't cause weird behaviours)
        guard
            let contact: Contact = Storage.shared.read({ db in Contact.fetchOrCreate(db, id: threadId) }),
            !contact.isApproved
        else { return }
        
        Storage.shared
            .writePublisher { db in
                // If we aren't creating a new thread (ie. sending a message request) then send a
                // messageRequestResponse back to the sender (this allows the sender to know that
                // they have been approved and can now use this contact in closed groups)
                if !isNewThread {
                    try MessageSender.send(
                        db,
                        message: MessageRequestResponse(
                            isApproved: true,
                            sentTimestampMs: UInt64(timestampMs)
                        ),
                        interactionId: nil,
                        threadId: threadId,
                        threadVariant: threadVariant,
                        using: dependencies
                    )
                }
                
                // Default 'didApproveMe' to true for the person approving the message request
                try contact.save(db)
                try Contact
                    .filter(id: contact.id)
                    .updateAllAndConfig(
                        db,
                        Contact.Columns.isApproved.set(to: true),
                        Contact.Columns.didApproveMe
                            .set(to: contact.didApproveMe || !isNewThread)
                    )
            }
            .subscribe(on: DispatchQueue.global(qos: .userInitiated))
            .receive(on: DispatchQueue.main)
            .sinkUntilComplete(
                receiveCompletion: { _ in
                    // Update the UI
                    updateNavigationBackStack()
                }
            )
    }

    @objc func acceptMessageRequest() {
        self.approveMessageRequestIfNeeded(
            for: self.viewModel.threadData.threadId,
            threadVariant: self.viewModel.threadData.threadVariant,
            isNewThread: false,
            timestampMs: SnodeAPI.currentOffsetTimestampMs()
        )
    }

    @objc func deleteMessageRequest() {
        let actions: [UIContextualAction]? = UIContextualAction.generateSwipeActions(
            [.delete],
            for: .trailing,
            indexPath: IndexPath(row: 0, section: 0),
            tableView: self.tableView,
            threadViewModel: self.viewModel.threadData,
            viewController: self
        )
        
        guard let action: UIContextualAction = actions?.first else { return }
        
        action.handler(action, self.view, { [weak self] didConfirm in
            guard didConfirm else { return }
            
            self?.stopObservingChanges()
            
            DispatchQueue.main.async {
                self?.navigationController?.popViewController(animated: true)
            }
        })
    }
    
    @objc func blockMessageRequest() {
        let actions: [UIContextualAction]? = UIContextualAction.generateSwipeActions(
            [.block],
            for: .trailing,
            indexPath: IndexPath(row: 0, section: 0),
            tableView: self.tableView,
            threadViewModel: self.viewModel.threadData,
            viewController: self
        )
        
        guard let action: UIContextualAction = actions?.first else { return }
        
        action.handler(action, self.view, { [weak self] didConfirm in
            guard didConfirm else { return }
            
            self?.stopObservingChanges()
            
            DispatchQueue.main.async {
                self?.navigationController?.popViewController(animated: true)
            }
        })
    }
}

// MARK: - MediaPresentationContextProvider

extension ConversationVC: MediaPresentationContextProvider {
    func mediaPresentationContext(mediaItem: Media, in coordinateSpace: UICoordinateSpace) -> MediaPresentationContext? {
        guard case let .gallery(galleryItem) = mediaItem else { return nil }
        
        // Note: According to Apple's docs the 'indexPathsForVisibleRows' method returns an
        // unsorted array which means we can't use it to determine the desired 'visibleCell'
        // we are after, due to this we will need to iterate all of the visible cells to find
        // the one we want
        let maybeMessageCell: VisibleMessageCell? = tableView.visibleCells
            .first { cell -> Bool in
                ((cell as? VisibleMessageCell)?
                    .albumView?
                    .itemViews
                    .contains(where: { mediaView in
                        mediaView.attachment.id == galleryItem.attachment.id
                    }))
                    .defaulting(to: false)
            }
            .map { $0 as? VisibleMessageCell }
        let maybeTargetView: MediaView? = maybeMessageCell?
            .albumView?
            .itemViews
            .first(where: { $0.attachment.id == galleryItem.attachment.id })
        
        guard
            let messageCell: VisibleMessageCell = maybeMessageCell,
            let targetView: MediaView = maybeTargetView,
            let mediaSuperview: UIView = targetView.superview
        else { return nil }

        let cornerRadius: CGFloat
        let cornerMask: CACornerMask
        let presentationFrame: CGRect = coordinateSpace.convert(targetView.frame, from: mediaSuperview)
        let frameInBubble: CGRect = messageCell.bubbleView.convert(targetView.frame, from: mediaSuperview)

        if messageCell.bubbleView.bounds == targetView.bounds {
            cornerRadius = messageCell.bubbleView.layer.cornerRadius
            cornerMask = messageCell.bubbleView.layer.maskedCorners
        }
        else {
            // If the frames don't match then assume it's either multiple images or there is a caption
            // and determine which corners need to be rounded
            cornerRadius = messageCell.bubbleView.layer.cornerRadius

            var newCornerMask = CACornerMask()
            let cellMaskedCorners: CACornerMask = messageCell.bubbleView.layer.maskedCorners

            if
                cellMaskedCorners.contains(.layerMinXMinYCorner) &&
                    frameInBubble.minX < CGFloat.leastNonzeroMagnitude &&
                    frameInBubble.minY < CGFloat.leastNonzeroMagnitude
            {
                newCornerMask.insert(.layerMinXMinYCorner)
            }

            if
                cellMaskedCorners.contains(.layerMaxXMinYCorner) &&
                abs(frameInBubble.maxX - messageCell.bubbleView.bounds.width) < CGFloat.leastNonzeroMagnitude &&
                    frameInBubble.minY < CGFloat.leastNonzeroMagnitude
            {
                newCornerMask.insert(.layerMaxXMinYCorner)
            }

            if
                cellMaskedCorners.contains(.layerMinXMaxYCorner) &&
                    frameInBubble.minX < CGFloat.leastNonzeroMagnitude &&
                abs(frameInBubble.maxY - messageCell.bubbleView.bounds.height) < CGFloat.leastNonzeroMagnitude
            {
                newCornerMask.insert(.layerMinXMaxYCorner)
            }

            if
                cellMaskedCorners.contains(.layerMaxXMaxYCorner) &&
                abs(frameInBubble.maxX - messageCell.bubbleView.bounds.width) < CGFloat.leastNonzeroMagnitude &&
                abs(frameInBubble.maxY - messageCell.bubbleView.bounds.height) < CGFloat.leastNonzeroMagnitude
            {
                newCornerMask.insert(.layerMaxXMaxYCorner)
            }

            cornerMask = newCornerMask
        }
        
        return MediaPresentationContext(
            mediaView: targetView,
            presentationFrame: presentationFrame,
            cornerRadius: cornerRadius,
            cornerMask: cornerMask
        )
    }

    func snapshotOverlayView(in coordinateSpace: UICoordinateSpace) -> (UIView, CGRect)? {
        return self.navigationController?.navigationBar.generateSnapshot(in: coordinateSpace)
    }
}
