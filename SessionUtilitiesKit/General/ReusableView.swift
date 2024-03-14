// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.


public protocol ReusableView: AnyObject {
    static var defaultReuseIdentifier: String { get }
}

public extension ReusableView where Self: Any {
    static var defaultReuseIdentifier: String {
        return String(describing: self.self)
    }
}

//extension UICollectionReusableView: ReusableView {}
//extension UITableViewCell: ReusableView {}
//extension UITableViewHeaderFooterView: ReusableView {}
