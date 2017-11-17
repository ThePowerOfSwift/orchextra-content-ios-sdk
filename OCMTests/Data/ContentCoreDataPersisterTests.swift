//
//  ContentCoreDataPersisterTests.swift
//  OCMTests
//
//  Created by José Estela on 7/11/17.
//  Copyright © 2017 Gigigo SL. All rights reserved.
//

import XCTest
import GIGLibrary
import Nimble
import CoreData
@testable import OCMSDK

class ContentCoreDataPersisterTests: XCTestCase {
    
    // MARK: - Attributes
    
    var persister: ContentCoreDataPersister!
    var managedObjectContext: NSManagedObjectContext!
    
    fileprivate lazy var applicationDocumentsDirectory: URL = {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[urls.count-1]
    }()
    
    fileprivate lazy var managedObjectModel: NSManagedObjectModel! = {
        guard let modelURL = Bundle.OCMBundle().url(forResource: "ContentDB", withExtension: "momd") else { return nil }
        return NSManagedObjectModel(contentsOf: modelURL)
    }()
    
    override func setUp() {
        super.setUp()
        self.managedObjectContext = setUpInMemoryManagedObjectContext()
        self.persister = ContentCoreDataPersister(managedObjectContext: self.managedObjectContext)
    }
    
    override func tearDown() {
        self.managedObjectContext = nil
        self.persister = nil
        super.tearDown()
    }
    
    func test_persister_saveMenusCorrectly() {
        // Arrange
        let json = JSON.from(file: "menus_ok")
        let menus = json["data.menus"]!.flatMap({ try? Menu.menuList($0) })
        // Act
        self.saveMenusAndSections(from: json)
        // Assert
        expect(self.persister.loadMenus().map({ $0.slug })).toEventually(equal(menus.map({ $0.slug })))
    }
    
    func test_persister_saveMenusAndSectionsCorrectly() {
        // Arrange
        let json = JSON.from(file: "menus_ok")
        let menus = json["data.menus"]!.flatMap({ try? Menu.menuList($0) })
        // Act
        self.saveMenusAndSections(from: json)
        // Assert
        expect(self.persister.loadMenus()).toEventually(equal(menus))
    }
    
    func test_persister_whenThereAreSectionsAlreadySaved_andNewSectionsWantToBeSaved_removeNonexistentDBSectionsInNewSections() {
        // Arrange
        let json = JSON.from(file: "menus_ok")
        let jsonWithOneSection = JSON.from(file: "menus_ok_with_one_section")
        let menusWithOneSection = jsonWithOneSection["data.menus"]!.flatMap({ try? Menu.menuList($0) })
        // Act
        self.saveMenusAndSections(from: json)
        self.saveMenusAndSections(from: jsonWithOneSection)
        // Assert
        expect(self.persister.loadMenus()).toEventually(equal(menusWithOneSection))
    }
    
    /*func test_persister_whenCleanDataBase_dbShouldBeEmpty() {
        // Arrange
        
        // Act
        
        // Assert
        //let allObjects = self.managedObjectModel.entities.map({ self.fetchAllObjects(of: $0.name!, in: self.managedObjectContext) })
    }*/
    
    // MARK: - Private methods
    
    private func fetchAllObjects(of entity: String, in context: NSManagedObjectContext?) -> [NSManagedObject] {
        var result: [NSManagedObject] = []
        context?.performAndWait({
            let fetch: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entity)
            guard let results = try? context?.fetch(fetch) else { return }
            result = results as! [NSManagedObject]
        })
        return result
    }
    
    private func saveMenusAndSections(from json: JSON) {
        guard
            let menuJson = json["data.menus"]
            else {
                return
        }
        
        let menus = menuJson.flatMap { try? Menu.menuList($0) }
        self.persister.save(menus: menus)
        var sectionsMenu: [[String]] = []
        for menu in menuJson {
            guard
                let menuModel = try? Menu.menuList(menu),
                let elements = menu["elements"]?.toArray() as? [NSDictionary],
                let elementsCache = json["data.elementsCache"]
                else {
                    return
            }
            // Sections to cache
            var sections = [String]()
            // Save sections in menu
            let jsonElements = elements.map({ JSON(from: $0) })
            self.persister.save(sections: jsonElements, in: menuModel.slug)
            for element in jsonElements {
                if let elementUrl = element["elementUrl"]?.toString(),
                    let elementCache = elementsCache["\(elementUrl)"] {
                    // Save each action in section
                    self.persister.save(action: elementCache, in: elementUrl)
                    if let sectionPath = elementCache["render"]?["contentUrl"]?.toString() {
                        sections.append(sectionPath)
                    }
                }
            }
            sectionsMenu.append(sections)
        }
    }
    
    private func saveContentAndActions(from json: JSON, in path: String) {
        let expirationDate = json["data.expireAt"]?.toDate()
        // Save content in path
        self.persister.save(content: json, in: path, expirationDate: expirationDate)
        if let elementsCache = json["data.elementsCache"]?.toDictionary() {
            for (identifier, action) in elementsCache {
                // Save each action linked to content path
                self.persister.save(action: JSON(from: action), with: identifier, in: path)
            }
        }
    }
    
    private func setUpInMemoryManagedObjectContext() -> NSManagedObjectContext {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.appendingPathComponent("ContentDB.sqlite")
        let options = [ NSInferMappingModelAutomaticallyOption: true,
                        NSMigratePersistentStoresAutomaticallyOption: true]
        do {
            try coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: url, options: options)
        } catch let error {
            print(error)
        }
        let managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return managedObjectContext
    }
}