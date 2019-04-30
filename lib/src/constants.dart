import 'dart:math';

const double PI = pi;
const double M_1_PI = 1.0 / PI;
const double PI_2 = PI / 2.0;
const double PI_4 = PI / 4.0;
double SQRT2 = sqrt(2.0);
const double E = e;
const double MAX_ERROR = 1.0 / (1 << 51);
  // The 4 cells around the equator extend to +/-45 degrees latitude at the
  // midpoints of their top and bottom edges. The two cells covering the
  // poles extend down to +/-35.26 degrees at their vertices.
  // adding kMaxError (as opposed to the C version) because of asin and atan2
  // roundoff errors
  //const double POLE_MIN_LAT = asin(sqrt(1.0 / 3.0)) - MAX_ERROR;
  const double POLE_MIN_LAT =0.615479709  - MAX_ERROR;
  
const int MAX_LEVEL = 30;
