// SPDX-License-Identifier: Apache-2.0
#include "DSBTransientGeometry.h"
#include <assert.h>

static void check(unsigned edge, double width, double height) {
    const double x = 11, y = 23, thickness = 20;
    DSBTransientGeometry g = DSBGeometryForEdge(edge, x, y, width, height, thickness);
    assert(g.height == thickness);
    assert(g.width == ((edge == DSBEdgeLeft || edge == DSBEdgeRight) ? height : width));
    assert(g.a*g.d - g.b*g.c == 1); // rotation, not mirror or scale
    for (int i = 0; i < 4; i++) {
        double u = (i & 1 ? 1 : -1) * g.width/2;
        double v = (i & 2 ? 1 : -1) * g.height/2;
        double px = g.centerX + g.a*u + g.c*v;
        double py = g.centerY + g.b*u + g.d*v;
        assert(px >= x && px <= x + width);
        assert(py >= y && py <= y + height);
    }
    // The outer edge is flush with the touched boundary. Sliding toward local
    // -Y must leave the display through that boundary in either landscape.
    double outerX = g.centerX - g.c*g.height/2;
    double outerY = g.centerY - g.d*g.height/2;
    if (edge == DSBEdgeTop) { assert(outerY == y && g.d == 1); }
    if (edge == DSBEdgeBottom) { assert(outerY == y + height && g.d == -1); }
    if (edge == DSBEdgeLeft) { assert(outerX == x && g.c == 1 && g.b == -1); }
    if (edge == DSBEdgeRight) { assert(outerX == x + width && g.c == -1 && g.b == 1); }
}

int main(void) {
    // The former nearest-boundary/pan-direction heuristic selected side bars
    // for portrait corner pulls. Portrait MUST remain top for every X, even
    // directly on the side boundary; there is no pan direction input anymore.
    for (int x = 0; x <= 320; x++) {
        assert(DSBDisplayTopEdge(false, false, x, 160) == DSBEdgeTop);
        assert(DSBDisplayTopEdge(false, true, x, 160) == DSBEdgeBottom);
    }
    // Landscape top spans the fixed screen's left OR right boundary. Its
    // along-edge position cannot change the selected edge, including corners.
    for (int inset = 0; inset <= 40; inset++) {
        assert(DSBDisplayTopEdge(true, false, inset, 160) == DSBEdgeLeft);
        assert(DSBDisplayTopEdge(true, false, 320-inset, 160) == DSBEdgeRight);
    }
    for (int width = 320; width <= 430; width++) {
        for (unsigned edge = 1; edge <= 8; edge *= 2) {
            check(edge, width, 568);
            check(edge, 568, width);
        }
    }
    return 0;
}
