// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import Foundation
import SignalUtilitiesKit
import SessionUtilitiesKit

public class GiphyDownloader: ProxiedContentDownloader {

    // MARK: - Properties

    public static let giphyDownloader = GiphyDownloader(downloadFolderName: "GIFs")
}
