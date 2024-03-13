// Copyright © 2023 Rangeproof Pty Ltd. All rights reserved.

import UIKit
import SessionMessagingKit
import SessionUIKit
import SessionUtilitiesKit

protocol SwipeActionOptimisticCell {
    func optimisticUpdate(isMuted: Bool?, isBlocked: Bool?, isPinned: Bool?, hasUnread: Bool?)
}

extension SwipeActionOptimisticCell {
    public func optimisticUpdate(isMuted: Bool) {
        optimisticUpdate(isMuted: isMuted, isBlocked: nil, isPinned: nil, hasUnread: nil)
    }
    
    public func optimisticUpdate(isBlocked: Bool) {
        optimisticUpdate(isMuted: nil, isBlocked: isBlocked, isPinned: nil, hasUnread: nil)
    }
    
    public func optimisticUpdate(isPinned: Bool) {
        optimisticUpdate(isMuted: nil, isBlocked: nil, isPinned: isPinned, hasUnread: nil)
    }
    
    public func optimisticUpdate(hasUnread: Bool) {
        optimisticUpdate(isMuted: nil, isBlocked: nil, isPinned: nil, hasUnread: hasUnread)
    }
}

public extension UIContextualAction {
    enum SwipeAction {
        case toggleReadStatus
        case hide
        case pin
        case mute
        case block
        case leave
        case delete
    }
    
    static func configuration(for actions: [UIContextualAction]?) -> UISwipeActionsConfiguration? {
        return actions.map { UISwipeActionsConfiguration(actions: $0) }
    }
    
    static func generateSwipeActions(
        _ actions: [SwipeAction],
        for side: UIContextualAction.Side,
        indexPath: IndexPath,
        tableView: UITableView,
        threadViewModel: SessionThreadViewModel,
        viewController: UIViewController?
    ) -> [UIContextualAction]? {
        guard !actions.isEmpty else { return nil }
        
        let unswipeAnimationDelay: DispatchTimeInterval = .milliseconds(500)
        
        // Note: for some reason the `UISwipeActionsConfiguration` expects actions to be left-to-right
        // for leading actions, but right-to-left for trailing actions...
        let targetActions: [SwipeAction] = (side == .trailing ? actions.reversed() : actions)
        let actionBackgroundColor: [ThemeValue] = [
            .conversationButton_swipeDestructive,
            .conversationButton_swipeSecondary,
            .conversationButton_swipeTertiary
        ]
        
        return targetActions
            .enumerated()
            .map { index, action -> UIContextualAction in
                // Even though we have to reverse the actions above, the indexes in the view hierarchy
                // are in the expected order
                let targetIndex: Int = (side == .trailing ? (targetActions.count - index) : index)
                let themeBackgroundColor: ThemeValue = actionBackgroundColor[
                    index % actionBackgroundColor.count
                ]
                
                switch action {
                    // MARK: -- toggleReadStatus
                        
                    case .toggleReadStatus:
                        let isUnread: Bool = (
                            threadViewModel.threadWasMarkedUnread == true ||
                            (threadViewModel.threadUnreadCount ?? 0) > 0
                        )
                        
                        return UIContextualAction(
                            title: (isUnread ?
                                "MARK_AS_READ".localized() :
                                "MARK_AS_UNREAD".localized()
                            ),
                            icon: (isUnread ?
                                UIImage(systemName: "envelope.open") :
                                UIImage(systemName: "envelope.badge")
                            ),
                            themeTintColor: .white,
                            themeBackgroundColor: .conversationButton_swipeRead,    // Always Custom
                            side: side,
                            actionIndex: targetIndex,
                            indexPath: indexPath,
                            tableView: tableView
                        ) { _, _, completionHandler  in
                            // Delay the change to give the cell "unswipe" animation some time to complete
                            DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + unswipeAnimationDelay) {
                                switch isUnread {
                                    case true: threadViewModel.markAsRead(
                                        target: .threadAndInteractions(
                                            interactionsBeforeInclusive: threadViewModel.interactionId
                                        )
                                    )
                                        
                                    case false: threadViewModel.markAsUnread()
                                }
                            }
                            completionHandler(true)
                        }
                        
                    // MARK: -- hide
                        
                    case .hide:
                        return UIContextualAction(
                            title: "TXT_HIDE_TITLE".localized(),
                            icon: UIImage(systemName: "eye.slash"),
                            themeTintColor: .white,
                            themeBackgroundColor: themeBackgroundColor,
                            side: side,
                            actionIndex: targetIndex,
                            indexPath: indexPath,
                            tableView: tableView
                        ) { _, _, completionHandler  in
                            switch threadViewModel.threadId {
                                case SessionThreadViewModel.messageRequestsSectionId:
                                    Storage.shared.write { db in db[.hasHiddenMessageRequests] = true }
                                    completionHandler(true)
                                    
                                default:
                                    let confirmationModalExplanation: NSAttributedString = {
                                        let message = String(
                                            format: "hide_note_to_self_confirmation_alert_message".localized(),
                                            threadViewModel.displayName
                                        )
                                        
                                        return NSAttributedString(string: message)
                                            .adding(
                                                attributes: [
                                                    .font: UIFont.boldSystemFont(ofSize: Values.smallFontSize)
                                                ],
                                                range: (message as NSString).range(of: threadViewModel.displayName)
                                            )
                                    }()
                                    
                                    let confirmationModal: ConfirmationModal = ConfirmationModal(
                                        info: ConfirmationModal.Info(
                                            title: "hide_note_to_self_confirmation_alert_title".localized(),
                                            body: .attributedText(confirmationModalExplanation),
                                            confirmTitle: "TXT_HIDE_TITLE".localized(),
                                            confirmAccessibility: Accessibility(
                                                identifier: "Hide"
                                            ),
                                            confirmStyle: .danger,
                                            cancelStyle: .alert_text,
                                            dismissOnConfirm: true,
                                            onConfirm: { _ in
                                                Storage.shared.writeAsync { db in
                                                    try SessionThread.deleteOrLeave(
                                                        db,
                                                        threadId: threadViewModel.threadId,
                                                        threadVariant: threadViewModel.threadVariant,
                                                        groupLeaveType: .silent,
                                                        calledFromConfigHandling: false
                                                    )
                                                }
                                                viewController?.dismiss(animated: true, completion: nil)
                                                
                                                completionHandler(true)
                                            },
                                            afterClosed: { completionHandler(false) }
                                        )
                                    )
                                    
                                    viewController?.present(confirmationModal, animated: true, completion: nil)
                            }
                        }
                        
                    // MARK: -- pin
                        
                    case .pin:
                        return UIContextualAction(
                            title: (threadViewModel.threadPinnedPriority > 0 ?
                                "UNPIN_BUTTON_TEXT".localized() :
                                "PIN_BUTTON_TEXT".localized()
                            ),
                            icon: (threadViewModel.threadPinnedPriority > 0 ?
                                UIImage(systemName: "pin.slash") :
                                UIImage(systemName: "pin")
                            ),
                            themeTintColor: .white,
                            themeBackgroundColor: .conversationButton_swipeTertiary,    // Always Tertiary
                            side: side,
                            actionIndex: targetIndex,
                            indexPath: indexPath,
                            tableView: tableView
                        ) { _, _, completionHandler in
                            (tableView.cellForRow(at: indexPath) as? SwipeActionOptimisticCell)?
                                .optimisticUpdate(
                                    isPinned: !(threadViewModel.threadPinnedPriority > 0)
                                )
                            completionHandler(true)
                            
                            // Delay the change to give the cell "unswipe" animation some time to complete
                            DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + unswipeAnimationDelay) {
                                Storage.shared.writeAsync { db in
                                    try SessionThread
                                        .filter(id: threadViewModel.threadId)
                                        .updateAllAndConfig(
                                            db,
                                            SessionThread.Columns.pinnedPriority
                                                .set(to: (threadViewModel.threadPinnedPriority == 0 ? 1 : 0))
                                        )
                                }
                            }
                        }

                    // MARK: -- mute

                    case .mute:
                        return UIContextualAction(
                            title: (threadViewModel.threadMutedUntilTimestamp == nil ?
                                "mute_button_text".localized() :
                                "unmute_button_text".localized()
                            ),
                            icon: (threadViewModel.threadMutedUntilTimestamp == nil ?
                                UIImage(systemName: "speaker.slash") :
                                UIImage(systemName: "speaker")
                            ),
                            iconHeight: Values.mediumFontSize,
                            themeTintColor: .white,
                            themeBackgroundColor: themeBackgroundColor,
                            side: side,
                            actionIndex: targetIndex,
                            indexPath: indexPath,
                            tableView: tableView
                        ) { _, _, completionHandler in
                            (tableView.cellForRow(at: indexPath) as? SwipeActionOptimisticCell)?
                                .optimisticUpdate(
                                    isMuted: !(threadViewModel.threadMutedUntilTimestamp != nil)
                                )
                            completionHandler(true)
                            
                            // Delay the change to give the cell "unswipe" animation some time to complete
                            DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + unswipeAnimationDelay) {
                                Storage.shared.writeAsync { db in
                                    let currentValue: TimeInterval? = try SessionThread
                                        .filter(id: threadViewModel.threadId)
                                        .select(.mutedUntilTimestamp)
                                        .asRequest(of: TimeInterval.self)
                                        .fetchOne(db)
                                    
                                    try SessionThread
                                        .filter(id: threadViewModel.threadId)
                                        .updateAll(
                                            db,
                                            SessionThread.Columns.mutedUntilTimestamp.set(
                                                to: (currentValue == nil ?
                                                    Date.distantFuture.timeIntervalSince1970 :
                                                    nil
                                                )
                                            )
                                        )
                                }
                            }
                        }
                        
                    // MARK: -- block
                        
                    case .block:
                        return UIContextualAction(
                            title: (threadViewModel.threadIsBlocked == true ?
                                "BLOCK_LIST_UNBLOCK_BUTTON".localized() :
                                "BLOCK_LIST_BLOCK_BUTTON".localized()
                            ),
                            icon: UIImage(named: "table_ic_block"),
                            iconHeight: Values.mediumFontSize,
                            themeTintColor: .white,
                            themeBackgroundColor: themeBackgroundColor,
                            side: side,
                            actionIndex: targetIndex,
                            indexPath: indexPath,
                            tableView: tableView
                        ) { [weak viewController] _, _, completionHandler in
                            let threadIsBlocked: Bool = (threadViewModel.threadIsBlocked == true)
                            let threadIsMessageRequest: Bool = (threadViewModel.threadIsMessageRequest == true)
                            let contactChanges: [ConfigColumnAssignment] = [
                                Contact.Columns.isBlocked.set(to: !threadIsBlocked),
                                
                                /// **Note:** We set `didApproveMe` to `true` so the current user will be able to send a
                                /// message to the person who originally sent them the message request in the future if they
                                /// unblock them
                                (!threadIsMessageRequest ? nil : Contact.Columns.didApproveMe.set(to: true)),
                                (!threadIsMessageRequest ? nil : Contact.Columns.isApproved.set(to: false))
                            ].compactMap { $0 }
                            
                            let performBlock: (UIViewController?) -> () = { viewController in
                                (tableView.cellForRow(at: indexPath) as? SwipeActionOptimisticCell)?
                                    .optimisticUpdate(
                                        isBlocked: !threadIsBlocked
                                    )
                                viewController?.dismiss(animated: true, completion: nil)
                                completionHandler(true)
                                
                                // Delay the change to give the cell "unswipe" animation some time to complete
                                DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + unswipeAnimationDelay) {
                                    Storage.shared
                                        .writePublisher { db in
                                            // Create the contact if it doesn't exist
                                            try Contact
                                                .fetchOrCreate(db, id: threadViewModel.threadId)
                                                .save(db)
                                            try Contact
                                                .filter(id: threadViewModel.threadId)
                                                .updateAllAndConfig(db, contactChanges)
                                            
                                            // Blocked message requests should be deleted
                                            if threadIsMessageRequest {
                                                try SessionThread.deleteOrLeave(
                                                    db,
                                                    threadId: threadViewModel.threadId,
                                                    threadVariant: .contact,
                                                    groupLeaveType: .silent,
                                                    calledFromConfigHandling: false
                                                )
                                            }
                                        }
                                        .subscribe(on: DispatchQueue.global(qos: .userInitiated))
                                        .sinkUntilComplete()
                                }
                            }
                                
                            switch threadIsMessageRequest {
                                case false: performBlock(nil)
                                case true:
                                    let confirmationModal: ConfirmationModal = ConfirmationModal(
                                        info: ConfirmationModal.Info(
                                            title: "MESSAGE_REQUESTS_BLOCK_CONFIRMATION_ACTON".localized(),
                                            confirmTitle: "BLOCK_LIST_BLOCK_BUTTON".localized(),
                                            confirmAccessibility: Accessibility(
                                                identifier: "Block"
                                            ),
                                            confirmStyle: .danger,
                                            cancelStyle: .alert_text,
                                            dismissOnConfirm: true,
                                            onConfirm: { _ in
                                                performBlock(viewController)
                                            },
                                            afterClosed: { completionHandler(false) }
                                        )
                                    )
                                    
                                    viewController?.present(confirmationModal, animated: true, completion: nil)
                            }
                        }

                    // MARK: -- leave

                    case .leave:
                        return UIContextualAction(
                            title: "LEAVE_BUTTON_TITLE".localized(),
                            icon: UIImage(systemName: "rectangle.portrait.and.arrow.right"),
                            iconHeight: Values.mediumFontSize,
                            themeTintColor: .white,
                            themeBackgroundColor: themeBackgroundColor,
                            side: side,
                            actionIndex: targetIndex,
                            indexPath: indexPath,
                            tableView: tableView
                        ) { [weak viewController] _, _, completionHandler in
                            let confirmationModalTitle: String = {
                                switch threadViewModel.threadVariant {
                                    case .legacyGroup, .group:
                                        return "leave_group_confirmation_alert_title".localized()
                                        
                                    default: return "leave_community_confirmation_alert_title".localized()
                                }
                            }()
                            
                            let confirmationModalExplanation: NSAttributedString = {
                                if threadViewModel.currentUserIsClosedGroupAdmin == true {
                                    return NSAttributedString(string: "admin_group_leave_warning".localized())
                                }
                                
                                let mutableAttributedString = NSMutableAttributedString(
                                    string: String(
                                        format: "leave_community_confirmation_alert_message".localized(),
                                        threadViewModel.displayName
                                    )
                                )
                                mutableAttributedString.addAttribute(
                                    .font,
                                    value: UIFont.boldSystemFont(ofSize: Values.smallFontSize),
                                    range: (mutableAttributedString.string as NSString).range(of: threadViewModel.displayName)
                                )
                                return mutableAttributedString
                            }()
                            
                            let confirmationModal: ConfirmationModal = ConfirmationModal(
                                info: ConfirmationModal.Info(
                                    title: confirmationModalTitle,
                                    body: .attributedText(confirmationModalExplanation),
                                    confirmTitle: "LEAVE_BUTTON_TITLE".localized(),
                                    confirmAccessibility: Accessibility(
                                        identifier: "Leave"
                                    ),
                                    confirmStyle: .danger,
                                    cancelStyle: .alert_text,
                                    dismissOnConfirm: true,
                                    onConfirm: { _ in
                                        Storage.shared.writeAsync { db in
                                            try SessionThread.deleteOrLeave(
                                                db,
                                                threadId: threadViewModel.threadId,
                                                threadVariant: threadViewModel.threadVariant,
                                                groupLeaveType: .standard,
                                                calledFromConfigHandling: false
                                            )
                                        }
                                        viewController?.dismiss(animated: true, completion: nil)
                                        
                                        completionHandler(true)
                                    },
                                    afterClosed: { completionHandler(false) }
                                )
                            )
                            
                            viewController?.present(confirmationModal, animated: true, completion: nil)
                        }
                        
                    // MARK: -- delete
                        
                    case .delete:
                        return UIContextualAction(
                            title: "TXT_DELETE_TITLE".localized(),
                            icon: UIImage(named: "icon_bin"),
                            iconHeight: Values.mediumFontSize,
                            themeTintColor: .white,
                            themeBackgroundColor: themeBackgroundColor,
                            side: side,
                            actionIndex: targetIndex,
                            indexPath: indexPath,
                            tableView: tableView
                        ) { [weak viewController] _, _, completionHandler in
                            let isMessageRequest: Bool = (threadViewModel.threadIsMessageRequest == true)
                            let confirmationModalTitle: String = {
                                switch (threadViewModel.threadVariant, isMessageRequest) {
                                    case (_, true): return "TXT_DELETE_TITLE".localized()
                                    case (.contact, _):
                                        return "delete_conversation_confirmation_alert_title".localized()
                                        
                                    case (.legacyGroup, _), (.group, _):
                                        return "delete_group_confirmation_alert_title".localized()
                                        
                                    case (.community, _): return "TXT_DELETE_TITLE".localized()
                                }
                            }()
                            let confirmationModalExplanation: NSAttributedString = {
                                guard !isMessageRequest else {
                                    return NSAttributedString(
                                        string: "MESSAGE_REQUESTS_DELETE_CONFIRMATION_ACTON".localized()
                                    )
                                }
                                guard threadViewModel.currentUserIsClosedGroupAdmin == false else {
                                    return NSAttributedString(
                                        string: "admin_group_leave_warning".localized()
                                    )
                                }
                                
                                let message = String(
                                    format: {
                                        switch threadViewModel.threadVariant {
                                            case .contact:
                                                return
                                                    "delete_conversation_confirmation_alert_message".localized()
                                                
                                            case .legacyGroup, .group:
                                                return
                                                    "delete_group_confirmation_alert_message".localized()
                                                
                                            case .community:
                                                return "leave_community_confirmation_alert_message".localized()
                                        }
                                    }(),
                                    threadViewModel.displayName
                                )
                                
                                return NSAttributedString(string: message)
                                    .adding(
                                        attributes: [
                                            .font: UIFont.boldSystemFont(ofSize: Values.smallFontSize)
                                        ],
                                        range: (message as NSString).range(of: threadViewModel.displayName)
                                    )
                            }()
                            
                            let confirmationModal: ConfirmationModal = ConfirmationModal(
                                info: ConfirmationModal.Info(
                                    title: confirmationModalTitle,
                                    body: .attributedText(confirmationModalExplanation),
                                    confirmTitle: "TXT_DELETE_TITLE".localized(),
                                    confirmAccessibility: Accessibility(
                                        identifier: "Confirm delete"
                                    ),
                                    confirmStyle: .danger,
                                    cancelStyle: .alert_text,
                                    dismissOnConfirm: true,
                                    onConfirm: { _ in
                                        Storage.shared.writeAsync { db in
                                            try SessionThread.deleteOrLeave(
                                                db,
                                                threadId: threadViewModel.threadId,
                                                threadVariant: threadViewModel.threadVariant,
                                                groupLeaveType: (isMessageRequest ? .silent : .forced),
                                                calledFromConfigHandling: false
                                            )
                                        }
                                        viewController?.dismiss(animated: true, completion: nil)
                                        
                                        completionHandler(true)
                                    },
                                    afterClosed: { completionHandler(false) }
                                )
                            )
                            
                            viewController?.present(confirmationModal, animated: true, completion: nil)
                        }
                }
            }
    }
}
