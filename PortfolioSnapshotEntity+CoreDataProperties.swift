//
//  PortfolioSnapshotEntity+CoreDataProperties.swift
//  FinanceMinister
//
//  Created by Shuhei Kinugasa on 2026/01/06.
//
//

public import Foundation
public import CoreData


public typealias PortfolioSnapshotEntityCoreDataPropertiesSet = NSSet

extension PortfolioSnapshotEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PortfolioSnapshotEntity> {
        return NSFetchRequest<PortfolioSnapshotEntity>(entityName: "PortfolioSnapshotEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var totalvalue: Double

}

extension PortfolioSnapshotEntity : Identifiable {

}
