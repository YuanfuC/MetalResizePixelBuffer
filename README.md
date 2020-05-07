# PerformancePixelBufferResize

This project is an example: How to Use Metal to resize CVPixelBuffer on the GPU.

### Resize detail steps:

* Create MTLTexture from  CVPixelBuffer

* MPSImageBilinearScale shaders scale texture for `scaleToFill\scaleAspectFit\ scaleAspectFill` mode

* Copy MTLTexture to MTLBuffer
 
* Create CVPixelBuffer from MTLBuffer


