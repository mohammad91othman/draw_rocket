
import UIKit
import PencilKit
import os

/// `DataModel` contains the drawings that make up the data model, including multiple image drawings and a signature drawing.
struct DataModel: Codable {
    
    /// Names of the drawing assets to be used to initialize the data model the first time.
    static let defaultDrawingNames: [String] = ["Notes"]
    
    /// The width used for drawing canvases.
    static let canvasWidth: CGFloat = 768
    
    /// The drawings that make up the current data model.
    var drawings: [PKDrawing] = []
    var signature = PKDrawing()
    
    var itemIdentifier:UUID
    
    func saveItem() {
        DataModelController.save(self, with: "\(itemIdentifier.uuidString)")
    }
    
  
    
  
}

/// `DataModelControllerObserver` is the behavior of an observer of data model changes.
protocol DataModelControllerObserver {
    /// Invoked when the data model changes.
    func dataModelChanged()
}

/// `DataModelController` coordinates changes to the data  model.
class DataModelController {
    var selecgedData : Data?
    /// The underlying data model.
    var dataModel = DataModel(itemIdentifier: UUID())
    
    /// Thumbnail images representing the drawings in the data model.
    var thumbnails = [UIImage]()
    var thumbnailTraitCollection = UITraitCollection() {
        didSet {
            // If the user interface style changed, regenerate all thumbnails.
            if oldValue.userInterfaceStyle != thumbnailTraitCollection.userInterfaceStyle {
                generateAllThumbnails()
            }
        }
    }
    static func getDocumentDirectory () -> URL {
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            return url
        }else{
            fatalError("Unable to get document directory")
        }
    }
    /// Dispatch queues for the background operations done by this controller.
    private let thumbnailQueue = DispatchQueue(label: "ThumbnailQueue", qos: .background)
    private let serializationQueue = DispatchQueue(label: "SerializationQueue", qos: .background)
    
    /// Observers add themselves to this array to start being informed of data model changes.
    var observers = [DataModelControllerObserver]()
    
    /// The size to use for thumbnail images.
    static let thumbnailSize = CGSize(width: 192, height: 256)
    
    /// Computed property providing access to the drawings in the data model.
    var drawings: [PKDrawing] {
        get { dataModel.drawings }
        set { dataModel.drawings = newValue }
    }
    /// Computed property providing access to the signature in the data model.
    var signature: PKDrawing {
        get { dataModel.signature }
        set { dataModel.signature = newValue }
    }
    
    /// Initialize a new data model.
    init() {
        loadDataModel()
    }
    
    /// Update a drawing at `index` and generate a new thumbnail.
    func updateDrawing(_ drawing: PKDrawing, at index: Int) {
        dataModel.drawings[index] = drawing
        generateThumbnail(index)
        saveDataModel()
    }
    func updateDrawing2(_ drawing: PKDrawing, at index: Int) {
        dataModel.drawings[index] = drawing
        generateThumbnail(index)
        saveDataModel()
    }
    
    /// Helper method to cause regeneration of all thumbnails.
    private func generateAllThumbnails() {
        for index in drawings.indices {
            generateThumbnail(index)
        }
    }
    
    /// Helper method to cause regeneration of a specific thumbnail, using the current user interface style
    /// of the thumbnail view controller.
    private func generateThumbnail(_ index: Int) {
        let drawing = drawings[index]
        let aspectRatio = DataModelController.thumbnailSize.width / DataModelController.thumbnailSize.height
        let thumbnailRect = CGRect(x: 0, y: 0, width: DataModel.canvasWidth, height: DataModel.canvasWidth / aspectRatio)
        let thumbnailScale = UIScreen.main.scale * DataModelController.thumbnailSize.width / DataModel.canvasWidth
        let traitCollection = thumbnailTraitCollection
        
        thumbnailQueue.async {
            traitCollection.performAsCurrent {
                let image = drawing.image(from: thumbnailRect, scale: thumbnailScale)
                DispatchQueue.main.async {
                    self.updateThumbnail(image, at: index)
                }
            }
        }
    }
    
    /// Helper method to replace a thumbnail at a given index.
    private func updateThumbnail(_ image: UIImage, at index: Int) {
        thumbnails[index] = image
        didChange()
    }
    
    /// Helper method to notify observer that the data model changed.
    private func didChange() {
        for observer in self.observers {
            observer.dataModelChanged()
        }
    }
    
    /// The URL of the file in which the current data model is saved.
    private var saveURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths.first!
        return documentsDirectory.appendingPathComponent("PencilKitDraw.data")
    }
    
    /// Save the data model to persistent storage.
    func saveDataModel() {
        let savingDataModel = dataModel
        let url = saveURL
        serializationQueue.async {
            do {
                let encoder = PropertyListEncoder()
                let data = try encoder.encode(savingDataModel)
                try data.write(to: url)
            } catch {
                os_log("Could not save data model: %s", type: .error, error.localizedDescription)
            }
        }
    }
    func saveDataModel(dataD: DataModel) {
       // let savingDataModel = dataModel
        let url = saveURL
        serializationQueue.async {
            do {
                let encoder = PropertyListEncoder()
                let data = try encoder.encode(dataD)
                try data.write(to: url)
            } catch {
                os_log("Could not save data model: %s", type: .error, error.localizedDescription)
            }
        }
    }
    
    /// Load the data model from persistent storage
     func loadDataModel() {
        let url = saveURL
        serializationQueue.async {
            // Load the data model, or the initial test data.
            let dataModel: DataModel
            
            if FileManager.default.fileExists(atPath: url.path) {
                do {
                    let decoder = PropertyListDecoder()
                    let data = try Data(contentsOf: url)
                    dataModel = try decoder.decode(DataModel.self, from: data)
                } catch {
                    os_log("Could not load data model: %s", type: .error, error.localizedDescription)
                    dataModel = self.loadDefaultDrawings()
                }
            } else {
                dataModel = self.loadDefaultDrawings()
            }
            
            DispatchQueue.main.async {
                self.setLoadedDataModel(dataModel)
            }
        }
    }
    func loadData()  {
        
        let savingDataModel = dataModel
        let url = saveURL
        serializationQueue.async {
            do {
                let encoder = PropertyListEncoder()
                let data = try encoder.encode(savingDataModel)
                let imageDataDict:[String: Data] = ["image": data]
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "sendD"), object: nil, userInfo: imageDataDict)
                try data.write(to: url)
                
            } catch {
                os_log("Could not save data model: %s", type: .error, error.localizedDescription)
            }
        }
        
   }
    func getDataFromModel () -> Data?
    {
        return selecgedData
    }
   
    
    static func save <T:Encodable> (_ object:T, with fileName:String) {
        let url = getDocumentDirectory().appendingPathComponent(fileName, isDirectory: false)
        
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(object)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            FileManager.default.createFile(atPath: url.path, contents: data, attributes: nil)
        }catch{
            fatalError(error.localizedDescription)
        }
    }
    /// Construct an initial data model when no data model already exists.
    private func loadDefaultDrawings() -> DataModel {
        var testDataModel = DataModel(itemIdentifier: UUID())
        for sampleDataName in DataModel.defaultDrawingNames {
            guard let data = NSDataAsset(name: sampleDataName)?.data else { continue }
            if let drawing = try? PKDrawing(data: data) {
                testDataModel.drawings.append(drawing)
            }
        }
        return testDataModel
    }
    
    /// Helper method to set the current data model to a data model created on a background queue.
    private func setLoadedDataModel(_ dataModel: DataModel) {
        self.dataModel = dataModel
        thumbnails = Array(repeating: UIImage(), count: dataModel.drawings.count)
        generateAllThumbnails()
    }
    
    /// Create a new drawing in the data model.
    func newDrawing() {
        let newDrawing = PKDrawing()
        dataModel.drawings.append(newDrawing)
        thumbnails.append(UIImage())
        updateDrawing(newDrawing, at: dataModel.drawings.count - 1)
    }
}
