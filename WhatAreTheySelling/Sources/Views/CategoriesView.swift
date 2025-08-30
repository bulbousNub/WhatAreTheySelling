//
//  AllTimeLeaderboardView.swift
//  WhatAreTheySelling
//
//  Created by bulbousNub on 8/29/25.
//

import SwiftUI

struct CategoriesView: View {
    @EnvironmentObject var store: DataStore
    var body: some View {
        List {
            ForEach(store.categories, id: \.self) { cat in
                Text(cat)
            }
        }
        .navigationTitle("Categories")
    }
}
