// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 drel4
#pragma once
#include <math.h>

// Match UIRectEdge without requiring UIKit in the geometry regression tests.
enum { DSBEdgeTop = 1, DSBEdgeLeft = 2, DSBEdgeBottom = 4, DSBEdgeRight = 8 };
static inline unsigned DSBStartingEdge(double x, double y, double tx, double ty,
                                     double minX, double minY, double width, double height) {
    x -= tx; y -= ty;
    unsigned edge = DSBEdgeTop;
    double best = fabs(y - minY), distance = fabs(x - minX);
    if (distance < best) { best = distance; edge = DSBEdgeLeft; }
    distance = fabs(x - minX - width);
    if (distance < best) { best = distance; edge = DSBEdgeRight; }
    distance = fabs(y - minY - height);
    if (distance < best) edge = DSBEdgeBottom;
    return edge;
}

// Near a corner, distance alone can choose an adjacent edge. Prefer the inward
// pan direction only when that boundary is also near the original touch.
static inline unsigned DSBPullEdge(double x, double y, double tx, double ty,
                                  double minX, double minY, double width, double height) {
    unsigned edge = DSBStartingEdge(x, y, 0, 0, minX, minY, width, height);
    double distances[4] = {fabs(y-minY), fabs(x-minX), fabs(y-minY-height), fabs(x-minX-width)};
    double best = distances[edge == DSBEdgeTop ? 0 : edge == DSBEdgeLeft ? 1 : edge == DSBEdgeBottom ? 2 : 3];
    unsigned direction = 0, index = 0;
    if (fabs(tx) > fabs(ty) && fabs(tx) > .5) {
        direction = tx > 0 ? DSBEdgeLeft : DSBEdgeRight;
        index = tx > 0 ? 1 : 3;
    } else if (fabs(ty) > .5) {
        direction = ty > 0 ? DSBEdgeTop : DSBEdgeBottom;
        index = ty > 0 ? 0 : 2;
    }
    return direction && distances[index] <= best + 12 ? direction : edge;
}

typedef struct {
    double width, height, centerX, centerY;
    double a, b, c, d;
} DSBTransientGeometry;

static inline DSBTransientGeometry DSBGeometryForEdge(unsigned edge, double minX, double minY,
                                                     double width, double height, double thickness) {
    DSBTransientGeometry g = {width, thickness, minX + width/2, minY + thickness/2, 1, 0, 0, 1};
    if (edge == DSBEdgeLeft) {
        g = (DSBTransientGeometry){height, thickness, minX + thickness/2, minY + height/2, 0, -1, 1, 0};
    } else if (edge == DSBEdgeRight) {
        g = (DSBTransientGeometry){height, thickness, minX + width - thickness/2, minY + height/2, 0, 1, -1, 0};
    } else if (edge == DSBEdgeBottom) {
        g = (DSBTransientGeometry){width, thickness, minX + width/2, minY + height - thickness/2, -1, 0, 0, -1};
    }
    return g;
}
