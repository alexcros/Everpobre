//
//  Notebook+CoreDataClass.swift
//  Everpobre
//
//  Created by Charles Moncada on 09/10/18.
//  Copyright © 2018 Charles Moncada. All rights reserved.
//
//

import Foundation
import CoreData

@objc(Notebook)
public class Notebook: NSManagedObject {

}

extension Notebook {
    func exportCSV() -> String {
        let exportName = self.name ?? "Unnamed"
        let exportedCreationDate = (creationDate as Date?)?.customStringLabel() ?? "ND"
        
        return "\(exportName),\(exportedCreationDate)\n"
    }
}
