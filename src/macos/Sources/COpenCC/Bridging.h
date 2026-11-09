#ifndef JIANFAN_CONV_BRIDGING_H
#define JIANFAN_CONV_BRIDGING_H

/*
 * Bridging header for the Swift targets. It exposes the OpenCC C API only;
 * the C++ section of opencc.h is skipped because Objective-C/Swift compile
 * this header without __cplusplus.
 */
#include "opencc.h"

#endif /* JIANFAN_CONV_BRIDGING_H */
