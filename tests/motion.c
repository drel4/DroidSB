// SPDX-License-Identifier: Apache-2.0
#include "DSBPrivacyMotion.h"
#include <assert.h>
int main(void) {
    assert(DSBTransientDuration(1)==.275 && DSBTransientDuration(0)==.340);
    double middle = DSBBezier(.5,.4,0,.2,1);
    assert(middle > .77 && middle < .78); // standard inset curve, not linear
    assert(DSBTransientOffset(0,40,-40,1)==-40);
    assert(DSBTransientOffset(1,40,-40,1)==0);
    assert(DSBTransientOffset(0,40,0,0)==0);
    assert(DSBTransientOffset(1,40,0,0)==-40);
    assert(DSBTransientOffset(0,40,-17,0)==-17); // interrupt without endpoint snap
    double prior=-40;
    for(int i=0;i<=1000;i++) {
        double y=DSBTransientOffset(i/1000.0,40,-40,1);
        assert(y>=prior && y>=-40 && y<=0 && y==(int)y); prior=y;
    }
    DSBPrivacyFrame a=DSBPrivacyAt(0,42,18);
    assert(a.alpha==0 && a.contentAlpha==0 && a.chromeAlpha==1);
    a=DSBPrivacyAt(.6,42,18);
    assert(a.width==42 && a.alpha==1 && a.contentAlpha==1 && a.chromeAlpha==0);
    a=DSBPrivacyAt(3.5,42,18); assert(a.width==42 && a.height==18);
    a=DSBPrivacyAt(DSB_PRIVACY_TIMELINE_SECONDS,42,18);
    assert(a.width==6 && a.height==6 && a.shift==6 && a.chromeAlpha==1 && a.chromeShift==0);
    for(int i=0;i<=4100;i++) {
        a=DSBPrivacyAt(i/1000.0,42,18);
        assert(a.width>=6 && a.width<=42 && a.height>=6 && a.height<=18);
        assert(a.alpha>=0 && a.alpha<=1 && a.contentAlpha>=0 && a.contentAlpha<=1);
        assert(a.chromeAlpha>=0 && a.chromeAlpha<=1);
    }
    return 0;
}
