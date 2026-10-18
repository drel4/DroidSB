// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 makr (LineageQS); modified for DroidSB by drel4.
// SVG path parser extracted from LineageQS; no theme/rendering dependencies.
#import "DSBPath.h"
typedef struct {
    const char *s;
    size_t i, n;
} LQSScanner;

static void SkipSeparators(LQSScanner *sc) {
    while (sc->i < sc->n) {
        char c = sc->s[sc->i];
        if (c == ' ' || c == ',' || c == '\n' || c == '\t' || c == '\r') sc->i++;
        else break;
    }
}

static BOOL ReadNumber(LQSScanner *sc, CGFloat *out) {
    SkipSeparators(sc);
    size_t start = sc->i;
    if (sc->i < sc->n && (sc->s[sc->i] == '-' || sc->s[sc->i] == '+')) sc->i++;
    BOOL digits = NO, dot = NO;
    while (sc->i < sc->n) {
        char c = sc->s[sc->i];
        if (c >= '0' && c <= '9') { digits = YES; sc->i++; }
        else if (c == '.' && !dot) { dot = YES; sc->i++; }
        else break;
    }
    if (digits && sc->i < sc->n && (sc->s[sc->i] == 'e' || sc->s[sc->i] == 'E')) {
        size_t save = sc->i++;
        if (sc->i < sc->n && (sc->s[sc->i] == '-' || sc->s[sc->i] == '+')) sc->i++;
        BOOL expDigits = NO;
        while (sc->i < sc->n && sc->s[sc->i] >= '0' && sc->s[sc->i] <= '9') { sc->i++; expDigits = YES; }
        if (!expDigits) sc->i = save;
    }
    if (!digits) { sc->i = start; return NO; }
    char buf[64];
    size_t len = MIN(sc->i - start, sizeof(buf) - 1);
    memcpy(buf, sc->s + start, len);
    buf[len] = 0;
    *out = (CGFloat)strtod(buf, NULL);
    return YES;
}

// Arc flags may be written without separators ("a1 1 0 011 1").
static BOOL ReadFlag(LQSScanner *sc, CGFloat *out) {
    SkipSeparators(sc);
    if (sc->i < sc->n && (sc->s[sc->i] == '0' || sc->s[sc->i] == '1')) {
        *out = sc->s[sc->i] == '1';
        sc->i++;
        return YES;
    }
    return NO;
}

static void AddArc(CGMutablePathRef path, CGPoint p0, CGFloat rx, CGFloat ry, CGFloat angleDeg,
                   BOOL largeArc, BOOL sweep, CGPoint p1) {
    if (CGPointEqualToPoint(p0, p1)) return;
    rx = fabs(rx); ry = fabs(ry);
    if (rx == 0 || ry == 0) { CGPathAddLineToPoint(path, NULL, p1.x, p1.y); return; }
    CGFloat phi = angleDeg * M_PI / 180.0, cphi = cos(phi), sphi = sin(phi);
    CGFloat dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2;
    CGFloat x1p = cphi * dx + sphi * dy, y1p = -sphi * dx + cphi * dy;
    CGFloat lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
    if (lambda > 1) { CGFloat s = sqrt(lambda); rx *= s; ry *= s; }
    CGFloat num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p;
    CGFloat den = rx * rx * y1p * y1p + ry * ry * x1p * x1p;
    CGFloat coef = (den == 0) ? 0 : sqrt(MAX(0, num / den));
    if (largeArc == sweep) coef = -coef;
    CGFloat cxp = coef * rx * y1p / ry, cyp = -coef * ry * x1p / rx;
    CGFloat cx = cphi * cxp - sphi * cyp + (p0.x + p1.x) / 2;
    CGFloat cy = sphi * cxp + cphi * cyp + (p0.y + p1.y) / 2;
    CGFloat ux = (x1p - cxp) / rx, uy = (y1p - cyp) / ry;
    CGFloat vx = (-x1p - cxp) / rx, vy = (-y1p - cyp) / ry;
    CGFloat theta1 = atan2(uy, ux);
    CGFloat dtheta = atan2(ux * vy - uy * vx, ux * vx + uy * vy);
    if (!sweep && dtheta > 0) dtheta -= 2 * M_PI;
    else if (sweep && dtheta < 0) dtheta += 2 * M_PI;
    int segs = (int)ceil(fabs(dtheta) / (M_PI / 2));
    CGFloat delta = dtheta / segs;
    CGFloat t = 4.0 / 3.0 * tan(delta / 4);
    CGFloat th = theta1;
    for (int k = 0; k < segs; k++) {
        CGFloat c1 = cos(th), s1 = sin(th), c2 = cos(th + delta), s2 = sin(th + delta);
        CGPoint e1 = CGPointMake(c1 - t * s1, s1 + t * c1);
        CGPoint e2 = CGPointMake(c2 + t * s2, s2 - t * c2);
        CGPoint e3 = CGPointMake(c2, s2);
        CGPoint pts[3] = {e1, e2, e3};
        for (int j = 0; j < 3; j++) {
            CGFloat x = pts[j].x * rx, y = pts[j].y * ry;
            pts[j] = CGPointMake(cphi * x - sphi * y + cx, sphi * x + cphi * y + cy);
        }
        CGPathAddCurveToPoint(path, NULL, pts[0].x, pts[0].y, pts[1].x, pts[1].y, pts[2].x, pts[2].y);
        th += delta;
    }
}

static BOOL NextIsCommand(LQSScanner *sc) {
    SkipSeparators(sc);
    if (sc->i >= sc->n) return YES;
    char c = sc->s[sc->i];
    return (c >= 'A' && c <= 'Z' && c != 'E') || (c >= 'a' && c <= 'z' && c != 'e');
}

static CGPathRef NewPathFromCString(const char *str, size_t n) {
    CGMutablePathRef path = CGPathCreateMutable();
    LQSScanner sc = {str, 0, n};
    char cmd = 0;
    CGPoint cur = CGPointZero, start = CGPointZero, lastCtrl = CGPointZero;
    char prev = 0;
    while (1) {
        SkipSeparators(&sc);
        if (sc.i >= sc.n) break;
        char c = sc.s[sc.i];
        if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')) { cmd = c; sc.i++; }
        else if (!cmd) { sc.i++; continue; } // stray token
        BOOL rel = (cmd >= 'a');
        char up = rel ? cmd - 32 : cmd;
        CGFloat v[7];
        switch (up) {
            case 'Z':
                CGPathCloseSubpath(path);
                cur = start;
                prev = 'Z';
                cmd = 0; // Z takes no arguments; next token must be a command
                continue;
            case 'M':
                if (!ReadNumber(&sc, &v[0]) || !ReadNumber(&sc, &v[1])) { if (NextIsCommand(&sc)) goto skipcmd; goto done; }
                cur = rel ? CGPointMake(cur.x + v[0], cur.y + v[1]) : CGPointMake(v[0], v[1]);
                CGPathMoveToPoint(path, NULL, cur.x, cur.y);
                start = cur;
                cmd = rel ? 'l' : 'L'; // implicit lineto after moveto
                break;
            case 'L':
                if (!ReadNumber(&sc, &v[0]) || !ReadNumber(&sc, &v[1])) { if (NextIsCommand(&sc)) goto skipcmd; goto done; }
                cur = rel ? CGPointMake(cur.x + v[0], cur.y + v[1]) : CGPointMake(v[0], v[1]);
                CGPathAddLineToPoint(path, NULL, cur.x, cur.y);
                break;
            case 'H':
                if (!ReadNumber(&sc, &v[0])) { if (NextIsCommand(&sc)) goto skipcmd; goto done; }
                cur.x = rel ? cur.x + v[0] : v[0];
                CGPathAddLineToPoint(path, NULL, cur.x, cur.y);
                break;
            case 'V':
                if (!ReadNumber(&sc, &v[0])) { if (NextIsCommand(&sc)) goto skipcmd; goto done; }
                cur.y = rel ? cur.y + v[0] : v[0];
                CGPathAddLineToPoint(path, NULL, cur.x, cur.y);
                break;
            case 'C': {
                for (int k = 0; k < 6; k++) if (!ReadNumber(&sc, &v[k])) { if (NextIsCommand(&sc)) goto skipcmd; goto done; }
                CGFloat ox = rel ? cur.x : 0, oy = rel ? cur.y : 0;
                CGPathAddCurveToPoint(path, NULL, ox + v[0], oy + v[1], ox + v[2], oy + v[3], ox + v[4], oy + v[5]);
                lastCtrl = CGPointMake(ox + v[2], oy + v[3]);
                cur = CGPointMake(ox + v[4], oy + v[5]);
                prev = 'C';
                continue;
            }
            case 'S': {
                for (int k = 0; k < 4; k++) if (!ReadNumber(&sc, &v[k])) { if (NextIsCommand(&sc)) goto skipcmd; goto done; }
                CGFloat ox = rel ? cur.x : 0, oy = rel ? cur.y : 0;
                CGPoint c1 = (prev == 'C') ? CGPointMake(2 * cur.x - lastCtrl.x, 2 * cur.y - lastCtrl.y) : cur;
                CGPathAddCurveToPoint(path, NULL, c1.x, c1.y, ox + v[0], oy + v[1], ox + v[2], oy + v[3]);
                lastCtrl = CGPointMake(ox + v[0], oy + v[1]);
                cur = CGPointMake(ox + v[2], oy + v[3]);
                prev = 'C';
                continue;
            }
            case 'Q': {
                for (int k = 0; k < 4; k++) if (!ReadNumber(&sc, &v[k])) { if (NextIsCommand(&sc)) goto skipcmd; goto done; }
                CGFloat ox = rel ? cur.x : 0, oy = rel ? cur.y : 0;
                CGPathAddQuadCurveToPoint(path, NULL, ox + v[0], oy + v[1], ox + v[2], oy + v[3]);
                lastCtrl = CGPointMake(ox + v[0], oy + v[1]);
                cur = CGPointMake(ox + v[2], oy + v[3]);
                prev = 'Q';
                continue;
            }
            case 'T': {
                for (int k = 0; k < 2; k++) if (!ReadNumber(&sc, &v[k])) { if (NextIsCommand(&sc)) goto skipcmd; goto done; }
                CGFloat ox = rel ? cur.x : 0, oy = rel ? cur.y : 0;
                CGPoint c1 = (prev == 'Q') ? CGPointMake(2 * cur.x - lastCtrl.x, 2 * cur.y - lastCtrl.y) : cur;
                CGPathAddQuadCurveToPoint(path, NULL, c1.x, c1.y, ox + v[0], oy + v[1]);
                lastCtrl = c1;
                cur = CGPointMake(ox + v[0], oy + v[1]);
                prev = 'Q';
                continue;
            }
            case 'A': {
                if (!ReadNumber(&sc, &v[0]) || !ReadNumber(&sc, &v[1]) || !ReadNumber(&sc, &v[2]) ||
                    !ReadFlag(&sc, &v[3]) || !ReadFlag(&sc, &v[4]) || !ReadNumber(&sc, &v[5]) || !ReadNumber(&sc, &v[6])) { if (NextIsCommand(&sc)) goto skipcmd; goto done; }
                CGPoint end = rel ? CGPointMake(cur.x + v[5], cur.y + v[6]) : CGPointMake(v[5], v[6]);
                AddArc(path, cur, v[0], v[1], v[2], v[3] != 0, v[4] != 0, end);
                cur = end;
                break;
            }
            default:
                cmd = 0;
                continue;
        }
        prev = up;
        continue;
    skipcmd:
        // Android PathParser accepts a command letter with no arguments
        // (e.g. Lottie-exported "...28.25c M31.94 ..."): it adds nothing.
        cmd = 0;
    }
done:
    return path;
}


CGPathRef DSBCreatePath(NSString *d) {
    if (![d isKindOfClass:NSString.class] || !d.length) return NULL;
    const char *c = d.UTF8String;
    return NewPathFromCString(c, strlen(c));
}
