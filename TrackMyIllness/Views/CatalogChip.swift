//
//  CatalogChip.swift
//  TrackMyIllness
//
//  The big tap target used to pick what you're reporting. Chips are deliberately
//  chunky: choosing an item should be one confident thumb tap.
//

import SwiftUI

struct CatalogChip: View {
    let item: CatalogItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: item.symbolName)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 24)
                Text(item.name)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? .white : Color.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? AnyShapeStyle(item.color.color)
                                     : AnyShapeStyle(item.color.color.opacity(0.12)))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(item.color.color.opacity(isSelected ? 0 : 0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    VStack(spacing: 12) {
        CatalogChip(item: PreviewData.sampleItem, isSelected: false) {}
        CatalogChip(item: PreviewData.sampleItem, isSelected: true) {}
    }
    .padding()
}
