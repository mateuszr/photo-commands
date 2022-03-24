//
//  main.swift
//  PhotoCommands
//
//  Created by matt on 17/11/2021.
//

import Foundation
import Photos
import ArgumentParser
import CryptoKit

struct PhotoInfo {
    let Name:String
    let Id:String
}

enum PhotoErrors: Error {
    case wrongAlbumId
    case wrongArguments
    case otherError
}


@main
struct PhotoCommands: ParsableCommand {
    
    @Flag(name: [.customShort("l"), .long], help: "List all albums with some metadata.")
    var list = false
    
    @Flag(name: [.customShort("c"), .long], help: "Count all photos in library.")
    var count = false
    
    @Flag(name: [.customShort("L"), .long], help: "List photos in an album with basic metadata. Requires <albumId> argument.")
    var listPhotos = false
    
    @Flag(name: [.customShort("f"), .long], help: "Find images that are not photos. Requires <albumId> argument.")
    var findNonApplePhotos = false
    
    @Flag(name: [.customShort("d"), .long], help: "Find duplicate images. Requires <albumId> argument.")
    var findDuplicates = false
    
    @Flag(name: [.customShort("s"), .long], help: "Silent mode. Showing only summary at the end when looking for duplicates.")
    var silent = false
    
    @Argument(help: "Id of the album (as returned by -l command)")
    var albumId: String = ""
    
    //verify agruments. In principle we allow either -l (listing) and no need for albumId
    //or one of: -d, -f, -c, -L with albumId argument.
    //Other usage is wrong and triggers error + help usage
    //there is also possibilkity
    mutating func validate() throws {
        guard list == true || count == true
        || (findNonApplePhotos == true || findDuplicates == true || listPhotos == true) else {
            throw ValidationError("Please use '-l' to list albums or '-c' to count photos or '-f' or '-d' or '-L' with 'albumId' argument")
        }
        
        guard list == true || count == true
                || ((findNonApplePhotos == true || findDuplicates == true || listPhotos == true) && albumId != "") else {
                    throw ValidationError("Please provide an 'albumId' argument")
                }
    }
    
    mutating func run() throws {
        if list {
            allAlbums()
        }
        if count {
            countAllPhotos()
        }
        if findNonApplePhotos == true || findDuplicates == true {
            //process other options:
            try findPhotos(albumLocalIdentifier: albumId,
                           duplicates:findDuplicates,
                           nonApple: findNonApplePhotos,
                           showMetaData: listPhotos,
                           silent: silent)
        }
    }
}

func toggleFavorite(for asset: PHAsset, toggle value: Bool = false) {
    PHPhotoLibrary.shared().performChanges {
        let request = PHAssetChangeRequest(for: asset)
        request.isFavorite = value
    } completionHandler: { success, error in
        print("Asset marked as favourite: " + (success ? "Success." : error!.localizedDescription))
    }
}

func getDateString() -> String {
    let date = Date()
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let dateString = df.string(from: date)
    return dateString
}

func allAlbums() {
    print("Listing all albums")
    
    let resultsAllAlbums: PHFetchResult<PHAssetCollection> = PHAssetCollection.fetchAssetCollections(with: PHAssetCollectionType.album, subtype: PHAssetCollectionSubtype.any, options: PHFetchOptions?.none)
    
    for i in 1..<resultsAllAlbums.count {
        let x = resultsAllAlbums.object(at: i)
        
        //printing album properties
        print("id: \(x.localIdentifier)\tcount: \(x.estimatedAssetCount)\tstart date: \(String(describing: x.startDate!))\tend date: \(x.endDate!)\tname: \(x.localizedTitle!)")
    }
}

func sha256(input: Data) -> String {
    //usage: print(sha256(input: Data("Message".utf8)))
    
    
    return SHA256.hash(data: input).description
}


func countAllPhotos()  {
    let allPhotosOptions = PHFetchOptions()
    allPhotosOptions.includeAssetSourceTypes = [.typeUserLibrary]
    allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
    let allPhotos = PHAsset.fetchAssets(with: allPhotosOptions)
    let photoCount = allPhotos.count
    print("Total number of photos in library: \(photoCount)")
}

func getPhotoInfoByIndex(index: Int) {
    print("Get single photo detail by index in album.")
    let allPhotosOptions = PHFetchOptions()
    allPhotosOptions.includeAssetSourceTypes = [.typeUserLibrary]
    allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
    let allPhotos = PHAsset.fetchAssets(with: allPhotosOptions)
    let photo1 = allPhotos.object(at: index)
    //slet photo1 = allPhotos.firstObject
    
    //print("photo1 \(photo1.creationDate ?? noDate)")
    dump(photo1)
    dump(photo1.modificationDate)
    
    print("------")
    
}

func getPhotoInfoById(localIdentifier: String) {
    print("Get single photo detail by local identifier.")
    let photo2 = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: .none).firstObject
    //print("photo1 \(photo1.creationDate ?? noDate)")
    dump(photo2)
    
}

func albumForPhoto(photo: PHAsset) {
    print("Get algum details by photo local identifier.")
    let resultsAlbumOfAPhoto: PHFetchResult<PHAssetCollection> = PHAssetCollection.fetchAssetCollectionsContaining(photo, with: PHAssetCollectionType.album, options: nil)
    //(withLocalIdentifiers: [photo1.localIdentifier], options: option)
    
    dump(resultsAlbumOfAPhoto.firstObject)
    dump(resultsAlbumOfAPhoto.firstObject?.localIdentifier)
}


func findPhotos(albumLocalIdentifier: String,
                duplicates: Bool = false,
                nonApple: Bool = false,
                showMetaData: Bool = false,
                silent: Bool = false) throws {
    do {
        let resultFilteredAlbum: PHFetchResult<PHAssetCollection> = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumLocalIdentifier], options: PHFetchOptions?.none)
        
        guard resultFilteredAlbum.firstObject != nil else {
            throw PhotoErrors.wrongAlbumId
        }
        
        let photoAlbum:PHAssetCollection = resultFilteredAlbum.firstObject!
        
        let fetchOptionsSort = PHFetchOptions()
        fetchOptionsSort.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let resultsPhotosFromAlbum: PHFetchResult = PHAsset.fetchAssets(in: photoAlbum, options: fetchOptionsSort)
        
        print("Total number of photos in album: \(resultsPhotosFromAlbum.count)")
        let exifKeyLens = "LensModel"
        let exifKeyLensMake = "LensMake"
        let exifDateTime = "DateTimeOriginal"
        let exifOffsetTime = "OffsetTime"
        let exifXDim = "PixelXDimension"
        let exifYDim = "PixelYDimension"
        
        let manager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        let requestOptionsVideo = PHVideoRequestOptions()
        requestOptions.isSynchronous = true
        requestOptions.deliveryMode = .fastFormat
        requestOptions.version = .current
        
        //Hashmap storing size and name of am asset (picture or video). Duplicates are detected based on the file size.
        var fileDuplicatesList: [String: [String]] = [:]
        var fileDuplicateHashList: [String: PhotoInfo] = [:]
        
        for i in 0..<resultsPhotosFromAlbum.count {
            let asset = resultsPhotosFromAlbum.object(at: i)
            
            let dispatchGroup = DispatchGroup()
            let dispatchGroup2 = DispatchGroup()
            
            //dump(asset)
            autoreleasepool {
                manager.requestImageDataAndOrientation(for: asset, options: requestOptions) { (data, fileName, orientation, info) in
                    if let data = data, let cImage = CIImage(data: data) {
                        //init all variables for keeping details of an assset
                        var sizeOnDisk: Int64 = 0
                        var video = "no"
                        var composableVideo = "no"
                        var plens = ""
                        var pmaker  = ""
                        var pexifdate = ""
                        var poffsettime = ""
                        var xDim:Int32 = 0
                        var yDim:Int32 = 0
                        var pname = ""
                        var isDuplicate = false
                        
                        let ar = PHAssetResource.assetResources(for: asset)
                        let pdate = asset.creationDate!
                        let album = photoAlbum.localizedTitle!
                        let shaHash = sha256(input: data)
                        let fav = asset.isFavorite
                        
                        //getting asset is asynchronous, we need to synchronise it to properly store all details of an asset
                        dispatchGroup.enter()
                        _ = manager.requestAVAsset(forVideo: asset, options: requestOptionsVideo, resultHandler: {
                            (asset: AVAsset?, audioMix: AVAudioMix?, info: [AnyHashable : Any]?) -> Void in
                            if let avAsset = asset {
                                //dump(asset)
                                
                                let metadata = asset!.metadata(forFormat: AVMetadataFormat.quickTimeMetadata)
                                //slowmo - check for AVComposition
                                //print("metadata")
                                //dump(metadata)
                                if (asset!.isComposable == true)   {
                                    //print("composable")
                                    
                                    
                                    //dump(info?["PHAdjustmentDataKey"])
                                    
                                    if info?["PHAdjustmentDataKey"] != nil {
                                        pmaker = "Apple"
                                        //other possibility: get better information from the PHAdjustmentData.data
                                        //let phdata:PHAdjustmentData = info?["PHAdjustmentDataKey"] as! PHAdjustmentData
                                        //dump(phdata.formatIdentifier)
                                        //dump(phdata.data)
                                        //dump(asset!.tracks)
                                        //let avcompo:AVComposition = asset as! AVComposition
                                        //dump(avcompo.tracks)
                                    }
                                }
                                
                                //check if we are dealing with video
                                for i in metadata {
                                    //print(i)
                                    let a:AVMetadataItem = i
                                    if (a.value(forKey: "key") as! String == "com.apple.quicktime.make") {
                                        pmaker =  a.value(forKey: "value") as! String
                                    }
                                    if (a.value(forKey: "key") as! String == "com.apple.quicktime.model") {
                                        plens =  a.value(forKey: "value") as! String
                                    }
                                    video = "yes"
                                    //print("video: \(pmaker) \(plens)")
                                    //print(a.value(forKey: "key"))
                                }
                            }
                            dispatchGroup.leave()
                        })
                        
                        dispatchGroup.wait()
                        
                        if ar != nil {
                            pname = PHAssetResource.assetResources(for: asset)[0].originalFilename
                        } else {
                            pname = "NA"
                        }
                        
                        let resources = PHAssetResource.assetResources(for: asset) // your PHAsset
                        
                        if let resource = resources.first {
                            let unsignedInt64 = resource.value(forKey: "fileSize") as? CLong
                            sizeOnDisk = Int64(bitPattern: UInt64(unsignedInt64!))
                            
                        }
                        
                        //get what we can from EXIF metadata
                        if let exif = cImage.properties["{Exif}"] as? [String:Any] {
                            
                            //Lens
                            if let value = exif[exifKeyLens] as? String {
                                plens = value
                            }
                            else {
                                if plens == "" {
                                    plens = "NA"
                                }
                            }
                            
                            //Lens manufacturer
                            if let value = exif[exifKeyLensMake] as? String {
                                pmaker = value
                            }
                            else {
                                if pmaker == "" {
                                    pmaker = "NA"
                                }
                            }
                            
                            //date and time of an asset
                            if let value = exif[exifDateTime] as? String {
                                pexifdate = value
                            }
                            else {
                                pexifdate = "NA"
                            }
                            
                            //time zone
                            if let value = exif[exifOffsetTime] as? String {
                                poffsettime = value
                            }
                            else {
                                poffsettime = "NA"
                            }
                            
                            //horizontal size in pixels
                            if let value = exif[exifXDim] as? Int32 {
                                xDim = value
                            } else {
                                xDim = 0
                            }
                            
                            //vertical size in pixels
                            if let value = exif[exifYDim] as? Int32 {
                                yDim = value
                            } else {
                                yDim = 0
                            }
                        }
                        else {
                            //in case of video and missing EXIF data, setting default value to "NA"
                            if pmaker == "" {
                                pmaker = "NA"
                            }
                            if plens == "" {
                                plens = "NA"
                            }
                        }
                        //let defaultValue = "NA"
                        let identifier = asset.localIdentifier
                        if showMetaData == true {
                            print("{\"lens\": \"\(plens)\", \"maker\":  \"\(pmaker)\", \"date\": \"\(pdate)\", \"exifdate\": \"\(pexifdate)\", \"offset\": \"\(poffsettime)\", \"album\": \"\(album)\", \"name\": \"\(pname)\", \"xdim\": \(xDim),  \"ydim\": \(yDim), \"id\": \"\(identifier)\", \"fav\": \(fav), \"size\": \(sizeOnDisk), sha256: \"\(shaHash)\"}")
                        }
                        
                        //it looks like optimising image deduplication by first checking size (cheap)
                        //and then only calculating hash if size is the same doesn;t really matter.
                        //calculating hash for all photos takes exactly the same amount of time.
                        //we will then skip checking for size and rather check hash directly.
                        /*
                         if fileDuplicates[sizeOnDisk] != nil {
                         isDuplicate = true
                         } else {
                         fileDuplicates[sizeOnDisk] = pname
                         fileDuplicatesList[pname] = []
                         }
                         */
                        dispatchGroup2.enter()
                        
                        if fileDuplicateHashList[shaHash] != nil {
                            isDuplicate = true
                        } else {
                            fileDuplicateHashList[shaHash] = PhotoInfo(Name: pname, Id: identifier)
                            fileDuplicatesList[pname] = []
                        }
                        
                        dispatchGroup2.leave()
                        
                        //we mark only duplicates
                        if duplicates == true {
                            if isDuplicate == true  {
                                
                                
                                let name = PHAssetResource.assetResources(for: asset)[0]
                                let originalName = fileDuplicateHashList[shaHash]!.Name
                                let originalId = fileDuplicateHashList[shaHash]!.Id
                                
                                if silent == false {
                                    print(getDateString() +  " Duplicate found! Name: \(name.originalFilename), id: \(name.assetLocalIdentifier) is duplicate with file name: \(originalName), id: \(originalId)")
                                }
                                
                                //we might remove it later, as all duplicates are listed above.
                                fileDuplicatesList[originalName]?.append(pname)
                                
                                toggleFavorite(for: asset, toggle: true)
                                
                            }
                        }
                        
                        if nonApple == true {
                            //set favorite to all non apple pictures
                            //we mark all that are not taken by phone
                            if pmaker == "NA" {
                                let name = PHAssetResource.assetResources(for: asset)[0]
                                
                                if silent == false {
                                    print("Non-apple image found: \(name), id: \(identifier)")
                                }
                                toggleFavorite(for: asset, toggle: true)
                                //usleep(5)
                                //dump(name)
                            }
                        }
                    }
                    else {
                        print("Error: cannot get image data \(i)")
                        dump(asset)
                        dump(fileName)
                        dump(info)
                        print("----")
                    }
                }
            }
        }
    } catch {
        print("Error: There is a problem with opening the album. Please check if albumId is correct.")
    }
}
