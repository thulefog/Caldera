# (Mount) Garibaldi

Garibaldi is a reference to [Mount Garibaldi](https://en.wikipedia.org/wiki/Mount_Garibaldi) which is a dormant stratovolcano in southwest British Columbia.

This builds on work enabling the iPhone camera as a capture device and channeling to a Metal pipeline creates an explosion of pixel data, a volcano of sorts.

**Current State:** Under Construction 🚧

The foundation models integration and forward pass wire up points that will be enabled as user selections are being evaluated in local working source code branches. These are not included in the repository yet. 

See the `Reference` section for more details around some of the baseline Foundation Models from Apple.

# Abstract

The original context for the code behind the original rough concept proof dates back to workbench learning in 2018 around a Metal based camera pipeline and evolution into early steps with a set of Machine Learning foundation models.

This is a rewrite and modernization, leveraging code level lessons learned as well as changes and evolutions in the Apple frameworks and ecosystem.

Reference the breakdown of the workflow features summarized in the table below.

|Workflow|Description|
|--|--|
| Augmentation | Minimal image filter set based on OpenCV2 | 
| Texture | Minimal image viewer using a `Metal` texture based canvas |
| Predictor | Primitive image classification based on the `MobileNet` model |
| Surface Render | Provides ability to load an STL 3D point cloud and render in a `SceneKit` view |

A refactor increment to generalize a classification pipeline is part of a spike in progress, but was replaced with a static (single frame) image viewer that is based on `Metal` and makes specific use of textures as a GPU pipeline enabler.

## User Interface 

The user interface under construction is illustrated below.

These screens represent the workflow to select or capture an image, then post process in augumentation or classification pathways. 

- 2D

There are concept proof, works in progress, features related to 2D static image capture and post processing.

| Augmentation | Classification |
|--|--|
| <img src="/statics/mtg-augment.png" alt="augment" width="256"> | <img src="/statics/mtg-predict.png" alt="predict" width="256">  |

- 3D

There is a concept proof feature related to loading a 3D STL format point cloud into a `SceneKit` view. Note that this is being reworked to shift to `RealityKit` based on the Apple framework evolution paths.

| Select | Render |
|--|--|
| <img src="/statics/mtg-surface-render-1.png" alt="select" width="256"> | <img src="/statics/mtg-surface-render-2.png" alt="render" width="256">  |

NOTE: Example STL point clouds were sourced from the NIH 3D download set, [here](https://3d.nih.gov/discover?q=brain&sort=relevant).

# References

As relates to the image capture and `Classification` pathways there are some common denonimators, code level, with the separate open source project, [Cinder Code](https://github.com/thulefog/CinderCone/tree/develop)

- Machine Learning Models

Reference this code example which was uses `MobileNet` model
[Apple Sample Code: Classifying Images with Vision and Core ML](https://developer.apple.com/documentation/coreml/classifying-images-with-vision-and-core-ml) - which provied a baseline implementation to start from.

NOTE: This approach showed some sensitivity with switching from Swift version 5 to 6 as far as concurrency changes in flight. The Swift Compiler** setting `Swift Language Version` needed to be left at Unspecified. In short, alternative approaches to what is described in that Apple example are being explored as offline homework.

This code sample was not used but as reference point - uses a diffent `Core ML Model`, `ObjectDetector` approach: [Apple Sample Code: Recognizing Objects in Live Capture](
https://developer.apple.com/documentation/vision/recognizing-objects-in-live-capture)

See also, the baseline foundation model set: [Apple: Core ML Models](https://developer.apple.com/machine-learning/models)

- Metal

[Metal Programming Guide,  Janie Clayton, Addison-Wesley, 2017](https://www.safaribooksonline.com/library/view/metal-programming-guide/9780134668963/ch06.xhtml)

[Apple Developer Sample Code: Metal samples](https://developer.apple.com/search/?q=metal%20sample&type=Sample%20Code)

# Software License

Selected components of this project are a derivative of MetalRenderCamera, originally licensed under the Apache License, Version 2.0. This version includes additional modifications described herein. Portions of this code are reproduced under the terms of the Apache License, Version 2.0.

The original open source code used as a starting point was Apache 2.0 licensed. Changes in Swift around @objc inference called for slight local changes to the original code published on Github by the original author. Addditional adjustments surfaced that were needed due to the Swift 5.x to 6.x changes.

The rest of the source code is under the MIT License as per below:

MIT License

Copyright (c) 2025 John Matthew Weston

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
