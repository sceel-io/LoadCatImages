//: A UIKit based Playground for presenting user interface
  
import UIKit
import Combine
import PlaygroundSupport

let apiUrl = URL(string: "https://api.thecatapi.com/v1/images/search")!

struct MeowResponse: Codable {
    let url: String
    
    private enum CodingKeys: String, CodingKey {
        case url
    }
}

enum MeowError: Error {
    case networkError(error: URLError)
    case badServerResponse(response: URLResponse)
    case badServerResponseData(coderError: Error)
}

class MyViewController : UIViewController {
    
    var imageView: UIImageView!
    var label: UILabel!
    
    var urlSession: URLSession?
    var cancellable: AnyCancellable!
    
    override func loadView() {
        let view = UIView()
        view.backgroundColor = .white

        imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.frame = CGRect(x: 50, y: 200, width: 200, height: 200)
        
        label = UILabel()
        label.frame = CGRect(x: 50, y: imageView.frame.maxY + 15, width: 200, height: 45)
        label.textAlignment = .center

        view.addSubview(imageView)
        view.addSubview(label)
        
        self.view = view
        
        cancellable = loadAll()
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { (completion: Subscribers.Completion<MeowError>) in
                switch completion {
                case .finished:
                    self.label.text = "Success"
                case .failure(let error):
                    switch error {
                    case .badServerResponse:
                        self.label.text = "Bad response"
                    case .badServerResponseData:
                        self.label.text = "Bad response data"
                    case .networkError:
                        self.label.text = "Network error"
                    }
                }
            
            }) { (imageData) in
                self.imageView?.image = UIImage(data: imageData)
            }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        imageView.center = CGPoint(x: view.bounds.midX,
                                   y: imageView.frame.minY + imageView.frame.height / 2)
        label.center = CGPoint(x: view.bounds.midX,
                               y: label.frame.minY + label.frame.height / 2)
        
        view.layoutIfNeeded()
    }
    
    func loadImageUrl() -> AnyPublisher<URL, MeowError> {
        if urlSession == nil {
            urlSession = URLSession(configuration: .default)
        }
        
        return urlSession!
            .dataTaskPublisher(for: apiUrl)
            .print()
            .mapError { (urlError: URLError) -> MeowError in
                MeowError.networkError(error: urlError)
            }
            .tryMap {
                if ($0.response as! HTTPURLResponse).statusCode != 200 {
                    throw MeowError.badServerResponse(response: $0.response)
                }
                return $0.data
            }
            .decode(type: [MeowResponse].self, decoder: JSONDecoder())
            .mapError { (error) -> MeowError in
                if let meowError = error as? MeowError {
                    return meowError
                }
                return MeowError.badServerResponseData(coderError: error)
            }
            .map { (response: [MeowResponse]) -> URL in
                URL(string:response.first!.url)!
            }
            .eraseToAnyPublisher()
    }
    
    func loadImageData(url: URL) -> AnyPublisher<Data, MeowError> {
        urlSession!
            .dataTaskPublisher(for: url)
            .mapError { (urlError: URLError) -> MeowError in
                return MeowError.networkError(error: urlError)
            }
            .tryMap { comp -> Data in
                if (comp.response as! HTTPURLResponse).statusCode != 200 {
                    throw MeowError.badServerResponse(response: comp.response)
                }
                return comp.data
            }
            .mapError{
                $0 as! MeowError
            }
            .eraseToAnyPublisher()
    }
    
    func loadAll() -> AnyPublisher<Data, MeowError> {
        loadImageUrl().flatMap {
            self.loadImageData(url: $0)
        }.eraseToAnyPublisher()

    }
}


// Present the view controller in the Live View window
PlaygroundPage.current.liveView = MyViewController()
