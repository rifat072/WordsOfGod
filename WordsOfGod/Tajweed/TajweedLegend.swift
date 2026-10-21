//
//  TajweedLegend.swift
//  WordsOfGod
//
//  Created by Rifat on 21/10/26.
//

import SwiftUI

struct TajweedLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(TajweedRule.allCases) { rule in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Circle()
                        .fill(rule.color)
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(rule.name)
                            .foregroundStyle(rule.color)
                            .fontWeight(.medium)
                        Text(rule.explanation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct TajweedLegendButton: View {
    @State private var isShowing = false

    var body: some View {
        Button("Tajweed Colors", systemImage: "paintpalette") { isShowing.toggle() }
            .popover(isPresented: $isShowing, arrowEdge: .bottom) {
                ScrollView {
                    TajweedLegend().padding(16)
                }
                .frame(minWidth: 320, idealWidth: 340, minHeight: 420, idealHeight: 460)
                .presentationDetents([.medium, .large])
            }
    }
}
