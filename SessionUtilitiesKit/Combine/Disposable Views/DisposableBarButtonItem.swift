// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import Combine

public class DisposableBarButtonItem: UIBarButtonItem {
    public var disposables: Set<AnyCancellable> = Set()
}
