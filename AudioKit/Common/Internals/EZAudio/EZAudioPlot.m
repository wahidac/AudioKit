//
//  EZAudioPlot.m
//  EZAudio
//
//  Created by Syed Haris Ali, revision history on Githbub.
//  Copyright (c) 2015 Syed Haris Ali. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "AudioKit/EZAudio.h"
#import "EZAudioPlot.h"

//------------------------------------------------------------------------------
#pragma mark - Constants
//------------------------------------------------------------------------------

UInt32 const kEZAudioPlotMaxHistoryBufferLength = 8192;
UInt32 const kEZAudioPlotDefaultHistoryBufferLength = 512;
UInt32 const EZAudioPlotDefaultHistoryBufferLength = 512;
UInt32 const EZAudioPlotDefaultMaxHistoryBufferLength = 8192;

//------------------------------------------------------------------------------
#pragma mark - EZAudioPlot (Implementation)
//------------------------------------------------------------------------------

@implementation EZAudioPlot

//------------------------------------------------------------------------------
#pragma mark - Dealloc
//------------------------------------------------------------------------------

- (void)dealloc
{
    [EZAudioUtilities freeHistoryInfo:self.historyInfo];
    free(self.points);
}

//------------------------------------------------------------------------------
#pragma mark - Initialization
//------------------------------------------------------------------------------

- (id)init
{
    self = [super init];
    if (self)
    {
        [self initPlot];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        [self initPlot];
    }
    return self;
}

#if TARGET_OS_IPHONE
- (id)initWithFrame:(CGRect)frameRect
#elif TARGET_OS_MAC
- (id)initWithFrame:(NSRect)frameRect
#endif
{
    self = [super initWithFrame:frameRect];
    if (self)
    {
        [self initPlot];
    }
    return self;
}

#if TARGET_OS_IPHONE
- (void)layoutSubviews
{
    [super layoutSubviews];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.waveformLayer.frame = self.bounds;
    [self redraw];
    [CATransaction commit];
}
#elif TARGET_OS_MAC
- (void)layout
{
    [super layout];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.waveformLayer.frame = self.bounds;
    [self redraw];
    [CATransaction commit];
}
#endif

- (void)initPlot
{
    self.shouldCenterYAxis = YES;
    self.shouldOptimizeForRealtimePlot = YES;
    self.gain = 1.0;
    self.plotType = EZPlotTypeBuffer;
    self.shouldMirror = NO;
    self.shouldFill = NO;

    // Setup history window
    [self resetHistoryBuffers];

    self.waveformLayer = [EZAudioPlotWaveformLayer layer];
    self.waveformLayer.frame = self.bounds;
    self.waveformLayer.lineWidth = 1.0f;
    self.waveformLayer.fillColor = nil;
    self.waveformLayer.backgroundColor = nil;
    self.waveformLayer.opaque = YES;

#if TARGET_OS_IPHONE
    self.color = [UIColor colorWithHue:0 saturation:1.0 brightness:1.0 alpha:1.0];
#elif TARGET_OS_MAC
    self.color = [NSColor colorWithCalibratedHue:0 saturation:1.0 brightness:1.0 alpha:1.0];
    self.wantsLayer = YES;
    self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;
#endif
    self.originalColor = self.color;
    self.backgroundColor = nil;
    self.fadeout = false;
    [self.layer insertSublayer:self.waveformLayer atIndex:0];

    //
    // Allow subclass to initialize plot
    //
    [self setupPlot];

    // Allocate an array of points, guessing this is what we will plot
    self.points = calloc(EZAudioPlotDefaultMaxHistoryBufferLength, sizeof(CGPoint));
    self.pointCount = [self initialPointCount];
    [self redraw];
}

//------------------------------------------------------------------------------

- (void)setupPlot
{
    //
    // Override in subclass
    //
}

//------------------------------------------------------------------------------
#pragma mark - Setup
//------------------------------------------------------------------------------

- (void)resetHistoryBuffers
{
    //
    // Clear any existing data
    //
    if (self.historyInfo)
    {
        [EZAudioUtilities freeHistoryInfo:self.historyInfo];
    }

    self.historyInfo = [EZAudioUtilities historyInfoWithDefaultLength:[self defaultRollingHistoryLength]
                                                        maximumLength:[self maximumRollingHistoryLength]];
}

//------------------------------------------------------------------------------
#pragma mark - Setters
//------------------------------------------------------------------------------

- (void)setBackgroundColor:(id)backgroundColor
{
    [super setBackgroundColor:backgroundColor];
    self.layer.backgroundColor = [backgroundColor CGColor];
}

//------------------------------------------------------------------------------

- (void)setColor:(id)color
{
    [super setColor:color];
    self.originalColor = color;
    self.waveformLayer.strokeColor = [color CGColor];
    if (self.shouldFill)
    {
        self.waveformLayer.fillColor = [color CGColor];
    }
}
- (void)updateColor:(id)color
{
    [super setColor:color];
    self.waveformLayer.strokeColor = [color CGColor];
    if (self.shouldFill)
    {
        self.waveformLayer.fillColor = [color CGColor];
    }
}

//------------------------------------------------------------------------------

- (void)setShouldOptimizeForRealtimePlot:(BOOL)shouldOptimizeForRealtimePlot
{
    _shouldOptimizeForRealtimePlot = shouldOptimizeForRealtimePlot;
    if (shouldOptimizeForRealtimePlot && !self.displayLink)
    {
        self.displayLink = [EZAudioDisplayLink displayLinkWithDelegate:self];
        [self.displayLink start];
    }
    else
    {
        [self.displayLink stop];
        self.displayLink = nil;
    }
}

//------------------------------------------------------------------------------

- (void)setShouldFill:(BOOL)shouldFill
{
    [super setShouldFill:shouldFill];
    self.waveformLayer.fillColor = shouldFill ? [self.color CGColor] : nil;
}

//------------------------------------------------------------------------------
#pragma mark - Drawing
//------------------------------------------------------------------------------

- (void)clear
{
    if (self.pointCount > 0)
    {
        [self resetHistoryBuffers];
        float data[self.pointCount];
        memset(data, 0, self.pointCount * sizeof(float));
        [self setSampleData:data length:self.pointCount];
        [self redraw];
    }
}

//------------------------------------------------------------------------------

- (void)redraw
{
    EZRect frame = [self.waveformLayer frame];
    CGPathRef path = [self createPathWithPoints:self.points
                                     pointCount:self.pointCount
                                         inRect:frame];
    
    if (!self.hasDumpedPointsOnce && self.pointCount > 1 && self.points[1].y > 0.0) {
        [self dumpPathToFile:path points:self.points pointCount:self.pointCount];
    }
    
    
    if (self.shouldOptimizeForRealtimePlot)
    {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        self.waveformLayer.path = path;
        [CATransaction commit];
    }
    else
    {
        self.waveformLayer.path = path;
    }
    CGPathRelease(path);
}

//------------------------------------------------------------------------------

- (void)dumpPathToFile:(CGPathRef)path points:(CGPoint *)points pointCount:(UInt32)pointCount {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docDir = [paths objectAtIndex: 0];
    NSString* docFileCGPath = [docDir stringByAppendingPathComponent: @"CGPathWaveformDump"];
    NSString* docFileCGPoints = [docDir stringByAppendingPathComponent: @"CGPointsWaveformDump"];
    
    NSLog(@"Doing a dump of the CGPath at %@ and CGPoints at %@", docFileCGPath, docFileCGPoints);
    UIBezierPath *bezierPath = [UIBezierPath bezierPathWithCGPath:path];
    BOOL successCGPath = [NSKeyedArchiver archiveRootObject:bezierPath toFile:docFileCGPath];
    
    NSMutableArray<NSValue *> *pointArray = [[NSMutableArray alloc] initWithCapacity:pointCount];
    for (int i = 0; i < pointCount; i++) {
        CGPoint point = points[i];
        [pointArray addObject:[NSValue valueWithCGPoint:point]];
    }
    BOOL successCGPoints = [NSKeyedArchiver archiveRootObject:pointArray toFile:docFileCGPoints];

    if (successCGPath && successCGPoints) {
        NSLog(@"Successfull marshalled to disk");
    } else {
        NSLog(@"Failed to marshall the object to disk");
    }
    self.hasDumpedPointsOnce = YES;
}

- (UIBezierPath *)loadPathFromFile {
    NSString *docFile = [[NSBundle mainBundle] pathForResource:@"CGPathWaveformDump" ofType:@""];
    UIBezierPath *bezierPath = [NSKeyedUnarchiver unarchiveObjectWithFile:docFile];
    return bezierPath;
}

// The main method for actually drawing the graph....this takes the entire scratch buffer and
// graphs it.
- (CGPathRef)createPathWithPoints:(CGPoint *)points
                  pointCount:(UInt32)pointCount
                      inRect:(EZRect)rect
{
    CGMutablePathRef path = NULL;
    if (pointCount > 0)
    {
        if(_fadeout){
            float total = 0.0;
            for (int i = 0; i < pointCount; i++){
                total += points[i].y;
            }
            float avg = total / (float)pointCount;
            double opacityThreshold = 0.00001;
            double opacityVal = 1.0;
            if(fabs(avg) < opacityThreshold){
                opacityVal = pow(fabs(avg)/opacityThreshold,5);
            }
            [self updateColor:[self.originalColor colorWithAlphaComponent:(CGFloat)opacityVal]];
        }else{
            [self updateColor:self.originalColor];
        }
        path = CGPathCreateMutable();
        // Define the spacing between your x points (just evenly dividing out your width points by # of points to graph)
        double xscale = (rect.size.width) / ((float)self.pointCount);
        double halfHeight = floor(rect.size.height / 2.0);
        int deviceOriginFlipped = [self isDeviceOriginFlipped] ? -1 : 1;
        CGAffineTransform xf = CGAffineTransformIdentity;
        CGFloat translateY = 0.0f;
        if (!self.shouldCenterYAxis)
        {
#if TARGET_OS_IPHONE
            translateY = CGRectGetHeight(rect);
#elif TARGET_OS_MAC
            translateY = 0.0f;
#endif
        }
        else
        {
            translateY = halfHeight + rect.origin.y;
        }
        // Smart. Essentially dumping all of the coordinate changes into an affine matrix. then when we plot, we
        // just do it from origin 0,0. But then apply the transform matrix to move everything.
        xf = CGAffineTransformTranslate(xf, 0.0, translateY);
        double yScaleFactor = halfHeight;
        if (!self.shouldCenterYAxis)
        {
            yScaleFactor = 2.0 * halfHeight;
        }
        
        // After applying this transform, f(t = 1) where t is the time of our
        // first sample, would just be plotted as (1, f(1)) on our graph. After
        // applying the affine transform, (which in lldb right now shows me xscale = 5.68
        // and yscale = 160), it would turn into point (5.68, -160*f(1)). The -1 is to
        // handle the fact that origin in iOS is flipped from how we would graph shit
        // on a piece of paper. positive y takes us down, but we want to graph upwards!
        // I think our amplitude values our 0-1.0, so a value of 1 = -160 i.e halfway
        // the entire window size
        // Then the CGAffineTransformTranslate above handles centering the plot
        xf = CGAffineTransformScale(xf, xscale, deviceOriginFlipped * yScaleFactor);
        CGPathAddLines(path, &xf, self.points, self.pointCount);
        if (self.shouldMirror)
        {
            // To get the mirror effect, we just flip all the Y values
            xf = CGAffineTransformScale(xf, 1.0f, -1.0f);
            CGPathAddLines(path, &xf, self.points, self.pointCount);
        }
        if (self.shouldFill)
        {
            CGPathCloseSubpath(path);
        }
    }
    
    return path;
}

//------------------------------------------------------------------------------
#pragma mark - Update
//------------------------------------------------------------------------------

- (void)updateBuffer:(float *)buffer withBufferSize:(UInt32)bufferSize
{
    // append the buffer to the history. this basically shifts our window
    [EZAudioUtilities appendBufferRMS:buffer
                       withBufferSize:bufferSize
                        toHistoryInfo:self.historyInfo];

    // copy samples
    switch (self.plotType)
    {
        case EZPlotTypeBuffer:
            [self setSampleData:buffer
                         length:bufferSize];
            break;
        case EZPlotTypeRolling:
            // Setting the scratch window as the data to plot
            [self setSampleData:self.historyInfo->buffer
                         length:self.historyInfo->bufferSize];
            break;
        default:
            break;
    }

    // update drawing
    if (!self.shouldOptimizeForRealtimePlot)
    {
        [self redraw];
    }
}

//------------------------------------------------------------------------------

- (void)setSampleData:(float *)data length:(int)length
{
    CGPoint *points = self.points;
     for (int i = 0; i < length; i++)
    {
        points[i].x = i;
        points[i].y = data[i] * self.gain; // Note: a gain parameter...can use this for sizing
    }
    points[0].y = points[length - 1].y = 0.0f;
    self.pointCount = length;
}

//------------------------------------------------------------------------------
#pragma mark - Adjusting History Resolution
//------------------------------------------------------------------------------

- (int)rollingHistoryLength
{
    return self.historyInfo->bufferSize;
}

//------------------------------------------------------------------------------

- (int)setRollingHistoryLength:(int)historyLength
{
    self.historyInfo->bufferSize = MIN(EZAudioPlotDefaultMaxHistoryBufferLength, historyLength);
    return self.historyInfo->bufferSize;
}

//------------------------------------------------------------------------------
#pragma mark - Subclass
//------------------------------------------------------------------------------

- (int)defaultRollingHistoryLength
{
    return EZAudioPlotDefaultHistoryBufferLength;
}

//------------------------------------------------------------------------------

- (int)initialPointCount
{
    return 100;
}

//------------------------------------------------------------------------------

- (int)maximumRollingHistoryLength
{
    return EZAudioPlotDefaultMaxHistoryBufferLength;
}

//------------------------------------------------------------------------------
#pragma mark - Utility
//------------------------------------------------------------------------------

- (BOOL)isDeviceOriginFlipped
{
    BOOL isDeviceOriginFlipped = NO;
#if TARGET_OS_IPHONE
    isDeviceOriginFlipped = YES;
#elif TARGET_OS_MAC
#endif
    return isDeviceOriginFlipped;
}

//------------------------------------------------------------------------------
#pragma mark - EZAudioDisplayLinkDelegate
//------------------------------------------------------------------------------

- (void)displayLinkNeedsDisplay:(EZAudioDisplayLink *)displayLink
{
    [self redraw];
}

//------------------------------------------------------------------------------

@end

////------------------------------------------------------------------------------
#pragma mark - EZAudioPlotWaveformLayer (Implementation)
////------------------------------------------------------------------------------

@implementation EZAudioPlotWaveformLayer

- (id<CAAction>)actionForKey:(NSString *)event
{
    if ([event isEqualToString:@"path"])
    {
        if ([CATransaction disableActions])
        {
            return nil;
        }
        else
        {
            CABasicAnimation *animation = [CABasicAnimation animation];
            animation.timingFunction = [CATransaction animationTimingFunction];
            animation.duration = [CATransaction animationDuration];
            return animation;
        }
        return nil;
    }
    return [super actionForKey:event];
}

@end
