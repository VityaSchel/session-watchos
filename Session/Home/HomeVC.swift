// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import UIKit
import GRDB
import DifferenceKit
import SessionUIKit
import SessionMessagingKit
import SessionUtilitiesKit
import SignalUtilitiesKit

final class HomeVC: BaseVC, SessionUtilRespondingViewController, UITableViewDataSource, UITableViewDelegate, SeedReminderViewDelegate {
    private static let loadingHeaderHeight: CGFloat = 40
    public static let newConversationButtonSize: CGFloat = 60
    
    private let viewModel: HomeViewModel = HomeViewModel()
    private var dataChangeObservable: DatabaseCancellable? {
        didSet { oldValue?.cancel() }   // Cancel the old observable if there was one
    }
    private var hasLoadedInitialStateData: Bool = false
    private var hasLoadedInitialThreadData: Bool = false
    private var isLoadingMore: Bool = false
    private var isAutoLoadingNextPage: Bool = false
    private var viewHasAppeared: Bool = false
    
    // MARK: - SessionUtilRespondingViewController
    
    let isConversationList: Bool = true
    
    // MARK: - Intialization
    
    init() {
        Storage.shared.addObserver(viewModel.pagedDataObserver)
        
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        preconditionFailure("Use init() instead.")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - UI
    
    private var tableViewTopConstraint: NSLayoutConstraint!
    
    private lazy var seedReminderView: SeedReminderView = {
        let result = SeedReminderView(hasContinueButton: true)
        result.accessibilityLabel = "Recovery phrase reminder"
        let title = "You're almost finished! 80%"
        result.subtitle = "view_seed_reminder_subtitle_1".localized()
        result.setProgress(0.8, animated: false)
        result.delegate = self
        result.isHidden = !self.viewModel.state.showViewedSeedBanner
        
        ThemeManager.onThemeChange(observer: result) { [weak result] _, primaryColor in
            let attributedTitle = NSMutableAttributedString(string: title)
            attributedTitle.addAttribute(
                .foregroundColor,
                value: primaryColor.color,
                range: (title as NSString).range(of: "80%")
            )
            result?.title = attributedTitle
        }
        
        return result
    }()
    
    private lazy var loadingConversationsLabel: UILabel = {
        let result: UILabel = UILabel()
        result.translatesAutoresizingMaskIntoConstraints = false
        result.font = .systemFont(ofSize: Values.smallFontSize)
        result.text = "LOADING_CONVERSATIONS".localized()
        result.themeTextColor = .textSecondary
        result.textAlignment = .center
        result.numberOfLines = 0
        
        return result
    }()
        
    private lazy var tableView: UITableView = {
        let result = UITableView()
        result.separatorStyle = .none
        result.themeBackgroundColor = .clear
        result.contentInset = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: (
                Values.largeSpacing +
                HomeVC.newConversationButtonSize +
                Values.smallSpacing +
                (UIApplication.shared.keyWindow?.safeAreaInsets.bottom ?? 0)
            ),
            right: 0
        )
        result.showsVerticalScrollIndicator = false
        result.register(view: MessageRequestsCell.self)
        result.register(view: FullConversationCell.self)
        result.dataSource = self
        result.delegate = self
        
        if #available(iOS 15.0, *) {
            result.sectionHeaderTopPadding = 0
        }
        
        return result
    }()
    
    private lazy var newConversationButton: UIView = {
        let result: UIView = UIView()
        result.set(.width, to: HomeVC.newConversationButtonSize)
        result.set(.height, to: HomeVC.newConversationButtonSize)
        
        let button = UIButton()
        button.accessibilityLabel = "New conversation button"
        button.isAccessibilityElement = true
        button.clipsToBounds = true
        button.setImage(
            UIImage(named: "Plus")?
                .withRenderingMode(.alwaysTemplate),
            for: .normal
        )
        button.contentMode = .center
        button.adjustsImageWhenHighlighted = false
        button.themeTintColor = .menuButton_icon
        button.setThemeBackgroundColor(.menuButton_background, for: .normal)
        button.setThemeBackgroundColor(
            .highlighted(.menuButton_background, alwaysDarken: true),
            for: .highlighted
        )
        button.contentEdgeInsets = UIEdgeInsets(
            top: ((HomeVC.newConversationButtonSize - 24) / 2),
            leading: ((HomeVC.newConversationButtonSize - 24) / 2),
            bottom: ((HomeVC.newConversationButtonSize - 24) / 2),
            trailing: ((HomeVC.newConversationButtonSize - 24) / 2)
        )
        button.layer.cornerRadius = (HomeVC.newConversationButtonSize / 2)
        button.addTarget(self, action: #selector(createNewConversation), for: .touchUpInside)
        result.addSubview(button)
        button.pin(to: result)
        
        // Add the outer shadow
        result.themeShadowColor = .menuButton_outerShadow
        result.layer.shadowRadius = 15
        result.layer.shadowOpacity = 0.3
        result.layer.shadowOffset = .zero
        result.layer.cornerRadius = (HomeVC.newConversationButtonSize / 2)
        result.layer.shadowPath = UIBezierPath(
            ovalIn: CGRect(
                origin: CGPoint.zero,
                size: CGSize(
                    width: HomeVC.newConversationButtonSize,
                    height: HomeVC.newConversationButtonSize
                )
            )
        ).cgPath
        
        // Add the inner shadow
        let innerShadowLayer: CALayer = CALayer()
        innerShadowLayer.masksToBounds = true
        innerShadowLayer.themeShadowColor = .menuButton_innerShadow
        innerShadowLayer.position = CGPoint(
            x: (HomeVC.newConversationButtonSize / 2),
            y: (HomeVC.newConversationButtonSize / 2)
        )
        innerShadowLayer.bounds = CGRect(
            x: 0,
            y: 0,
            width: HomeVC.newConversationButtonSize,
            height: HomeVC.newConversationButtonSize
        )
        innerShadowLayer.cornerRadius = (HomeVC.newConversationButtonSize / 2)
        innerShadowLayer.shadowOffset = .zero
        innerShadowLayer.shadowOpacity = 0.4
        innerShadowLayer.shadowRadius = 2

        let cutout: UIBezierPath = UIBezierPath(
            roundedRect: innerShadowLayer.bounds
                .insetBy(dx: innerShadowLayer.shadowRadius, dy: innerShadowLayer.shadowRadius),
            cornerRadius: (HomeVC.newConversationButtonSize / 2)
        ).reversing()
        let path: UIBezierPath = UIBezierPath(
            roundedRect: innerShadowLayer.bounds,
            cornerRadius: (HomeVC.newConversationButtonSize / 2)
        )
        path.append(cutout)
        innerShadowLayer.shadowPath = path.cgPath
        result.layer.addSublayer(innerShadowLayer)

        return result
    }()
    
    private lazy var emptyStateView: UIView = {
        let explanationLabel = UILabel()
        explanationLabel.font = .systemFont(ofSize: Values.smallFontSize)
        explanationLabel.text = "vc_home_empty_state_message".localized()
        explanationLabel.themeTextColor = .textPrimary
        explanationLabel.textAlignment = .center
        explanationLabel.lineBreakMode = .byWordWrapping
        explanationLabel.numberOfLines = 0
        
        let createNewPrivateChatButton = SessionButton(style: .bordered, size: .large)
        createNewPrivateChatButton.setTitle("vc_home_empty_state_button_title".localized(), for: .normal)
        createNewPrivateChatButton.addTarget(self, action: #selector(createNewConversation), for: .touchUpInside)
        createNewPrivateChatButton.set(.width, to: Values.iPadButtonWidth)
        
        let result = UIStackView(arrangedSubviews: [ explanationLabel, createNewPrivateChatButton ])
        result.axis = .vertical
        result.spacing = Values.mediumSpacing
        result.alignment = .center
        result.isHidden = true
        
        return result
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Note: This is a hack to ensure `isRTL` is initially gets run on the main thread so the value
        // is cached (it gets called on background threads and if it hasn't cached the value then it can
        // cause odd performance issues since it accesses UIKit)
        if Singleton.hasAppContext { _ = Singleton.appContext.isRTL }
        
        // Preparation
        SessionApp.homeViewController.mutate { $0 = self }
        
        updateNavBarButtons(userProfile: self.viewModel.state.userProfile)
        setUpNavBarSessionHeading()
        
        // Recovery phrase reminder
        view.addSubview(seedReminderView)
        seedReminderView.pin(.leading, to: .leading, of: view)
        seedReminderView.pin(.top, to: .top, of: view)
        seedReminderView.pin(.trailing, to: .trailing, of: view)
        
        // Loading conversations label
        view.addSubview(loadingConversationsLabel)
        
        loadingConversationsLabel.pin(.top, to: .top, of: view, withInset: Values.veryLargeSpacing)
        loadingConversationsLabel.pin(.leading, to: .leading, of: view, withInset: 50)
        loadingConversationsLabel.pin(.trailing, to: .trailing, of: view, withInset: -50)
        
        // Table view
        view.addSubview(tableView)
        tableView.pin(.leading, to: .leading, of: view)
        if self.viewModel.state.showViewedSeedBanner {
            tableViewTopConstraint = tableView.pin(.top, to: .bottom, of: seedReminderView)
        }
        else {
            tableViewTopConstraint = tableView.pin(.top, to: .top, of: view)
        }
        tableView.pin(.trailing, to: .trailing, of: view)
        tableView.pin(.bottom, to: .bottom, of: view)
        
        // Empty state view
        view.addSubview(emptyStateView)
        emptyStateView.center(.horizontal, in: view)
        let verticalCenteringConstraint = emptyStateView.center(.vertical, in: view)
        verticalCenteringConstraint.constant = -16 // Makes things appear centered visually
        
        // New conversation button
        view.addSubview(newConversationButton)
        newConversationButton.center(.horizontal, in: view)
        newConversationButton.pin(.bottom, to: .bottom, of: view.safeAreaLayoutGuide, withInset: -Values.smallSpacing)
        
        // Notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive(_:)),
            name: UIApplication.didEnterBackgroundNotification, object: nil
        )
        
        // Start polling if needed (i.e. if the user just created or restored their Session ID)
        if Identity.userExists(), let appDelegate: AppDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.startPollersIfNeeded()
        }
        
        // Onion request path countries cache
        IP2Country.shared.populateCacheIfNeededAsync()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        startObservingChanges()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.viewHasAppeared = true
        self.autoLoadNextPageIfNeeded()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        stopObservingChanges()
    }
    
    @objc func applicationDidBecomeActive(_ notification: Notification) {
        /// Need to dispatch to the next run loop to prevent a possible crash caused by the database resuming mid-query
        DispatchQueue.main.async { [weak self] in
            self?.startObservingChanges(didReturnFromBackground: true)
        }
    }
    
    @objc func applicationDidResignActive(_ notification: Notification) {
        stopObservingChanges()
    }
    
    // MARK: - Updating
    
    public func startObservingChanges(didReturnFromBackground: Bool = false, onReceivedInitialChange: (() -> ())? = nil) {
        guard dataChangeObservable == nil else { return }
        
        var runAndClearInitialChangeCallback: (() -> ())? = nil
        
        runAndClearInitialChangeCallback = { [weak self] in
            guard self?.hasLoadedInitialStateData == true && self?.hasLoadedInitialThreadData == true else { return }
            
            onReceivedInitialChange?()
            runAndClearInitialChangeCallback = nil
        }
        
        dataChangeObservable = Storage.shared.start(
            viewModel.observableState,
            onError: { _ in },
            onChange: { [weak self] state in
                // The default scheduler emits changes on the main thread
                self?.handleUpdates(state)
                runAndClearInitialChangeCallback?()
            }
        )
        
        self.viewModel.onThreadChange = { [weak self] updatedThreadData, changeset in
            self?.handleThreadUpdates(updatedThreadData, changeset: changeset)
            runAndClearInitialChangeCallback?()
        }
        
        // Note: When returning from the background we could have received notifications but the
        // PagedDatabaseObserver won't have them so we need to force a re-fetch of the current
        // data to ensure everything is up to date
        if didReturnFromBackground {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.viewModel.pagedDataObserver?.reload()
            }
        }
    }
    
    private func stopObservingChanges() {
        // Stop observing database changes
        self.dataChangeObservable = nil
        self.viewModel.onThreadChange = nil
    }
    
    private func handleUpdates(_ updatedState: HomeViewModel.State, initialLoad: Bool = false) {
        // Ensure the first load runs without animations (if we don't do this the cells will animate
        // in from a frame of CGRect.zero)
        guard hasLoadedInitialStateData else {
            hasLoadedInitialStateData = true
            UIView.performWithoutAnimation { handleUpdates(updatedState, initialLoad: true) }
            return
        }
        
        if updatedState.userProfile != self.viewModel.state.userProfile {
            updateNavBarButtons(userProfile: updatedState.userProfile)
        }
        
        // Update the 'view seed' UI
        if updatedState.showViewedSeedBanner != self.viewModel.state.showViewedSeedBanner {
            tableViewTopConstraint.isActive = false
            seedReminderView.isHidden = !updatedState.showViewedSeedBanner
            
            if updatedState.showViewedSeedBanner {
                tableViewTopConstraint = tableView.pin(.top, to: .bottom, of: seedReminderView)
            }
            else {
                tableViewTopConstraint = tableView.pin(.top, to: .top, of: view, withInset: Values.smallSpacing)
            }
        }
        
        self.viewModel.updateState(updatedState)
    }
    
    private func handleThreadUpdates(
        _ updatedData: [HomeViewModel.SectionModel],
        changeset: StagedChangeset<[HomeViewModel.SectionModel]>,
        initialLoad: Bool = false
    ) {
        // Ensure the first load runs without animations (if we don't do this the cells will animate
        // in from a frame of CGRect.zero)
        guard hasLoadedInitialThreadData else {
            UIView.performWithoutAnimation { [weak self] in
                // Hide the 'loading conversations' label (now that we have received conversation data)
                self?.loadingConversationsLabel.isHidden = true
                
                // Show the empty state if there is no data
                self?.emptyStateView.isHidden = (
                    !updatedData.isEmpty &&
                    updatedData.contains(where: { !$0.elements.isEmpty })
                )
                
                self?.viewModel.updateThreadData(updatedData)
                self?.tableView.reloadData()
                self?.hasLoadedInitialThreadData = true
            }
            return
        }
        
        // Hide the 'loading conversations' label (now that we have received conversation data)
        loadingConversationsLabel.isHidden = true
        
        // Show the empty state if there is no data
        emptyStateView.isHidden = (
            !updatedData.isEmpty &&
            updatedData.contains(where: { !$0.elements.isEmpty })
        )
        
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            // Complete page loading
            self?.isLoadingMore = false
            self?.autoLoadNextPageIfNeeded()
        }
        
        // Reload the table content (animate changes after the first load)
        tableView.reload(
            using: changeset,
            deleteSectionsAnimation: .none,
            insertSectionsAnimation: .none,
            reloadSectionsAnimation: .none,
            deleteRowsAnimation: .bottom,
            insertRowsAnimation: .none,
            reloadRowsAnimation: .none,
            interrupt: { $0.changeCount > 100 }    // Prevent too many changes from causing performance issues
        ) { [weak self] updatedData in
            self?.viewModel.updateThreadData(updatedData)
        }
        
        CATransaction.commit()
    }
    
    private func autoLoadNextPageIfNeeded() {
        guard
            self.hasLoadedInitialThreadData &&
            !self.isAutoLoadingNextPage &&
            !self.isLoadingMore
        else { return }
        
        self.isAutoLoadingNextPage = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + PagedData.autoLoadNextPageDelay) { [weak self] in
            self?.isAutoLoadingNextPage = false
            
            // Note: We sort the headers as we want to prioritise loading newer pages over older ones
            let sections: [(HomeViewModel.Section, CGRect)] = (self?.viewModel.threadData
                .enumerated()
                .map { index, section in (section.model, (self?.tableView.rectForHeader(inSection: index) ?? .zero)) })
                .defaulting(to: [])
            let shouldLoadMore: Bool = sections
                .contains { section, headerRect in
                    section == .loadMore &&
                    headerRect != .zero &&
                    (self?.tableView.bounds.contains(headerRect) == true)
                }
            
            guard shouldLoadMore else { return }
            
            self?.isLoadingMore = true
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.viewModel.pagedDataObserver?.load(.pageAfter)
            }
        }
    }
    
    private func updateNavBarButtons(userProfile: Profile) {
        // Profile picture view
        let profilePictureView = ProfilePictureView(size: .navigation)
        profilePictureView.accessibilityIdentifier = "User settings"
        profilePictureView.accessibilityLabel = "User settings"
        profilePictureView.isAccessibilityElement = true
        profilePictureView.update(
            publicKey: userProfile.id,
            threadVariant: .contact,
            customImageData: nil,
            profile: userProfile,
            additionalProfile: nil
        )
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(openSettings))
        profilePictureView.addGestureRecognizer(tapGestureRecognizer)
        
        // Path status indicator
        let pathStatusView = PathStatusView()
        pathStatusView.accessibilityLabel = "Current onion routing path indicator"
        
        // Container view
        let profilePictureViewContainer = UIView()
        profilePictureViewContainer.addSubview(profilePictureView)
        profilePictureView.autoPinEdgesToSuperviewEdges()
        profilePictureViewContainer.addSubview(pathStatusView)
        pathStatusView.pin(.trailing, to: .trailing, of: profilePictureViewContainer)
        pathStatusView.pin(.bottom, to: .bottom, of: profilePictureViewContainer)
        
        // Left bar button item
        let leftBarButtonItem = UIBarButtonItem(customView: profilePictureViewContainer)
        leftBarButtonItem.isAccessibilityElement = true
        navigationItem.leftBarButtonItem = leftBarButtonItem
        
        // Right bar button item - search button
        let rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .search, target: self, action: #selector(showSearchUI))
        rightBarButtonItem.accessibilityLabel = "Search button"
        rightBarButtonItem.isAccessibilityElement  = true
        navigationItem.rightBarButtonItem = rightBarButtonItem
    }
    
    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.threadData.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section: HomeViewModel.SectionModel = viewModel.threadData[section]
        
        return section.elements.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section: HomeViewModel.SectionModel = viewModel.threadData[indexPath.section]
        
        switch section.model {
            case .messageRequests:
                let threadViewModel: SessionThreadViewModel = section.elements[indexPath.row]
                let cell: MessageRequestsCell = tableView.dequeue(type: MessageRequestsCell.self, for: indexPath)
                cell.accessibilityIdentifier = "Message requests banner"
                cell.isAccessibilityElement = true
                cell.update(with: Int(threadViewModel.threadUnreadCount ?? 0))
                return cell
                
            case .threads:
                let threadViewModel: SessionThreadViewModel = section.elements[indexPath.row]
                let cell: FullConversationCell = tableView.dequeue(type: FullConversationCell.self, for: indexPath)
                cell.update(with: threadViewModel)
                cell.accessibilityIdentifier = "Conversation list item"
                cell.accessibilityLabel = threadViewModel.displayName
                return cell
                
            default: preconditionFailure("Other sections should have no content")
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let section: HomeViewModel.SectionModel = viewModel.threadData[section]
        
        switch section.model {
            case .loadMore:
                let loadingIndicator: UIActivityIndicatorView = UIActivityIndicatorView(style: .medium)
                loadingIndicator.themeTintColor = .textPrimary
                loadingIndicator.alpha = 0.5
                loadingIndicator.startAnimating()
                
                let view: UIView = UIView()
                view.addSubview(loadingIndicator)
                loadingIndicator.center(in: view)
                
                return view
            
            default: return nil
        }
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let section: HomeViewModel.SectionModel = viewModel.threadData[section]
        
        switch section.model {
            case .loadMore: return HomeVC.loadingHeaderHeight
            default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard self.hasLoadedInitialThreadData && self.viewHasAppeared && !self.isLoadingMore else { return }
        
        let section: HomeViewModel.SectionModel = self.viewModel.threadData[section]
        
        switch section.model {
            case .loadMore:
                self.isLoadingMore = true
                
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    self?.viewModel.pagedDataObserver?.load(.pageAfter)
                }
                
            default: break
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let section: HomeViewModel.SectionModel = self.viewModel.threadData[indexPath.section]
        
        switch section.model {
            case .messageRequests:
                let viewController: SessionTableViewController = SessionTableViewController(
                    viewModel: MessageRequestsViewModel()
                )
                self.navigationController?.pushViewController(viewController, animated: true)
                
            case .threads:
                let threadViewModel: SessionThreadViewModel = section.elements[indexPath.row]
                show(
                    threadViewModel.threadId,
                    variant: threadViewModel.threadVariant,
                    isMessageRequest: (threadViewModel.threadIsMessageRequest == true),
                    with: .none,
                    focusedInteractionInfo: nil,
                    animated: true
                )
                
            default: break
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, willBeginEditingRowAt indexPath: IndexPath) {
        UIContextualAction.willBeginEditing(indexPath: indexPath, tableView: tableView)
    }
    
    func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?) {
        UIContextualAction.didEndEditing(indexPath: indexPath, tableView: tableView)
    }
    
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let section: HomeViewModel.SectionModel = self.viewModel.threadData[indexPath.section]
        let threadViewModel: SessionThreadViewModel = section.elements[indexPath.row]
        
        switch section.model {
            case .threads:
                // Cannot properly sync outgoing blinded message requests so don't provide the option
                guard
                    threadViewModel.threadVariant != .contact ||
                    SessionId(from: section.elements[indexPath.row].threadId)?.prefix == .standard
                else { return nil }
                
                return UIContextualAction.configuration(
                    for: UIContextualAction.generateSwipeActions(
                        [.toggleReadStatus],
                        for: .leading,
                        indexPath: indexPath,
                        tableView: tableView,
                        threadViewModel: threadViewModel,
                        viewController: self
                    )
                )
            
            default: return nil
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let section: HomeViewModel.SectionModel = self.viewModel.threadData[indexPath.section]
        let threadViewModel: SessionThreadViewModel = section.elements[indexPath.row]
        
        switch section.model {
            case .messageRequests:
                return UIContextualAction.configuration(
                    for: UIContextualAction.generateSwipeActions(
                        [.hide],
                        for: .trailing,
                        indexPath: indexPath,
                        tableView: tableView,
                        threadViewModel: threadViewModel,
                        viewController: self
                    )
                )
                
            case .threads:
                let sessionIdPrefix: SessionId.Prefix? = SessionId(from: threadViewModel.threadId)?.prefix
                
                // Cannot properly sync outgoing blinded message requests so only provide valid options
                let shouldHavePinAction: Bool = (
                    sessionIdPrefix != .blinded15 &&
                    sessionIdPrefix != .blinded25
                )
                let shouldHaveMuteAction: Bool = {
                    switch threadViewModel.threadVariant {
                        case .contact: return (
                            !threadViewModel.threadIsNoteToSelf &&
                            sessionIdPrefix != .blinded15 &&
                            sessionIdPrefix != .blinded25
                        )
                            
                        case .legacyGroup, .group: return (
                            threadViewModel.currentUserIsClosedGroupMember == true
                        )
                            
                        case .community: return true
                    }
                }()
                let destructiveAction: UIContextualAction.SwipeAction = {
                    switch (threadViewModel.threadVariant, threadViewModel.threadIsNoteToSelf, threadViewModel.currentUserIsClosedGroupMember) {
                        case (.contact, true, _): return .hide
                        case (.legacyGroup, _, true), (.group, _, true), (.community, _, _): return .leave
                        default: return .delete
                    }
                }()
                
                return UIContextualAction.configuration(
                    for: UIContextualAction.generateSwipeActions(
                        [
                            (!shouldHavePinAction ? nil : .pin),
                            (!shouldHaveMuteAction ? nil : .mute),
                            destructiveAction
                        ].compactMap { $0 },
                        for: .trailing,
                        indexPath: indexPath,
                        tableView: tableView,
                        threadViewModel: threadViewModel,
                        viewController: self
                    )
                )
                
            default: return nil
        }
    }
    
    // MARK: - Interaction
    
    func handleContinueButtonTapped(from seedReminderView: SeedReminderView) {
        let targetViewController: UIViewController = {
            if let seedVC: SeedVC = try? SeedVC() {
                return StyledNavigationController(rootViewController: seedVC)
            }
            
            return ConfirmationModal(
                info: ConfirmationModal.Info(
                    title: "ALERT_ERROR_TITLE".localized(),
                    body: .text("LOAD_RECOVERY_PASSWORD_ERROR".localized()),
                    cancelTitle: "BUTTON_OK".localized(),
                    cancelStyle: .alert_text
                )
            )
        }()
        
        present(targetViewController, animated: true, completion: nil)
    }
    
    func show(
        _ threadId: String,
        variant: SessionThread.Variant,
        isMessageRequest: Bool,
        with action: ConversationViewModel.Action,
        focusedInteractionInfo: Interaction.TimestampInfo?,
        animated: Bool
    ) {
        if let presentedVC = self.presentedViewController {
            presentedVC.dismiss(animated: false, completion: nil)
        }
        
        let finalViewControllers: [UIViewController] = [
            self,
            (isMessageRequest ? SessionTableViewController(viewModel: MessageRequestsViewModel()) : nil),
            ConversationVC(
                threadId: threadId,
                threadVariant: variant,
                focusedInteractionInfo: focusedInteractionInfo
            )
        ].compactMap { $0 }
        
        self.navigationController?.setViewControllers(finalViewControllers, animated: animated)
    }
    
    @objc private func openSettings() {
        let settingsViewController: SessionTableViewController = SessionTableViewController(
            viewModel: SettingsViewModel()
        )
        let navigationController = StyledNavigationController(rootViewController: settingsViewController)
        navigationController.modalPresentationStyle = .fullScreen
        present(navigationController, animated: true, completion: nil)
    }
    
    @objc private func showSearchUI() {
        if let presentedVC = self.presentedViewController {
            presentedVC.dismiss(animated: false, completion: nil)
        }
        let searchController = GlobalSearchViewController()
        self.navigationController?.setViewControllers([ self, searchController ], animated: true)
    }
    
    @objc func createNewConversation() {
        let newConversationVC = NewConversationVC()
        let navigationController = StyledNavigationController(rootViewController: newConversationVC)
        if UIDevice.current.isIPad {
            navigationController.modalPresentationStyle = .fullScreen
        }
        navigationController.modalPresentationCapturesStatusBarAppearance = true
        present(navigationController, animated: true, completion: nil)
    }
    
    func createNewDMFromDeepLink(sessionId: String) {
        let newDMVC = NewDMVC(sessionId: sessionId, shouldShowBackButton: false)
        let navigationController = StyledNavigationController(rootViewController: newDMVC)
        if UIDevice.current.isIPad {
            navigationController.modalPresentationStyle = .fullScreen
        }
        navigationController.modalPresentationCapturesStatusBarAppearance = true
        present(navigationController, animated: true, completion: nil)
    }
}
