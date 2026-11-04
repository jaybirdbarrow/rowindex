// Stitches the PNG frames from render-intro.sh into an H.264 MP4 (1080x1920, 60fps).
// Usage: swift render-intro-encode.swift <frames dir> <out.mp4>
import AVFoundation
import AppKit
let dir=CommandLine.arguments[1], out=URL(fileURLWithPath:CommandLine.arguments[2])
try? FileManager.default.removeItem(at:out)
let W=1080,H=1920; let FPS:Int32=60
let w=try! AVAssetWriter(outputURL:out,fileType:.mp4)
let inp=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:W,AVVideoHeightKey:H,
  AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey:20_000_000,AVVideoProfileLevelKey:AVVideoProfileLevelH264HighAutoLevel]])
inp.expectsMediaDataInRealTime=false
let ad=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:inp,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32ARGB,kCVPixelBufferWidthKey as String:W,kCVPixelBufferHeightKey as String:H])
w.add(inp); w.startWriting(); w.startSession(atSourceTime:.zero)
let files=try! FileManager.default.contentsOfDirectory(atPath:dir).filter{$0.hasSuffix(".png")}.sorted()
for (i,f) in files.enumerated(){
  let img=NSImage(contentsOfFile:dir+"/"+f)!.cgImage(forProposedRect:nil,context:nil,hints:nil)!
  var pb:CVPixelBuffer?
  CVPixelBufferPoolCreatePixelBuffer(nil,ad.pixelBufferPool!,&pb)
  CVPixelBufferLockBaseAddress(pb!,[])
  let ctx=CGContext(data:CVPixelBufferGetBaseAddress(pb!),width:W,height:H,bitsPerComponent:8,bytesPerRow:CVPixelBufferGetBytesPerRow(pb!),space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.noneSkipFirst.rawValue)!
  ctx.draw(img,in:CGRect(x:0,y:0,width:W,height:H))
  CVPixelBufferUnlockBaseAddress(pb!,[])
  while !inp.isReadyForMoreMediaData { usleep(2000) }
  ad.append(pb!,withPresentationTime:CMTime(value:Int64(i),timescale:FPS))
}
inp.markAsFinished()
let sem=DispatchSemaphore(value:0); w.finishWriting{sem.signal()}; sem.wait()
if w.status != .completed { print("Encode failed:", w.error as Any); exit(1) }
