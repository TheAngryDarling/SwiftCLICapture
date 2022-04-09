# CLI Capture

![swift >= 4.0](https://img.shields.io/badge/swift-%3E%3D4.0-brightgreen.svg)
![macOS](https://img.shields.io/badge/os-macOS-green.svg?style=flat)
![Linux](https://img.shields.io/badge/os-linux-green.svg?style=flat)
[![Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg?style=flat)](LICENSE.md)

Class used for capturing STD Out and STD Err of CLI processes

## Requirements

* Xcode 9+ (If working within Xcode)
* Swift 4.0+

## Usage

```swift
let cliCapture = CLICapture(executable: URL(fileURLWithPath: "/usr/bin/swift"))
// Captures both STD Out and STD Err of the process and does not pass any to STD Out or STD Err
// of our application
let resp = try cliCapture.waitAndCaptureStringResponse(arguments: ["--version"],
                                                       outputOptions: .captureAll)
// Check the terminationStatus of the process
if resp.exitStatusCode != 0 {

}
// Check the STD Out from the process
if let out = resp.out {

}
// Check the STD Err from the process
if let err = resp.err {

}
// Check the Output (STD Out + STD Err ordered) from the process
if let output = resp.output {

}
```

## Dependencies

* **[SwiftHelpfulProtocols](https://github.com/TheAngryDarling/SwiftHelpfulProtocols.git)** - Some helpful protocols used when dealing with generics

## Author

* **Tyler Anger** - *Initial work*  - [TheAngryDarling](https://github.com/TheAngryDarling)

## License

*Copyright 2022 Tyler Anger*

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

[HERE](LICENSE.md) or [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
