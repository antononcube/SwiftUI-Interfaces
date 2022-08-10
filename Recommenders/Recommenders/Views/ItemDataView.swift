//
//  ItemDataView.swift
//  Recommenders
//
//  Created by Anton Antonov on 8/9/22.
//

import Foundation
import SwiftUI
import StreamsBlendingRecommender

struct ItemDetailView: View {
    var item: String
    var selectedSBR: String
    @ObservedObject var sbrOb: ObservableSBR
    
    func sbrExists() -> Bool {
        return sbrOb.sbrs[selectedSBR] != nil
    }
    
    var body: some View {
          
        if !sbrExists() {
            Text("Nothing")
        } else {
            
            let profile: [Dictionary<String, Double>.Element] = sbrOb.sbrs[selectedSBR]!.profile(items: [item])
          
            ScrollView {
                VStack (alignment: .leading) {
                    
                    ForEach( (profile.count > 40 ? Array(profile[0..<40]) : profile).indices, id: \.self) { i in
                        HStack {
                            Image(systemName: "\(i+1).circle")
                            Text("\(String(format:"%.2f", profile[i].value)) : \(profile[i].key)")
                        }
                    }
                }
            }
            .navigationTitle(item)
        }
    }
}

//struct ItemDetailView_Previews: PreviewProvider {
//    static var previews: some View {
//        ItemDetailView(profile: Profile.example1())
//    }
//}

