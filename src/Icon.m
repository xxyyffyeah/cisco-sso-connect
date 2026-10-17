#import <AppKit/AppKit.h>
// Original geometric artwork, generated locally; no third-party logo assets.
int main(int argc,const char *argv[]) {
    @autoreleasepool {
        if (argc!=2) return 1;
        NSImage *image=[[NSImage alloc] initWithSize:NSMakeSize(1024,1024)];
        [image lockFocus];
        [NSColor.whiteColor setFill];NSRectFill(NSMakeRect(0,0,1024,1024));
        [[NSColor colorWithSRGBRed:0.08 green:0.32 blue:0.65 alpha:1] setStroke];
        NSBezierPath *chevron=[NSBezierPath bezierPath];
        chevron.lineWidth=72;chevron.lineCapStyle=NSLineCapStyleRound;chevron.lineJoinStyle=NSLineJoinStyleRound;
        [chevron moveToPoint:NSMakePoint(245,700)];[chevron lineToPoint:NSMakePoint(450,512)];
        [chevron lineToPoint:NSMakePoint(245,324)];[chevron stroke];
        NSBezierPath *cursor=[NSBezierPath bezierPath];
        cursor.lineWidth=72;cursor.lineCapStyle=NSLineCapStyleRound;
        [cursor moveToPoint:NSMakePoint(555,324)];[cursor lineToPoint:NSMakePoint(780,324)];[cursor stroke];
        [image unlockFocus];
        NSBitmapImageRep *rep=[[NSBitmapImageRep alloc] initWithData:image.TIFFRepresentation];
        return [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}]
            writeToFile:@(argv[1]) atomically:YES]?0:1;
    }
}
