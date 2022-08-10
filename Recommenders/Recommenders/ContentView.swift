//
//  ContentView.swift
//  TTRExperiment
//
//  Created by Anton Antonov on 8/9/22.
//


import SwiftUI
import SwiftCSV
import StreamsBlendingRecommender

class ObservableSBR: ObservableObject {
    @Published var sbrs: [String : CoreSBR] = [:]
}

struct ContentView: View {
    @StateObject private var sbrOb = ObservableSBR()
    @State private var recommendedItemLabels = [String]()
    @State private var recommendedItems = [Dictionary<String, Double>.Element]()
    @State private var newTag = ""
    @State private var nrecs: Double = 10
    
    @State private var errorTitle = ""
    @State private var errorMessage = ""
    @State private var showingError = false
    
    @State private var selectedSBR = "ZefEcosystem"
    let availableSBRs = ["ZefEcosystem", "FineliFoodData", "USDAFoodData"]
    
    @State private var exportType = "CSV"
    let availableExportTypes = ["CSV", "Email", "Plaintext"]
    
    var body: some View {
        
        NavigationView {
            List {
                
                Section {
                    VStack {
                        //Text("Selected recommender: \(selectedSBR)")
                        Picker("Select a recommender", selection: $selectedSBR) {
                            ForEach(availableSBRs, id: \.self) {
                                Text($0)
                            }
                        }
                        .pickerStyle(.menu)
                       
                        Slider(value: $nrecs, in: 1...100, step: 1)
                        Text("Number of recommendations: \(Int(round(nrecs)))")
                    }
                    //.onChange(of: selectedSBR, perform: { _ in loadSBR() })
                    
                }
                
                Section {
                    HStack{
                        TextField("Enter tags", text: $newTag )
                            .autocapitalization(.none)
                        Image(systemName: "mic.fill")
                    }
                }
                
                // First version
                Section {
                    ForEach(recommendedItems.indices, id: \.self) { i in
                        NavigationLink {
                            ItemDetailView(item: recommendedItems[i].key, selectedSBR: selectedSBR, sbrOb: sbrOb)
                        } label: {
                            HStack {
                                Image(systemName: "\(i+1).circle")
                                Text(recommendedItemLabels[i])
                            }
                        }
                    }
                }
                
                // Using navigation
//                Section {
//                    ForEach(recommendedItems.indices, id: \.self) { i in
//                        NavigationLink(destination: ItemDetailView(item: recommendedItems[i].key, selectedSBR: selectedSBR, sbrOb: sbrOb),
//                        label: {
//                            HStack {
//                                Image(systemName: "\(i+1).circle")
//                                Text(recommendedItemLabels[i])
//                            }
//                        })
//                        .onTapGesture(count:2) {
//                            newTag = "Item:" + recommendedItems[i].key
//                            addNewRecommendations()
//                        }
//                        .buttonStyle(PlainButtonStyle())        // << required !!
//                        .simultaneousGesture(TapGesture(count: 2)
//                            .onEnded { print(">> double tap")})
//                    }
//                }
            }
            .navigationTitle("Recommendations")
            .onSubmit(addNewRecommendations)
            .onChange(of: nrecs, perform: { _ in addNewRecommendations() })
            .onAppear(perform: loadSBR)
            .alert(errorTitle, isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("About") {
                        tagError( title: "About",
                                  message: "Recommenders app for iOS and iPadOS.")
                    }
                    
                    Button("Help") {
                        tagError( title: "Help",
                                  message: "Enter a tag, or tags separated with ';' into the text field. Browse the recommended items.")
                    }
                }
            }
        }
    }
    
    func addNewRecommendations() {
        
        //var newLoad: Bool = false
        
        //        guard isKnownTag(tag: newTag) else {
        //            tagError(title: "Query not possible", message: "Unknown tag: '\(newTag)'!")
        //            return
        //        }
        
        // Load the selected recommender if needed
        if sbrOb.sbrs[selectedSBR] == nil {
            //newLoad = true
            loadSBR()
        }
        
        // Make the query
        var query: [String] = []
        var wordsQ: Bool = false
        var itemQ: Bool = false
        
        // Split into separate tags
        if newTag.contains(";") {
            query = newTag.components(separatedBy: ";")
        } else if !newTag.contains(":") && !newTag.contains(";") {
            query = newTag.components(separatedBy: " ")
            wordsQ = true
        } else if newTag.starts(with: "Item:") {
            query = [String(newTag.dropFirst(5))]
            itemQ = true
        } else {
            query = [newTag]
        }
        
        // Trim white space
        query = query.map { t in t.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        // Add "Word:" to "free" words
        if wordsQ {
            query = query.map { t in t.contains(":") ? t : "Word:" + t }
        }
        
        // Union
        query = Array(Set(query))
        
        // Find recommenations
        var recs: [Dictionary<String, Double>.Element]
                
        if itemQ {
            recs = sbrOb.sbrs[selectedSBR]!.recommend(items: query, nrecs: Int(round(nrecs)))
        } else {
            recs = sbrOb.sbrs[selectedSBR]!.recommendByProfile(prof: query, nrecs: Int(round(nrecs)))
        }
        
        guard recs.count > 0 else { return }
        
        // Recommendation labels and items to display
        recommendedItemLabels = [String]()
        recommendedItems = [Dictionary<String, Double>.Element]()
        
        let answer: [String] = recs.map({ r in "\(String(format:"%.2f", r.value)) : \(r.key)"})
        
        // Fill-in the recommendation labels
        //if newLoad {
        recommendedItemLabels.insert(contentsOf: answer, at: 0)
        //        } else {
        //            withAnimation {
        //                recommendedItemLabels.insert(contentsOf: answer, at: 0)
        //            }
        //        }
        
        recommendedItems.insert(contentsOf: recs, at:0)
    }

    func loadSBR() {
        if sbrOb.sbrs[selectedSBR] == nil {
            
            if let urlSMRMatrixJSON = Bundle.main.url(forResource: selectedSBR + "-SMRMatrixColumnDictionaries", withExtension: "json") {
                
                let fname: String = (urlSMRMatrixJSON.absoluteString).replacingOccurrences(of: "file://", with: "")
                
                sbrOb.sbrs[selectedSBR] = CoreSBR()
                
                let res: Bool = sbrOb.sbrs[selectedSBR]!.ingestSMRMatrixJSONFile(fileName: fname, tagTypesFromTagPrefixes: false, sep: ":")
                
                
                if !res {
                    print(selectedSBR + " SBR created.")
                }
                
                return
            }
            
            fatalError("Could not load " + selectedSBR + "-SMRMatrixColumnDictionaries.json from bundle.")
            
        }
        return
    }
    
    func loadSBRCSV() {
        if sbrOb.sbrs[selectedSBR] == nil {
            
            if let urlSMRMatrixCSV = Bundle.main.url(forResource: selectedSBR + "-dfSMRMatrix", withExtension: "csv") {

                let fname: String = (urlSMRMatrixCSV.absoluteString).replacingOccurrences(of: "file://", with: "")
                
                sbrOb.sbrs[selectedSBR] = CoreSBR()
                
                _ = sbrOb.sbrs[selectedSBR]!.ingestSMRMatrixCSVFile(fileName: fname, sep: ",")
                
                let res: Bool = sbrOb.sbrs[selectedSBR]!.makeTagInverseIndexes()
                
                if !res {
                    print(selectedSBR + " SBR created.")
                }
                
                return
            }
            
            fatalError("Could not load " + selectedSBR + "-dfSMRMatrix.csv from bundle.")
            
        }
        return
    }
    
    func isKnownTag(tag: String) -> Bool {
        
        //return sbrOb.sbrs[selectedSBR] .knownTags.contains(tag)
        return true
    }
    
    func tagError(title: String, message: String) {
        errorTitle = title
        errorMessage = message
        showingError = true
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
