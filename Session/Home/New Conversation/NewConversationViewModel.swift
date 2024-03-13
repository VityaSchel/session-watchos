// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import GRDB
import SessionMessagingKit


public class NewConversationViewModel {
    struct SectionData {
        var sectionName: String
        var contacts: [Profile]
    }

    let sectionData: [SectionData]
    
    init() {
        let contactProfiles: [Profile] = Profile.fetchAllContactProfiles(excludeCurrentUser: true)
        
        var groupedContacts: [String: SectionData] = [:]
        contactProfiles.forEach { profile in
            let displayName = NSMutableString(string: profile.displayName())
            CFStringTransform(displayName, nil, kCFStringTransformToLatin, false)
            CFStringTransform(displayName, nil, kCFStringTransformStripDiacritics, false)
            
            let initialCharacter: String = (displayName.length > 0 ? displayName.substring(to: 1) : "")
            let section: String = initialCharacter.capitalized.isSingleAlphabet ?
            initialCharacter.capitalized :
                "#"
            
            if groupedContacts[section] == nil {
                groupedContacts[section] = SectionData(
                    sectionName: section,
                    contacts: []
                )
            }
            groupedContacts[section]?.contacts.append(profile)
        }
        
        sectionData = groupedContacts.values.sorted { $0.sectionName < $1.sectionName }
    }
}
