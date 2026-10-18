// The clay implementation unit — clay.h is single-header; the C compiler
// (not translate-c) owns CLAY_IMPLEMENTATION. The .kz cImport brings in the
// declarations/types only.
#define CLAY_IMPLEMENTATION
#include "clay.h"

#include <CoreFoundation/CoreFoundation.h>
#include <CoreText/CoreText.h>

// Rendered-content measure — Core Text typographic bounds of the string at
// the requested point size (advance width, ascent+descent+leading height).
// Registered as clay's own MeasureTextFunction AND called directly by the
// clay:measure.text verb, so a spec walk and any future CLAY_TEXT element
// read the identical metric. The font is the system face — the same face
// metal's draw.text shapes through NSFont systemFontOfSize:, so measured
// boxes and drawn glyphs agree. If metal's text font ever becomes
// configurable this must become a shared measure bridge, not a twin.
Clay_Dimensions koru_clay_measure(const char *chars, int32_t len, double size) {
    Clay_Dimensions d = { 0.0f, 0.0f };
    if (!chars || len <= 0 || size <= 0.0) return d;
    CTFontRef font = CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, (CGFloat)size, NULL);
    if (!font) return d;
    CFStringRef str = CFStringCreateWithBytes(kCFAllocatorDefault,
        (const UInt8 *)chars, (CFIndex)len, kCFStringEncodingUTF8, false);
    if (!str) { CFRelease(font); return d; }
    const void *keys[] = { (const void *)kCTFontAttributeName };
    const void *vals[] = { font };
    CFDictionaryRef attrs = CFDictionaryCreate(kCFAllocatorDefault,
        keys, vals, 1,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFAttributedStringRef as = CFAttributedStringCreate(kCFAllocatorDefault, str, attrs);
    CTLineRef line = CTLineCreateWithAttributedString(as);
    CGFloat asc = 0, desc = 0, lead = 0;
    double w = CTLineGetTypographicBounds(line, &asc, &desc, &lead);
    d.width = (float)w;
    d.height = (float)(asc + desc + lead);
    CFRelease(line);
    CFRelease(as);
    CFRelease(attrs);
    CFRelease(str);
    CFRelease(font);
    return d;
}

static Clay_Dimensions koru_clay_measure_cb(Clay_StringSlice text,
        Clay_TextElementConfig *config, void *userData) {
    (void)userData;
    return koru_clay_measure(text.chars, text.length,
        config ? (double)config->fontSize : 12.0);
}

void koru_clay_install_measure(void) {
    Clay_SetMeasureTextFunction(koru_clay_measure_cb, NULL);
}
