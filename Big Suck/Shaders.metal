//
//  Shaders.metal
//  Big Suck
//
//  Created by Izzy Fraimow on 5/5/24.
//

#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Math adapted from https://people.csail.mit.edu/jaffer/Marbling/

/*
 C + (P − C) · sqrt( 1 - (r2 / ||P − C||^2)
 */

[[ stitchable ]] float2 discWarp(float2 position, float2 size, float radius, float2 center) {
    float2 p = position - center;
    float m = length(p);
    if (m < radius) {
        return position;
    }

    float root = sqrt(1.0 - (radius * radius) / (m * m));
    p = p * root;
    p = p + center;
    
    return p;
}

/*
 h = ||P−C||             l = (z·u^−r) · u^h             a =    l/h

 
 C + (P − C)· ( cos a   sin a
               −sin a  cos a )
 */


[[ stitchable ]] float2 swirl(float2 position, float2 size, float radius, float2 center) {
    float2 p = position - center;
    float h = length(p);
    float z = 20.0;
    float u = 1.0;
    float l = (z * pow(u, -radius)) * pow(u, h);
    float a = l/h;
    float cos = metal::cos(a);
    float sin = metal::sin(a);

    float2x2 matrix = float2x2(cos, -sin, sin, cos);
    p = p * matrix;
    p = p + center;
    
    return p;
}
