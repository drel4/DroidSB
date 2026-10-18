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
    // Portrait-aligned SpringBoard over both landscape app orientations.
    assert(DSBStartingEdge(45, 250, 44, 0, 0, 0, 320, 568) == DSBEdgeLeft);
    assert(DSBStartingEdge(270, 250, -49, 0, 0, 0, 320, 568) == DSBEdgeRight);
    // A large current translation must not replace the gesture's starting edge.
    assert(DSBStartingEdge(200, 280, 199, 0, 0, 0, 320, 568) == DSBEdgeLeft);
    // Already-oriented host: top remains top, no double rotation.
    assert(DSBStartingEdge(284, 40, 0, 39, 0, 0, 568, 320) == DSBEdgeTop);
    assert(DSBStartingEdge(284, 290, 0, -29, 0, 0, 568, 320) == DSBEdgeBottom);
    for (int width = 320; width <= 430; width++) {
        for (unsigned edge = 1; edge <= 8; edge *= 2) {
            check(edge, width, 568);
            check(edge, 568, width);
        }
    }
    return 0;
}
