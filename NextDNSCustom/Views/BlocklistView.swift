import SwiftUI

struct BlocklistView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""
    @State private var exactDomains: [String] = []
    @State private var wildcards: [String] = []
    @State private var selectedTab: Int = 0
    @State private var showingAddAlert = false
    @State private var newDomainInput = ""
    @State private var isWildcardToggle = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("Loại", selection: $selectedTab) {
                    Text("Chính xác (\(exactDomains.count))").tag(0)
                    Text("Wildcard (*.) (\(wildcards.count))").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                if filteredList.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                        Text("Không tìm thấy domain nào")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filteredList, id: \.self) { item in
                            HStack {
                                Image(systemName: selectedTab == 0 ? "xmark.shield.fill" : "asterisk.circle.fill")
                                    .foregroundColor(selectedTab == 0 ? .red : .orange)
                                    .font(.subheadline)
                                
                                Text(selectedTab == 1 && !item.hasPrefix("*.") ? "*.\(item)" : item)
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                
                                Spacer()
                                
                                Text("Blocked")
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.12))
                                    .foregroundColor(.red)
                                    .cornerRadius(6)
                            }
                            .padding(.vertical, 3)
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .searchable(text: $searchText, prompt: "Tìm kiếm domain...")
            .navigationTitle("Danh sách chặn")
            .navigationBarItems(
                leading: Button("Đặt lại") {
                    BlockList.resetToDefaults()
                    reloadLists()
                }
                .foregroundColor(.red),
                trailing: HStack(spacing: 16) {
                    Button(action: { showingAddAlert = true }) {
                        Image(systemName: "plus")
                    }
                    Button("Xong") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                }
            )
            .sheet(isPresented: $showingAddAlert) {
                addDomainSheet
            }
            .onAppear {
                reloadLists()
            }
        }
    }

    private var filteredList: [String] {
        let currentList = selectedTab == 0 ? exactDomains : wildcards
        if searchText.isEmpty {
            return currentList
        }
        return currentList.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private func reloadLists() {
        exactDomains = BlockList.getExactDomains().sorted()
        wildcards = BlockList.getWildcards().sorted()
    }

    private func deleteItems(at offsets: IndexSet) {
        if selectedTab == 0 {
            exactDomains.remove(atOffsets: offsets)
            BlockList.saveExactDomains(exactDomains)
        } else {
            wildcards.remove(atOffsets: offsets)
            BlockList.saveWildcards(wildcards)
        }
    }

    private var addDomainSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Thông tin tên miền")) {
                    TextField("VD: tracker.example.com", text: $newDomainInput)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Toggle("Là Wildcard (*.domain.com)", isOn: $isWildcardToggle)
                }
                
                Section(footer: Text("Nếu chọn wildcard, tất cả các subdomains (con) của domain này cũng sẽ tự động bị chặn.")) {
                    Button("Thêm vào danh sách chặn") {
                        addNewDomain()
                    }
                    .disabled(newDomainInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Thêm Domain")
            .navigationBarItems(trailing: Button("Hủy") {
                showingAddAlert = false
                newDomainInput = ""
            })
        }
    }

    private func addNewDomain() {
        var clean = newDomainInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if clean.hasPrefix("*.") {
            clean = String(clean.dropFirst(2))
            isWildcardToggle = true
        }

        if isWildcardToggle {
            if !wildcards.contains(clean) {
                wildcards.append(clean)
                BlockList.saveWildcards(wildcards)
            }
        } else {
            if !exactDomains.contains(clean) {
                exactDomains.append(clean)
                BlockList.saveExactDomains(exactDomains)
            }
        }
        reloadLists()
        newDomainInput = ""
        showingAddAlert = false
    }
}
