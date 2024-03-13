// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import UIKit
import GRDB
import SessionUIKit
import SessionMessagingKit
import SignalUtilitiesKit

final class NewConversationVC: BaseVC, ThemedNavigation, UITableViewDelegate, UITableViewDataSource {
    private let newConversationViewModel = NewConversationViewModel()
    private var groupedContacts: OrderedDictionary<String, [Profile]> = OrderedDictionary()
    
    // MARK: - UI
    
    var navigationBackground: ThemeValue { .newConversation_background }
    
    private lazy var newDMButton: NewConversationButton = {
        let result = NewConversationButton(icon: #imageLiteral(resourceName: "Message"), title: "vc_create_private_chat_title".localized())
        result.accessibilityIdentifier = "New direct message"
        result.isAccessibilityElement = true
        
        return result
    }()
    
    private lazy var newGroupButton: NewConversationButton = {
        let result = NewConversationButton(icon: #imageLiteral(resourceName: "Group"), title: "vc_create_closed_group_title".localized())
        result.accessibilityLabel = "Create group"
        result.isAccessibilityElement = true
        
        return result
    }()
    private lazy var joinCommunityButton: NewConversationButton = NewConversationButton(icon: #imageLiteral(resourceName: "Globe"), title: "vc_join_public_chat_title".localized(), shouldShowSeparator: false)
    
    private lazy var buttonStackView: UIStackView = {
        let lineTop: UIView = UIView()
        lineTop.themeBackgroundColor = .borderSeparator
        lineTop.set(.height, to: Values.separatorThickness)
        
        let lineBottom = UIView()
        lineBottom.themeBackgroundColor = .borderSeparator
        lineBottom.set(.height, to: Values.separatorThickness)
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapGestureRecognizer.numberOfTapsRequired = 1
        
        let result = UIStackView(
            arrangedSubviews: [
                lineTop,
                newDMButton,
                newGroupButton,
                joinCommunityButton,
                lineBottom
            ]
        )
        result.axis = .vertical
        result.addGestureRecognizer(tapGestureRecognizer)
        
        return result
    }()
    
    private lazy var buttonStackViewContainer = UIView(wrapping: buttonStackView, withInsets: .zero)
    
    private lazy var contactsTitleLabel: UILabel = {
        let result: UILabel = UILabel()
        result.font = .systemFont(ofSize: Values.mediumFontSize)
        result.text = (newConversationViewModel.sectionData.isEmpty ?
            "vc_create_closed_group_empty_state_message".localized() :
            "NEW_CONVERSATION_CONTACTS_SECTION_TITLE".localized()
        )
        result.themeTextColor = (newConversationViewModel.sectionData.isEmpty ?
            .textSecondary :
            .textPrimary
        )
        
        return result
    }()
    
    private lazy var contactsTableView: UITableView = {
        let result: UITableView = UITableView()
        result.delegate = self
        result.dataSource = self
        result.separatorStyle = .none
        result.themeBackgroundColor = .newConversation_background
        result.register(view: SessionCell.self)
        
        if #available(iOS 15.0, *) {
            result.sectionHeaderTopPadding = 0
        }
        
        return result
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setNavBarTitle("vc_new_conversation_title".localized())
        view.themeBackgroundColor = .newConversation_background
        
        // Set up navigation bar buttons
        let closeButton = UIBarButtonItem(image: #imageLiteral(resourceName: "X"), style: .plain, target: self, action: #selector(close))
        closeButton.themeTintColor = .textPrimary
        navigationItem.leftBarButtonItem = closeButton
        setUpViewHierarchy()
    }
    
    private func setUpViewHierarchy() {
        buttonStackViewContainer.themeBackgroundColor = .newConversation_background
        
        let headerView = UIView(
            frame: CGRect(
                x: 0, y: 0,
                width: UIScreen.main.bounds.width,
                height: NewConversationButton.height * 3 + Values.mediumSpacing * 2 + Values.mediumFontSize
            )
        )
        headerView.addSubview(buttonStackViewContainer)
        buttonStackViewContainer.pin([ UIView.HorizontalEdge.leading, UIView.HorizontalEdge.trailing], to: headerView)
        buttonStackViewContainer.pin(.top, to: .top, of: headerView, withInset: Values.verySmallSpacing)
        headerView.addSubview(contactsTitleLabel)
        contactsTitleLabel.pin(.leading, to: .leading, of: headerView, withInset: Values.mediumSpacing)
        contactsTitleLabel.pin(.top, to: .bottom, of: buttonStackViewContainer, withInset: Values.mediumSpacing)
        
        contactsTableView.tableHeaderView = headerView
        view.addSubview(contactsTableView)
        contactsTableView.pin(to: view)
    }
    
    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return newConversationViewModel.sectionData.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return newConversationViewModel.sectionData[section].contacts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: SessionCell = tableView.dequeue(type: SessionCell.self, for: indexPath)
        let profile = newConversationViewModel.sectionData[indexPath.section].contacts[indexPath.row]
        cell.update(
            with: SessionCell.Info(
                id: profile,
                position: Position.with(
                    indexPath.row,
                    count: newConversationViewModel.sectionData[indexPath.section].contacts.count
                ),
                leftAccessory: .profile(id: profile.id, profile: profile),
                title: profile.displayName(),
                styling: SessionCell.StyleInfo(backgroundStyle: .edgeToEdge)
            )
        )
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let label: UILabel = UILabel()
        label.font = .systemFont(ofSize: Values.smallFontSize)
        label.text = newConversationViewModel.sectionData[section].sectionName
        label.themeTextColor = .textPrimary
        
        let headerView: UIView = UIView()
        headerView.themeBackgroundColor = .newConversation_background
        headerView.addSubview(label)
        
        label.pin(.leading, to: .leading, of: headerView, withInset: Values.mediumSpacing)
        label.pin(.top, to: .top, of: headerView, withInset: Values.verySmallSpacing)
        label.pin(.bottom, to: .bottom, of: headerView, withInset: -Values.verySmallSpacing)
        
        return headerView
    }
    
    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let sessionId = newConversationViewModel.sectionData[indexPath.section].contacts[indexPath.row].id
        
        SessionApp.presentConversationCreatingIfNeeded(
            for: sessionId,
            variant: .contact,
            dismissing: navigationController,
            animated: false
        )
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        view.themeBackgroundColor = .newConversation_background
    }
    
    // MARK: - Interaction
    
    @objc private func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        let location = gestureRecognizer.location(in: self.view)
        
        if newDMButton.frame.contains(location) {
            createNewDM()
        }
        else if newGroupButton.frame.contains(location) {
            createClosedGroup()
        }
        else if joinCommunityButton.frame.contains(location) {
            joinOpenGroup()
        }
    }
    
    @objc private func close() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func createNewDM() {
        let newDMVC = NewDMVC()
        self.navigationController?.pushViewController(newDMVC, animated: true)
    }
    
    @objc func createClosedGroup() {
        let newClosedGroupVC = NewClosedGroupVC()
        self.navigationController?.pushViewController(newClosedGroupVC, animated: true)
    }
    
    @objc func joinOpenGroup() {
        let joinOpenGroupVC: JoinOpenGroupVC = JoinOpenGroupVC()
        self.navigationController?.pushViewController(joinOpenGroupVC, animated: true)
    }
}

// MARK: - NewConversationButton

private final class NewConversationButton: UIView {
    private let icon: UIImage
    private let title: String
    private let shouldShowSeparator: Bool
    private var didTouchDownInside: Bool = false
    
    public static let height: CGFloat = 56
    private static let iconSize: CGFloat = 38
    
    private let selectedBackgroundView: UIView = {
        let result: UIView = UIView()
        result.themeBackgroundColor = .highlighted(.settings_tabBackground)
        result.isHidden = true
        
        return result
    }()
    
    init(icon: UIImage, title: String, shouldShowSeparator: Bool = true) {
        self.icon = icon.withRenderingMode(.alwaysTemplate)
        self.title = title
        self.shouldShowSeparator = shouldShowSeparator
        
        super.init(frame: .zero)
        
        self.themeBackgroundColor = .settings_tabBackground
        setUpViewHierarchy()
    }
    
    override init(frame: CGRect) {
        preconditionFailure("Use init(icon:title:) instead.")
    }
        
    required init?(coder: NSCoder) {
        preconditionFailure("Use init(icon:title:) instead.")
    }
    
    private func setUpViewHierarchy() {
        addSubview(selectedBackgroundView)
        selectedBackgroundView.pin(to: self)
        
        let iconImageView = UIImageView(image: self.icon)
        iconImageView.contentMode = .center
        iconImageView.themeTintColor = .textPrimary
        iconImageView.set(.width, to: NewConversationButton.iconSize)
        
        let titleLable: UILabel = UILabel()
        titleLable.font = .systemFont(ofSize: Values.mediumFontSize)
        titleLable.text = self.title
        titleLable.themeTextColor = .textPrimary
        
        let stackView = UIStackView(
            arrangedSubviews: [
                iconImageView,
                UIView.hSpacer(Values.mediumSpacing),
                titleLable,
                UIView.hStretchingSpacer()
            ]
        )
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.layoutMargins = UIEdgeInsets(uniform: Values.mediumSpacing)
        addSubview(stackView)
        stackView.pin(to: self)
        stackView.set(.width, to: UIScreen.main.bounds.width)
        stackView.set(.height, to: NewConversationButton.height)
        
        let line: UIView = UIView()
        line.themeBackgroundColor = .borderSeparator
        addSubview(line)
        
        line.pin([UIView.VerticalEdge.bottom, UIView.HorizontalEdge.trailing], to: self)
        line.pin(
            .leading,
            to: .leading,
            of: self,
            withInset: (NewConversationButton.iconSize + 2 * Values.mediumSpacing)
        )
        line.set(.height, to: Values.separatorThickness)
        
        line.isHidden = !shouldShowSeparator
    }
    
    // MARK: - Interaction
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard
            isUserInteractionEnabled,
            let location: CGPoint = touches.first?.location(in: self),
            bounds.contains(location)
        else { return }
        
        didTouchDownInside = true
        selectedBackgroundView.isHidden = false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard
            isUserInteractionEnabled,
            let location: CGPoint = touches.first?.location(in: self),
            bounds.contains(location),
            didTouchDownInside
        else {
            selectedBackgroundView.isHidden = true
            return
        }
        
        selectedBackgroundView.isHidden = false
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        selectedBackgroundView.isHidden = true
        didTouchDownInside = false
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        selectedBackgroundView.isHidden = true
        didTouchDownInside = false
    }
}
