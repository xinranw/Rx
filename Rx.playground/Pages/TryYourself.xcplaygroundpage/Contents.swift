/*:
 > # IMPORTANT: To use **Rx.playground**:
 1. Open **Rx.xcworkspace**.
 1. Build the **RxSwift-macOS** scheme (**Product** → **Build**).
 1. Open **Rx** playground in the **Project navigator**.
 1. Show the Debug Area (**View** → **Debug Area** → **Show Debug Area**).
 */
import Foundation
import RxSwift

/*:
 # Try Yourself
 
 It's time to play with Rx 🎉
 */
playgroundShouldContinueIndefinitely()

example("Try yourself") {
  // let disposeBag = DisposeBag()
  _ = Observable.just("Hello, RxSwift!")
    .debug("Observable")
    .subscribe()
    // .disposed(by: disposeBag) // If dispose bag is used instead, sequence will terminate on scope exit
}

let disposeBag = DisposeBag()

let helloWorld: Observable<String> = Observable.just("hello world")

helloWorld
    .subscribe(onNext: { (string) in
        print(string)
    })


let numbers: Observable<Int> = Observable.from([1, 2, 3, 4, 5])

numbers.subscribe(onNext: { print($0) })


func loadData(completion: (Data?, Error?) -> Void) {

}
func getData() -> Observable<Data?> {
    return Observable.create { observer in
        loadData { (data, error) in
            if let error = error {
                observer.onError(error)
            }
            observer.onNext(data)
            observer.onCompleted()
        }
        return Disposables.create()
    }
}

getData()
    .subscribe(onNext: { data in
        // handle the data
    }, onError: { error in
        // handle error
    })
    .disposed(by: disposeBag)



//
//struct Stock {
//    var price: Int
//    func isAmerican() -> Bool {
//        return true
//    }
//}
//let fetchStocks: Observable<Stock>
//fetchStocks // Observable<Stock>
//    .filter { $0.isAmerican() }
//    .map { $0.price }
//    .subscribe(onNext: { price in
//        print(price)
//    })
//
//
func simpleRequest(with req: URLRequest) -> Observable<[String: Any]> {
    return URLSession.shared.rx.json(request: req)
}

func customRequest(with req: URLRequest) -> Observable<(Data?, URLResponse?)> {
    return Observable.create{ observer in
        URLSession.shared.dataTask(with: req) { (data, response, error) in
            if let error = error {
                observer.onError(error)
            }
            observer.onNext((data, response))
            observer.onCompleted()
        }
        return Disposables.create()
    }
}

var request: URLRequest = URLRequest(url:
    URL(string: "http://api.mysite.com/test")!)
request.setValue("token", forHTTPHeaderField: "Authentication")
request.httpMethod = "POST"

let reqObservable = simpleRequest(with: request)
reqObservable
    .subscribe(onNext: { json in
        // handle json response
    })
    .disposed(by: disposeBag)

enum APIError: Error {
    case invalidResponse(URLResponse?)
    case badStatusCode(URLResponse)
    case badData(Data?, URLResponse?)
    case jsonParsingError
}

class APIClient {
    
    let apiClientDisposeBag = DisposeBag()
    
    func response(request: URLRequest, completion: ([String: Any])->Void) {
        responseObservable(request: request)
            .subscribe(onNext: { data in
                completion(data)
            })
            .disposed(by: apiClientDisposeBag)
    }
    
    func responseObservable(request: URLRequest) -> Observable<[String: Any]> {
        return rxResponse(request)
            .flatMap { (data: Data?, response: URLResponse?) throws -> Observable<[String: Any]> in
                return try handle(data: data, response: response)
            }
            // .retry(3)
            .retryWhen { (errors: Observable<Error>) -> ObservableType in
                return errors.enumerated.flatMap { (error, i) -> ObservableType in
                    return handle(error: error, i: i)
                }
        }
    }
    
    private func rxResponse(req: URLRequest) -> Observable<Data?, Response?> {
        return Observable.create{ observer in
            URLSession.shared.dataTask(with: req) { (data, response, error) in
                if let error = error {
                    observer.onError(error)
                }
                observer.onNext((data, response))
                observer.onCompleted()
            }
            return Disposables.create()
        }
    }
    
    private func handle(data: Data?, response: URLResponse?) throws -> Observable<[String: Any]> {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse(response)
        }
        
        guard 200..<300 ~= httpResponse.statusCode else {
            throw APIError.badStatusCode(httpResponse)
        }
        
        guard let responseData = data else {
            throw APIError.badData(data, httpResponse)
        }
        
        if let json = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any] {
            return Observable.just(json)
        } else {
            throw APIError.jsonParsingError
        }
    }
    
    private func handle(error: Error, i: Int) -> Observable<Any> {
        // handle max number of retries based on `i`
        guard i < 3 else {
            return Observable.error(error) // propagate error
        }
        
        switch error {
        // case .expiredToken:
        //    refreshToken()
        //    return Observable.just(()) <- forces retry
        default:
            return Observable.just(()) // <- forces retry
        }
    }
}

let customReqObservable = customRequest(with: request)
    .flatMap { (data: Data?, response: URLResponse?) throws -> Observable<[String: Any]> in
        return try handle(data: data, response: response)
    }
    // .retry(3)
    .retryWhen { (errors: Observable<Error>) -> ObservableType in
        return errors.enumerated.flatMap { (error, i) -> ObservableType in
            return handle(error: error, i: i)
        }
    }

customReqObservable
    .subscribe(onNext: { json in
        // do stuff with json
    }, onError: { error in
        // handle any errors that were propagated down
    })
    .disposed(by: disposeBag)

//
// combine stream operators
let mediaIds: [Int] = []
func isImage(_ id: Int) -> Bool {
    return true
}
func isVideo(_ id: Int) -> Bool {
    return true
}
struct Store {
    func isFull() -> Bool {
        return true
    }
}
let imageStore = Store()
struct Media {
    init(_ image: Media, _ video: Media) {
    }
}
protocol API {
    func fetchImage(_ id: Int) -> Observable<Media>
    func fetchVideo(_ id: Int) -> Observable<Media>
    func autocomplete(_ text: String) -> Observable<String>
}
func isCached(_ id: Int) -> Bool {
    return true
}
func fetchMedia(with api: API) {
    Observable.from(mediaIds)
        .filter { !isCached($0) }
        .flatMap { id -> Observable<Media> in
            if isImage(id) && isVideo(id) {
                return Observable.zip(
                    api.fetchImage(id),
                    api.fetchVideo(id)
                ) { (image, video) in
                    return Media(image, video)
                }
            } else if isImage(id) {
                return api.fetchImage(id)
            } else if isVideo(id) {
                return api.fetchImage(id)
            } else {
                return Observable.never()
            }
        }
}
//
//let textFieldValues: Observable<String> = Observable.from(["", ""])
//struct UILabel {
//    var text: String = ""
//}
//var autocompleteLabel = UILabel()
//func textField(api: API) {
//    textFieldValues
//        .filter { $0.isEmpty }
//        .throttle(2, latest: false, scheduler: MainScheduler.instance)
//        .flatMap { value -> Observable<String> in
//            return api.autocomplete(value)
//        }
//        .observeOn(MainScheduler.instance)
//        .subscribe(onNext: { value in
//            autocompleteLabel.text = value
//        })
//        .disposed(by: disposeBag)
//}

